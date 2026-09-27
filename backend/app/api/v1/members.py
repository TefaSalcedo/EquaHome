import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_membership
from app.core.db import get_db
from app.models.household import HouseholdMember, MemberRole
from app.models.user import User
from app.schemas.auth import UserOut
from app.schemas.household import MemberProfileUpdate, MembershipOut

router = APIRouter(prefix="/members", tags=["members"])


def _membership_out(m: HouseholdMember) -> MembershipOut:
    return MembershipOut(
        household_id=m.household_id,
        household_name=m.household.name,
        role=m.role,
        member_type=m.member_type,
        capacity_factor=m.capacity_factor,
        is_primary=m.is_primary,
        weekly_minutes=m.weekly_minutes,
        days_available=m.days_available,
        room_scope=m.room_scope,
    )


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user


@router.get("/me/households", response_model=list[MembershipOut])
def my_households(user: User = Depends(get_current_user)):
    return [_membership_out(m) for m in user.memberships]


@router.patch("/me/households/{household_id}/primary", response_model=list[MembershipOut])
def set_primary(
    household_id: uuid.UUID,
    user: User = Depends(get_current_user),
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    for m in user.memberships:
        m.is_primary = m.id == membership.id
    db.commit()
    return [_membership_out(m) for m in user.memberships]


@router.patch("/me/households/{household_id}/profile", response_model=MembershipOut)
def update_member_profile(
    body: MemberProfileUpdate,
    household_id: uuid.UUID,
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    data = body.model_dump(exclude_unset=True)
    if "member_type" in data:
        membership.member_type = data["member_type"]
    if "capacity_factor" in data:
        membership.capacity_factor = data["capacity_factor"]
    if "weekly_minutes" in data:
        membership.weekly_minutes = data["weekly_minutes"]
    if "days_available" in data:
        membership.days_available = data["days_available"]
    if "room_scope" in data:
        membership.room_scope = data["room_scope"]
    db.commit()
    return _membership_out(membership)


@router.delete("/me/households/{household_id}", status_code=204)
def leave_household(
    household_id: uuid.UUID,
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    if membership.role == MemberRole.owner:
        owners = [m for m in membership.household.members if m.role == MemberRole.owner]
        if len(owners) == 1 and len(membership.household.members) > 1:
            raise HTTPException(409, "Transfer ownership before leaving a household with other members")
    db.delete(membership)
    db.commit()
