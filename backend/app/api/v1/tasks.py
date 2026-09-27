import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_membership
from app.core.db import get_db
from app.models.household import HouseholdMember
from app.models.room import Room
from app.models.task import (
    Effort,
    PreferenceKind,
    Task,
    TaskAssignment,
    TaskCategory,
    TaskOrigin,
    TaskPreference,
    TaskStatus,
    TaskTemplate,
    utcnow,
)
from app.models.user import User
from app.schemas.task import (
    AssigneeOut,
    LoadOut,
    LoadSuggestion,
    MemberLoad,
    PreferenceIn,
    PreferenceOut,
    TaskCreate,
    TaskOut,
    WeekDay,
    WeekOut,
)
from app.services.plan import materialize_day

router = APIRouter(tags=["tasks"])

# carried_over sigue siendo seleccionable: es una pendiente que viene de ayer.
_UNSELECTABLE = (TaskStatus.done, TaskStatus.skipped)


def _task_out(task: Task) -> TaskOut:
    return TaskOut(
        id=task.id,
        title=task.title,
        estimated_minutes=task.estimated_minutes,
        weighted_minutes=task.weighted_minutes,
        effort=task.effort,
        category=task.category,
        room_id=task.room_id,
        room_name=task.room.name if task.room else None,
        template_id=task.template_id,
        scheduled_date=task.scheduled_date,
        status=task.status,
        origin=task.origin,
        carried_from_id=task.carried_from_id,
        assignees=[
            AssigneeOut(
                member_id=a.member_id,
                display_name=a.member.user.display_name,
                completed_at=a.completed_at,
            )
            for a in task.assignments
        ],
    )


def _require_task_membership(
    task_id: uuid.UUID, user: User, db: Session
) -> tuple[Task, HouseholdMember]:
    task = db.get(Task, task_id)
    if task is None:
        raise HTTPException(404, "Tarea no encontrada")
    member = (
        db.query(HouseholdMember)
        .filter(
            HouseholdMember.household_id == task.household_id,
            HouseholdMember.user_id == user.id,
        )
        .first()
    )
    if member is None:
        raise HTTPException(403, "No eres miembro de este hogar")
    return task, member


