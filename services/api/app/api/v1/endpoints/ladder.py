import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Path, Query, status

from app.api.deps import CurrentUser
from app.api.v1.endpoints.ai import AI_ERRORS, Limited, get_ai_provider
from app.core.config import Settings, get_settings
from app.database.session import DbSession
from app.domain.challenge_ladder import STEPS
from app.integrations.ai import AIProvider
from app.schemas.ladder import (
    LadderAnswer,
    LadderOverview,
    LadderRoundRead,
    LadderStart,
    LadderStepRead,
)
from app.services.ladder_service import LadderService

router = APIRouter(prefix="/ladder", tags=["ladder"])


def get_ladder_service(
    session: DbSession,
    provider: Annotated[AIProvider | None, Depends(get_ai_provider)],
    settings: Annotated[Settings, Depends(get_settings)],
    user: CurrentUser,
) -> LadderService:
    return LadderService(session, user.id, provider, settings)


Service = Annotated[LadderService, Depends(get_ladder_service)]
StepNumber = Annotated[int, Path(ge=1, le=STEPS)]
RoundNumber = Annotated[int, Path(ge=1)]


@router.get(
    "/overview",
    response_model=LadderOverview,
    summary="Topics for an exam, most repeated first, and the learner's own best climb",
)
def overview(exam: Annotated[str, Query(max_length=32)], service: Service) -> LadderOverview:
    return service.overview(exam)


@router.post(
    "/sessions",
    response_model=LadderRoundRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Start a ladder on a topic: plans round 1 (questions come step by step)",
)
def start(body: LadderStart, service: Service) -> LadderRoundRead:
    return service.start(body)


@router.post(
    "/sessions/{session_id}/rounds",
    response_model=LadderRoundRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Test me more: plans the next, harder round",
)
def next_round(session_id: uuid.UUID, service: Service) -> LadderRoundRead:
    return service.next_round(session_id)


@router.get(
    "/sessions/{session_id}/rounds/{round_number}",
    response_model=LadderRoundRead,
    summary="A round with its steps (answers only for answered steps)",
)
def read_round(
    session_id: uuid.UUID, round_number: RoundNumber, service: Service
) -> LadderRoundRead:
    return service.read_round(session_id, round_number)


@router.post(
    "/sessions/{session_id}/rounds/{round_number}/steps/{step}/generate",
    response_model=LadderStepRead,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Write and check one step's question (paper text and web excerpts go to the AI)",
)
def generate(
    session_id: uuid.UUID, round_number: RoundNumber, step: StepNumber, service: Service
) -> LadderStepRead:
    return service.generate(session_id, round_number, step)


@router.post(
    "/sessions/{session_id}/rounds/{round_number}/steps/{step}/answer",
    response_model=LadderStepRead,
    summary="Answer a step: returns whether it was right, with the solution",
)
def answer(
    session_id: uuid.UUID,
    round_number: RoundNumber,
    step: StepNumber,
    body: LadderAnswer,
    service: Service,
) -> LadderStepRead:
    return service.answer(session_id, round_number, step, body)
