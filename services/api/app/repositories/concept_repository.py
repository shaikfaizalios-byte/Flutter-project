import uuid
from collections.abc import Sequence
from dataclasses import dataclass

from sqlalchemy import Select, func, or_, select
from sqlalchemy.orm import Session

from app.models.concept import Concept


@dataclass(frozen=True, slots=True)
class ConceptFilter:
    query: str | None = None
    exam_code: str | None = None
    subject: str | None = None
    topic: str | None = None
    language: str | None = None
    tag: str | None = None
    include_archived: bool = False


def _escape_like(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


class ConceptRepository:
    """Persistence for concepts. Owns queries only; transactions belong to the service."""

    def __init__(self, session: Session, owner_id: uuid.UUID) -> None:
        self._session = session
        self._owner_id = owner_id

    def get(self, concept_id: uuid.UUID) -> Concept | None:
        concept = self._session.get(Concept, concept_id)
        return concept if concept is not None and concept.owner_id == self._owner_id else None

    def add(self, concept: Concept) -> Concept:
        concept.owner_id = self._owner_id
        self._session.add(concept)
        self._session.flush()
        return concept

    def delete(self, concept: Concept) -> None:
        self._session.delete(concept)
        self._session.flush()

    def search(
        self, filters: ConceptFilter, *, limit: int, offset: int
    ) -> tuple[Sequence[Concept], int]:
        base = self._apply_filters(select(Concept), filters)
        total = self._session.scalar(
            self._apply_filters(select(func.count()).select_from(Concept), filters)
        )
        items = self._session.scalars(
            base.order_by(Concept.updated_at.desc(), Concept.id).limit(limit).offset(offset)
        ).all()
        return items, total or 0

    def _apply_filters[*Ts](self, stmt: Select[*Ts], f: ConceptFilter) -> Select[*Ts]:
        stmt = stmt.where(Concept.owner_id == self._owner_id)
        if not f.include_archived:
            stmt = stmt.where(Concept.archived_at.is_(None))
        if f.exam_code:
            stmt = stmt.where(Concept.exam_code == f.exam_code)
        if f.subject:
            stmt = stmt.where(func.lower(Concept.subject) == f.subject.lower())
        if f.topic:
            stmt = stmt.where(func.lower(Concept.topic) == f.topic.lower())
        if f.language:
            stmt = stmt.where(Concept.language == f.language)
        if f.tag:
            # tags @> ARRAY[tag] can use the GIN index on tags.
            stmt = stmt.where(Concept.tags.contains([f.tag]))
        if f.query:
            pattern = f"%{_escape_like(f.query)}%"
            stmt = stmt.where(
                or_(
                    Concept.title.ilike(pattern, escape="\\"),
                    Concept.notes.ilike(pattern, escape="\\"),
                    Concept.topic.ilike(pattern, escape="\\"),
                    Concept.subtopic.ilike(pattern, escape="\\"),
                )
            )
        return stmt
