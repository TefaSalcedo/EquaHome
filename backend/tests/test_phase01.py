"""Phase 01 flow: auth, household of 1..N members, invites, primary residence."""

from fastapi.testclient import TestClient

from tests.helpers import auth, register


def test_health(client: TestClient):
    assert client.get("/health").json() == {"status": "ok"}


def test_register_login_refresh_me(client: TestClient):
    tokens = register(client, "ana@example.com", "Ana")
    assert client.get("/api/v1/auth/me", headers=auth(tokens)).json()["email"] == "ana@example.com"

    bad = client.post("/api/v1/auth/login", json={"email": "ana@example.com", "password": "wrong"})
    assert bad.status_code == 401

    ok = client.post("/api/v1/auth/login", json={"email": "ana@example.com", "password": "password123"})
    assert ok.status_code == 200

    refreshed = client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert refreshed.status_code == 200
    assert refreshed.json()["access_token"]

    dup = client.post(
        "/api/v1/auth/register",
        json={"email": "ana@example.com", "password": "password123", "display_name": "Otra"},
    )
    assert dup.status_code == 409


def test_household_invite_join_and_members(client: TestClient):
    ana = register(client, "a@example.com", "Ana")
    bruno = register(client, "b@example.com", "Bruno")

    created = client.post("/api/v1/households", json={"name": "Casa Principal"}, headers=auth(ana))
    assert created.status_code == 201, created.text
    household = created.json()
    assert household["member_count"] == 1

    invite = client.post(f"/api/v1/households/{household['id']}/invitations", headers=auth(ana))
    assert invite.status_code == 201
    code = invite.json()["code"]

    joined = client.post("/api/v1/households/join", json={"code": code}, headers=auth(bruno))
    assert joined.status_code == 201
    assert joined.json()["member_count"] == 2

    detail = client.get(f"/api/v1/households/{household['id']}", headers=auth(bruno)).json()
    names = {m["display_name"] for m in detail["members"]}
    assert names == {"Ana", "Bruno"}
    assert {m["role"] for m in detail["members"]} == {"owner", "member"}

    # Second user cannot reuse a consumed code
    carol = register(client, "c@example.com", "Carol")
    reused = client.post("/api/v1/households/join", json={"code": code}, headers=auth(carol))
    assert reused.status_code == 404


def test_multiple_households_and_primary(client: TestClient):
    user = register(client, "multi@example.com", "Multi")

    first = client.post("/api/v1/households", json={"name": "Apartamento"}, headers=auth(user)).json()
    second = client.post("/api/v1/households", json={"name": "Casa de campo"}, headers=auth(user)).json()

    households = client.get("/api/v1/members/me/households", headers=auth(user)).json()
    assert len(households) == 2
    primary = [h for h in households if h["is_primary"]]
    assert len(primary) == 1 and primary[0]["household_id"] == first["id"]

    resp = client.patch(
        f"/api/v1/members/me/households/{second['id']}/primary", headers=auth(user)
    )
    assert resp.status_code == 200
    households = resp.json()
    primary = [h for h in households if h["is_primary"]]
    assert len(primary) == 1 and primary[0]["household_id"] == second["id"]


def test_member_profile_and_room_scope(client: TestClient):
    user = register(client, "hijo@example.com", "Hijo")
    household = client.post("/api/v1/households", json={"name": "Casa"}, headers=auth(user)).json()

    resp = client.patch(
        f"/api/v1/members/me/households/{household['id']}/profile",
        json={
            "member_type": "child",
            "capacity_factor": 0.4,
            "weekly_minutes": 60,
            "days_available": [6, 7],
            "room_scope": ["room-abc"],
        },
        headers=auth(user),
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["member_type"] == "child"
    assert body["capacity_factor"] == 0.4
    assert body["room_scope"] == ["room-abc"]


def test_auth_required(client: TestClient):
    assert client.get("/api/v1/members/me/households").status_code == 401
    assert client.post("/api/v1/households", json={"name": "X"}).status_code == 401
