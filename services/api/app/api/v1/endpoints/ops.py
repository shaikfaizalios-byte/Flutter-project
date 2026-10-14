import secrets
from typing import Annotated

from fastapi import APIRouter, Depends, Request
from fastapi.responses import PlainTextResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import Settings, get_settings
from app.domain.errors import NotFoundError

router = APIRouter(tags=["ops"])

_bearer = HTTPBearer(auto_error=False)


@router.get(
    "/metrics",
    response_class=PlainTextResponse,
    include_in_schema=False,
    summary="Prometheus metrics (requires PREPLOOP_METRICS_TOKEN)",
)
def metrics(
    request: Request,
    settings: Annotated[Settings, Depends(get_settings)],
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> PlainTextResponse:
    token = settings.metrics_token
    if (
        token is None
        or credentials is None
        or not secrets.compare_digest(credentials.credentials, token.get_secret_value())
    ):
        raise NotFoundError("Not found.")  # metrics stay invisible without the token
    return PlainTextResponse(
        request.app.state.metrics.render(), media_type="text/plain; version=0.0.4"
    )
