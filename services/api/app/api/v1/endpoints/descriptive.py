import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, File, Path, Query, UploadFile, status

from app.api.deps import CurrentUser
from app.api.v1.endpoints.ai import AI_ERRORS, Limited, get_ai_provider
from app.core.config import Settings, get_settings
from app.database.session import DbSession
from app.integrations.ai import AIProvider
from app.schemas.descriptive import (
    DescriptiveAnswer,
    DescriptiveOverview,
    DescriptivePhotoRead,
    DescriptiveSessionRead,
    DescriptiveStart,
    DescriptiveStepRead,
)
from app.services.descriptive_service import DescriptiveService

router = APIRouter(prefix="/descriptive", tags=["descriptive"])


def get_descriptive_service(
    session: DbSession,
    provider: Annotated[AIProvider | None, Depends(get_ai_provider)],
    settings: Annotated[Settings, Depends(get_settings)],
    user: CurrentUser,
) -> DescriptiveService:
    return DescriptiveService(session, user.id, provider, settings)


Service = Annotated[DescriptiveService, Depends(get_descriptive_service)]
StepNumber = Annotated[int, Path(ge=1, le=20)]


@router.get(
    "/overview",
    response_model=DescriptiveOverview,
    summary="Whether an exam has written practice, and its topics",
)
def overview(exam: Annotated[str, Query(max_length=32)], service: Service) -> DescriptiveOverview:
    return service.overview(exam)


@router.post(
    "/sessions",
    response_model=DescriptiveSessionRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Start written practice on a topic: plans the levels (questions come one by one)",
)
def start(body: DescriptiveStart, service: Service) -> DescriptiveSessionRead:
    return service.start(body)


@router.get(
    "/sessions/{session_id}",
    response_model=DescriptiveSessionRead,
    summary="Read a written practice session",
)
def read(session_id: uuid.UUID, service: Service) -> DescriptiveSessionRead:
    return service.read(session_id)


@router.post(
    "/sessions/{session_id}/steps/{number}/generate",
    response_model=DescriptiveStepRead,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Write one level's question and rubric, and check them",
)
def generate(session_id: uuid.UUID, number: StepNumber, service: Service) -> DescriptiveStepRead:
    return service.generate(session_id, number)


@router.post(
    "/sessions/{session_id}/steps/{number}/answer",
    response_model=DescriptiveStepRead,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Mark an answer against the rubric: estimated marks, not an official grade",
)
def answer(
    session_id: uuid.UUID, number: StepNumber, body: DescriptiveAnswer, service: Service
) -> DescriptiveStepRead:
    return service.answer(session_id, number, body)


@router.post(
    "/read-photo",
    response_model=DescriptivePhotoRead,
    dependencies=Limited,
    responses=AI_ERRORS,
    summary="Read a handwritten answer from a photo for correcting (nothing is stored)",
)
def read_photo(
    file: Annotated[UploadFile, File(description="JPEG or PNG photo")], service: Service
) -> DescriptivePhotoRead:
    return service.read_photo(file.file)
