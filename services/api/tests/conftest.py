from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.core.config import Environment, Settings
from app.main import create_app


@pytest.fixture
def settings() -> Settings:
    # _env_file=None keeps a developer's local .env from influencing tests.
    return Settings(
        _env_file=None,
        environment=Environment.TEST,
        cors_origins=["https://allowed.example"],
    )


@pytest.fixture
def client(settings: Settings) -> Iterator[TestClient]:
    with TestClient(create_app(settings), raise_server_exceptions=False) as test_client:
        yield test_client
