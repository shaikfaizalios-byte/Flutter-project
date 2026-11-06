"""The shared bank: papers the operator publishes for every learner.

Visibility is one rule, used by practice, mocks, question reading, figures and repeats: a
learner sees their own questions, plus the VERIFIED source questions of papers in the shared
bank (read-only). Publishing records the rights basis and the source, and is refused while a
verified question still uses a private topic or question type (other learners couldn't see
it). Publishing happens only through the operator CLI (`python -m app.cli.shared_bank`).
"""

import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, date, datetime

from sqlalchemy import ColumnElement, Select, and_, func, or_, select
from sqlalchemy.orm import Session

from app.domain.errors import ConflictError, NotFoundError
from app.models.content import ContentRights
from app.models.document import Document
from app.models.question import (
    Question,
    QuestionOrigin,
    QuestionPattern,
    Topic,
    VerificationStatus,
)
from app.schemas.insights import SharedBankExam
from app.services.content import audit, set_rights

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
    session: Session,
    document_id: uuid.UUID,
    *,
    rights_basis: str,
    source: str,
    uses: Sequence[str] = ("practice",),
    decided_by: str = "operator",
    rights_holder: str | None = None,
    territory: str | None = None,
    attribution: str | None = None,
    review_by: date | None = None,
) -> PublishResult:
    """Shares a paper's verified questions, recording why it may be shared and for which uses
    (content_rights; "diagnostic" lets the starter check use them)."""
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
    # A question type is private when it, or the topic it belongs to, is.
    private_patterns = session.scalars(
        select(QuestionPattern.name)
        .join(verified, verified.c.pattern_id == QuestionPattern.id)
        .join(Topic, Topic.id == QuestionPattern.topic_id)
        .where(or_(Topic.owner_id.is_not(None), QuestionPattern.owner_id.is_not(None)))
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
    rights = set_rights(
        session,
        document,
        basis=rights_basis,
        uses=uses,
        decided_by=decided_by,
        rights_holder=rights_holder,
        territory=territory,
        attribution=attribution,
        review_by=review_by,
    )
    audit(
        session,
        decided_by,
        "publish",
        "document",
        document.id,
        f"uses={','.join(rights.permitted_uses)}; source={source}",
    )
    session.commit()
    return PublishResult(document.id, document.original_filename, count, shared=True)


def unpublish(
    session: Session,
    document_id: uuid.UUID,
    *,
    actor: str = "operator",
    reason: str = "",
    commit: bool = True,
) -> PublishResult:
    document = session.get(Document, document_id)
    if document is None:
        raise NotFoundError("Document not found.")
    document.shared_at = None
    document.shared_rights_basis = None
    document.shared_source = None
    rights = session.get(ContentRights, document.id)
    if rights is not None:
        session.delete(rights)
    audit(session, actor, "unpublish", "document", document.id, reason)
    if commit:
        session.commit()
    return PublishResult(document.id, document.original_filename, 0, shared=False)


def shared_documents(session: Session) -> list[Document]:
    return list(
        session.scalars(
            select(Document).where(Document.shared_at.is_not(None)).order_by(Document.shared_at)
        )
    )


def exams_summary(session: Session) -> list[SharedBankExam]:
    """Per exam: shared papers and their verified questions (what other learners can see)."""
    rows = session.execute(
        select(
            Document.exam_code,
            func.count(func.distinct(Document.id)),
            func.count(Question.id),
        )
        .join(Question, and_(Question.document_id == Document.id, shared_question()), isouter=True)
        .where(Document.shared_at.is_not(None))
        .group_by(Document.exam_code)
        .order_by(Document.exam_code)
    ).all()
    return [
        SharedBankExam(exam_code=code, papers=papers, questions=questions)
        for code, papers, questions in rows
    ]
