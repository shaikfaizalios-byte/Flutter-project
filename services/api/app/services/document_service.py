"""Upload validation and document management.

Validation order: size (while streaming) → magic bytes → PDF structure (encrypted, damaged,
empty, too many pages). Only a file that passes everything is moved into storage and
recorded; rejected uploads leave nothing behind.
"""

import hashlib
import logging
import re
import unicodedata
import uuid
from pathlib import Path
from typing import BinaryIO

import pypdfium2 as pdfium
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain.errors import (
    ConflictError,
    InvalidDocumentError,
    InvalidReferenceError,
    NotFoundError,
    UnsupportedFileTypeError,
    UploadTooLargeError,
)
from app.integrations.storage import DocumentStorage
from app.models.document import Document, DocumentStatus
from app.models.question import ExamFormat
from app.repositories.document_repository import DocumentRepository
from app.repositories.exam_repository import ExamRepository
from app.schemas.document import DocumentPageList, DocumentRead, PageList, PageRead

logger = logging.getLogger("app.documents")

_CHUNK = 1024 * 1024
# The PDF header may be preceded by up to 1 KB of junk (PDF 1.7, §7.5.2).
_HEADER_SEARCH_BYTES = 1024
_PDF_MAGIC = b"%PDF-"
_UNSAFE_FILENAME = re.compile(r"[\x00-\x1f\x7f<>:\"/\\|?*]")


def sanitize_filename(raw: str | None) -> str:
    """Display-only name: last path component, no control or path characters, NFC, ≤255."""
    name = (raw or "").replace("\\", "/").rsplit("/", 1)[-1]
    name = unicodedata.normalize("NFC", _UNSAFE_FILENAME.sub("", name)).strip(" .")
    if not name:
        return "document.pdf"
    if len(name) > 255:
        stem, dot, ext = name.rpartition(".")
        name = (stem[: 250 - len(ext)] + dot + ext) if dot and len(ext) <= 10 else name[:255]
    return name


