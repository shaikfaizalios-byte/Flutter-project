from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.deps import CurrentUser
from app.database.session import DbSession
from app.schemas.errors import ErrorResponse
from app.schemas.sync import PullResult, PushRequest, PushResult
from app.services.sync_service import MAX_PULL, SyncService

router = APIRouter(
    prefix="/sync",
    tags=["sync"],
    responses={503: {"model": ErrorResponse, "description": "Database unavailable"}},
)


def get_sync_service(session: DbSession, user: CurrentUser) -> SyncService:
    return SyncService(session, user.id)


Service = Annotated[SyncService, Depends(get_sync_service)]


@router.post(
    "/push",
    response_model=PushResult,
    summary="Upload this device's changes (last writer wins; deletes win over edits)",
)
def push(body: PushRequest, service: Service) -> PushResult:
    return service.push(body.changes)


@router.get(
    "/pull",
    response_model=PullResult,
    summary="Changes for this account after `cursor`, oldest first",
)
def pull(
    service: Service,
    cursor: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1, le=MAX_PULL)] = MAX_PULL,
) -> PullResult:
    return service.pull(cursor, limit)
