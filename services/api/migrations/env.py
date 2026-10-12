"""Alembic environment.

URL resolution order:
1. A connection passed programmatically via ``config.attributes["connection"]`` (tests).
2. ``PREPLOOP_DATABASE_URL`` from the environment or services/api/.env (app settings).
"""

from logging.config import fileConfig

from alembic import context
from sqlalchemy import Connection, create_engine, pool

import app.models  # noqa: F401  (registers all tables on Base.metadata)
from app.core.config import Settings
from app.database.base import Base

config = context.config

if config.config_file_name is not None and config.attributes.get("configure_logger", True):
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def _database_url() -> str:
    settings = Settings()
    if settings.database_url is None:
        raise RuntimeError("PREPLOOP_DATABASE_URL is not set (see services/api/.env.example).")
    return settings.database_url.get_secret_value()


def _configure(connection: Connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=True,
        compare_server_default=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_offline() -> None:
    """Emit SQL to stdout (``alembic upgrade head --sql``) without a database."""
    context.configure(
        url=_database_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connection = config.attributes.get("connection")
    if connection is not None:
        _configure(connection)
        return
    engine = create_engine(_database_url(), poolclass=pool.NullPool)
    with engine.connect() as conn:
        _configure(conn)


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
