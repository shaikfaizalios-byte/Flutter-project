import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.core.config import Environment, Settings
from app.main import create_app


def test_cors_origins_parsed_from_comma_separated_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("PREPLOOP_CORS_ORIGINS", "https://a.example, https://b.example")

    settings = Settings(_env_file=None)

    assert settings.cors_origins == ["https://a.example", "https://b.example"]


def test_production_rejects_wildcard_cors() -> None:
    with pytest.raises(ValidationError):
        Settings(_env_file=None, environment=Environment.PRODUCTION, cors_origins=["*"])


def test_production_rejects_origin_regex() -> None:
    with pytest.raises(ValidationError):
        Settings(
            _env_file=None,
            environment=Environment.PRODUCTION,
            cors_origin_regex=r"^http://localhost(:\d+)?$",
        )


def test_production_disables_interactive_docs() -> None:
    app = create_app(
        Settings(_env_file=None, environment=Environment.PRODUCTION, auth_secret="s" * 40)
    )
    client = TestClient(app)

    assert client.get("/docs").status_code == 404
    assert client.get("/api/v1/openapi.json").status_code == 404


def test_cors_allows_configured_origin(client: TestClient) -> None:
    response = client.get("/health", headers={"Origin": "https://allowed.example"})

    assert response.headers["access-control-allow-origin"] == "https://allowed.example"


def test_cors_rejects_unknown_origin(client: TestClient) -> None:
    response = client.get("/health", headers={"Origin": "https://evil.example"})

    assert "access-control-allow-origin" not in response.headers


def test_production_and_staging_require_an_auth_secret() -> None:
    for environment in (Environment.PRODUCTION, Environment.STAGING):
        with pytest.raises(ValueError, match="PREPLOOP_AUTH_SECRET"):
            Settings(_env_file=None, environment=environment)
        with pytest.raises(ValueError, match="PREPLOOP_AUTH_SECRET"):
            Settings(_env_file=None, environment=environment, auth_secret="too-short")