class DocumentService:
    def __init__(self, session: Session, storage: DocumentStorage, settings: Settings) -> None:
        self._session = session
        self._storage = storage
        self._settings = settings
        self._documents = DocumentRepository(session)
        self._exams = ExamRepository(session)

    def upload(
        self,
        *,
        stream: BinaryIO,
        filename: str | None,
        exam_code: str,
        language: str,
        exam_format_code: str | None = None,
    ) -> DocumentRead:
        exam = self._exams.get(exam_code)
        if exam is None or not exam.is_active:
            raise InvalidReferenceError(f"Unknown exam '{exam_code}'.")
        exam_format = self._find_format(exam_code, exam_format_code)

        temp = self._storage.temp_dir() / f"{uuid.uuid4().hex}.part"
        try:
            size, digest = self._copy_limited(stream, temp)
            if size == 0:
                raise InvalidDocumentError("empty_file", "The file is empty.")
            self._check_magic(temp)
            page_count = self._inspect_pdf(temp)

            key = self._storage.new_key()
            self._storage.save(key, temp)
        finally:
            temp.unlink(missing_ok=True)

        document = Document(
            exam_code=exam_code,
            language=language,
            original_filename=sanitize_filename(filename),
            size_bytes=size,
            sha256=digest,
            storage_key=key,
            page_count=page_count,
            status=DocumentStatus.QUEUED,
            exam_format_id=exam_format.id if exam_format else None,
        )
        try:
            self._documents.add(document)
            self._session.commit()
        except Exception:
            # Don't leave an orphaned file if the database write fails.
            self._session.rollback()
            self._storage.delete(key)
            raise
        logger.info(
            "document uploaded",
            extra={"fields": {"document_id": str(document.id), "pages": page_count, "bytes": size}},
        )
        return DocumentRead.model_validate(document)

    def get(self, document_id: uuid.UUID) -> DocumentRead:
        return DocumentRead.model_validate(self._get_or_404(document_id))

    def list(self, *, status: str | None, limit: int, offset: int) -> DocumentPageList:
        items, total = self._documents.list(status=status, limit=limit, offset=offset)
        return DocumentPageList(
            items=[DocumentRead.model_validate(d) for d in items],
            total=total,
            limit=limit,
            offset=offset,
        )

    def pages(self, document_id: uuid.UUID, *, limit: int, offset: int) -> PageList:
        self._get_or_404(document_id)
        items, total = self._documents.pages(document_id, limit=limit, offset=offset)
        return PageList(
            items=[PageRead.model_validate(p) for p in items],
            total=total,
            limit=limit,
            offset=offset,
        )

    def delete(self, document_id: uuid.UUID) -> None:
        """Permanent deletion of the record, its pages and the original file — only on an
        explicit user request."""
        document = self._get_or_404(document_id)
        key = document.storage_key
        self._documents.delete(document)
        self._session.commit()
        self._storage.delete(key)

    def set_exam_format(self, document_id: uuid.UUID, exam_format_code: str | None) -> DocumentRead:
        document = self._get_or_404(document_id)
        exam_format = self._find_format(document.exam_code, exam_format_code)
        document.exam_format_id = exam_format.id if exam_format else None
        self._session.commit()
        return DocumentRead.model_validate(document)

    def require_extracted(self, document_id: uuid.UUID) -> None:
        if self._get_or_404(document_id).status != DocumentStatus.COMPLETED:
            raise ConflictError(
                "document_not_ready", "Text extraction must finish before questions are parsed."
            )

    def _find_format(self, exam_code: str, code: str | None) -> ExamFormat | None:
        if code is None:
            return None
        exam_format = self._session.scalars(
            select(ExamFormat).where(ExamFormat.code == code)
        ).first()
        if exam_format is None or exam_format.exam_code != exam_code:
            raise InvalidReferenceError(f"Unknown paper format '{code}' for this exam.")
        return exam_format

    def _get_or_404(self, document_id: uuid.UUID) -> Document:
        document = self._documents.get(document_id)
        if document is None:
            raise NotFoundError("Document not found.")
        return document

    def _copy_limited(self, stream: BinaryIO, destination: Path) -> tuple[int, str]:
        limit = self._settings.max_upload_bytes
        size = 0
        digest = hashlib.sha256()
        with destination.open("wb") as out:
            while chunk := stream.read(_CHUNK):
                size += len(chunk)
                if size > limit:
                    raise UploadTooLargeError(
                        f"The file is larger than {limit // (1024 * 1024)} MB."
                    )
                digest.update(chunk)
                out.write(chunk)
        return size, digest.hexdigest()

    @staticmethod
    def _check_magic(path: Path) -> None:
        with path.open("rb") as file:
            head = file.read(_HEADER_SEARCH_BYTES)
        if _PDF_MAGIC not in head:
            raise UnsupportedFileTypeError("Only PDF files can be imported.")

    def _inspect_pdf(self, path: Path) -> int:
        try:
            document = pdfium.PdfDocument(path)
        except pdfium.PdfiumError as exc:
            if getattr(exc, "err_code", None) == pdfium.raw.FPDF_ERR_PASSWORD:
                raise InvalidDocumentError(
                    "encrypted_pdf", "Password-protected PDFs cannot be imported."
                ) from exc
            raise InvalidDocumentError(
                "invalid_pdf", "The file is damaged or is not a valid PDF."
            ) from exc
        try:
            pages = len(document)
        finally:
            document.close()
        if pages == 0:
            raise InvalidDocumentError("invalid_pdf", "The PDF has no pages.")
        if pages > self._settings.max_pdf_pages:
            raise InvalidDocumentError(
                "too_many_pages",
                f"The PDF has {pages} pages; the limit is {self._settings.max_pdf_pages}.",
            )
        return pages
