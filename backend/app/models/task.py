import enum
import uuid
from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base
from app.models.user import utcnow

if TYPE_CHECKING:
    from app.models.household import Household, HouseholdMember
    from app.models.room import Room


class Effort(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"


class Frequency(str, enum.Enum):
    daily = "daily"
    weekly = "weekly"
    monthly = "monthly"
    once = "once"


class TaskCategory(str, enum.Enum):
    cleaning = "cleaning"
    kitchen = "kitchen"
    laundry = "laundry"
    bathroom = "bathroom"
    organization = "organization"
    outdoor = "outdoor"
    general = "general"


# Ponderación de la carga: el esfuerzo multiplica los minutos estimados.
EFFORT_WEIGHT: dict[Effort, float] = {
    Effort.low: 1.0,
    Effort.medium: 1.15,
    Effort.high: 1.35,
}


class TaskTemplate(Base):
    __tablename__ = "task_templates"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    household_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("households.id", ondelete="CASCADE"), index=True
    )
    room_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("rooms.id", ondelete="SET NULL"), nullable=True
    )
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    category: Mapped[TaskCategory] = mapped_column(
        Enum(TaskCategory, name="task_category"), default=TaskCategory.general
    )
    base_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    effort: Mapped[Effort] = mapped_column(
        Enum(Effort, name="effort"), default=Effort.medium
    )
    frequency: Mapped[Frequency] = mapped_column(
        Enum(Frequency, name="frequency"), default=Frequency.weekly
    )
    preferred_weekday: Mapped[int | None] = mapped_column(Integer, nullable=True)
    active: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    household: Mapped["Household"] = relationship()
    room: Mapped["Room | None"] = relationship()
    conditions: Mapped[list["TaskCondition"]] = relationship(
        back_populates="template", cascade="all, delete-orphan"
    )

    @property
    def estimated_minutes(self) -> int:
        extra = sum(c.extra_minutes for c in self.conditions if c.applies)
        return self.base_minutes + extra

    @property
    def weighted_minutes(self) -> float:
        return self.estimated_minutes * EFFORT_WEIGHT[self.effort]


class TaskCondition(Base):
    __tablename__ = "task_conditions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    template_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("task_templates.id", ondelete="CASCADE"), index=True
    )
    label: Mapped[str] = mapped_column(String(160), nullable=False)
    extra_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    applies: Mapped[bool] = mapped_column(default=False)

    template: Mapped[TaskTemplate] = relationship(back_populates="conditions")


class TaskStatus(str, enum.Enum):
    pending = "pending"
    selected = "selected"
    done = "done"
    skipped = "skipped"
    carried_over = "carried_over"


class TaskOrigin(str, enum.Enum):
    template = "template"
    extra = "extra"
    manual = "manual"


class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    household_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("households.id", ondelete="CASCADE"), index=True
    )
    template_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("task_templates.id", ondelete="SET NULL"), nullable=True
    )
    room_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("rooms.id", ondelete="SET NULL"), nullable=True
    )
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    estimated_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    effort: Mapped[Effort] = mapped_column(
        Enum(Effort, name="effort", create_type=False), default=Effort.medium
    )
    category: Mapped[TaskCategory] = mapped_column(
        Enum(TaskCategory, name="task_category", create_type=False),
        default=TaskCategory.general,
    )
    scheduled_date: Mapped[date] = mapped_column(Date, index=True)
    # Fecha original para deduplicar materializaciones: el carry-over mueve
    # scheduled_date pero esta se conserva.
    first_scheduled_date: Mapped[date] = mapped_column(Date)
    status: Mapped[TaskStatus] = mapped_column(
        Enum(TaskStatus, name="task_status"), default=TaskStatus.pending
    )
    origin: Mapped[TaskOrigin] = mapped_column(
        Enum(TaskOrigin, name="task_origin"), default=TaskOrigin.manual
    )
    carried_from_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True
    )
    created_by_member_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("household_members.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    household: Mapped["Household"] = relationship()
    room: Mapped["Room | None"] = relationship()
    assignments: Mapped[list["TaskAssignment"]] = relationship(
        back_populates="task", cascade="all, delete-orphan"
    )

    @property
    def weighted_minutes(self) -> float:
        return self.estimated_minutes * EFFORT_WEIGHT[self.effort]


class TaskAssignment(Base):
    """La persona elige la tarea: la app propone, nunca asigna sola."""

    __tablename__ = "task_assignments"
    __table_args__ = (
        UniqueConstraint("task_id", "member_id", name="uq_assignment_task_member"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    task_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tasks.id", ondelete="CASCADE"), index=True
    )
    member_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("household_members.id", ondelete="CASCADE"), index=True
    )
    selected_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    task: Mapped[Task] = relationship(back_populates="assignments")
    member: Mapped["HouseholdMember"] = relationship()


class PreferenceKind(str, enum.Enum):
    like = "like"
    dislike = "dislike"
    cannot_do = "cannot_do"


class TaskPreference(Base):
    """Preferencia de un miembro sobre una plantilla o una categoría."""

    __tablename__ = "task_preferences"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    member_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("household_members.id", ondelete="CASCADE"), index=True
    )
    kind: Mapped[PreferenceKind] = mapped_column(
        Enum(PreferenceKind, name="preference_kind")
    )
    template_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("task_templates.id", ondelete="CASCADE"), nullable=True
    )
    category: Mapped[TaskCategory | None] = mapped_column(
        Enum(TaskCategory, name="task_category", create_type=False), nullable=True
    )

    member: Mapped["HouseholdMember"] = relationship()
    template: Mapped[TaskTemplate | None] = relationship()
