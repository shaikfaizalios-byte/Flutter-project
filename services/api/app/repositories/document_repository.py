import uuid
from collections.abc import Sequence
from datetime import datetime

from sqlalchemy import delete, func, or_, select
from sqlalchemy.orm import Session

from app.models.document import Document, DocumentPage, DocumentStatus


class DocumentRepository:
    """Persistence for documents and pages. Transactions belong to the caller."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def get(self, document_id: uuid.UUID) -> Document | None:
        return self._session.get(Document, document_id)

    def add(self, document: Document) -> Document:
        self._session.add(document)
        self._session.flush()
        return document

    def delete(self, document: Document) -> None:
        self._session.delete(document)
        self._session.flush()

    def list(
        self, *, owner_id: uuid.UUID, status: str | None, limit: int, offset: int
    ) -> tuple[Sequence[Document], int]:
        query = select(Document).where(Document.owner_id == owner_id)
        count = select(func.count()).select_from(Document).where(Document.owner_id == owner_id)
        if status is not None:
            query = query.where(Document.status == status)
            count = count.where(Document.status == status)
        items = self._session.scalars(
            query.order_by(Document.created_at.desc(), Document.id).limit(limit).offset(offset)
        ).all()
        return items, self._session.scalar(count) or 0

    def pages(
        self, document_id: uuid.UUID, *, limit: int, offset: int
    ) -> tuple[Sequence[DocumentPage], int]:
        base = select(DocumentPage).where(DocumentPage.document_id == document_id)
        items = self._session.scalars(
            base.order_by(DocumentPage.page_number).limit(limit).offset(offset)
        ).all()
        total = self._session.scalar(
            select(func.count())
            .select_from(DocumentPage)
            .where(DocumentPage.document_id == document_id)
        )
        return items, total or 0

    def clear_pages(self, document_id: uuid.UUID) -> None:
        self._session.execute(delete(DocumentPage).where(DocumentPage.document_id == document_id))

    def add_page(self, page: DocumentPage) -> None:
        self._session.add(page)
        self._session.flush()

    def claim_next(self, *, now: datetime, lease_until: datetime) -> Document | None:
        """Atomically take the oldest queued document, or one whose worker lease expired
        (e.g. the worker crashed). ``SKIP LOCKED`` lets several workers run safely."""
        stmt = (
            select(Document)
            .where(
                or_(
                    Document.status == DocumentStatus.QUEUED,
                    (Document.status == DocumentStatus.PROCESSING)
                    & (Document.lease_expires_at < now),
                )
            )
            .order_by(Document.created_at)
            .limit(1)
            .with_for_update(skip_locked=True)
        )
        document = self._session.scalars(stmt).first()
        if document is None:
            return None
        document.status = DocumentStatus.PROCESSING
        document.lease_expires_at = lease_until
        document.attempts += 1
        document.processing_started_at = now
        self._session.flush()
        return document
