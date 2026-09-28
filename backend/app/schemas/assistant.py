from pydantic import BaseModel, Field


class InstructionIn(BaseModel):
    text: str = Field(min_length=1, max_length=500)


class ActionIn(BaseModel):
    """Acción propuesta por el asistente; el backend solo ejecuta tipos
    permitidos y siempre a nombre de quien confirma."""

    type: str
    title: str | None = None
    estimated_minutes: int | None = None


class InstructionOut(BaseModel):
    summary: str
    actions: list[ActionIn]


class ApplyIn(BaseModel):
    actions: list[ActionIn]


class ApplyOut(BaseModel):
    applied: list[str]
