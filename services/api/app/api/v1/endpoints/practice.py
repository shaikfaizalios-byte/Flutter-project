import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Query, status

from app.database.session import DbSession
from app.schemas.errors import ErrorResponse
from app.schemas.practice import (
    AnswerAck,
    AnswerUpdate,
    MockAvailability,
    MockCreate,
    PracticeCreate,
    QuestionHistory,
    SessionList,
    SessionRead,
)
from app.schemas.question import QuestionList
from app.services.practice_service import PracticeService
from app.services.question_service import QuestionService

router = APIRouter(
    tags=["practice"],
    responses={503: {"model": ErrorResponse, "description": "Database unavailable"}},
)

NOT_FOUND: dict[int | str, dict[str, Any]] = {
    404: {"model": ErrorResponse, "description": "Not found"}
}


def get_practice_service(session: DbSession) -> PracticeService:
    return PracticeService(session)


Service = Annotated[PracticeService, Depends(get_practice_service)]


@router.post(
    "/practice/sessions",
    response_model=SessionRead,
    status_code=status.HTTP_201_CREATED,
    summary="Start an untimed practice session (topic, subject, section or mixed)",
    responses={422: {"model": ErrorResponse, "description": "no_questions_available"}},
)
def start_practice(body: PracticeCreate, service: Service) -> SessionRead:
    return service.start_practice(body)


@router.get(
    "/practice/mock-tests",
    response_model=list[MockAvailability],
    summary="Mock tests available from verified exam formats",
)
def mock_tests(
    service: Service, exam: Annotated[str | None, Query(max_length=32)] = None
) -> list[MockAvailability]:
    return service.mock_availability(exam)


@router.post(
    "/practice/mock-tests",
    response_model=SessionRead,
    status_code=status.HTTP_201_CREATED,
    summary="Start a timed mock test (structure and marking from the verified format)",
    responses={422: {"model": ErrorResponse, "description": "not_enough_questions"}},
)
def start_mock(body: MockCreate, service: Service) -> SessionRead:
    return service.start_mock(body)


@router.get("/practice/sessions", response_model=SessionList, summary="Session history")
def list_sessions(
    service: Service,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0, le=100_000)] = 0,
) -> SessionList:
    return service.list_sessions(limit=limit, offset=offset)


@router.get("/practice/sessions/{session_id}", response_model=SessionRead, responses=NOT_FOUND)
def get_session(session_id: uuid.UUID, service: Service) -> SessionRead:
    return service.get(session_id)


@router.put(
    "/practice/sessions/{session_id}/answers/{position}",
    response_model=AnswerAck,
    summary="Save an answer (idempotent; older client_seq values are ignored)",
    responses={
        **NOT_FOUND,
        409: {"model": ErrorResponse, "description": "session_closed"},
        422: {"model": ErrorResponse, "description": "invalid_answer"},
    },
)
def save_answer(
    session_id: uuid.UUID, position: int, body: AnswerUpdate, service: Service
) -> AnswerAck:
    return service.answer(session_id, position, body)


@router.post(
    "/practice/sessions/{session_id}/submit",
    response_model=SessionRead,
    summary="Submit (idempotent: returns the existing result if already submitted)",
    responses=NOT_FOUND,
)
def submit_session(session_id: uuid.UUID, service: Service) -> SessionRead:
    return service.submit(session_id)


@router.put(
    "/questions/{question_id}/bookmark",
    status_code=status.HTTP_204_NO_CONTENT,
    responses=NOT_FOUND,
)
def add_bookmark(question_id: uuid.UUID, service: Service) -> None:
    service.set_bookmark(question_id, bookmarked=True)


@router.delete(
    "/questions/{question_id}/bookmark",
    status_code=status.HTTP_204_NO_CONTENT,
    responses=NOT_FOUND,
)
def remove_bookmark(question_id: uuid.UUID, service: Service) -> None:
    service.set_bookmark(question_id, bookmarked=False)


@router.get(
    "/questions/{question_id}/history",
    response_model=QuestionHistory,
    responses=NOT_FOUND,
    summary="Attempts and last result for a question",
)
def question_history(question_id: uuid.UUID, service: Service) -> QuestionHistory:
    return service.history(question_id)


@router.get("/practice/bookmarks", response_model=QuestionList, summary="Bookmarked questions")
def bookmarks(service: Service, session: DbSession) -> QuestionList:
    return QuestionService(session).by_ids(service.bookmarked_ids())


@router.get(
    "/practice/incorrect",
    response_model=QuestionList,
    summary="Questions whose latest answer was wrong (for review)",
)
def incorrect(service: Service, session: DbSession) -> QuestionList:
    return QuestionService(session).by_ids(service.incorrect_ids())
