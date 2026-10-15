import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request, status

from app.api.deps import CurrentUser, client_key
from app.core.config import Settings, get_settings
from app.database.session import DbSession
from app.integrations.ai import AIProvider
from app.schemas.ai import (
    AIStatus,
    ExplanationReview,
    GenerateQuestionsRequest,
    GenerateQuestionsResult,
    PaperTopicsResult,
    QuestionReport,
    TopicSuggestionResult,
)
from app.schemas.errors import ErrorResponse
from app.schemas.question import AIExplanationRead, QuestionRead
from app.services.ai_service import AIService
from app.services.question_service import QuestionService

router = APIRouter(
    tags=["ai"],
    responses={503: {"model": ErrorResponse, "description": "Database or AI not available"}},
)

AI_ERRORS: dict[int | str, dict[str, Any]] = {
    404: {"model": ErrorResponse, "description": "Not found"},
    409: {"model": ErrorResponse, "description": "Not in a state that allows this"},
    422: {"model": ErrorResponse, "description": "Not eligible for AI assistance"},
    429: {"model": ErrorResponse, "description": "Too many AI requests (Retry-After)"},
    502: {"model": ErrorResponse, "description": "AI provider failed; retry later"},
}


def get_ai_provider(request: Request) -> AIProvider | None:
    provider: AIProvider | None = request.app.state.ai_provider
    return provider


def get_ai_service(
    session: DbSession,
    provider: Annotated[AIProvider | None, Depends(get_ai_provider)],
    settings: Annotated[Settings, Depends(get_settings)],
    user: CurrentUser,
) -> AIService:
    return AIService(session, user.id, provider, settings)


def guard_ai(request: Request, user: CurrentUser) -> None:
    """Rate limit per account for calls that reach the AI provider (cost and abuse)."""
    request.app.state.ai_rate_limiter.check(client_key(request, user))


Service = Annotated[AIService, Depends(get_ai_service)]
Limited = [Depends(guard_ai)]


@router.get("/ai/status", response_model=AIStatus, summary="Whether AI assistance is available")
def ai_status(service: Service) -> AIStatus:
    return service.status()


@router.post(
    "/ai/questions/{question_id}/explanation",
    response_model=AIExplanationRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Draft an AI explanation for a verified source question without one",
)
def draft_explanation(question_id: uuid.UUID, service: Service) -> AIExplanationRead:
    return service.draft_explanation(question_id)


@router.patch(
    "/ai/explanations/{explanation_id}",
    response_model=AIExplanationRead,
    responses=AI_ERRORS,
    summary="Approve (optionally edited) or reject an AI explanation",
)
def review_explanation(
    explanation_id: uuid.UUID, body: ExplanationReview, service: Service
) -> AIExplanationRead:
    return service.review_explanation(explanation_id, body)


@router.post(
    "/ai/questions/generate",
    response_model=GenerateQuestionsResult,
    status_code=status.HTTP_201_CREATED,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Generate unverified AI practice questions from a verified question or a concept",
)
def generate_questions(body: GenerateQuestionsRequest, service: Service) -> GenerateQuestionsResult:
    return service.generate_questions(body)


@router.post(
    "/ai/documents/{document_id}/topic-suggestions",
    response_model=PaperTopicsResult,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Suggest topics for a paper's questions that have none (call again while "
    "'remaining' > 0)",
)
def suggest_paper_topics(document_id: uuid.UUID, service: Service) -> PaperTopicsResult:
    return service.suggest_paper_topics(document_id)


@router.post(
    "/ai/questions/{question_id}/topic-suggestion",
    response_model=TopicSuggestionResult,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Suggest a topic from the taxonomy for a question without one",
)
def suggest_topic(question_id: uuid.UUID, service: Service) -> TopicSuggestionResult:
    return service.suggest_topic(question_id)


@router.post(
    "/questions/{question_id}/report",
    response_model=QuestionRead,
    responses={404: {"model": ErrorResponse, "description": "Not found"}},
    summary="Report a question as wrong or unclear (sends it back to review)",
)
def report_question(
    question_id: uuid.UUID, body: QuestionReport, session: DbSession, user: CurrentUser
) -> QuestionRead:
    return QuestionService(session, user.id).report(question_id, body.reason, body.note)
