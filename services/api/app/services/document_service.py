"""Upload validation and document management.

Validation order: size (while streaming) → magic bytes → PDF structure (encrypted, damaged,
empty, too many pages). Only a file that passes everything is moved into storage and
recorded; rejected uploads leave nothing behind.
"""

import hashlib
import json
import logging
import re
import unicodedata
import uuid
from collections import defaultdict
from collections.abc import Sequence
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import BinaryIO

import pypdfium2 as pdfium
from sqlalchemy import distinct, func, select
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
from app.domain.paper_duplicates import looks_like_same_paper, shared_share
from app.integrations.storage import DocumentStorage
from app.models.document import Document, DocumentStatus
from app.models.question import (
    ExamFormat,
    FormatStatus,
    Question,
    QuestionIssue,
    QuestionOrigin,
    VerificationStatus,
)
from app.repositories.document_repository import DocumentRepository
from app.repositories.exam_repository import ExamRepository
from app.schemas.document import (
    DocumentPageList,
    DocumentRead,
    DuplicateSuggestion,
    PageList,
    PageRead,
    PaperDateUpdate,
    PaperDetailsUpdate,
)
from app.services.page_layout import PdfRenderer

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


def read_documents(session: Session, documents: Sequence[Document]) -> list[DocumentRead]:
    """Public views, with how many questions of each still need a look (one query)."""
    ids = [d.id for d in documents]
    counts: dict[uuid.UUID, int] = {}
    if ids:
        rows = session.execute(
            select(Question.document_id, func.count(distinct(Question.id)))
            .join(QuestionIssue, QuestionIssue.question_id == Question.id)
            .where(
                Question.document_id.in_(ids),
                QuestionIssue.resolved.is_(False),
                Question.verification_status != VerificationStatus.REJECTED,
            )
            .group_by(Question.document_id)
        ).all()
        counts = {doc_id: count for doc_id, count in rows if doc_id is not None}
    return [
        DocumentRead.model_validate(d).model_copy(
            update={"questions_to_check": counts.get(d.id, 0)}
        )
        for d in documents
    ]


SAMPLE_FOLDER = Path(__file__).resolve().parents[2] / "data" / "sample_papers"


@dataclass(frozen=True, slots=True)
class SamplePaper:
    path: Path
    filename: str
    sha256: str


@lru_cache(maxsize=1)
def sample_papers() -> tuple[SamplePaper, ...]:
    """PrepLoop's made-up sample papers, as listed in data/sample_papers/sample_papers.json."""
    listing = json.loads((SAMPLE_FOLDER / "sample_papers.json").read_text(encoding="utf-8"))
    papers = []
    for paper in listing["papers"]:
        path = SAMPLE_FOLDER / paper["file"]
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        papers.append(SamplePaper(path, f"{paper['title']} (sample).pdf", digest))
    return tuple(papers)


