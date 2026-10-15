from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.deps import CurrentUser
from app.database.session import DbSession
from app.schemas.errors import ErrorResponse
from app.schemas.insights import RepeatsReport
from app.services.insights_service import InsightsService

router = APIRouter(
    tags=["insights"],
    responses={503: {"model": ErrorResponse, "description": "Database unavailable"}},
)


def get_insights_service(session: DbSession, user: CurrentUser) -> InsightsService:
    return InsightsService(session, owner_id=user.id)


Service = Annotated[InsightsService, Depends(get_insights_service)]


@router.get(
    "/insights/repeats",
    response_model=RepeatsReport,
    summary="How often each topic and question pattern appeared in your imported papers",
)
def repeats(
    service: Service,
    exam: Annotated[
        str | None, Query(max_length=32, description="Exam code, e.g. SSC_CHSL")
    ] = None,
) -> RepeatsReport:
    return service.repeats(exam)
