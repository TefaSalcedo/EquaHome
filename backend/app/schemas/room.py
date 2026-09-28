import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.room import ObjectSource, RoomType


class RoomCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    type: RoomType
    floor: str | None = Field(default=None, max_length=40)


class RoomUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    type: RoomType | None = None
    floor: str | None = Field(default=None, max_length=40)


class RoomObjectCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    quantity: int = Field(default=1, ge=1)


class RoomObjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    quantity: int | None = Field(default=None, ge=1)
    confirmed: bool | None = None


class RoomObjectOut(BaseModel):
    id: uuid.UUID
    name: str
    quantity: int
    source: ObjectSource
    confirmed: bool

    model_config = {"from_attributes": True}


class RoomOut(BaseModel):
    id: uuid.UUID
    name: str
    type: RoomType
    floor: str | None
    object_count: int
    created_at: datetime


class RoomDetail(BaseModel):
    id: uuid.UUID
    name: str
    type: RoomType
    floor: str | None
    objects: list[RoomObjectOut]
