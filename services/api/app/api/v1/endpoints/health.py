from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.config import Settings, get_settings
from app.schemas.health import HealthResponse

router = APIRouter()


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
