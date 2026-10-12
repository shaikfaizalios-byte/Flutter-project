from collections.abc import Iterator
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy import Engine, create_engine, text
from sqlalchemy.orm import Session

from app.core.config import Environment, Settings
from app.database.session import get_session
from app.main import create_app

API_ROOT = Path(__file__).resolve().parents[1]


class _TestDatabaseSettings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="PREPLOOP_", env_file=API_ROOT / ".env", extra="ignore"
    )

    test_database_url: SecretStr | None = None


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
    """App without a database (database-backed endpoints return 503)."""
    with TestClient(create_app(settings), raise_server_exceptions=False) as test_client:
        yield test_client


def _alembic_config(connection: object) -> Config:
    config = Config(str(API_ROOT / "alembic.ini"))
    config.attributes["connection"] = connection
    config.attributes["configure_logger"] = False
    return config


@pytest.fixture(scope="session")
def db_engine() -> Iterator[Engine]:
    """Real PostgreSQL test database, rebuilt from migrations once per test run.

    Running upgrade → downgrade → upgrade also verifies the migrations are reversible.
    """
    url = _TestDatabaseSettings().test_database_url
    if url is None:
        pytest.skip("PREPLOOP_TEST_DATABASE_URL is not set; skipping database tests.")
    engine = create_engine(url.get_secret_value())
    with engine.begin() as connection:
        connection.execute(text("DROP SCHEMA IF EXISTS public CASCADE"))
        connection.execute(text("CREATE SCHEMA public"))
    with engine.begin() as connection:
        config = _alembic_config(connection)
        command.upgrade(config, "head")
        command.downgrade(config, "base")
        command.upgrade(config, "head")
    yield engine
    engine.dispose()


@pytest.fixture
def db_session(db_engine: Engine) -> Iterator[Session]:
    """A session whose commits become savepoints inside an outer transaction that is
    rolled back after each test, so tests are isolated and leave no data behind."""
    connection = db_engine.connect()
    transaction = connection.begin()
    session = Session(
        bind=connection,
        join_transaction_mode="create_savepoint",
        autoflush=False,
        expire_on_commit=False,
    )
    try:
        yield session
    finally:
        session.close()
        transaction.rollback()
        connection.close()


@pytest.fixture
def db_client(settings: Settings, db_engine: Engine, db_session: Session) -> Iterator[TestClient]:
    app = create_app(settings, engine=db_engine)
    app.dependency_overrides[get_session] = lambda: db_session
    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client
