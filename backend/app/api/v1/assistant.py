"""Asistente de texto: interpreta una instrucción y propone acciones.

La app propone y reorganiza; nunca impone: /interpret solo devuelve el
borrador y /apply ejecuta únicamente lo que la persona confirmó, a nombre
de quien confirma y solo con tipos de acción permitidos.
"""

from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_membership
from app.core.db import get_db
from app.models.household import HouseholdMember
from app.models.task import Task, TaskOrigin, TaskStatus
from app.schemas.assistant import ApplyIn, ApplyOut, InstructionIn, InstructionOut
from app.services.ai import get_ai_service

router = APIRouter(tags=["assistant"])

_ALLOWED_ACTIONS = {"release_my_tasks", "postpone_my_tasks", "create_task"}


def _my_open_tasks(db: Session, member: HouseholdMember, day: date) -> list[Task]:
    return [
        task
        for task in db.query(Task)
        .filter(
            Task.household_id == member.household_id,
            Task.scheduled_date == day,
            Task.status.in_([TaskStatus.selected, TaskStatus.carried_over]),
        )
        .all()
        if any(a.member_id == member.id for a in task.assignments)
    ]


@router.post(
    "/households/{household_id}/assistant/interpret",
    response_model=InstructionOut,
)
def interpret(
    body: InstructionIn,
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    today = date.today()
    open_tasks = (
        db.query(Task)
        .filter(
            Task.household_id == membership.household_id,
            Task.scheduled_date == today,
            Task.status.in_(
                [TaskStatus.pending, TaskStatus.selected, TaskStatus.carried_over]
            ),
        )
        .all()
    )
    context = {
        "member": membership.user.display_name,
        "today": today.isoformat(),
        "open_tasks": [
            {
                "title": t.title,
                "minutes": t.estimated_minutes,
                "mine": any(a.member_id == membership.id for a in t.assignments),
            }
            for t in open_tasks
        ],
    }
    try:
        result = get_ai_service().interpret_instruction(body.text, context)
    except NotImplementedError as exc:
        raise HTTPException(503, "El proveedor de IA no está configurado") from exc
    return InstructionOut(
        summary=result.get("summary", ""),
        actions=[a for a in result.get("actions", []) if a.get("type") in _ALLOWED_ACTIONS],
    )


@router.post(
    "/households/{household_id}/assistant/apply",
    response_model=ApplyOut,
)
def apply(
    body: ApplyIn,
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    today = date.today()
    applied: list[str] = []
    mine = _my_open_tasks(db, membership, today)
    for action in body.actions:
        if action.type not in _ALLOWED_ACTIONS:
            continue
        if action.type == "release_my_tasks":
            count = 0
            for task in mine:
                for a in list(task.assignments):
                    if a.member_id == membership.id:
                        db.delete(a)
                        task.assignments.remove(a)
                        count += 1
                if not task.assignments:
                    task.status = TaskStatus.pending
            applied.append(f"Liberé {count} tarea(s) de hoy")
        elif action.type == "postpone_my_tasks":
            tomorrow = today + timedelta(days=1)
            for task in mine:
                task.scheduled_date = tomorrow
                task.status = TaskStatus.pending
            applied.append(f"Moví {len(mine)} tarea(s) a mañana")
        elif action.type == "create_task" and action.title:
            db.add(
                Task(
                    household_id=membership.household_id,
                    title=action.title.strip()[:160],
                    estimated_minutes=action.estimated_minutes or 15,
                    scheduled_date=today,
                    first_scheduled_date=today,
                    origin=TaskOrigin.extra,
                    created_by_member_id=membership.id,
                )
            )
            applied.append(f"Creé la tarea «{action.title.strip()[:60]}»")
    db.commit()
    return ApplyOut(applied=applied)
