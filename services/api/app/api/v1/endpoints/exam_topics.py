"""A learner's exams (catalog + own) and their own topics and question types."""

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Depends, File, Form, Request, Response, UploadFile

from app.api.deps import CurrentUser
from app.api.v1.endpoints.documents import UPLOAD_ERRORS, guard_upload
from app.core.config import Settings, get_settings
from app.database.session import DbSession
from app.schemas.concept import Language
from app.schemas.errors import ErrorResponse
from app.schemas.exam import (
    CustomExamCreate,
    CustomExamUpdate,
    ExamRead,
    OwnTopicRead,
    PatternCreate,
    SyllabusDraftRead,
    SyllabusImportRead,
    SyllabusText,
    TopicCompletionUpdate,
    TopicCreate,
    TopicsBulkCreate,
    TopicsBulkDelete,
    TopicsDeleted,
    TopicUpdate,
)
from app.schemas.question import PatternRead
from app.services.syllabus_service import SyllabusService
from app.services.topic_service import TopicService

router = APIRouter(
    tags=["exams"],
    responses={503: {"model": ErrorResponse, "description": "Database unavailable"}},
)
NOT_FOUND: dict[int | str, dict[str, Any]] = {404: {"model": ErrorResponse}}
CONFLICT: dict[int | str, dict[str, Any]] = {409: {"model": ErrorResponse}}


def get_topic_service(session: DbSession, user: CurrentUser) -> TopicService:
    return TopicService(session, owner_id=user.id)


Service = Annotated[TopicService, Depends(get_topic_service)]


@router.get("/me/exams", response_model=list[ExamRead], summary="Catalog exams plus your own")
def my_exams(service: Service) -> list[ExamRead]:
    return service.exams()


@router.post(
    "/me/exams",
    response_model=ExamRead,
    status_code=201,
    responses=CONFLICT,
    summary="Create your own exam (private to you)",
)
def create_exam(body: CustomExamCreate, service: Service) -> ExamRead:
    return service.create_exam(body)


@router.patch("/me/exams/{code}", response_model=ExamRead, responses=NOT_FOUND)
def rename_exam(code: str, body: CustomExamUpdate, service: Service) -> ExamRead:
    return service.rename_exam(code, body)


@router.delete(
    "/me/exams/{code}",
    status_code=204,
    responses={**NOT_FOUND, **CONFLICT},
    summary="Delete one of your own exams (only when nothing uses it)",
)
def delete_exam(code: str, service: Service) -> Response:
    service.delete_exam(code)
    return Response(status_code=204)


@router.get(
    "/exams/{code}/topics",
    response_model=list[OwnTopicRead],
    summary="Topics that apply to an exam: shared ones and your own",
)
def exam_topics(code: str, service: Service) -> list[OwnTopicRead]:
    return service.topics(code)


@router.post(
    "/exams/{code}/syllabus",
    response_model=SyllabusDraftRead,
    responses=UPLOAD_ERRORS,
    dependencies=[Depends(guard_upload)],
    summary="Read subjects and topics from a syllabus PDF (nothing is saved)",
)
def read_syllabus(
    code: str,
    request: Request,
    session: DbSession,
    user: CurrentUser,
    settings: Annotated[Settings, Depends(get_settings)],
    file: Annotated[UploadFile, File(description="Syllabus PDF")],
    language: Annotated[Language, Form(description="Language of the syllabus")] = "en",
) -> SyllabusDraftRead:
    service = SyllabusService(
        session,
        owner_id=user.id,
        settings=settings,
        ocr=request.app.state.ocr_engine,
        temp_dir=request.app.state.document_storage.temp_dir(),
    )
    return service.read(code, file.file, language)


@router.post(
    "/exams/{code}/syllabus/text",
    response_model=SyllabusDraftRead,
    summary="Read subjects and topics from a typed or pasted syllabus (nothing is saved)",
)
def read_syllabus_text(
    code: str,
    body: SyllabusText,
    request: Request,
    session: DbSession,
    user: CurrentUser,
    settings: Annotated[Settings, Depends(get_settings)],
) -> SyllabusDraftRead:
    service = SyllabusService(
        session,
        owner_id=user.id,
        settings=settings,
        ocr=request.app.state.ocr_engine,
        temp_dir=request.app.state.document_storage.temp_dir(),
    )
    return service.read_text(code, body.text)


@router.get(
    "/exams/{code}/syllabus-imports",
    response_model=list[SyllabusImportRead],
    summary="Your syllabus imports for an exam (each groups the topics it added)",
)
def syllabus_imports(code: str, service: Service) -> list[SyllabusImportRead]:
    return service.syllabus_imports(code)


@router.delete(
    "/syllabus-imports/{import_id}",
    response_model=TopicsDeleted,
    responses=NOT_FOUND,
    summary="Remove a syllabus import and all its topics",
)
def delete_syllabus_import(import_id: uuid.UUID, service: Service) -> TopicsDeleted:
    return TopicsDeleted(deleted=service.delete_syllabus_import(import_id))


@router.post(
    "/topics/bulk-delete",
    response_model=TopicsDeleted,
    summary="Remove several of your own topics (their questions go back to no topic)",
)
def delete_topics(body: TopicsBulkDelete, service: Service) -> TopicsDeleted:
    return TopicsDeleted(deleted=service.delete_topics(body.topic_ids))


@router.put(
    "/topics/{topic_id}/completion",
    response_model=OwnTopicRead,
    responses=NOT_FOUND,
    summary="Mark a topic as revised (or not) for you",
)
def set_topic_completion(
    topic_id: uuid.UUID, body: TopicCompletionUpdate, service: Service
) -> OwnTopicRead:
    return service.set_completed(topic_id, body.completed)


@router.post("/topics", response_model=OwnTopicRead, status_code=201, responses=CONFLICT)
def create_topic(body: TopicCreate, service: Service) -> OwnTopicRead:
    return service.create_topic(body)


@router.post(
    "/topics/bulk",
    response_model=list[OwnTopicRead],
    status_code=201,
    summary="Save several topics at once (e.g. an accepted draft); duplicates are skipped",
)
def create_topics(body: TopicsBulkCreate, service: Service) -> list[OwnTopicRead]:
    return service.create_topics(body.exam_code, body.topics, body.source)


@router.patch(
    "/topics/{topic_id}", response_model=OwnTopicRead, responses={**NOT_FOUND, **CONFLICT}
)
def update_topic(topic_id: uuid.UUID, body: TopicUpdate, service: Service) -> OwnTopicRead:
    return service.update_topic(topic_id, body)


@router.delete(
    "/topics/{topic_id}",
    status_code=204,
    responses=NOT_FOUND,
    summary="Delete one of your topics (its questions go back to 'no topic')",
)
def delete_topic(topic_id: uuid.UUID, service: Service) -> Response:
    service.delete_topic(topic_id)
    return Response(status_code=204)


@router.post("/patterns", response_model=PatternRead, status_code=201, responses=CONFLICT)
def create_pattern(body: PatternCreate, service: Service) -> PatternRead:
    return service.create_pattern(body)


@router.delete("/patterns/{pattern_id}", status_code=204, responses=NOT_FOUND)
def delete_pattern(pattern_id: uuid.UUID, service: Service) -> Response:
    service.delete_pattern(pattern_id)
    return Response(status_code=204)
