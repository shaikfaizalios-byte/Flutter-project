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
    QuickAnswer,
    QuickAnswerRequest,
    SearchAnswer,
    SearchAnswerRequest,
    TopicDraft,
    TopicLessonRead,
    TopicQuizRead,
    TopicQuizRequest,
    TopicRequest,
    TopicSuggestionResult,
)
from app.schemas.document import DocumentRead
from app.schemas.errors import ErrorResponse
from app.schemas.question import AIExplanationRead, QuestionRead
from app.services.ai_service import AIService
from app.services.plus_service import PlusService
from app.services.question_service import QuestionService

router = APIRouter(
    tags=["ai"],
    responses={503: {"model": ErrorResponse, "description": "Database or AI not available"}},
)

AI_ERRORS: dict[int | str, dict[str, Any]] = {
    403: {"model": ErrorResponse, "description": "PrepLoop Plus required (plus_required)"},
    404: {"model": ErrorResponse, "description": "Not found"},
    409: {"model": ErrorResponse, "description": "Not in a state that allows this"},
    422: {"model": ErrorResponse, "description": "Not eligible for AI assistance"},
    429: {
        "model": ErrorResponse,
        "description": "Too many AI requests, or the monthly allowance is used (ai_allowance_used)",
    },
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


def guard_ai(
    request: Request,
    user: CurrentUser,
    session: DbSession,
    settings: Annotated[Settings, Depends(get_settings)],
    provider: Annotated[AIProvider | None, Depends(get_ai_provider)],
) -> None:
    """Calls that reach the AI provider: rate limit per account (cost and abuse), then PrepLoop
    Plus (active subscription, allowance left). Without a provider the endpoint itself answers
    that AI is off."""
    request.app.state.ai_rate_limiter.check(client_key(request, user))
    if provider is not None:
        PlusService(session, user.id, settings).check_ai_allowed()


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
    "/ai/exams/{exam_code}/topic-draft",
    response_model=TopicDraft,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Draft a topic list for an exam from your imported questions (nothing is saved)",
)
def draft_topics(exam_code: str, service: Service) -> TopicDraft:
    return service.draft_topics(exam_code)


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
    "/ai/quick-answer",
    response_model=QuickAnswer,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="A short AI answer to a search no imported question matched (nothing is saved)",
)
def quick_answer(body: QuickAnswerRequest, service: Service) -> QuickAnswer:
    return service.quick_answer(body)


@router.post(
    "/ai/topic-lesson",
    response_model=TopicLessonRead,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="A short AI lesson on a topic for a learner new to it (nothing is saved)",
)
def topic_lesson(body: TopicRequest, service: Service) -> TopicLessonRead:
    return service.topic_lesson(body)


@router.post(
    "/ai/topic-quiz",
    response_model=TopicQuizRead,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="AI questions to check a topic the learner already knows (nothing is saved)",
)
def topic_quiz(body: TopicQuizRequest, service: Service) -> TopicQuizRead:
    return service.topic_quiz(body)


@router.post(
    "/ai/documents/{document_id}/read",
    response_model=DocumentRead,
    status_code=status.HTTP_202_ACCEPTED,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Read this paper's questions with AI (queued; pages are sent to the AI provider)",
)
def read_paper(document_id: uuid.UUID, service: Service) -> DocumentRead:
    return service.queue_paper_read(document_id)


@router.post(
    "/ai/search-answer",
    response_model=SearchAnswer,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Answer a search only from your own material, with the sources it cites",
)
def search_answer(body: SearchAnswerRequest, service: Service) -> SearchAnswer:
    return service.search_answer(body)


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
