"""Background processing of uploaded documents.

Each page result is committed as soon as it is ready, so progress is visible while a
document is processed and a crash loses at most one page of work. A document claimed by a
worker carries a lease; if the worker dies, another worker re-claims it once the lease
expires and starts again from the first page (up to ``MAX_ATTEMPTS``).
"""

import logging
import time
import uuid
from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from sqlalchemy.orm.exc import StaleDataError

from app.core.config import Settings
from app.integrations.ocr import OcrEngine
from app.integrations.storage import DocumentStorage
from app.models.document import Document, DocumentPage, DocumentStatus
from app.repositories.document_repository import DocumentRepository
from app.services.extraction import ProcessingTimeoutError, extract_pages, summarize_methods
from app.services.segmentation_service import SegmentationService

logger = logging.getLogger("app.processing")

MAX_ATTEMPTS = 3
_LEASE_MARGIN = timedelta(minutes=2)


class DocumentProcessor:
    def __init__(
        self,
        *,
        storage: DocumentStorage,
        ocr: OcrEngine,
        settings: Settings,
        now: Callable[[], datetime] = lambda: datetime.now(UTC),
        monotonic: Callable[[], float] = time.monotonic,
    ) -> None:
        self._storage = storage
        self._ocr = ocr
        self._settings = settings
        self._now = now
        self._monotonic = monotonic

    def claim_next(self, session: Session) -> uuid.UUID | None:
        """Take the next document to process (committing the claim), or None."""
        now = self._now()
        lease = now + timedelta(seconds=self._settings.processing_timeout_seconds) + _LEASE_MARGIN
        document = DocumentRepository(session).claim_next(now=now, lease_until=lease)
        if document is None:
            session.commit()
            return None
        document_id = document.id
        if document.attempts > MAX_ATTEMPTS:
            self._finish(session, document, DocumentStatus.FAILED, error_code="too_many_attempts")
            return None
        session.commit()
        return document_id

    def process(self, session: Session, document_id: uuid.UUID) -> None:
        """Extract every page of a claimed document. Never raises for document problems;
        the outcome is recorded on the document."""
        repo = DocumentRepository(session)
        document = repo.get(document_id)
        if document is None:
            return  # deleted while queued
        repo.clear_pages(document_id)  # a retry starts over from page 1
        document.pages_processed = 0
        document.needs_review_count = 0
        session.commit()

        methods: set[str] = set()
        deadline = self._monotonic() + self._settings.processing_timeout_seconds
        try:
            path = self._storage.path_for(document.storage_key)
            for result in extract_pages(
                path,
                language=document.language,
                ocr=self._ocr,
                settings=self._settings,
                deadline=deadline,
                monotonic=self._monotonic,
            ):
                repo.add_page(
                    DocumentPage(
                        document_id=document_id,
                        page_number=result.page_number,
                        method=result.method,
                        text=result.text,
                        char_count=len(result.text),
                        ocr_confidence=result.ocr_confidence,
                        needs_review=result.needs_review,
                        review_reasons=list(result.review_reasons),
                    )
                )
                methods.add(result.method)
                document.pages_processed = result.page_number
                document.needs_review_count += int(result.needs_review)
                session.commit()
        except (IntegrityError, StaleDataError):
            # The document was deleted while we were working on it.
            session.rollback()
            logger.info("document deleted during processing", extra=_fields(document_id))
            return
        except ProcessingTimeoutError:
            session.rollback()
            self._finish_by_id(session, document_id, error_code="processing_timeout")
            return
        except FileNotFoundError:
            session.rollback()
            self._finish_by_id(session, document_id, error_code="source_file_missing")
            return
        except Exception:
            session.rollback()
            logger.exception("document processing failed", extra=_fields(document_id))
            self._finish_by_id(session, document_id, error_code="processing_error")
            return

        self._finish(
            session, document, DocumentStatus.COMPLETED, summary=summarize_methods(methods)
        )
        # Question segmentation runs right after extraction; its failure never fails the document.
        SegmentationService(session, self._storage).segment_document(document_id)

    def _finish_by_id(self, session: Session, document_id: uuid.UUID, *, error_code: str) -> None:
        document = DocumentRepository(session).get(document_id)
        if document is not None:
            self._finish(session, document, DocumentStatus.FAILED, error_code=error_code)

    def _finish(
        self,
        session: Session,
        document: Document,
        status: DocumentStatus,
        *,
        error_code: str | None = None,
        summary: str | None = None,
    ) -> None:
        document.status = status
        document.error_code = error_code
        document.extraction_summary = summary
        document.lease_expires_at = None
        document.processing_finished_at = self._now()
        session.commit()
        logger.info(
            "document processed",
            extra=_fields(
                document.id,
                status=str(status),
                error_code=error_code,
                pages=document.pages_processed,
                needs_review=document.needs_review_count,
            ),
        )


def _fields(document_id: uuid.UUID, **extra: object) -> dict[str, object]:
    return {"fields": {"document_id": str(document_id), **extra}}