@router.get("/households/{household_id}/tasks", response_model=list[TaskOut])
def list_tasks(
    on_date: date | None = Query(default=None, alias="date"),
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    day = on_date or date.today()
    today = date.today()
    materialize_day(db, membership.household_id, day, carry=day == today)
    db.commit()
    tasks = (
        db.query(Task)
        .filter(Task.household_id == membership.household_id, Task.scheduled_date == day)
        .order_by(Task.created_at)
        .all()
    )
    return [_task_out(t) for t in tasks]


@router.get("/households/{household_id}/week", response_model=WeekOut)
def week_view(
    start: date | None = Query(default=None),
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    """Vista semanal para el calendario: propone cada día y resume minutos."""
    today = date.today()
    first = start or (today - timedelta(days=today.weekday()))
    first = first - timedelta(days=first.weekday())
    days: list[WeekDay] = []
    for offset in range(7):
        day = first + timedelta(days=offset)
        materialize_day(db, membership.household_id, day, carry=day == today)
        db.commit()
        tasks = (
            db.query(Task)
            .filter(
                Task.household_id == membership.household_id,
                Task.scheduled_date == day,
            )
            .order_by(Task.created_at)
            .all()
        )
        days.append(
            WeekDay(
                date=day,
                total_minutes=round(sum(t.weighted_minutes for t in tasks), 1),
                done_count=sum(1 for t in tasks if t.status == TaskStatus.done),
                tasks=[_task_out(t) for t in tasks],
            )
        )
    return WeekOut(start=first, days=days)


@router.post("/households/{household_id}/tasks", response_model=TaskOut, status_code=201)
def create_task(
    body: TaskCreate,
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    task = Task(
        household_id=membership.household_id,
        scheduled_date=body.scheduled_date or date.today(),
        created_by_member_id=membership.id,
    )
    if body.template_id is not None:
        template = db.get(TaskTemplate, body.template_id)
        if template is None or template.household_id != membership.household_id:
            raise HTTPException(422, "La plantilla no pertenece a este hogar")
        task.template_id = template.id
        task.title = template.name
        task.estimated_minutes = template.estimated_minutes
        task.effort = template.effort
        task.category = template.category
        task.room_id = template.room_id
        task.origin = TaskOrigin.template
    else:
        if body.room_id is not None:
            room = db.get(Room, body.room_id)
            if room is None or room.household_id != membership.household_id:
                raise HTTPException(422, "La habitación no pertenece a este hogar")
        task.title = body.title.strip() if body.title else ""
        task.estimated_minutes = body.estimated_minutes or 0
        task.effort = body.effort or Effort.medium
        task.category = body.category or TaskCategory.general
        task.room_id = body.room_id
        task.origin = TaskOrigin.extra
    db.add(task)
    db.commit()
    return _task_out(task)


@router.delete("/tasks/{task_id}", status_code=204)
def delete_task(
    task_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task, member = _require_task_membership(task_id, user, db)
    if task.status == TaskStatus.done:
        raise HTTPException(409, "No puedes eliminar una tarea completada")
    db.delete(task)
    db.commit()


def _preference_blocks(task: Task, member: HouseholdMember, db: Session) -> str | None:
    prefs = (
        db.query(TaskPreference)
        .filter(
            TaskPreference.member_id == member.id,
            TaskPreference.kind == PreferenceKind.cannot_do,
        )
        .all()
    )
    for pref in prefs:
        if pref.template_id and pref.template_id == task.template_id:
            return "Marcaste que no puedes hacer esta tarea"
        if pref.category and pref.category == task.category:
            return "Marcaste que no puedes hacer tareas de esta categoría"
    return None


@router.post("/tasks/{task_id}/select", response_model=TaskOut)
def select_task(
    task_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task, member = _require_task_membership(task_id, user, db)
    if task.status in _UNSELECTABLE:
        raise HTTPException(409, "Esta tarea ya no está disponible")
    if member.room_scope:
        room_scope = {str(r) for r in member.room_scope}
        if task.room_id is not None and str(task.room_id) not in room_scope:
            raise HTTPException(
                403, "Esta tarea está fuera de las habitaciones que te corresponden"
            )
    blocked = _preference_blocks(task, member, db)
    if blocked:
        raise HTTPException(422, blocked)
    if all(a.member_id != member.id for a in task.assignments):
        db.add(TaskAssignment(task=task, member_id=member.id))
    task.status = TaskStatus.selected
    db.commit()
    return _task_out(task)


@router.post("/tasks/{task_id}/unselect", response_model=TaskOut)
def unselect_task(
    task_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task, member = _require_task_membership(task_id, user, db)
    assignment = next((a for a in task.assignments if a.member_id == member.id), None)
    if assignment is None:
        raise HTTPException(404, "No tienes esta tarea seleccionada")
    db.delete(assignment)
    db.flush()
    task.assignments.remove(assignment)
    if not task.assignments and task.status == TaskStatus.selected:
        task.status = TaskStatus.pending
    db.commit()
    return _task_out(task)


@router.post("/tasks/{task_id}/complete", response_model=TaskOut)
def complete_task(
    task_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task, member = _require_task_membership(task_id, user, db)
    assignment = next((a for a in task.assignments if a.member_id == member.id), None)
    if assignment is None:
        raise HTTPException(404, "No tienes esta tarea seleccionada")
    assignment.completed_at = utcnow()
    task.status = TaskStatus.done
    db.commit()
    return _task_out(task)


@router.post("/tasks/{task_id}/skip", response_model=TaskOut)
def skip_task(
    task_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task, _ = _require_task_membership(task_id, user, db)
    if task.status == TaskStatus.done:
        raise HTTPException(409, "La tarea ya está hecha")
    task.status = TaskStatus.skipped
    db.commit()
    return _task_out(task)


@router.post("/tasks/{task_id}/restore", response_model=TaskOut)
def restore_task(
    task_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task, _ = _require_task_membership(task_id, user, db)
    if task.status not in (TaskStatus.skipped, TaskStatus.carried_over):
        raise HTTPException(409, "Solo se recuperan tareas pasadas a mañana")
    task.status = TaskStatus.pending
    db.commit()
    return _task_out(task)


# --- Preferencias del miembro ---


@router.get(
    "/households/{household_id}/members/me/preferences",
    response_model=list[PreferenceOut],
)
def list_preferences(
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    prefs = (
        db.query(TaskPreference)
        .filter(TaskPreference.member_id == membership.id)
        .all()
    )
    return [
        PreferenceOut(
            id=p.id,
            kind=p.kind,
            template_id=p.template_id,
            category=p.category,
            template_name=p.template.name if p.template else None,
        )
        for p in prefs
    ]


@router.put(
    "/households/{household_id}/members/me/preferences",
    response_model=list[PreferenceOut],
)
def replace_preferences(
    body: list[PreferenceIn],
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    for p in body:
        if p.template_id is not None:
            template = db.get(TaskTemplate, p.template_id)
            if template is None or template.household_id != membership.household_id:
                raise HTTPException(422, "La plantilla no pertenece a este hogar")
    db.query(TaskPreference).filter(
        TaskPreference.member_id == membership.id
    ).delete()
    for p in body:
        db.add(
            TaskPreference(
                member_id=membership.id,
                kind=p.kind,
                template_id=p.template_id,
                category=p.category,
            )
        )
    db.commit()
    return list_preferences(membership, db)


# --- Carga del hogar ---

DEFAULT_WEEKLY_MINUTES = 300


@router.get("/households/{household_id}/load", response_model=LoadOut)
def household_load(
    on_date: date | None = Query(default=None, alias="date"),
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    day = on_date or date.today()
    tasks = (
        db.query(Task)
        .filter(
            Task.household_id == membership.household_id,
            Task.scheduled_date == day,
            Task.status.in_(
                [
                    TaskStatus.pending,
                    TaskStatus.selected,
                    TaskStatus.done,
                    TaskStatus.carried_over,
                ]
            ),
        )
        .all()
    )
    members = membership.household.members
    total = sum(t.weighted_minutes for t in tasks)
    weights = {
        m.id: (m.weekly_minutes or DEFAULT_WEEKLY_MINUTES) * m.capacity_factor
        for m in members
    }
    total_weight = sum(weights.values()) or 1.0

    loads: list[MemberLoad] = []
    single = len(members) == 1
    for m in members:
        assigned = sum(
            t.weighted_minutes
            for t in tasks
            if any(a.member_id == m.id for a in t.assignments)
        )
        expected = None if single else total * weights[m.id] / total_weight
        loads.append(
            MemberLoad(
                member_id=m.id,
                display_name=m.user.display_name,
                assigned_minutes=round(assigned, 1),
                expected_minutes=None if expected is None else round(expected, 1),
                difference_minutes=None
                if expected is None
                else round(assigned - expected, 1),
                weekly_minutes=m.weekly_minutes,
                capacity_factor=m.capacity_factor,
            )
        )

    suggestion = None
    notice = None
    if not single:
        unassigned = [
            t
            for t in tasks
            if not t.assignments
            and t.status in (TaskStatus.pending, TaskStatus.carried_over)
        ]
        worst = min(loads, key=lambda load: load.difference_minutes or 0)
        if worst.difference_minutes is not None and worst.difference_minutes < -5 and unassigned:
            deficit = -(worst.difference_minutes or 0)
            candidates = sorted(
                unassigned, key=lambda t: abs(t.weighted_minutes - deficit)
            )[:3]
            suggestion = LoadSuggestion(
                member_id=worst.member_id,
                display_name=worst.display_name,
                deficit_minutes=round(deficit, 1),
                candidates=[_task_out(t) for t in candidates],
            )
    else:
        member = members[0]
        if member.weekly_minutes and total > member.weekly_minutes / 7:
            notice = (
                f"Las tareas de hoy (~{total:.0f} min) superan lo que sueles "
                f"tener disponible al día (~{member.weekly_minutes // 7} min)."
            )

    return LoadOut(
        date=day,
        single_member=single,
        total_minutes=round(total, 1),
        members=loads,
        suggestion=suggestion,
        notice=notice,
    )
