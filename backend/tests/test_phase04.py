"""Fase 04: preferencias, selección voluntaria y carga del hogar."""

from tests.helpers import auth, create_household, register


def _join(client, owner_tokens, hid, email="bru@test.com", name="Bruno"):
    invite = client.post(
        f"/api/v1/households/{hid}/invitations", headers=auth(owner_tokens)
    ).json()["code"]
    tokens = register(client, email, name)
    client.post("/api/v1/households/join", json={"code": invite},
                headers=auth(tokens))
    return tokens


def _make_task(client, tokens, hid, minutes=30, title="Barrer"):
    return client.post(
        f"/api/v1/households/{hid}/tasks",
        json={"title": title, "estimated_minutes": minutes, "effort": "low"},
        headers=auth(tokens),
    ).json()


def test_task_from_template_snapshots_estimate(client):
    tokens = register(client, "a@test.com")
    hid = create_household(client, tokens)
    template = client.post(
        f"/api/v1/households/{hid}/task-templates",
        json={
            "name": "Lavar ropa",
            "base_minutes": 25,
            "effort": "medium",
            "conditions": [
                {"label": "Colgar", "extra_minutes": 15, "applies": True},
            ],
        },
        headers=auth(tokens),
    ).json()

    task = client.post(
        f"/api/v1/households/{hid}/tasks",
        json={"template_id": template["id"]},
        headers=auth(tokens),
    ).json()
    assert task["title"] == "Lavar ropa"
    assert task["estimated_minutes"] == 40
    assert task["status"] == "pending"
    assert task["origin"] == "template"


def test_select_unselect_complete(client):
    tokens = register(client, "a@test.com")
    hid = create_household(client, tokens)
    task = _make_task(client, tokens, hid)

    t = client.post(f"/api/v1/tasks/{task['id']}/select", headers=auth(tokens)).json()
    assert t["status"] == "selected" and len(t["assignees"]) == 1
    assert t["assignees"][0]["display_name"] == "Ana"

    t = client.post(f"/api/v1/tasks/{task['id']}/unselect", headers=auth(tokens)).json()
    assert t["status"] == "pending" and t["assignees"] == []

    client.post(f"/api/v1/tasks/{task['id']}/select", headers=auth(tokens))
    t = client.post(f"/api/v1/tasks/{task['id']}/complete", headers=auth(tokens)).json()
    assert t["status"] == "done"
    assert t["assignees"][0]["completed_at"] is not None

    r = client.post(f"/api/v1/tasks/{task['id']}/select", headers=auth(tokens))
    assert r.status_code == 409


def test_skip_and_cannot_do_preference(client):
    tokens = register(client, "a@test.com")
    hid = create_household(client, tokens)
    template = client.post(
        f"/api/v1/households/{hid}/task-templates",
        json={"name": "Lavar baño", "category": "bathroom", "base_minutes": 20},
        headers=auth(tokens),
    ).json()
    task = client.post(
        f"/api/v1/households/{hid}/tasks",
        json={"template_id": template["id"]},
        headers=auth(tokens),
    ).json()

    client.put(
        f"/api/v1/households/{hid}/members/me/preferences",
        json=[{"kind": "cannot_do", "category": "bathroom"}],
        headers=auth(tokens),
    )
    r = client.post(f"/api/v1/tasks/{task['id']}/select", headers=auth(tokens))
    assert r.status_code == 422

    r = client.post(f"/api/v1/tasks/{task['id']}/skip", headers=auth(tokens))
    assert r.json()["status"] == "skipped"

    # Una tarea pasada a mañana se recupera y vuelve a estar disponible.
    r = client.post(f"/api/v1/tasks/{task['id']}/restore", headers=auth(tokens))
    assert r.json()["status"] == "pending"


def test_load_balance_two_members(client):
    tokens_a = register(client, "a@test.com", "Ana")
    hid = create_household(client, tokens_a)
    tokens_b = _join(client, tokens_a, hid)

    # Ana declara 300 min/semana, Bruno 150 → reparto esperado 2:1.
    client.patch(
        f"/api/v1/members/me/households/{hid}/profile",
        json={"weekly_minutes": 300},
        headers=auth(tokens_a),
    )
    client.patch(
        f"/api/v1/members/me/households/{hid}/profile",
        json={"weekly_minutes": 150},
        headers=auth(tokens_b),
    )

    t1 = _make_task(client, tokens_a, hid, minutes=30, title="A")
    t2 = _make_task(client, tokens_a, hid, minutes=30, title="B")
    _make_task(client, tokens_a, hid, minutes=30, title="C sin asignar")
    client.post(f"/api/v1/tasks/{t1['id']}/select", headers=auth(tokens_a))
    client.post(f"/api/v1/tasks/{t2['id']}/select", headers=auth(tokens_b))

    load = client.get(f"/api/v1/households/{hid}/load", headers=auth(tokens_a)).json()
    assert load["single_member"] is False
    assert load["total_minutes"] == 90
    ana, bru = load["members"][0], load["members"][1]
    # Esperado 60/30 sobre 90 min totales.
    assert ana["expected_minutes"] == 60 and bru["expected_minutes"] == 30
    assert ana["assigned_minutes"] == 30 and bru["assigned_minutes"] == 30
    # Ana está 30 por debajo → la sugerencia apunta a ella.
    assert load["suggestion"]["member_id"] == ana["member_id"]
    assert load["suggestion"]["deficit_minutes"] == 30
    assert load["suggestion"]["candidates"][0]["title"] == "C sin asignar"


def test_load_single_member_no_comparison(client):
    tokens = register(client, "solo@test.com", "Solo")
    hid = create_household(client, tokens)
    _make_task(client, tokens, hid, minutes=45)

    load = client.get(f"/api/v1/households/{hid}/load", headers=auth(tokens)).json()
    assert load["single_member"] is True
    assert load["members"][0]["expected_minutes"] is None
    assert load["members"][0]["difference_minutes"] is None
    assert load["suggestion"] is None


def test_room_scope_blocks_child(client):
    tokens_a = register(client, "a@test.com", "Ana")
    hid = create_household(client, tokens_a)
    tokens_b = _join(client, tokens_a, hid, "hijo@test.com", "Hijo")

    room = client.post(
        f"/api/v1/households/{hid}/rooms",
        json={"name": "Sala", "type": "living"},
        headers=auth(tokens_a),
    ).json()
    other_room = client.post(
        f"/api/v1/households/{hid}/rooms",
        json={"name": "Cuarto Hijo", "type": "bedroom"},
        headers=auth(tokens_a),
    ).json()
    # El hijo solo puede tomar tareas de su cuarto.
    client.patch(
        f"/api/v1/members/me/households/{hid}/profile",
        json={"member_type": "child", "room_scope": [other_room["id"]]},
        headers=auth(tokens_b),
    )

    task = client.post(
        f"/api/v1/households/{hid}/tasks",
        json={
            "title": "Ordenar sala",
            "estimated_minutes": 15,
            "room_id": room["id"],
        },
        headers=auth(tokens_a),
    ).json()
    r = client.post(f"/api/v1/tasks/{task['id']}/select", headers=auth(tokens_b))
    assert r.status_code == 403

    own = client.post(
        f"/api/v1/households/{hid}/tasks",
        json={
            "title": "Ordenar mi cuarto",
            "estimated_minutes": 10,
            "room_id": other_room["id"],
        },
        headers=auth(tokens_a),
    ).json()
    r = client.post(f"/api/v1/tasks/{own['id']}/select", headers=auth(tokens_b))
    assert r.status_code == 200
