"""Reading a syllabus PDF into a topic draft for one exam. Nothing is stored: the PDF is read
from a temporary file that is deleted at once, and the learner saves the topics they keep
(POST /topics/bulk)."""

import uuid
from pathlib import Path
from typing import BinaryIO

import pypdfium2 as pdfium
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain.errors import (
    InvalidDocumentError,
    InvalidReferenceError,
    UnsupportedFileTypeError,
    UploadTooLargeError,
)
from app.domain.syllabus import parse_syllabus
from app.integrations.ocr import OcrEngine
from app.models.document import ExtractionMethod
from app.repositories.exam_repository import ExamRepository
from app.schemas.exam import SyllabusDraftRead, SyllabusSubjectRead
from app.services.extraction import extract_pages
from app.services.topic_service import visible_topics

# Syllabi are short; a long PDF here is most likely a question paper picked by mistake.
MAX_SYLLABUS_PAGES = 40
_CHUNK = 1024 * 1024


class SyllabusService:
    def __init__(
        self,
        session: Session,
        owner_id: uuid.UUID,
        settings: Settings,
        ocr: OcrEngine,
        temp_dir: Path,
    ) -> None:
        self._session = session
        self._owner_id = owner_id
        self._settings = settings
        self._ocr = ocr
        self._temp_dir = temp_dir

    def read(self, exam_code: str, stream: BinaryIO, language: str) -> SyllabusDraftRead:
        if ExamRepository(self._session).get_visible(exam_code, self._owner_id) is None:
            raise InvalidReferenceError(f"Unknown exam '{exam_code}'.")
        temp = self._temp_dir / f"syllabus-{uuid.uuid4().hex}.pdf"
        try:
            self._save_limited(stream, temp)
            pages = self._page_count(temp)
            extracted = list(
                extract_pages(temp, language=language, ocr=self._ocr, settings=self._settings)
            )
        finally:
            temp.unlink(missing_ok=True)
        known = {t.subject for t in visible_topics(self._session, self._owner_id, exam_code)}
        draft = parse_syllabus([p.text for p in extracted], known_subjects=known)
        methods = {p.method for p in extracted if p.method != ExtractionMethod.NONE}
        return SyllabusDraftRead(
            exam_code=exam_code,
            pages=pages,
            read_by="mixed" if len(methods) > 1 else (methods.pop() if methods else "none"),
            unreadable_pages=sum(p.needs_review for p in extracted),
            subjects=[SyllabusSubjectRead(name=s.name, topics=s.topics) for s in draft.subjects],
            topic_count=draft.topic_count,
            truncated=draft.truncated,
        )

    def _save_limited(self, stream: BinaryIO, destination: Path) -> None:
        limit = self._settings.max_upload_bytes
        size = 0
        with destination.open("wb") as out:
            while chunk := stream.read(_CHUNK):
                size += len(chunk)
                if size > limit:
                    raise UploadTooLargeError(
                        f"The file is larger than {limit // (1024 * 1024)} MB."
                    )
                out.write(chunk)
        if size == 0:
            raise InvalidDocumentError("empty_file", "The file is empty.")
        with destination.open("rb") as file:
            if b"%PDF-" not in file.read(1024):
                raise UnsupportedFileTypeError("Only PDF files can be imported.")

    @staticmethod
    def _page_count(path: Path) -> int:
        try:
            document = pdfium.PdfDocument(path)
        except pdfium.PdfiumError as exc:
            raise InvalidDocumentError(
                "invalid_pdf", "The file is damaged, password-protected or not a valid PDF."
            ) from exc
        try:
            pages = len(document)
        finally:
            document.close()
        if pages == 0:
            raise InvalidDocumentError("invalid_pdf", "The PDF has no pages.")
        if pages > MAX_SYLLABUS_PAGES:
            raise InvalidDocumentError(
                "too_many_pages",
                f"A syllabus has at most {MAX_SYLLABUS_PAGES} pages; this PDF has {pages}. "
                "Is it a question paper?",
            )
        return pages
