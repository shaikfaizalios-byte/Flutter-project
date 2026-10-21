from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.api.deps import CurrentUser
from app.database.session import DbSession
from app.schemas.errors import ErrorResponse
from app.schemas.feedback import SuggestionCreate, SuggestionRead
from app.services.feedback_service import FeedbackService

router = APIRouter(
    tags=["feedback"],
    responses={503: {"model": ErrorResponse, "description": "Database unavailable"}},
)


def get_feedback_service(session: DbSession, user: CurrentUser) -> FeedbackService:
    return FeedbackService(session, owner_id=user.id)


Service = Annotated[FeedbackService, Depends(get_feedback_service)]


@router.post(
    "/suggestions",
    response_model=SuggestionRead,
    status_code=status.HTTP_201_CREATED,
    responses={429: {"model": ErrorResponse, "description": "Too many suggestions today"}},
    summary="Suggest a feature to add, remove or change",
)
def suggest(body: SuggestionCreate, service: Service) -> SuggestionRead:
    return service.suggest(body)


@router.get("/suggestions", response_model=list[SuggestionRead], summary="Your suggestions")
def my_suggestions(service: Service) -> list[SuggestionRead]:
    return service.mine()
