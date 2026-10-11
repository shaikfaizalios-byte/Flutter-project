import pytest
from fastapi.testclient import TestClient


@pytest.mark.parametrize("path", ["/health", "/api/v1/health"])
def test_health_returns_ok(client: TestClient, path: str) -> None:
    response = client.get(path)

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "PrepLoop API",
        "version": "0.1.0",
        "environment": "test",
    }


def test_response_carries_generated_request_id(client: TestClient) -> None:
    response = client.get("/health")

    assert len(response.headers["X-Request-ID"]) == 32


def test_valid_incoming_request_id_is_echoed(client: TestClient) -> None:
    response = client.get("/health", headers={"X-Request-ID": "abc-123"})

    assert response.headers["X-Request-ID"] == "abc-123"


def test_unsafe_incoming_request_id_is_replaced(client: TestClient) -> None:
    response = client.get("/health", headers={"X-Request-ID": "bad id\twith spaces"})

    assert response.headers["X-Request-ID"] != "bad id\twith spaces"
    assert len(response.headers["X-Request-ID"]) == 32
