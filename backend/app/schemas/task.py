import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.task import Effort, Frequency, TaskCategory


class ConditionIn(BaseModel):
    label: str = Field(min_length=1, max_length=160)
    extra_minutes: int = Field(ge=0)
    applies: bool = False


class ConditionOut(ConditionIn):
    id: uuid.UUID

    model_config = {"from_attributes": True}


class TaskTemplateCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    category: TaskCategory = TaskCategory.general
    room_id: uuid.UUID | None = None
    base_minutes: int = Field(ge=1)
    effort: Effort = Effort.medium
    frequency: Frequency = Frequency.weekly
    preferred_weekday: int | None = Field(default=None, ge=1, le=7)
    conditions: list[ConditionIn] = []


class TaskTemplateUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    category: TaskCategory | None = None
    room_id: uuid.UUID | None = None
    base_minutes: int | None = Field(default=None, ge=1)
    effort: Effort | None = None
    frequency: Frequency | None = None
    preferred_weekday: int | None = Field(default=None, ge=1, le=7)
    active: bool | None = None


class TaskTemplateOut(BaseModel):
    id: uuid.UUID
    name: str
    category: TaskCategory
    room_id: uuid.UUID | None
    room_name: str | None
    base_minutes: int
    effort: Effort
    effort_weight: float
    frequency: Frequency
    preferred_weekday: int | None
    active: bool
    conditions: list[ConditionOut]
    estimated_minutes: int
    weighted_minutes: float
    created_at: datetime
