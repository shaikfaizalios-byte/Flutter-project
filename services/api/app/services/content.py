"""Content governance: rights of shared content, learners' reports, takedowns and the audit log
of operator decisions (docs/shared-bank.md "Rights, reports and takedown")."""

import uuid
from collections.abc import Sequence
from datetime import UTC, date, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.domain.errors import ConflictError, InvalidReferenceError, NotFoundError, RateLimitedError
from app.domain.library import is_visible
from app.models.content import AuditEvent, ContentReport, ContentRights
from app.models.document import Document
from app.models.library import LibraryEntry
from app.models.question import Question
from app.schemas.content import ContentReportCreate, ContentReportRead

USES = ("practice", "diagnostic")
REPORTS_PER_DAY = 10


def audit(
    session: Session, actor: str, action: str, target_type: str, target_id: object, detail: str = ""
) -> None:
    """Records an operator decision (no content: ids, action and a short reason)."""
    session.add(
        AuditEvent(
            actor=actor.strip()[:100] or "operator",
            action=action[:40],
            target_type=target_type[:20],
            target_id=str(target_id)[:64],
            detail=detail[:500],
        )
    )


def set_rights(
    session: Session,
    document: Document,
    *,
    basis: str,
    uses: Sequence[str],
    decided_by: str,
    rights_holder: str | None = None,
    territory: str | None = None,
    attribution: str | None = None,
    review_by: date | None = None,
) -> ContentRights:
    """The rights record of a paper being shared (replaces an earlier one)."""
    chosen = sorted(set(uses))
    if not chosen or not set(chosen) <= set(USES):
        raise ConflictError("uses_invalid", f"Permitted uses must be among: {', '.join(USES)}.")
    if not decided_by.strip():
        raise ConflictError("decided_by_required", "Record who decided the rights.")
    record = session.get(ContentRights, document.id)
    if record is None:
        record = ContentRights(document_id=document.id)
        session.add(record)
    record.basis = basis.strip()[:500]
    record.permitted_uses = chosen
    record.decided_by = decided_by.strip()[:100]
    record.rights_holder = rights_holder.strip()[:200] if rights_holder else None
    record.territory = (territory or "not recorded").strip()[:200] or "not recorded"
    record.attribution = attribution.strip()[:300] if attribution else None
    record.review_by = review_by
    record.decided_at = datetime.now(UTC)
    return record


class ContentReports:
    """Learners report shared content they can see (their own papers use question reports)."""

    def __init__(self, session: Session, owner_id: uuid.UUID) -> None:
        self._session = session
        self._owner_id = owner_id

    def create(self, data: ContentReportCreate) -> ContentReportRead:
        since = datetime.now(UTC) - timedelta(days=1)
        recent = self._session.scalar(
            select(func.count())
            .select_from(ContentReport)
            .where(ContentReport.owner_id == self._owner_id, ContentReport.created_at >= since)
        )
        if (recent or 0) >= REPORTS_PER_DAY:
            raise RateLimitedError("You can send up to 10 reports a day.", retry_after_seconds=3600)
        document_id = data.document_id
        if data.question_id is not None:
            question = self._session.get(Question, data.question_id)
            if question is None:
                raise NotFoundError("Question not found.")
            if self._in_library(question):
                return self._save(data, question.document_id)
            if question.document_id is None:
                raise NotFoundError("Question not found.")
            if document_id is not None and document_id != question.document_id:
                raise InvalidReferenceError("The question is not from that paper.")
            document_id = question.document_id
        if document_id is None:
            raise InvalidReferenceError("Say which paper or question the report is about.")
        document = self._session.get(Document, document_id)
        if document is None or document.shared_at is None or document.owner_id == self._owner_id:
            raise NotFoundError("Shared paper not found.")
        return self._save(data, document_id)

    def _in_library(self, question: Question) -> bool:
        entry = self._session.get(LibraryEntry, question.id)
        return entry is not None and is_visible(entry.status, entry.rights_status)

    def _save(self, data: ContentReportCreate, document_id: uuid.UUID | None) -> ContentReportRead:
        report = ContentReport(
            owner_id=self._owner_id,
            document_id=document_id,
            question_id=data.question_id,
            kind=data.kind,
            text=data.text,
        )
        self._session.add(report)
        self._session.commit()
        return ContentReportRead.model_validate(report)

    def mine(self) -> list[ContentReportRead]:
        rows = self._session.scalars(
            select(ContentReport)
            .where(ContentReport.owner_id == self._owner_id)
            .order_by(ContentReport.created_at.desc())
        ).all()
        return [ContentReportRead.model_validate(r) for r in rows]


def resolve(
    session: Session, report_id: uuid.UUID, *, upheld: bool, note: str, actor: str
) -> ContentReport:
    report = session.get(ContentReport, report_id)
    if report is None:
        raise NotFoundError("Report not found.")
    if report.status != "open":
        raise ConflictError("already_resolved", f"The report is already {report.status}.")
    report.status = "upheld" if upheld else "dismissed"
    report.resolution = note.strip()[:500] or None
    report.resolved_at = datetime.now(UTC)
    audit(session, actor, f"report_{report.status}", "content_report", report.id, note)
    return report


def takedown(session: Session, document_id: uuid.UUID, *, reason: str, actor: str) -> int:
    """Withdraws a paper from the shared bank and upholds its open reports; returns how many
    reports were closed. The paper stays in its owner's account."""
    from app.services import shared_bank

    if not reason.strip():
        raise ConflictError("reason_required", "Give the reason for the takedown.")
    shared_bank.unpublish(session, document_id, actor=actor, reason=reason, commit=False)
    open_reports = session.scalars(
        select(ContentReport).where(
            ContentReport.document_id == document_id, ContentReport.status == "open"
        )
    ).all()
    for report in open_reports:
        report.status = "upheld"
        report.resolution = f"Taken down: {reason.strip()}"[:500]
        report.resolved_at = datetime.now(UTC)
    audit(session, actor, "takedown", "document", document_id, reason)
    session.commit()
    return len(open_reports)
