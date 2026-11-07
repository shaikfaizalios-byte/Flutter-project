"""Reading a syllabus PDF into a topic draft for one exam. Nothing is stored: the PDF is read
from a temporary file that is deleted at once, and the learner saves the topics they keep
(POST /topics/bulk)."""

import uuid
from pathlib import Path
from typing import BinaryIO

from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain.errors import InvalidReferenceError
from app.domain.syllabus import parse_syllabus
from app.integrations.ocr import OcrEngine
from app.models.document import ExtractionMethod
from app.repositories.exam_repository import ExamRepository
from app.schemas.exam import SyllabusDraftRead, SyllabusSubjectRead
from app.services.extraction import extract_pages
from app.services.pdf_upload import page_count, save_limited
from app.services.topic_service import visible_topics

# Syllabi are short; a long PDF here is most likely a question paper picked by mistake.
MAX_SYLLABUS_PAGES = 40


def _too_long(pages: int) -> str:
    return (
        f"A syllabus has at most {MAX_SYLLABUS_PAGES} pages; this PDF has {pages}. "
        "Is it a question paper?"
    )


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
            save_limited(stream, temp, self._settings.max_upload_bytes)
            pages = page_count(temp, MAX_SYLLABUS_PAGES, _too_long)
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

    def read_text(self, exam_code: str, text: str) -> SyllabusDraftRead:
        """A syllabus the learner typed or pasted (no PDF available)."""
        if ExamRepository(self._session).get_visible(exam_code, self._owner_id) is None:
            raise InvalidReferenceError(f"Unknown exam '{exam_code}'.")
        known = {t.subject for t in visible_topics(self._session, self._owner_id, exam_code)}
        draft = parse_syllabus([text], known_subjects=known)
        return SyllabusDraftRead(
            exam_code=exam_code,
            pages=0,
            read_by="typed",
            unreadable_pages=0,
            subjects=[SyllabusSubjectRead(name=s.name, topics=s.topics) for s in draft.subjects],
            topic_count=draft.topic_count,
            truncated=draft.truncated,
        )
