import uuid

from fastapi.testclient import TestClient
from sqlalchemy import Engine, create_engine

from app.core.config import Settings
from app.main import create_app
from app.models.user import User
from tests.conftest import auth_headers


def test_ready_without_database_reports_not_configured(client: TestClient) -> None:
    response = client.get("/api/v1/health/ready")

    assert response.status_code == 503
    assert response.json() == {"status": "not_ready", "checks": {"database": "not_configured"}}


def test_ready_with_reachable_database(settings: Settings, db_engine: Engine) -> None:
    with TestClient(create_app(settings, engine=db_engine)) as client:
        response = client.get("/api/v1/health/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready", "checks": {"database": "ok"}}


def test_ready_with_unreachable_database(settings: Settings) -> None:
    # Port 1 on localhost refuses connections immediately.
    engine = create_engine(
        "postgresql+psycopg://nobody:secret@127.0.0.1:1/none",
        connect_args={"connect_timeout": 1},
    )
    with TestClient(create_app(settings, engine=engine)) as client:
        response = client.get("/api/v1/health/ready")

    assert response.status_code == 503
    assert response.json()["checks"] == {"database": "unavailable"}
    assert "secret" not in response.text


def test_liveness_does_not_depend_on_database(client: TestClient) -> None:
    assert client.get("/api/v1/health").status_code == 200


def test_database_endpoint_without_database_returns_503_envelope(client: TestClient) -> None:
    response = client.get("/api/v1/concepts")

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "service_unavailable"


def test_database_endpoint_with_unreachable_database_returns_503(settings: Settings) -> None:
    engine = create_engine(
        "postgresql+psycopg://nobody:secret@127.0.0.1:1/none",
        connect_args={"connect_timeout": 1},
    )
    with TestClient(create_app(settings, engine=engine), raise_server_exceptions=False) as client:
        # A token makes the request reach the database (loading the account).
        response = client.get("/api/v1/concepts", headers=auth_headers(User(id=uuid.uuid4())))

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "database_unavailable"
    assert "secret" not in response.text
