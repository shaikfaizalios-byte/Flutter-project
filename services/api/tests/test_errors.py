from fastapi import FastAPI, Query
from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app


def test_unknown_route_returns_consistent_error_shape(client: TestClient) -> None:
    response = client.get("/api/v1/does-not-exist")

    assert response.status_code == 404
    body = response.json()
    assert body["error"]["code"] == "not_found"
    assert body["error"]["request_id"] == response.headers["X-Request-ID"]
    assert body["error"]["details"] == []


def test_wrong_method_returns_405(client: TestClient) -> None:
    response = client.post("/api/v1/health")

    assert response.status_code == 405
    assert response.json()["error"]["code"] == "method_not_allowed"


def _app_with_test_routes(settings: Settings) -> FastAPI:
    app = create_app(settings)

    @app.get("/test/validate")
    def validate(count: int = Query(ge=1)) -> dict[str, int]:
        return {"count": count}

    @app.get("/test/boom")
    def boom() -> None:
        raise RuntimeError("secret internal detail")

    return app


def test_validation_error_lists_fields(settings: Settings) -> None:
    client = TestClient(_app_with_test_routes(settings), raise_server_exceptions=False)

    response = client.get("/test/validate", params={"count": "0"})

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "validation_error"
    assert error["details"][0]["field"] == "query.count"


def test_unhandled_error_hides_internal_details(settings: Settings) -> None:
    client = TestClient(_app_with_test_routes(settings), raise_server_exceptions=False)

    response = client.get("/test/boom")

    assert response.status_code == 500
    assert response.json()["error"]["code"] == "internal_error"
    assert "secret internal detail" not in response.text
    assert "Traceback" not in response.text
