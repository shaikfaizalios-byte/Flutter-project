"""The shared bank: papers the operator publishes for every learner.

Visibility is one rule, used by practice, mocks, question reading, figures and repeats: a
learner sees their own questions, plus the VERIFIED source questions of papers in the shared
bank (read-only). Publishing records the rights basis and the source, and is refused while a
verified question still uses a private topic or question type (other learners couldn't see
it). Publishing happens only through the operator CLI (`python -m app.cli.shared_bank`).
"""

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import ColumnElement, Select, and_, func, or_, select
from sqlalchemy.orm import Session

from app.domain.errors import ConflictError, NotFoundError
from app.models.document import Document
from app.models.question import (
    Question,
    QuestionOrigin,
    QuestionPattern,
    Topic,
    VerificationStatus,
)

RIGHTS_MAX = 500


def shared_document_ids() -> Select[uuid.UUID]:
    return select(Document.id).where(Document.shared_at.is_not(None))


def shared_question() -> ColumnElement[bool]:
    """A question other learners may see: verified, from a source paper in the shared bank."""
    return and_(
        Question.origin == QuestionOrigin.SOURCE,
        Question.verification_status == VerificationStatus.VERIFIED,
        Question.document_id.in_(shared_document_ids()),
    )


def visible_question(owner_id: uuid.UUID, *, include_shared: bool = True) -> ColumnElement[bool]:
    """The learner's own questions, plus shared-bank questions when wanted."""
    own = Question.owner_id == owner_id
    return or_(own, shared_question()) if include_shared else own


@dataclass(frozen=True, slots=True)
class PublishResult:
    document_id: uuid.UUID
    filename: str
    verified_questions: int
    shared: bool


def publish(
    session: Session, document_id: uuid.UUID, *, rights_basis: str, source: str
) -> PublishResult:
    rights_basis, source = rights_basis.strip(), source.strip()
    if not rights_basis or not source:
        raise ConflictError("rights_required", "A rights basis and a source are both required.")
    if len(rights_basis) > RIGHTS_MAX or len(source) > RIGHTS_MAX:
        raise ConflictError("too_long", f"Keep each text under {RIGHTS_MAX} characters.")
    document = session.get(Document, document_id)
    if document is None:
        raise NotFoundError("Document not found.")
    if document.segmentation_status != "completed":
        raise ConflictError("not_parsed", "The paper hasn't been parsed yet.")
    verified = (
        select(Question)
        .where(
            Question.document_id == document_id,
            Question.origin == QuestionOrigin.SOURCE,
            Question.verification_status == VerificationStatus.VERIFIED,
        )
        .subquery()
    )
    count = session.scalar(select(func.count()).select_from(verified)) or 0
    if count == 0:
        raise ConflictError("nothing_verified", "Verify the paper's questions before sharing it.")
    private_topics = session.scalars(
        select(Topic.name)
        .join(verified, verified.c.topic_id == Topic.id)
        .where(Topic.owner_id.is_not(None))
        .distinct()
    ).all()
    # A question type belongs to a topic; it is private when its topic is.
    private_patterns = session.scalars(
        select(QuestionPattern.name)
        .join(verified, verified.c.pattern_id == QuestionPattern.id)
        .join(Topic, Topic.id == QuestionPattern.topic_id)
        .where(Topic.owner_id.is_not(None))
        .distinct()
    ).all()
    if private_topics or private_patterns:
        names = ", ".join(sorted({*private_topics, *private_patterns}))
        raise ConflictError(
            "private_topics",
            f"These topics or question types are private, so other learners can't see them: "
            f"{names}. Use shared topics, or clear them, before sharing.",
        )
    document.shared_at = datetime.now(UTC)
    document.shared_rights_basis = rights_basis
    document.shared_source = source
    session.commit()
    return PublishResult(document.id, document.original_filename, count, shared=True)


def unpublish(session: Session, document_id: uuid.UUID) -> PublishResult:
    document = session.get(Document, document_id)
    if document is None:
        raise NotFoundError("Document not found.")
    document.shared_at = None
    document.shared_rights_basis = None
    document.shared_source = None
    session.commit()
    return PublishResult(document.id, document.original_filename, 0, shared=False)


def shared_documents(session: Session) -> list[Document]:
    return list(
        session.scalars(
            select(Document).where(Document.shared_at.is_not(None)).order_by(Document.shared_at)
        )
    )
