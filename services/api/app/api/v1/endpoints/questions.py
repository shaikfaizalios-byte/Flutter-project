import uuid
from typing import Annotated, Any, Literal

from fastapi import APIRouter, Depends, Query, Response

from app.api.deps import CurrentUser
from app.database.session import DbSession
from app.schemas.concept import Language
from app.schemas.errors import ErrorResponse
from app.schemas.question import (
    ExamFormatRead,
    PatternRead,
    QuestionList,
    QuestionRead,
    QuestionUpdate,
    TopicRead,
    VerificationLiteral,
)
from app.services.question_service import QuestionFilter, QuestionService

router = APIRouter(responses={503: {"model": ErrorResponse, "description": "Database unavailable"}})

NOT_FOUND: dict[int | str, dict[str, Any]] = {
    404: {"model": ErrorResponse, "description": "Question not found"}
}


def get_question_service(session: DbSession, user: CurrentUser) -> QuestionService:
    return QuestionService(session, user.id)


Service = Annotated[QuestionService, Depends(get_question_service)]


@router.get(
    "/questions", response_model=QuestionList, tags=["questions"], summary="Search questions"
)
def list_questions(
    service: Service,
    q: Annotated[str | None, Query(max_length=100, description="Text search in the stem")] = None,
    exam: Annotated[str | None, Query(max_length=32)] = None,
    section: Annotated[str | None, Query(max_length=120)] = None,
    subject: Annotated[str | None, Query(max_length=100)] = None,
    topic_id: uuid.UUID | None = None,
    pattern_id: uuid.UUID | None = None,
    language: Language | None = None,
    document_id: uuid.UUID | None = None,
    status: VerificationLiteral | None = None,
    has_issues: bool | None = None,
    image_dependent: bool | None = None,
    origin: Literal["source", "ai"] | None = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0, le=100_000)] = 0,
) -> QuestionList:
    filters = QuestionFilter(
        query=q.strip() if q and q.strip() else None,
        exam_code=exam,
        section=section,
        subject=subject,
        topic_id=topic_id,
        pattern_id=pattern_id,
        language=language,
        document_id=document_id,
        status=status,
        has_issues=has_issues,
        image_dependent=image_dependent,
        origin=origin,
    )
    return service.search(filters, limit=limit, offset=offset)


@router.get(
    "/questions/{question_id}", response_model=QuestionRead, tags=["questions"], responses=NOT_FOUND
)
def get_question(question_id: uuid.UUID, service: Service) -> QuestionRead:
    return service.get(question_id)


@router.patch(
    "/questions/{question_id}",
    response_model=QuestionRead,
    tags=["questions"],
    summary="Review a question (edit, verify, reject)",
    responses={
        **NOT_FOUND,
        422: {"model": ErrorResponse, "description": "validation_error, cannot_verify"},
    },
)
def update_question(question_id: uuid.UUID, body: QuestionUpdate, service: Service) -> QuestionRead:
    return service.update(question_id, body)


@router.get(
    "/questions/{question_id}/figures/{figure_id}",
    tags=["questions"],
    summary="A figure cropped from the question's source PDF (PNG)",
    response_class=Response,
    responses={
        200: {"content": {"image/png": {}}, "description": "The image"},
        404: {"model": ErrorResponse, "description": "Figure not found"},
    },
)
def get_question_figure(question_id: uuid.UUID, figure_id: uuid.UUID, service: Service) -> Response:
    figure = service.figure(question_id, figure_id)
    return Response(
        content=figure.data,
        media_type=figure.content_type,
        # Figures never change (a re-run creates new ids); only this account may cache them.
        headers={"Cache-Control": "private, max-age=604800, immutable"},
    )


@router.get("/patterns", response_model=list[PatternRead], tags=["questions"])
def list_patterns(service: Service, topic_id: uuid.UUID | None = None) -> list[PatternRead]:
    """Named question types within topics (taxonomy data)."""
    return service.patterns(topic_id)


@router.get("/topics", response_model=list[TopicRead], tags=["questions"])
def list_topics(
    service: Service, subject: Annotated[str | None, Query(max_length=100)] = None
) -> list[TopicRead]:
    return service.topics(subject)


@router.get(
    "/exam-formats",
    response_model=list[ExamFormatRead],
    tags=["exams"],
    summary="Verified paper formats (with official source references)",
)
def list_exam_formats(
    service: Service, exam: Annotated[str | None, Query(max_length=32)] = None
) -> list[ExamFormatRead]:
    return service.exam_formats(exam)
