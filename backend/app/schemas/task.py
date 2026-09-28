import uuid
from datetime import date, datetime

from pydantic import BaseModel, Field, model_validator

from app.models.task import (
    Effort,
    Frequency,
    PreferenceKind,
    TaskCategory,
    TaskOrigin,
    TaskStatus,
)


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


# --- Fase 04: tareas concretas, selección voluntaria, preferencias y carga ---


class TaskCreate(BaseModel):
    """Crea una tarea puntual: desde una plantilla o extraordinaria."""

    template_id: uuid.UUID | None = None
    title: str | None = Field(default=None, min_length=1, max_length=160)
    estimated_minutes: int | None = Field(default=None, ge=1)
    effort: Effort | None = None
    category: TaskCategory | None = None
    room_id: uuid.UUID | None = None
    scheduled_date: date | None = None

    @model_validator(mode="after")
    def _require_data(self):
        if self.template_id is None and (self.title is None or self.estimated_minutes is None):
            raise ValueError("Indica una plantilla o título y minutos estimados")
        return self


class AssigneeOut(BaseModel):
    member_id: uuid.UUID
    display_name: str
    completed_at: datetime | None


class TaskOut(BaseModel):
    id: uuid.UUID
    title: str
    estimated_minutes: int
    weighted_minutes: float
    effort: Effort
    category: TaskCategory
    room_id: uuid.UUID | None
    room_name: str | None
    template_id: uuid.UUID | None
    scheduled_date: date
    status: TaskStatus
    origin: TaskOrigin
    carried_from_id: uuid.UUID | None
    assignees: list[AssigneeOut]


class PreferenceIn(BaseModel):
    kind: PreferenceKind
    template_id: uuid.UUID | None = None
    category: TaskCategory | None = None

    @model_validator(mode="after")
    def _one_target(self):
        if (self.template_id is None) == (self.category is None):
            raise ValueError("La preferencia apunta a una plantilla o a una categoría")
        return self


class PreferenceOut(PreferenceIn):
    id: uuid.UUID
    template_name: str | None = None


class MemberLoad(BaseModel):
    member_id: uuid.UUID
    display_name: str
    assigned_minutes: float
    expected_minutes: float | None
    difference_minutes: float | None
    weekly_minutes: int | None
    capacity_factor: float


class LoadSuggestion(BaseModel):
    member_id: uuid.UUID
    display_name: str
    deficit_minutes: float
    candidates: list[TaskOut]


class LoadOut(BaseModel):
    date: date
    single_member: bool
    total_minutes: float
    members: list[MemberLoad]
    suggestion: LoadSuggestion | None
    notice: str | None
