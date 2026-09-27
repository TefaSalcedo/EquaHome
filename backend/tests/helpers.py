"""Helpers compartidos entre los tests de fases."""

from fastapi.testclient import TestClient


def register(client: TestClient, email: str, name: str = "Ana") -> dict:
    resp = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "password123", "display_name": name},
    )
    assert resp.status_code == 201, resp.text
    return resp.json()


def auth(tokens: dict) -> dict:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def create_household(client: TestClient, tokens: dict, name: str = "Casa Centro") -> str:
    resp = client.post("/api/v1/households", json={"name": name}, headers=auth(tokens))
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]
