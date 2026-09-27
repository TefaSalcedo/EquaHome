"""Fase 02: habitaciones y objetos de la casa."""

from tests.helpers import auth, create_household, register


def test_room_crud(client):
    tokens = register(client, "ana@test.com")
    hid = create_household(client, tokens)

    r = client.post(
        f"/api/v1/households/{hid}/rooms",
        json={"name": "Cocina", "type": "kitchen"},
        headers=auth(tokens),
    )
    assert r.status_code == 201
    room = r.json()
    assert room["name"] == "Cocina" and room["object_count"] == 0

    r = client.patch(
        f"/api/v1/rooms/{room['id']}",
        json={"name": "Cocina principal", "floor": "1"},
        headers=auth(tokens),
    )
    assert r.status_code == 200 and r.json()["floor"] == "1"

    rooms = client.get(f"/api/v1/households/{hid}/rooms", headers=auth(tokens)).json()
    assert len(rooms) == 1 and rooms[0]["name"] == "Cocina principal"

    r = client.delete(f"/api/v1/rooms/{room['id']}", headers=auth(tokens))
    assert r.status_code == 204
    assert client.get(f"/api/v1/households/{hid}/rooms", headers=auth(tokens)).json() == []


def test_room_objects(client):
    tokens = register(client, "ana@test.com")
    hid = create_household(client, tokens)
    room = client.post(
        f"/api/v1/households/{hid}/rooms",
        json={"name": "Baño", "type": "bathroom"},
        headers=auth(tokens),
    ).json()

    obj = client.post(
        f"/api/v1/rooms/{room['id']}/objects",
        json={"name": "Espejo", "quantity": 2},
        headers=auth(tokens),
    ).json()
    assert obj["quantity"] == 2 and obj["source"] == "manual" and obj["confirmed"] is True

    detail = client.get(f"/api/v1/rooms/{room['id']}", headers=auth(tokens)).json()
    assert len(detail["objects"]) == 1

    obj = client.patch(
        f"/api/v1/objects/{obj['id']}", json={"quantity": 3}, headers=auth(tokens)
    ).json()
    assert obj["quantity"] == 3

    assert client.delete(f"/api/v1/objects/{obj['id']}", headers=auth(tokens)).status_code == 204


def test_rooms_scoped_to_member(client):
    tokens_a = register(client, "a@test.com")
    tokens_b = register(client, "b@test.com")
    hid = create_household(client, tokens_a)
    room = client.post(
        f"/api/v1/households/{hid}/rooms",
        json={"name": "Sala", "type": "living"},
        headers=auth(tokens_a),
    ).json()

    r = client.get(f"/api/v1/rooms/{room['id']}", headers=auth(tokens_b))
    assert r.status_code == 403
    r = client.get(f"/api/v1/households/{hid}/rooms", headers=auth(tokens_b))
    assert r.status_code == 403
