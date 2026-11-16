"""Current affairs cards from the learner's own sources (app/domain/current_affairs.py).

Pasted text or a PDF read in the request (text layer or OCR, from a temporary file deleted at
once). NOTHING is stored here: the drafts go back to the learner, who approves each one in the
app, where approved cards become concepts on the revision ladder. The AI call is logged without
its text, like every other."""

import logging
import uuid
from pathlib import Path
from typing import BinaryIO

from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain import ai_content
from app.domain import current_affairs as ca
from app.domain.errors import AIDisabledError, AIUnavailableError, InvalidReferenceError
from app.integrations.ai import AIProvider, AIProviderError, AIResult
from app.integrations.ocr import OcrEngine
from app.models.ai import AIGeneration
from app.repositories.exam_repository import ExamRepository
from app.schemas.current_affairs import CurrentAffairsCard, CurrentAffairsDraft
from app.services.extraction import extract_pages
from app.services.pdf_upload import page_count, save_limited

logger = logging.getLogger(__name__)

TASK = "current_affairs"
MAX_PAGES = 40


def _too_long(pages: int) -> str:
    return f"Current affairs PDFs can have at most {MAX_PAGES} pages; this one has {pages}."


class CurrentAffairsService:
    def __init__(
        self,
        session: Session,
        owner_id: uuid.UUID,
        provider: AIProvider | None,
        settings: Settings,
    ) -> None:
        self._session = session
        self._owner_id = owner_id
        self._provider = provider
        self._settings = settings

    def from_text(self, exam_code: str, text: str, language: str) -> CurrentAffairsDraft:
        self._check_exam(exam_code)
        return self._draft([ca.SourcePart("P1", "Pasted text", text)], language)

    def from_pdf(
        self,
        exam_code: str,
        stream: BinaryIO,
        filename: str,
        language: str,
        *,
        ocr: OcrEngine,
        temp_dir: Path,
    ) -> CurrentAffairsDraft:
        self._check_exam(exam_code)
        temp = temp_dir / f"current-affairs-{uuid.uuid4().hex}.pdf"
        try:
            save_limited(stream, temp, self._settings.max_upload_bytes)
            page_count(temp, MAX_PAGES, _too_long)
            pages = list(extract_pages(temp, language=language, ocr=ocr, settings=self._settings))
        finally:
            temp.unlink(missing_ok=True)
        name = Path(filename or "document.pdf").name[:80]
        parts = [
            ca.SourcePart(f"P{i}", f"{name}, page {p.page_number}", p.text)
            for i, p in enumerate(pages, start=1)
        ]
        return self._draft(parts, language)

    def _draft(self, parts: list[ca.SourcePart], language: str) -> CurrentAffairsDraft:
        provider = self._provider
        if provider is None:
            raise AIDisabledError("AI assistance is not configured on this server.")
        sent, left_out = ca.parts_within_limit(parts)
        if not sent:
            return CurrentAffairsDraft(cards=[], dropped=0, left_out=False, no_text=True)
        try:
            result = provider.complete_json(
                system=ca.SYSTEM,
                prompt=ca.prompt(sent, language=language),
                schema=dict(ca.SCHEMA),
                max_tokens=self._settings.ai_max_output_tokens,
            )
        except AIProviderError as exc:
            logger.warning("AI %s call failed: %s", TASK, exc.reason)
            self._log(provider, "error", AIResult({}), exc.reason)
            self._session.commit()
            raise AIUnavailableError(
                "The AI service is not available right now. Please try again in a moment."
            ) from exc
        cards, dropped = ca.validate(result.data, sent)
        self._log(
            provider,
            "ok" if cards else "invalid",
            result,
            f"{len(cards)} cards, {dropped} dropped",
            created=len(cards),
            rejected=dropped,
        )
        self._session.commit()
        return CurrentAffairsDraft(
            cards=[
                CurrentAffairsCard(
                    front=c.front, back=c.back, source_label=c.source_label, quote=c.quote
                )
                for c in cards
            ],
            dropped=dropped,
            left_out=left_out,
            model=provider.model,
        )

    def _check_exam(self, exam_code: str) -> None:
        if ExamRepository(self._session).get_visible(exam_code, self._owner_id) is None:
            raise InvalidReferenceError(f"Unknown exam '{exam_code}'.")

    def _log(
        self,
        provider: AIProvider,
        outcome: str,
        result: AIResult,
        detail: str,
        *,
        created: int = 0,
        rejected: int = 0,
    ) -> None:
        self._session.add(
            AIGeneration(
                owner_id=self._owner_id,
                task=TASK,
                provider=provider.name,
                model=provider.model,
                prompt_version=ai_content.PROMPT_VERSION,
                outcome=outcome,
                detail=detail[:300],
                input_tokens=result.input_tokens,
                output_tokens=result.output_tokens,
                items_created=created,
                items_rejected=rejected,
            )
        )
