"""Engine/session lifecycle and the per-request session dependency."""

from collections.abc import Iterator
from typing import Annotated

from fastapi import Depends, HTTPException, Request
from sqlalchemy import Engine, create_engine, text
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import Settings


def build_engine(settings: Settings) -> Engine | None:
    if settings.database_url is None:
        return None
    return create_engine(
        settings.database_url.get_secret_value(),
        pool_size=settings.database_pool_size,
        pool_pre_ping=True,
        connect_args={"connect_timeout": settings.database_connect_timeout_seconds},
    )


def build_sessionmaker(engine: Engine) -> sessionmaker[Session]:
    # expire_on_commit=False lets services return ORM objects after committing.
    return sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def check_database(engine: Engine) -> None:
    """Raises if the database cannot be reached."""
    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))


def get_session(request: Request) -> Iterator[Session]:
    factory: sessionmaker[Session] | None = getattr(request.app.state, "sessionmaker", None)
    if factory is None:
        raise HTTPException(status_code=503, detail="The database is not configured.")
    with factory() as session:
        try:
            yield session
        except Exception:
            session.rollback()
            raise


DbSession = Annotated[Session, Depends(get_session)]
