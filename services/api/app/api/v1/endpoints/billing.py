"""Store purchases for PrepLoop Plus (docs/plus.md "Google Play")."""

import logging
from typing import Annotated, Any

from fastapi import APIRouter, Body, Depends, Request, Response, status

from app.api.deps import CurrentUser
from app.api.v1.endpoints.plus import Service as PlusServiceDep
from app.api.v1.endpoints.plus import billing_service
from app.core.config import Settings, get_settings
from app.database.session import DbSession
from app.domain.errors import UnauthorizedError
from app.integrations.play_billing import PlayBillingError
from app.schemas.errors import ErrorResponse
from app.schemas.plus import PlayPurchaseVerify, PlusStatus

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/billing",
    tags=["billing"],
    responses={503: {"model": ErrorResponse, "description": "Purchases not available"}},
)


@router.post(
    "/play/verify",
    response_model=PlusStatus,
    responses={
        422: {"model": ErrorResponse, "description": "Purchase refused"},
        502: {"model": ErrorResponse, "description": "Google Play unreachable"},
    },
    summary="Add a Google Play purchase to your account (checked with Google first)",
)
def verify_play_purchase(
    body: PlayPurchaseVerify,
    request: Request,
    session: DbSession,
    user: CurrentUser,
    settings: Annotated[Settings, Depends(get_settings)],
    plus: PlusServiceDep,
) -> PlusStatus:
    billing_service(request, session, settings).verify_play(
        user.id, body.product_id, body.purchase_token
    )
    return plus.status()


@router.post(
    "/play/rtdn",
    status_code=status.HTTP_204_NO_CONTENT,
    include_in_schema=False,  # called by Google Pub/Sub only
)
def play_notification(
    request: Request,
    session: DbSession,
    settings: Annotated[Settings, Depends(get_settings)],
    body: Annotated[dict[str, Any], Body()],
) -> Response:
    verifier = request.app.state.play_push_verifier
    if verifier is None:
        raise UnauthorizedError("Notifications are not accepted on this server.")
    try:
        verifier.verify(request.headers.get("authorization"))
    except PlayBillingError as exc:
        logger.warning("Play notification refused: %s", exc.reason)
        raise UnauthorizedError("Not a valid Google push request.") from exc
    billing_service(request, session, settings).handle_notification(body)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
