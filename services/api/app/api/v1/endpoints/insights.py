from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query

from app.api.deps import CurrentUser
from app.database.session import DbSession
from app.schemas.errors import ErrorResponse
from app.schemas.insights import (
    ChapterReport,
    ConceptHintRead,
    RepeatsReport,
    SharedBankExam,
    SharedChapter,
)
from app.services import shared_bank
from app.services.insights_service import InsightsService
from app.services.repeat_analysis import RepeatAnalysis

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
    summary="How often each topic and question pattern appeared in your papers, the shared "
    "bank, or both",
)
def repeats(
    service: Service,
    exam: Annotated[str | None, Query(max_length=32, description="Exam code")] = None,
    scope: Annotated[
        Literal["mine", "shared", "all"],
        Query(description="mine = your papers; shared = the shared bank; all = both"),
    ] = "mine",
) -> RepeatsReport:
    return service.repeats(exam, scope)


def get_analysis(session: DbSession, user: CurrentUser) -> RepeatAnalysis:
    return RepeatAnalysis(session, owner_id=user.id)


Analysis = Annotated[RepeatAnalysis, Depends(get_analysis)]
Scope = Annotated[Literal["mine", "shared", "all"], Query()]


@router.get(
    "/insights/chapters",
    response_model=ChapterReport,
    summary="Chapters by shift and year, from reviewed questions in the counted papers",
)
def chapters(
    analysis: Analysis, exam: Annotated[str, Query(max_length=32)], scope: Scope = "all"
) -> ChapterReport:
    return analysis.chapters(exam, scope)


@router.get(
    "/insights/shared-chapters",
    response_model=list[SharedChapter],
    summary="Chapters reviewers linked across these exams",
)
def shared_chapters(
    analysis: Analysis,
    exam: Annotated[list[str], Query(min_length=2, max_length=4)],
    scope: Scope = "all",
) -> list[SharedChapter]:
    return analysis.shared_chapters(exam, scope)


@router.get(
    "/insights/concept-hints",
    response_model=list[ConceptHintRead],
    summary="AI hints of questions testing one concept, outside every reviewed count",
)
def concept_hints(
    analysis: Analysis, exam: Annotated[str, Query(max_length=32)]
) -> list[ConceptHintRead]:
    return analysis.hints(exam)


@router.get(
    "/insights/shared-bank",
    response_model=list[SharedBankExam],
    summary="Starter papers: shared papers and verified questions per exam",
)
def shared_bank_exams(session: DbSession) -> list[SharedBankExam]:
    return shared_bank.exams_summary(session)
