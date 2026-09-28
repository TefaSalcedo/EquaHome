import uuid
from datetime import datetime

from pydantic import BaseModel

from app.models.photo import AIStatus, PhotoPurpose


class DetectedObjectIn(BaseModel):
    name: str
    quantity: int = 1


class AnalysisOut(BaseModel):
    id: uuid.UUID
    provider: str
    model: str | None
    summary: str
    objects: list[DetectedObjectIn]
    confirmed_by_user: bool


class PhotoOut(BaseModel):
    id: uuid.UUID
    room_id: uuid.UUID | None
    room_name: str | None
    purpose: PhotoPurpose
    ai_status: AIStatus
    uploaded_at: datetime
    file_url: str
    analysis: AnalysisOut | None


class ConfirmIn(BaseModel):
    """La persona corrige los objetos detectados antes de guardarlos."""

    objects: list[DetectedObjectIn] = []
