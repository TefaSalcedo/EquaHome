"""Fase 03: plantillas de tareas con condiciones y estimado calculado."""

from tests.helpers import auth, create_household, register


def test_template_with_conditions_estimate(client):
    """Criterio de fase: 'Lavar ropa' 25 + 10 + 15 + 10 → 60 min estimado."""
    tokens = register(client, "ana@test.com")
    hid = create_household(client, tokens)

    r = client.post(
        f"/api/v1/households/{hid}/task-templates",
        json={
            "name": "Lavar ropa",
            "category": "laundry",
            "base_minutes": 25,
            "effort": "medium",
            "frequency": "weekly",
            "conditions": [
                {"label": "Separar por colores", "extra_minutes": 10, "applies": True},
                {"label": "Colgar al aire", "extra_minutes": 15, "applies": True},
                {"label": "Doblar y guardar", "extra_minutes": 10, "applies": True},
            ],
        },
        headers=auth(tokens),
    )
    assert r.status_code == 201, r.text
    t = r.json()
    assert t["estimated_minutes"] == 60
    assert t["effort_weight"] == 1.15
    assert t["weighted_minutes"] == 60 * 1.15
    assert len(t["conditions"]) == 3


def test_conditions_toggle_and_replace(client):
    tokens = register(client, "ana@test.com")
    hid = create_household(client, tokens)
    t = client.post(
        f"/api/v1/households/{hid}/task-templates",
        json={
            "name": "Lavar platos",
            "base_minutes": 15,
            "effort": "low",
            "conditions": [{"label": "Sartén pegada", "extra_minutes": 5, "applies": False}],
        },
        headers=auth(tokens),
    ).json()
    assert t["estimated_minutes"] == 15

    r = client.put(
        f"/api/v1/task-templates/{t['id']}/conditions",
        json=[{"label": "Sartén pegada", "extra_minutes": 5, "applies": True}],
        headers=auth(tokens),
    )
    assert r.json()["estimated_minutes"] == 20


def test_template_update_and_room_link(client):
    tokens = register(client, "ana@test.com")
    hid = create_household(client, tokens)
    room = client.post(
        f"/api/v1/households/{hid}/rooms",
        json={"name": "Cocina", "type": "kitchen"},
        headers=auth(tokens),
    ).json()

    t = client.post(
        f"/api/v1/households/{hid}/task-templates",
        json={"name": "Barrer", "room_id": room["id"], "base_minutes": 10, "effort": "low"},
        headers=auth(tokens),
    ).json()
    assert t["room_name"] == "Cocina"

    r = client.patch(
        f"/api/v1/task-templates/{t['id']}",
        json={"effort": "high", "active": False},
        headers=auth(tokens),
    )
    body = r.json()
    assert body["active"] is False and body["effort_weight"] == 1.35


def test_template_rejects_foreign_room(client):
    tokens_a = register(client, "a@test.com")
    tokens_b = register(client, "b@test.com")
    hid_a = create_household(client, tokens_a)
    hid_b = create_household(client, tokens_b)
    room_b = client.post(
        f"/api/v1/households/{hid_b}/rooms",
        json={"name": "Sala", "type": "living"},
        headers=auth(tokens_b),
    ).json()

    r = client.post(
        f"/api/v1/households/{hid_a}/task-templates",
        json={"name": "X", "room_id": room_b["id"], "base_minutes": 5},
        headers=auth(tokens_a),
    )
    assert r.status_code == 422
