from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.deps import CurrentUser
from app.database.session import DbSession
from app.schemas.analytics import AnalyticsOverview
from app.schemas.errors import ErrorResponse
from app.services.analytics_service import AnalyticsService

router = APIRouter(
    tags=["analytics"],
    responses={503: {"model": ErrorResponse, "description": "Database unavailable"}},
)


def get_analytics_service(session: DbSession, user: CurrentUser) -> AnalyticsService:
    return AnalyticsService(session, owner_id=user.id)


Service = Annotated[AnalyticsService, Depends(get_analytics_service)]


@router.get(
    "/analytics/overview",
    response_model=AnalyticsOverview,
    summary="Answer counts per subject, topic and local day, plus mock results",
    responses={422: {"model": ErrorResponse, "description": "Unknown timezone"}},
)
def overview(
    service: Service,
    timezone: Annotated[
        str,
        Query(
            min_length=1, max_length=64, description="Learner's IANA timezone, e.g. Asia/Kolkata"
        ),
    ],
    days: Annotated[int, Query(ge=1, le=365, description="Days of daily history")] = 30,
    recent_days: Annotated[
        int, Query(ge=1, le=90, description="Window for the recent counts (trend)")
    ] = 14,
) -> AnalyticsOverview:
    return service.overview(timezone=timezone, days=days, recent_days=recent_days)
