"""A learner's exams (catalog + own) and their own topics and question types."""

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Response

from app.api.deps import CurrentUser
from app.database.session import DbSession
from app.schemas.errors import ErrorResponse
from app.schemas.exam import (
    CustomExamCreate,
    CustomExamUpdate,
    ExamRead,
    OwnTopicRead,
    PatternCreate,
    TopicCreate,
    TopicsBulkCreate,
    TopicUpdate,
)
from app.schemas.question import PatternRead
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
    return service.create_topics(body.exam_code, body.topics)


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
