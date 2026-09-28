"""Fase 05: materialización del día, carry-over y vista semanal."""

from datetime import date, timedelta

from tests.helpers import auth, create_household, register


def _create_template(client, tokens, hid, name, frequency="daily", **extra):
    resp = client.post(
        f"/api/v1/households/{hid}/task-templates",
        json={
            "name": name,
            "base_minutes": 20,
            "frequency": frequency,
            **extra,
        },
        headers=auth(tokens),
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


def _day_tasks(client, tokens, hid, day: date):
    resp = client.get(
        f"/api/v1/households/{hid}/tasks",
        params={"date": day.isoformat()},
        headers=auth(tokens),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


def test_daily_template_materializes_today(client):
    tokens = register(client, "a1@test.com")
    hid = create_household(client, tokens)
    _create_template(client, tokens, hid, "Barrer sala")

    tasks = _day_tasks(client, tokens, hid, date.today())
    titles = [t["title"] for t in tasks]
    assert "Barrer sala" in titles
    # Re-materializar no duplica.
    tasks2 = _day_tasks(client, tokens, hid, date.today())
    assert [t["title"] for t in tasks2] == titles


def test_weekly_template_only_on_preferred_weekday(client):
    tokens = register(client, "b1@test.com")
    hid = create_household(client, tokens)
    saturday = 6  # ISO: 1=lunes … 7=domingo
    _create_template(
        client, tokens, hid, "Lavar ropa", frequency="weekly",
        preferred_weekday=saturday,
    )
    today = date.today()
    other = today if today.isoweekday() != saturday else today + timedelta(days=2)
    if other.isoweekday() == saturday:
        other += timedelta(days=1)
    next_sat = today + timedelta(days=(saturday - today.isoweekday()) % 7 or 7)

    assert all(
        t["title"] != "Lavar ropa" for t in _day_tasks(client, tokens, hid, other)
    )
    sat_tasks = _day_tasks(client, tokens, hid, next_sat)
    assert any(t["title"] == "Lavar ropa" for t in sat_tasks)


def test_pending_carries_to_today_without_duplicating(client):
    tokens = register(client, "c1@test.com")
    hid = create_household(client, tokens)
    yesterday = date.today() - timedelta(days=1)
    resp = client.post(
        f"/api/v1/households/{hid}/tasks",
        json={"title": "Sacar basura", "estimated_minutes": 10,
              "scheduled_date": yesterday.isoformat()},
        headers=auth(tokens),
    )
    assert resp.status_code == 201, resp.text
    task_id = resp.json()["id"]

    today_tasks = _day_tasks(client, tokens, hid, date.today())
    carried = [t for t in today_tasks if t["title"] == "Sacar basura"]
    assert len(carried) == 1
    assert carried[0]["id"] == task_id
    assert carried[0]["status"] == "carried_over"
    # El día de ayer ya no la lista.
    assert not _day_tasks(client, tokens, hid, yesterday)
    # Se puede volver a elegir.
    resp = client.post(f"/api/v1/tasks/{task_id}/select", headers=auth(tokens))
    assert resp.status_code == 200, resp.text


def test_skipped_carries_as_no_puedo_hoy(client):
    tokens = register(client, "d1@test.com")
    hid = create_household(client, tokens)
    yesterday = date.today() - timedelta(days=1)
    resp = client.post(
        f"/api/v1/households/{hid}/tasks",
        json={"title": "Limpiar baño", "estimated_minutes": 25,
              "scheduled_date": yesterday.isoformat()},
        headers=auth(tokens),
    )
    task_id = resp.json()["id"]
    client.post(f"/api/v1/tasks/{task_id}/skip", headers=auth(tokens))

    today_tasks = _day_tasks(client, tokens, hid, date.today())
    carried = [t for t in today_tasks if t["title"] == "Limpiar baño"]
    assert len(carried) == 1
    assert carried[0]["status"] == "carried_over"


def test_week_never_materializes_before_template_creation(client):
    """Regresión: una plantilla creada hoy no debe llenar días pasados."""
    tokens = register(client, "g1@test.com")
    hid = create_household(client, tokens)
    _create_template(client, tokens, hid, "Fregar platos")

    resp = client.get(f"/api/v1/households/{hid}/week", headers=auth(tokens))
    assert resp.status_code == 200
    today_iso = date.today().isoformat()
    # Los días de la semana ANTERIORES a hoy no tienen la tarea; hoy y los
    # siguientes sí (una sola vez cada uno).
    for day in resp.json()["days"]:
        count = sum(t["title"] == "Fregar platos" for t in day["tasks"])
        assert count == (0 if day["date"] < today_iso else 1)
    expected = sum(1 for d in resp.json()["days"] if d["date"] >= today_iso)
    # Volver a pedir la semana tras el carry no duplica.
    resp = client.get(f"/api/v1/households/{hid}/week", headers=auth(tokens))
    total = sum(
        t["title"] == "Fregar platos"
        for d in resp.json()["days"]
        for t in d["tasks"]
    )
    assert total == expected


def test_week_endpoint_returns_seven_days(client):
    tokens = register(client, "e1@test.com")
    hid = create_household(client, tokens)
    _create_template(client, tokens, hid, "Tender cama")

    resp = client.get(f"/api/v1/households/{hid}/week", headers=auth(tokens))
    assert resp.status_code == 200, resp.text
    week = resp.json()
    assert len(week["days"]) == 7
    assert week["days"][0]["date"] == week["start"]
    today = date.today()
    today_day = next(d for d in week["days"] if d["date"] == today.isoformat())
    assert any(t["title"] == "Tender cama" for t in today_day["tasks"])
    assert today_day["total_minutes"] > 0