class DocumentService:
    def __init__(
        self,
        session: Session,
        storage: DocumentStorage,
        settings: Settings,
        *,
        owner_id: uuid.UUID,
    ) -> None:
        self._owner_id = owner_id
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
        is_sample: bool = False,
    ) -> DocumentRead:
        if self._exams.get_visible(exam_code, self._owner_id) is None:
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
            owner_id=self._owner_id,
            exam_code=exam_code,
            language=language,
            original_filename=sanitize_filename(filename),
            size_bytes=size,
            sha256=digest,
            storage_key=key,
            page_count=page_count,
            status=DocumentStatus.QUEUED,
            exam_format_id=exam_format.id if exam_format else None,
            is_sample=is_sample,
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

    def add_samples(self, exam_code: str) -> list[DocumentRead]:
        """Adds PrepLoop's made-up sample papers to this exam, through the normal import, so a new
        learner can try solving, reviewing and repeated models. Already added ones are returned
        as they are (by file content), so asking twice adds nothing."""
        if self._exams.get_visible(exam_code, self._owner_id) is None:
            raise InvalidReferenceError(f"Unknown exam '{exam_code}'.")
        papers: list[DocumentRead] = []
        for sample in sample_papers():
            existing = self._session.scalar(
                select(Document).where(
                    Document.owner_id == self._owner_id,
                    Document.exam_code == exam_code,
                    Document.is_sample.is_(True),
                    Document.sha256 == sample.sha256,
                )
            )
            if existing is not None:
                papers.append(DocumentRead.model_validate(existing))
                continue
            with sample.path.open("rb") as stream:
                papers.append(
                    self.upload(
                        stream=stream,
                        filename=sample.filename,
                        exam_code=exam_code,
                        language="en",
                        is_sample=True,
                    )
                )
        return papers

    def get(self, document_id: uuid.UUID) -> DocumentRead:
        return read_documents(self._session, [self._get_or_404(document_id)])[0]

    def list(self, *, status: str | None, limit: int, offset: int) -> DocumentPageList:
        items, total = self._documents.list(
            owner_id=self._owner_id, status=status, limit=limit, offset=offset
        )
        return DocumentPageList(
            items=read_documents(self._session, items),
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

    def set_paper_date(self, document_id: uuid.UUID, data: PaperDateUpdate) -> DocumentRead:
        """The reviewer confirms (or corrects) when the paper was held."""
        document = self._get_or_404(document_id)
        document.exam_year = data.exam_year
        document.exam_date = data.exam_date
        document.exam_shift = data.exam_shift
        document.paper_date_status = "confirmed"
        document.paper_date_reason = None
        self._session.commit()
        return DocumentRead.model_validate(document)

    def set_details(self, document_id: uuid.UUID, data: PaperDetailsUpdate) -> DocumentRead:
        document = self._get_or_404(document_id)
        changes = data.model_dump(exclude_unset=True)
        if "duplicate_of_id" in changes:
            self._check_duplicate(document, changes["duplicate_of_id"])
        for field, value in changes.items():
            setattr(document, field, value or None if field != "extra_languages" else value)
        self._session.commit()
        return DocumentRead.model_validate(document)

    def _check_duplicate(self, document: Document, target_id: uuid.UUID | None) -> None:
        if target_id is None:
            return
        target = self._documents.get(target_id)
        if (
            target is None
            or target.owner_id != self._owner_id
            or target.id == document.id
            or target.exam_code != document.exam_code
            or target.duplicate_of_id is not None
        ):
            raise InvalidReferenceError("That can't be another set of this paper.")
        pointed_to = self._session.scalar(
            select(Document.id).where(Document.duplicate_of_id == document.id).limit(1)
        )
        if pointed_to is not None:
            raise InvalidReferenceError("Other papers are marked as sets of this one.")

    def duplicate_suggestions(self, document_id: uuid.UUID) -> Sequence[DuplicateSuggestion]:
        """Own papers of the exam that look like another set of this one. Only a suggestion."""
        document = self._get_or_404(document_id)
        rows = self._session.execute(
            select(Question.document_id, Question.stem)
            .join(Document, Document.id == Question.document_id)
            .where(
                Document.owner_id == self._owner_id,
                Document.exam_code == document.exam_code,
                Document.duplicate_of_id.is_(None),
                Question.origin == QuestionOrigin.SOURCE,
            )
        ).all()
        stems: dict[uuid.UUID, list[str]] = defaultdict(list)
        for paper_id, stem in rows:
            if paper_id is not None:
                stems[paper_id].append(stem)
        mine = stems.pop(document.id, [])
        found = []
        for paper_id, others in stems.items():
            if looks_like_same_paper(mine, others):
                other = self._documents.get(paper_id)
                if other is not None:
                    found.append(
                        DuplicateSuggestion(
                            document_id=paper_id,
                            filename=other.original_filename,
                            set_code=other.set_code,
                            shared_share=round(shared_share(mine, others), 3),
                        )
                    )
        return sorted(found, key=lambda s: -s.shared_share)

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
        if (
            exam_format is None
            or exam_format.exam_code != exam_code
            or exam_format.status == FormatStatus.DRAFT
        ):
            raise InvalidReferenceError(f"Unknown paper format '{code}' for this exam.")
        return exam_format

    def page_image(self, document_id: uuid.UUID, page_number: int, max_edge: int) -> bytes:
        """One page of the original PDF as PNG, exactly as uploaded (for reading the paper)."""
        document = self._get_or_404(document_id)
        if not 1 <= page_number <= document.page_count:
            raise NotFoundError("Page not found.")
        path = self._storage.path_for(document.storage_key)
        if not path.exists():
            raise NotFoundError("The original file is no longer available.")
        with PdfRenderer(path) as renderer:
            return renderer.page_png(page_number, max_edge)

    def _get_or_404(self, document_id: uuid.UUID) -> Document:
        document = self._documents.get(document_id)
        if document is not None and document.owner_id != self._owner_id:
            document = None  # another account's document looks exactly like a missing one
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
