import uuid
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.domain.errors import InvalidReferenceError, NotFoundError
from app.models.concept import Concept
from app.repositories.concept_repository import ConceptFilter, ConceptRepository
from app.repositories.exam_repository import ExamRepository
from app.schemas.concept import ConceptCreate, ConceptPage, ConceptRead, ConceptUpdate


class ConceptService:
    """Business rules for concepts. Owns the transaction boundary (commit per operation)."""

    def __init__(self, session: Session) -> None:
        self._session = session
        self._concepts = ConceptRepository(session)
        self._exams = ExamRepository(session)

    def create(self, data: ConceptCreate) -> ConceptRead:
        self._require_active_exam(data.exam_code)
        concept = self._concepts.add(Concept(**data.model_dump()))
        self._session.commit()
        return ConceptRead.model_validate(concept)

    def get(self, concept_id: uuid.UUID) -> ConceptRead:
        return ConceptRead.model_validate(self._get_or_404(concept_id))

    def search(self, filters: ConceptFilter, *, limit: int, offset: int) -> ConceptPage:
        items, total = self._concepts.search(filters, limit=limit, offset=offset)
        return ConceptPage(
            items=[ConceptRead.model_validate(c) for c in items],
            total=total,
            limit=limit,
            offset=offset,
        )

    def update(self, concept_id: uuid.UUID, data: ConceptUpdate) -> ConceptRead:
        concept = self._get_or_404(concept_id)
        changes = data.model_dump(exclude_unset=True)
        if "exam_code" in changes:
            self._require_active_exam(changes["exam_code"])
        for field, value in changes.items():
            setattr(concept, field, value)
        self._session.commit()
        self._session.refresh(concept)
        return ConceptRead.model_validate(concept)

    def set_archived(self, concept_id: uuid.UUID, *, archived: bool) -> ConceptRead:
        concept = self._get_or_404(concept_id)
        if archived and concept.archived_at is None:
            concept.archived_at = datetime.now(UTC)
        elif not archived:
            concept.archived_at = None
        self._session.commit()
        self._session.refresh(concept)
        return ConceptRead.model_validate(concept)

    def delete(self, concept_id: uuid.UUID) -> None:
        """Permanent deletion, only on an explicit user request."""
        self._concepts.delete(self._get_or_404(concept_id))
        self._session.commit()

    def _get_or_404(self, concept_id: uuid.UUID) -> Concept:
        concept = self._concepts.get(concept_id)
        if concept is None:
            raise NotFoundError("Concept not found.")
        return concept

    def _require_active_exam(self, code: str) -> None:
        exam = self._exams.get(code)
        if exam is None or not exam.is_active:
            raise InvalidReferenceError(f"Unknown exam '{code}'.")
