from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.deps import CurrentUser
from app.core.config import Settings, get_settings
from app.database.session import DbSession
from app.schemas.analytics import AnalyticsOverview, CanonicalTopicStats, SpeedReport
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
    "/analytics/canonical",
    response_model=list[CanonicalTopicStats],
    summary="Answers on topics that mean the same across exams, per exam and combined",
)
def canonical(
    service: Service,
    exam: Annotated[list[str], Query(max_length=20, description="Exams to compare")],
) -> list[CanonicalTopicStats]:
    return service.canonical(exam)


@router.get(
    "/analytics/speed",
    response_model=SpeedReport,
    summary="Speed per question type: accuracy, time and right-but-slow against the target",
)
def speed_report(
    service: Service,
    settings: Annotated[Settings, Depends(get_settings)],
    exam: Annotated[str, Query(max_length=32)],
    own_target_seconds: Annotated[
        float | None,
        Query(gt=0, le=600, description="The learner's own target, used only without a format"),
    ] = None,
) -> SpeedReport:
    return service.speed(
        exam, own_target_seconds=own_target_seconds, slow_factor=settings.speed_slow_factor
    )


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
    exam: Annotated[
        str | None,
        Query(max_length=32, description="Only this exam; all if omitted"),
    ] = None,
) -> AnalyticsOverview:
    return service.overview(timezone=timezone, days=days, recent_days=recent_days, exam=exam)
