import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_membership
from app.core.db import get_db
from app.models.household import HouseholdMember
from app.models.room import Room
from app.models.task import EFFORT_WEIGHT, TaskCondition, TaskTemplate
from app.models.user import User
from app.schemas.task import (
    ConditionIn,
    ConditionOut,
    TaskTemplateCreate,
    TaskTemplateOut,
    TaskTemplateUpdate,
)

router = APIRouter(tags=["task-templates"])


def _require_template_membership(
    template_id: uuid.UUID, user: User, db: Session
) -> TaskTemplate:
    template = db.get(TaskTemplate, template_id)
    if template is None:
        raise HTTPException(404, "Plantilla no encontrada")
    member = (
        db.query(HouseholdMember)
        .filter(
            HouseholdMember.household_id == template.household_id,
            HouseholdMember.user_id == user.id,
        )
        .first()
    )
    if member is None:
        raise HTTPException(403, "No eres miembro de este hogar")
    return template


def _template_out(t: TaskTemplate) -> TaskTemplateOut:
    return TaskTemplateOut(
        id=t.id,
        name=t.name,
        category=t.category,
        room_id=t.room_id,
        room_name=t.room.name if t.room else None,
        base_minutes=t.base_minutes,
        effort=t.effort,
        effort_weight=EFFORT_WEIGHT[t.effort],
        frequency=t.frequency,
        preferred_weekday=t.preferred_weekday,
        active=t.active,
        conditions=[ConditionOut.model_validate(c) for c in t.conditions],
        estimated_minutes=t.estimated_minutes,
        weighted_minutes=t.weighted_minutes,
        created_at=t.created_at,
    )


def _check_room(room_id: uuid.UUID | None, household_id: uuid.UUID, db: Session) -> None:
    if room_id is None:
        return
    room = db.get(Room, room_id)
    if room is None or room.household_id != household_id:
        raise HTTPException(422, "La habitación no pertenece a este hogar")


def _sync_conditions(t: TaskTemplate, conditions: list[ConditionIn]) -> None:
    t.conditions.clear()
    for c in conditions:
        t.conditions.append(
            TaskCondition(label=c.label.strip(), extra_minutes=c.extra_minutes, applies=c.applies)
        )


@router.get(
    "/households/{household_id}/task-templates", response_model=list[TaskTemplateOut]
)
def list_templates(
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    templates = (
        db.query(TaskTemplate)
        .filter(TaskTemplate.household_id == membership.household_id)
        .order_by(TaskTemplate.created_at)
        .all()
    )
    return [_template_out(t) for t in templates]


@router.post(
    "/households/{household_id}/task-templates",
    response_model=TaskTemplateOut,
    status_code=201,
)
def create_template(
    body: TaskTemplateCreate,
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    _check_room(body.room_id, membership.household_id, db)
    template = TaskTemplate(
        household_id=membership.household_id,
        room_id=body.room_id,
        name=body.name.strip(),
        category=body.category,
        base_minutes=body.base_minutes,
        effort=body.effort,
        frequency=body.frequency,
        preferred_weekday=body.preferred_weekday,
    )
    _sync_conditions(template, body.conditions)
    db.add(template)
    db.commit()
    return _template_out(template)


@router.patch("/task-templates/{template_id}", response_model=TaskTemplateOut)
def update_template(
    template_id: uuid.UUID,
    body: TaskTemplateUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    template = _require_template_membership(template_id, user, db)
    data = body.model_dump(exclude_unset=True)
    if "room_id" in data:
        _check_room(data["room_id"], template.household_id, db)
        template.room_id = data["room_id"]
    if "name" in data:
        template.name = data["name"].strip()
    if "category" in data:
        template.category = data["category"]
    if "base_minutes" in data:
        template.base_minutes = data["base_minutes"]
    if "effort" in data:
        template.effort = data["effort"]
    if "frequency" in data:
        template.frequency = data["frequency"]
    if "preferred_weekday" in data:
        template.preferred_weekday = data["preferred_weekday"]
    if "active" in data:
        template.active = data["active"]
    db.commit()
    return _template_out(template)


@router.delete("/task-templates/{template_id}", status_code=204)
def delete_template(
    template_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    template = _require_template_membership(template_id, user, db)
    db.delete(template)
    db.commit()


@router.put("/task-templates/{template_id}/conditions", response_model=TaskTemplateOut)
def replace_conditions(
    template_id: uuid.UUID,
    body: list[ConditionIn],
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    template = _require_template_membership(template_id, user, db)
    _sync_conditions(template, body)
    db.commit()
    return _template_out(template)
