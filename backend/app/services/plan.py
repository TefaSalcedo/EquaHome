"""PlanGenerator: materializa el día a partir de plantillas y arrastra pendientes.

La app propone el plan; las personas siempre eligen qué hacen. Las tareas
abiertas de días anteriores reaparecen (carry-over) sin duplicarse.
"""

import calendar
from datetime import date, timedelta

from sqlalchemy.orm import Session

from app.models.task import (
    Frequency,
    Task,
    TaskOrigin,
    TaskStatus,
    TaskTemplate,
)

_OPEN_STATUSES = (
    TaskStatus.pending,
    TaskStatus.selected,
    TaskStatus.skipped,
    TaskStatus.carried_over,
)


def _applies_on(template: TaskTemplate, day: date) -> bool:
    """Regla de programación por frecuencia."""
    # Nunca materializa días anteriores a la creación de la plantilla.
    if day < template.created_at.date():
        return False
    if template.frequency == Frequency.daily:
        return True
    if template.frequency == Frequency.weekly:
        # preferred_weekday es ISO (1=lunes … 7=domingo); sin día, cae el lunes.
        return day.isoweekday() == (template.preferred_weekday or 1)
    if template.frequency == Frequency.monthly:
        last_day = calendar.monthrange(day.year, day.month)[1]
        return day.day == min(template.created_at.day, last_day)
    # once: aparece el primer día que se materializa tras su creación
    return True


def _period_bounds(frequency: Frequency, day: date) -> tuple[date, date]:
    """Rango de deduplicación según la frecuencia."""
    if frequency == Frequency.weekly:
        start = day - timedelta(days=day.weekday())
        return start, start + timedelta(days=6)
    if frequency == Frequency.monthly:
        last_day = calendar.monthrange(day.year, day.month)[1]
        return date(day.year, day.month, 1), date(day.year, day.month, last_day)
    return day, day


def _already_materialized(
    db: Session, household_id, template: TaskTemplate, day: date
) -> bool:
    # El dedup mira la fecha original: una tarea arrastrada a hoy sigue
    # contando para su período, así el carry-over nunca duplica.
    query = db.query(Task.id).filter(
        Task.household_id == household_id, Task.template_id == template.id
    )
    if template.frequency != Frequency.once:
        start, end = _period_bounds(template.frequency, day)
        query = query.filter(
            Task.first_scheduled_date >= start,
            Task.first_scheduled_date <= end,
        )
    return query.first() is not None


def materialize_day(db: Session, household_id, day: date, *, carry: bool) -> None:
    """Crea las tareas que corresponden a `day` y arrastra pendientes anteriores.

    `carry` solo es True para el día actual: mover tareas de días pasados a un
    día futuro mezclaría el plan.
    """
    if carry:
        overdue = (
            db.query(Task)
            .filter(
                Task.household_id == household_id,
                Task.scheduled_date < day,
                Task.status.in_(_OPEN_STATUSES),
            )
            .all()
        )
        for task in overdue:
            task.carried_from_id = task.carried_from_id or task.id
            task.scheduled_date = day
            task.status = TaskStatus.carried_over
        db.flush()

    templates = (
        db.query(TaskTemplate)
        .filter(
            TaskTemplate.household_id == household_id,
            TaskTemplate.active.is_(True),
        )
        .all()
    )
    for template in templates:
        if not _applies_on(template, day):
            continue
        if _already_materialized(db, household_id, template, day):
            continue
        db.add(
            Task(
                household_id=household_id,
                template_id=template.id,
                room_id=template.room_id,
                title=template.name,
                estimated_minutes=template.estimated_minutes,
                effort=template.effort,
                category=template.category,
                scheduled_date=day,
                first_scheduled_date=day,
                origin=TaskOrigin.template,
            )
        )
    db.flush()
