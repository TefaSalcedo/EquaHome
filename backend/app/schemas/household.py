import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.household import MemberRole, MemberType


class HouseholdCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    timezone: str = Field(default="America/Bogota", max_length=64)


class MemberOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    display_name: str
    role: MemberRole
    member_type: MemberType
    capacity_factor: float
    is_primary: bool
    joined_at: datetime


class HouseholdOut(BaseModel):
    id: uuid.UUID
    name: str
    timezone: str
    member_count: int


class HouseholdDetail(BaseModel):
    id: uuid.UUID
    name: str
    timezone: str
    members: list[MemberOut]


class MembershipOut(BaseModel):
    id: uuid.UUID
    household_id: uuid.UUID
    household_name: str
    role: MemberRole
    member_type: MemberType
    capacity_factor: float
    is_primary: bool
    weekly_minutes: int | None
    days_available: list[int] | None
    room_scope: list[str] | None


class JoinRequest(BaseModel):
    code: str = Field(min_length=4, max_length=16)


class MemberProfileUpdate(BaseModel):
    member_type: MemberType | None = None
    capacity_factor: float | None = Field(default=None, ge=0.1, le=1.0)
    weekly_minutes: int | None = Field(default=None, ge=0)
    days_available: list[int] | None = None
    room_scope: list[str] | None = None


class InvitationOut(BaseModel):
    code: str
    expires_at: datetime
