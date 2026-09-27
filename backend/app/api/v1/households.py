import secrets
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_membership
from app.core.config import settings
from app.core.db import get_db
from app.models.household import (
    Household,
    HouseholdInvitation,
    HouseholdMember,
    InviteStatus,
    MemberRole,
)
from app.models.user import User
from app.schemas.household import (
    HouseholdCreate,
    HouseholdDetail,
    HouseholdOut,
    InvitationOut,
    JoinRequest,
    MemberOut,
)

router = APIRouter(prefix="/households", tags=["households"])


def _member_out(member: HouseholdMember) -> MemberOut:
    return MemberOut(
        id=member.id,
        user_id=member.user_id,
        display_name=member.user.display_name,
        role=member.role,
        member_type=member.member_type,
        capacity_factor=member.capacity_factor,
        is_primary=member.is_primary,
        joined_at=member.joined_at,
    )


@router.post("", response_model=HouseholdOut, status_code=status.HTTP_201_CREATED)
def create_household(
    body: HouseholdCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    household = Household(name=body.name.strip(), timezone=body.timezone)
    db.add(household)
    db.flush()
    membership = HouseholdMember(
        household_id=household.id,
        user_id=user.id,
        role=MemberRole.owner,
        is_primary=not user.memberships,
    )
    db.add(membership)
    db.commit()
    return HouseholdOut(
        id=household.id, name=household.name, timezone=household.timezone, member_count=1
    )


@router.get("/{household_id}", response_model=HouseholdDetail)
def get_household(
    membership: HouseholdMember = Depends(get_membership),
):
    household = membership.household
    return HouseholdDetail(
        id=household.id,
        name=household.name,
        timezone=household.timezone,
        members=[_member_out(m) for m in household.members],
    )


@router.post("/{household_id}/invitations", response_model=InvitationOut, status_code=status.HTTP_201_CREATED)
def create_invitation(
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    code = secrets.token_urlsafe(settings.invite_code_length)[: settings.invite_code_length]
    invitation = HouseholdInvitation(
        household_id=membership.household_id,
        inviter_member_id=membership.id,
        code=code,
        expires_at=datetime.now(UTC) + timedelta(days=settings.invite_expiry_days),
    )
    db.add(invitation)
    db.commit()
    return InvitationOut(code=invitation.code, expires_at=invitation.expires_at)


@router.post("/join", response_model=HouseholdOut, status_code=status.HTTP_201_CREATED)
def join_household(
    body: JoinRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    invitation = (
        db.query(HouseholdInvitation)
        .filter(HouseholdInvitation.code == body.code.strip())
        .first()
    )
    if invitation is None or invitation.status != InviteStatus.active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Invalid invite code")
    if invitation.expires_at < datetime.now(UTC):
        raise HTTPException(status.HTTP_410_GONE, "Invite code expired")

    household = invitation.household
    existing = next((m for m in household.members if m.user_id == user.id), None)
    if existing is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Already a member of this household")

    membership = HouseholdMember(
        household_id=household.id,
        user_id=user.id,
        role=MemberRole.member,
        is_primary=not user.memberships,
    )
    db.add(membership)
    db.flush()
    invitation.status = InviteStatus.used
    invitation.used_by_member_id = membership.id
    db.commit()
    member_count = db.scalar(
        select(func.count())
        .select_from(HouseholdMember)
        .where(HouseholdMember.household_id == household.id)
    )
    return HouseholdOut(
        id=household.id,
        name=household.name,
        timezone=household.timezone,
        member_count=member_count,
    )
