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


class RoomType(str, enum.Enum):
    bedroom = "bedroom"
    bathroom = "bathroom"
    kitchen = "kitchen"
    living = "living"
    dining = "dining"
    balcony = "balcony"
    patio = "patio"
    laundry = "laundry"
    other = "other"


class ObjectSource(str, enum.Enum):
    manual = "manual"
    ai = "ai"


class Room(Base):
    __tablename__ = "rooms"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    household_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("households.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    type: Mapped[RoomType] = mapped_column(Enum(RoomType, name="room_type"))
    floor: Mapped[str | None] = mapped_column(String(40), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    household: Mapped["Household"] = relationship()
    objects: Mapped[list["RoomObject"]] = relationship(
        back_populates="room", cascade="all, delete-orphan"
    )


class RoomObject(Base):
    __tablename__ = "room_objects"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    room_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("rooms.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    source: Mapped[ObjectSource] = mapped_column(
        Enum(ObjectSource, name="object_source"), default=ObjectSource.manual
    )
    confirmed: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    room: Mapped[Room] = relationship(back_populates="objects")
