"""Fase 02: habitaciones y objetos de la casa."""


def _register(client, email="ana@test.com"):
    r = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "segura123", "display_name": "Ana"},
    )
    return r.json()["access_token"]


def _household(client, token):
    r = client.post("/api/v1/households", json={"name": "Casa Centro"},
                    headers={"Authorization": f"Bearer {token}"})
    return r.json()["id"]


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def test_room_crud(client):
    token = _register(client)
    hid = _household(client, token)

    r = client.post(
        f"/api/v1/households/{hid}/rooms",
        json={"name": "Cocina", "type": "kitchen"},
        headers=_auth(token),
    )
    assert r.status_code == 201
    room = r.json()
    assert room["name"] == "Cocina" and room["object_count"] == 0

    r = client.patch(
        f"/api/v1/rooms/{room['id']}",
        json={"name": "Cocina principal", "floor": "1"},
        headers=_auth(token),
    )
    assert r.status_code == 200 and r.json()["floor"] == "1"

    rooms = client.get(f"/api/v1/households/{hid}/rooms", headers=_auth(token)).json()
    assert len(rooms) == 1 and rooms[0]["name"] == "Cocina principal"

    r = client.delete(f"/api/v1/rooms/{room['id']}", headers=_auth(token))
    assert r.status_code == 204
    assert client.get(f"/api/v1/households/{hid}/rooms", headers=_auth(token)).json() == []


def test_room_objects(client):
    token = _register(client)
    hid = _household(client, token)
    room = client.post(
        f"/api/v1/households/{hid}/rooms",
        json={"name": "Baño", "type": "bathroom"},
        headers=_auth(token),
    ).json()

    obj = client.post(
        f"/api/v1/rooms/{room['id']}/objects",
        json={"name": "Espejo", "quantity": 2},
        headers=_auth(token),
    ).json()
    assert obj["quantity"] == 2 and obj["source"] == "manual" and obj["confirmed"] is True

    detail = client.get(f"/api/v1/rooms/{room['id']}", headers=_auth(token)).json()
    assert len(detail["objects"]) == 1

    obj = client.patch(
        f"/api/v1/objects/{obj['id']}", json={"quantity": 3}, headers=_auth(token)
    ).json()
    assert obj["quantity"] == 3

    assert client.delete(f"/api/v1/objects/{obj['id']}", headers=_auth(token)).status_code == 204


def test_rooms_scoped_to_member(client):
    token_a = _register(client, "a@test.com")
    token_b = _register(client, "b@test.com")
    hid = _household(client, token_a)
    room = client.post(
        f"/api/v1/households/{hid}/rooms",
        json={"name": "Sala", "type": "living"},
        headers=_auth(token_a),
    ).json()

    r = client.get(f"/api/v1/rooms/{room['id']}", headers=_auth(token_b))
    assert r.status_code == 403
    r = client.get(f"/api/v1/households/{hid}/rooms", headers=_auth(token_b))
    assert r.status_code == 403
