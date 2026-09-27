import enum
import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base
from app.models.user import utcnow

if TYPE_CHECKING:
    from app.models.household import Household
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
