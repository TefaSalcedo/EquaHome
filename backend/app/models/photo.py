import enum
import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Enum, ForeignKey, String
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base
from app.models.user import utcnow

if TYPE_CHECKING:
    from app.models.household import Household, HouseholdMember
    from app.models.room import Room


class PhotoPurpose(str, enum.Enum):
    room_scan = "room_scan"  # detectar objetos de una habitación
    daily_check = "daily_check"  # estado general del día, sin culpar


class AIStatus(str, enum.Enum):
    none = "none"
    done = "done"
    failed = "failed"


class Photo(Base):
    __tablename__ = "photos"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    household_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("households.id", ondelete="CASCADE"), index=True
    )
    room_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("rooms.id", ondelete="SET NULL"), nullable=True
    )
    member_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("household_members.id", ondelete="SET NULL"), nullable=True
    )
    storage_key: Mapped[str] = mapped_column(String(255), nullable=False)
    content_type: Mapped[str] = mapped_column(String(64), nullable=False)
    purpose: Mapped[PhotoPurpose] = mapped_column(
        Enum(PhotoPurpose, name="photo_purpose"), default=PhotoPurpose.room_scan
    )
    ai_status: Mapped[AIStatus] = mapped_column(
        Enum(AIStatus, name="ai_status"), default=AIStatus.none
    )
    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )

    household: Mapped["Household"] = relationship()
    room: Mapped["Room | None"] = relationship()
    member: Mapped["HouseholdMember | None"] = relationship()
    analysis: Mapped["AIAnalysis | None"] = relationship(
        back_populates="photo", cascade="all, delete-orphan"
    )


class AIAnalysis(Base):
    """Resultado de IA sobre una foto. Siempre corregible por la persona."""

    __tablename__ = "ai_analyses"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    photo_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("photos.id", ondelete="CASCADE"), unique=True, index=True
    )
    provider: Mapped[str] = mapped_column(String(64), nullable=False)
    model: Mapped[str | None] = mapped_column(String(64), nullable=True)
    summary: Mapped[str] = mapped_column(String(500), nullable=False)
    raw_json: Mapped[dict] = mapped_column(JSONB, nullable=False)
    confirmed_by_user: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )

    photo: Mapped[Photo] = relationship(back_populates="analysis")
