from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.deps import CurrentUser
from app.database.session import DbSession
from app.schemas.errors import ErrorResponse
from app.schemas.radar import RadarReport, RadarSettings, RadarSettingsUpdate
from app.services.radar_service import RadarService

router = APIRouter(
    tags=["radar"],
    responses={503: {"model": ErrorResponse, "description": "Database unavailable"}},
)


def get_radar_service(session: DbSession, user: CurrentUser) -> RadarService:
    return RadarService(session, owner_id=user.id)


Service = Annotated[RadarService, Depends(get_radar_service)]


@router.get(
    "/radar",
    response_model=RadarReport,
    summary="Topic and question-type repetition pooled over learners who share their counts",
)
def radar(
    service: Service,
    exam: Annotated[
        str | None, Query(max_length=32, description="Exam code, e.g. SSC_CHSL")
    ] = None,
) -> RadarReport:
    return service.report(exam)


@router.get("/radar/settings", response_model=RadarSettings, summary="Your Radar sharing choice")
def radar_settings(service: Service) -> RadarSettings:
    return service.settings()


@router.put(
    "/radar/settings",
    response_model=RadarSettings,
    summary="Turn sharing your confirmed counts with the Repeat Radar on or off",
)
def update_radar_settings(body: RadarSettingsUpdate, service: Service) -> RadarSettings:
    return service.set_share(body.share)
