"""Fases 07–08: asistente (interpretar→proponer→aplicar) y evaluación diaria."""

import io
from datetime import date, timedelta

from tests.helpers import auth, create_household, register
from tests.test_phase06 import _PNG


def _select_task(client, tokens, hid, title="Sacar basura"):
    resp = client.post(
        f"/api/v1/households/{hid}/tasks",
        json={"title": title, "estimated_minutes": 15},
        headers=auth(tokens),
    )
    task_id = resp.json()["id"]
    resp = client.post(f"/api/v1/tasks/{task_id}/select", headers=auth(tokens))
    assert resp.status_code == 200, resp.text
    return task_id


def test_interpret_and_apply_release(client):
    tokens = register(client, "a7@test.com")
    hid = create_household(client, tokens)
    task_id = _select_task(client, tokens, hid)

    resp = client.post(
        f"/api/v1/households/{hid}/assistant/interpret",
        json={"text": "mañana no estoy"},
        headers=auth(tokens),
    )
    assert resp.status_code == 200, resp.text
    proposal = resp.json()
    assert [a["type"] for a in proposal["actions"]] == ["release_my_tasks"]

    resp = client.post(
        f"/api/v1/households/{hid}/assistant/apply",
        json={"actions": proposal["actions"]},
        headers=auth(tokens),
    )
    assert resp.status_code == 200, resp.text
    assert "Liberé" in resp.json()["applied"][0]

    resp = client.get(
        f"/api/v1/households/{hid}/tasks", headers=auth(tokens)
    )
    task = next(t for t in resp.json() if t["id"] == task_id)
    assert task["status"] == "pending"
    assert task["assignees"] == []


def test_apply_postpone_and_create(client):
    tokens = register(client, "b7@test.com")
    hid = create_household(client, tokens)
    task_id = _select_task(client, tokens, hid)
    tomorrow = (date.today() + timedelta(days=1)).isoformat()

    resp = client.post(
        f"/api/v1/households/{hid}/assistant/apply",
        json={
            "actions": [
                {"type": "postpone_my_tasks"},
                {"type": "create_task", "title": "Regar", "estimated_minutes": 10},
                {"type": "delete_everything"},  # no permitida: se ignora
            ]
        },
        headers=auth(tokens),
    )
    assert resp.status_code == 200, resp.text
    applied = resp.json()["applied"]
    assert len(applied) == 2

    resp = client.get(
        f"/api/v1/households/{hid}/tasks",
        params={"date": tomorrow},
        headers=auth(tokens),
    )
    moved = next(t for t in resp.json() if t["id"] == task_id)
    assert moved["scheduled_date"] == tomorrow

    resp = client.get(
        f"/api/v1/households/{hid}/tasks", headers=auth(tokens)
    )
    assert any(t["title"] == "Regar" for t in resp.json())


def test_daily_check_photo_flow(client):
    tokens = register(client, "c7@test.com")
    hid = create_household(client, tokens)
    resp = client.post(
        f"/api/v1/households/{hid}/photos",
        files={"file": ("cierre.png", io.BytesIO(_PNG), "image/png")},
        data={"purpose": "daily_check"},
        headers=auth(tokens),
    )
    assert resp.status_code == 201, resp.text
    photo_id = resp.json()["id"]

    resp = client.post(
        f"/api/v1/photos/{photo_id}/analyze", headers=auth(tokens)
    )
    assert resp.status_code == 200, resp.text
    analysis = resp.json()["analysis"]
    assert "orientativa" in analysis["summary"]
    assert analysis["objects"] == []
