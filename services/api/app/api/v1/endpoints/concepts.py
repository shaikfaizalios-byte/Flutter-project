import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Query, status

from app.api.deps import CurrentUser
from app.database.session import DbSession
from app.repositories.concept_repository import ConceptFilter
from app.schemas.concept import ConceptCreate, ConceptPage, ConceptRead, ConceptUpdate, Language
from app.schemas.errors import ErrorResponse
from app.services.concept_service import ConceptService

router = APIRouter(
    prefix="/concepts",
    responses={503: {"model": ErrorResponse, "description": "Database unavailable"}},
)

NOT_FOUND: dict[int | str, dict[str, Any]] = {
    404: {"model": ErrorResponse, "description": "Concept not found"}
}


def get_concept_service(session: DbSession, user: CurrentUser) -> ConceptService:
    return ConceptService(session, user.id)


Service = Annotated[ConceptService, Depends(get_concept_service)]


@router.get("", response_model=ConceptPage, summary="Search and list concepts")
def list_concepts(
    service: Service,
    q: Annotated[str | None, Query(max_length=100, description="Text search")] = None,
    exam: Annotated[str | None, Query(max_length=32)] = None,
    subject: Annotated[str | None, Query(max_length=100)] = None,
    topic: Annotated[str | None, Query(max_length=100)] = None,
    language: Language | None = None,
    tag: Annotated[str | None, Query(max_length=50)] = None,
    include_archived: bool = False,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0, le=100_000)] = 0,
) -> ConceptPage:
    filters = ConceptFilter(
        query=q.strip() if q and q.strip() else None,
        exam_code=exam,
        subject=subject,
        topic=topic,
        language=language,
        tag=tag.lower() if tag else None,
        include_archived=include_archived,
    )
    return service.search(filters, limit=limit, offset=offset)


@router.post(
    "",
    response_model=ConceptRead,
    status_code=status.HTTP_201_CREATED,
    responses={422: {"model": ErrorResponse}},
)
def create_concept(body: ConceptCreate, service: Service) -> ConceptRead:
    return service.create(body)


@router.get("/{concept_id}", response_model=ConceptRead, responses=NOT_FOUND)
def get_concept(concept_id: uuid.UUID, service: Service) -> ConceptRead:
    return service.get(concept_id)


@router.patch("/{concept_id}", response_model=ConceptRead, responses=NOT_FOUND)
def update_concept(concept_id: uuid.UUID, body: ConceptUpdate, service: Service) -> ConceptRead:
    return service.update(concept_id, body)


@router.post("/{concept_id}/archive", response_model=ConceptRead, responses=NOT_FOUND)
def archive_concept(concept_id: uuid.UUID, service: Service) -> ConceptRead:
    return service.set_archived(concept_id, archived=True)


@router.post("/{concept_id}/unarchive", response_model=ConceptRead, responses=NOT_FOUND)
def unarchive_concept(concept_id: uuid.UUID, service: Service) -> ConceptRead:
    return service.set_archived(concept_id, archived=False)


@router.delete("/{concept_id}", status_code=status.HTTP_204_NO_CONTENT, responses=NOT_FOUND)
def delete_concept(concept_id: uuid.UUID, service: Service) -> None:
    service.delete(concept_id)
