"""Fase 06: subida de fotos, análisis IA (mock) y confirmación corregible."""

import io

from tests.helpers import auth, create_household, register

# PNG mínimo válido (1x1 px).
_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\xcf"
    b"\xc0\xf0\x1f\x00\x05\x00\x01\xff\xa9B\x11N\x00\x00\x00\x00IEND\xaeB`\x82"
)


def _make_room(client, tokens, hid):
    resp = client.post(
        f"/api/v1/households/{hid}/rooms",
        json={"name": "Habitación", "type": "bedroom"},
        headers=auth(tokens),
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


def _upload(client, tokens, hid, room_id=None):
    data = {"purpose": "room_scan"}
    if room_id:
        data["room_id"] = room_id
    resp = client.post(
        f"/api/v1/households/{hid}/photos",
        files={"file": ("foto.png", io.BytesIO(_PNG), "image/png")},
        data=data,
        headers=auth(tokens),
    )
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_upload_analyze_and_confirm_creates_objects(client):
    tokens = register(client, "f1@test.com")
    hid = create_household(client, tokens)
    room_id = _make_room(client, tokens, hid)

    photo = _upload(client, tokens, hid, room_id)
    assert photo["ai_status"] == "none"

    resp = client.get(
        f"/api/v1/photos/{photo['id']}/file", headers=auth(tokens)
    )
    assert resp.status_code == 200
    assert resp.content[:4] == _PNG[:4]

    resp = client.post(
        f"/api/v1/photos/{photo['id']}/analyze", headers=auth(tokens)
    )
    assert resp.status_code == 200, resp.text
    photo = resp.json()
    assert photo["ai_status"] == "done"
    analysis = photo["analysis"]
    assert analysis["provider"] == "mock"
    assert analysis["confirmed_by_user"] is False
    assert len(analysis["objects"]) >= 1

    # La persona corrige el borrador: quita un objeto, edita cantidad, agrega uno.
    corrected = [
        {"name": "Cama", "quantity": 2},
        {"name": "Escritorio", "quantity": 1},
    ]
    resp = client.patch(
        f"/api/v1/analyses/{analysis['id']}/confirm",
        json={"objects": corrected},
        headers=auth(tokens),
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["analysis"]["confirmed_by_user"] is True

    resp = client.get(
        f"/api/v1/rooms/{room_id}", headers=auth(tokens)
    )
    objects = {o["name"]: o for o in resp.json()["objects"]}
    assert objects["Cama"]["quantity"] == 2
    assert objects["Cama"]["source"] == "ai"
    assert objects["Escritorio"]["quantity"] == 1
    assert "Lámpara" not in objects


def test_photo_endpoints_require_membership(client):
    tokens = register(client, "g1@test.com")
    hid = create_household(client, tokens)
    photo = _upload(client, tokens, hid)

    other = register(client, "h1@test.com", name="Bruno")
    resp = client.get(
        f"/api/v1/photos/{photo['id']}", headers=auth(other)
    )
    assert resp.status_code == 403
    resp = client.post(
        f"/api/v1/photos/{photo['id']}/analyze", headers=auth(other)
    )
    assert resp.status_code == 403


def test_upload_rejects_non_image(client):
    tokens = register(client, "i1@test.com")
    hid = create_household(client, tokens)
    resp = client.post(
        f"/api/v1/households/{hid}/photos",
        files={"file": ("doc.txt", io.BytesIO(b"hola"), "text/plain")},
        data={"purpose": "room_scan"},
        headers=auth(tokens),
    )
    assert resp.status_code == 415
