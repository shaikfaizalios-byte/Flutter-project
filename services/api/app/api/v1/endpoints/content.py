"""Learners report shared content (docs/shared-bank.md "Rights, reports and takedown")."""

from typing import Annotated, Any

from fastapi import APIRouter, Depends, status

from app.api.deps import CurrentUser
from app.database.session import DbSession
from app.schemas.content import ContentReportCreate, ContentReportRead
from app.schemas.errors import ErrorResponse
from app.services.content import ContentReports

router = APIRouter(
    tags=["content"],
    responses={503: {"model": ErrorResponse, "description": "Database unavailable"}},
)
ERRORS: dict[int | str, dict[str, Any]] = {
    404: {"model": ErrorResponse, "description": "Not a shared paper you can see"},
    429: {"model": ErrorResponse, "description": "Too many reports today"},
}


def get_reports(session: DbSession, user: CurrentUser) -> ContentReports:
    return ContentReports(session, user.id)


Reports = Annotated[ContentReports, Depends(get_reports)]


@router.post(
    "/content-reports",
    response_model=ContentReportRead,
    status_code=status.HTTP_201_CREATED,
    responses=ERRORS,
    summary="Report a shared paper or question (rights problem, error, other)",
)
def report_content(body: ContentReportCreate, reports: Reports) -> ContentReportRead:
    return reports.create(body)


@router.get(
    "/content-reports",
    response_model=list[ContentReportRead],
    summary="Your reports and their status",
)
def my_reports(reports: Reports) -> list[ContentReportRead]:
    return reports.mine()
