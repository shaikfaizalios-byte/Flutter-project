import logging
from typing import Annotated

from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy import Engine
from sqlalchemy.exc import SQLAlchemyError

from app.core.config import Settings, get_settings
from app.database.session import check_database
from app.schemas.health import CheckStatus, HealthResponse, ReadinessResponse

router = APIRouter()
logger = logging.getLogger("app.health")


def build_health(settings: Settings) -> HealthResponse:
    return HealthResponse(
        status="ok",
        service=settings.app_name,
        version=settings.app_version,
        environment=settings.environment.value,
    )


@router.get("/health", response_model=HealthResponse, summary="Liveness check")
def health(settings: Annotated[Settings, Depends(get_settings)]) -> HealthResponse:
    return build_health(settings)


@router.get(
    "/health/ready",
    response_model=ReadinessResponse,
    summary="Readiness check (dependencies reachable)",
    responses={503: {"model": ReadinessResponse, "description": "A dependency is unavailable"}},
)
def readiness(request: Request) -> JSONResponse:
    engine: Engine | None = getattr(request.app.state, "engine", None)
    database: CheckStatus
    if engine is None:
        database = "not_configured"
    else:
        try:
            check_database(engine)
            database = "ok"
        except SQLAlchemyError as exc:
            # Log the class only: driver messages can include host and user names.
            logger.warning("database readiness check failed: %s", type(exc).__name__)
            database = "unavailable"
    ready = database == "ok"
    body = ReadinessResponse(
        status="ready" if ready else "not_ready", checks={"database": database}
    )
    return JSONResponse(status_code=200 if ready else 503, content=body.model_dump())
