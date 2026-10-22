from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.deps import CurrentUser
from app.core.config import Settings, get_settings
from app.database.session import DbSession
from app.schemas.errors import ErrorResponse
from app.schemas.plus import PlusStatus, PlusTestStart
from app.services.plus_service import PlusService

router = APIRouter(
    tags=["plus"],
    responses={503: {"model": ErrorResponse, "description": "Database unavailable"}},
)


def get_plus_service(
    session: DbSession, user: CurrentUser, settings: Annotated[Settings, Depends(get_settings)]
) -> PlusService:
    return PlusService(session, user.id, settings)


Service = Annotated[PlusService, Depends(get_plus_service)]


@router.get("/me/plus", response_model=PlusStatus, summary="Your PrepLoop Plus status")
def plus_status(service: Service) -> PlusStatus:
    return service.status()


@router.post(
    "/me/plus/test",
    response_model=PlusStatus,
    responses={
        409: {"model": ErrorResponse, "description": "Test mode off, or already subscribed"}
    },
    summary="Start a free test subscription (development servers only)",
)
def start_test(body: PlusTestStart, service: Service) -> PlusStatus:
    return service.start_test(body.days)


@router.delete("/me/plus/test", response_model=PlusStatus, summary="End your test subscription")
def end_test(service: Service) -> PlusStatus:
    return service.end_test()
