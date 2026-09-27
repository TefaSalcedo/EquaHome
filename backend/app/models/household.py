import enum
import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Enum, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base
from app.models.user import utcnow

if TYPE_CHECKING:
    from app.models.user import User


class MemberRole(str, enum.Enum):
    owner = "owner"
    member = "member"


class MemberType(str, enum.Enum):
    adult = "adult"
    child = "child"


class InviteStatus(str, enum.Enum):
    active = "active"
    used = "used"
    revoked = "revoked"


class Household(Base):
    __tablename__ = "households"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    timezone: Mapped[str] = mapped_column(String(64), default="America/Bogota")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    members: Mapped[list["HouseholdMember"]] = relationship(
        back_populates="household", cascade="all, delete-orphan"
    )
    invitations: Mapped[list["HouseholdInvitation"]] = relationship(
        back_populates="household", cascade="all, delete-orphan"
    )


class HouseholdMember(Base):
    __tablename__ = "household_members"
    __table_args__ = (UniqueConstraint("household_id", "user_id", name="uq_member_household_user"),)

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    household_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("households.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    role: Mapped[MemberRole] = mapped_column(
        Enum(MemberRole, name="member_role"), default=MemberRole.member
    )
    member_type: Mapped[MemberType] = mapped_column(
        Enum(MemberType, name="member_type"), default=MemberType.adult
    )
    capacity_factor: Mapped[float] = mapped_column(Float, default=1.0)
    weekly_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    days_available: Mapped[list | None] = mapped_column(JSONB, nullable=True)
    is_primary: Mapped[bool] = mapped_column(default=False)
    room_scope: Mapped[list | None] = mapped_column(JSONB, nullable=True)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    household: Mapped[Household] = relationship(back_populates="members")
    user: Mapped["User"] = relationship(back_populates="memberships")


class HouseholdInvitation(Base):
    __tablename__ = "household_invitations"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    household_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("households.id", ondelete="CASCADE"), index=True
    )
    inviter_member_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("household_members.id", ondelete="CASCADE")
    )
    code: Mapped[str] = mapped_column(String(16), unique=True, index=True)
    status: Mapped[InviteStatus] = mapped_column(
        Enum(InviteStatus, name="invite_status"), default=InviteStatus.active
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    used_by_member_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("household_members.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    household: Mapped[Household] = relationship(back_populates="invitations")
