"""Reading a paper's questions with AI (run by the document worker, asked by the learner).

For papers PrepLoop's rules can't read (new layouts, two columns, tables, scans), the pages are
rendered to images and sent with their extracted text, a few pages per request. The returned
questions are checked (app/domain/ai_reading.py) and replace the rules' unreviewed questions;
reviewed (verified or rejected) questions are kept, exactly as a re-run of the rules does.
Every request is logged in ai_generations without any text.
"""

import logging
import uuid
from collections.abc import Callable, Sequence
from datetime import UTC, datetime, timedelta
from pathlib import Path

from sqlalchemy import delete, or_, select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain import ai_content, ai_reading
from app.domain.ai_reading import PageInput, ReadQuestion
from app.domain.topics import TopicCandidate, subject_for_section, suggest_topic
from app.integrations.ai import AIProvider, AIProviderError, AIResult
from app.integrations.storage import DocumentStorage
from app.models.ai import AIGeneration
from app.models.document import Document, DocumentPage
from app.models.question import (
    Passage,
    Question,
    QuestionIssue,
    QuestionOption,
    QuestionOrigin,
    TopicStatus,
    VerificationStatus,
)
from app.services.page_layout import PdfRenderer
from app.services.patterns import pattern_candidates, refresh_pattern
from app.services.topic_service import visible_topics

logger = logging.getLogger("app.ai_reading")

# A job left "running" this long (worker crashed or restarted) is taken up again.
STALE_AFTER = timedelta(minutes=30)
TASK = "paper_read"


def batches(pages: Sequence[int], size: int = ai_reading.PAGES_PER_CALL) -> list[list[int]]:
    """Main pages per request: [1,2,3], [4,5,6], ..."""
    return [list(pages[i : i + size]) for i in range(0, len(pages), size)]


class AiPaperReader:
    def __init__(
        self,
        provider: AIProvider | None,
        storage: DocumentStorage,
        settings: Settings,
        now: Callable[[], datetime] | None = None,
    ) -> None:
        self._provider = provider
        self._storage = storage
        self._settings = settings
        self._now = now or (lambda: datetime.now(UTC))

    # --- the job ------------------------------------------------------------------------------

    def claim_next(self, session: Session) -> uuid.UUID | None:
        """Take the next queued reading (or a stale running one), committing the claim."""
        now = self._now()
        document = session.scalars(
            select(Document)
            .where(
                or_(
                    Document.ai_read_status == "queued",
                    (Document.ai_read_status == "running")
                    & (Document.ai_read_started_at < now - STALE_AFTER),
                )
            )
            .order_by(Document.updated_at)
            .limit(1)
            .with_for_update(skip_locked=True)
        ).first()
        if document is None:
            session.commit()
            return None
        document.ai_read_status = "running"
        document.ai_read_started_at = now
        document.ai_read_pages_done = 0
        document.ai_read_error = None
        session.commit()
        return document.id

    def read(self, session: Session, document_id: uuid.UUID) -> None:
        """Read a claimed document. Never raises for document or provider problems: the
        document's ai_read_status says how it ended."""
        document = session.get(Document, document_id)
        if document is None:
            return
        try:
            error = self._read(session, document)
        except Exception:
            session.rollback()
            logger.exception(
                "AI reading failed", extra={"fields": {"document_id": str(document_id)}}
            )
            error = "internal_error"
        document = session.get(Document, document_id)
        if document is None:
            return
        document.ai_read_status = "failed" if error else "completed"
        document.ai_read_error = error
        session.commit()

    def _read(self, session: Session, document: Document) -> str | None:
        provider = self._provider
        if provider is None:
            return "ai_disabled"
        try:
            pdf_path: Path = self._storage.path_for(document.storage_key)
        except ValueError:
            return "file_missing"
        if not pdf_path.is_file():
            return "file_missing"
        pages = session.scalars(
            select(DocumentPage)
            .where(DocumentPage.document_id == document.id)
            .order_by(DocumentPage.page_number)
        ).all()
        texts = {p.page_number: p.text for p in pages}
        numbers = [p.page_number for p in pages][: self._settings.ai_read_max_pages]
        if not numbers:
            return "no_pages"

        found: list[ReadQuestion] = []
        failures = 0
        with PdfRenderer(pdf_path) as renderer:
            for main in batches(numbers):
                context = [n for n in numbers if n == main[-1] + 1]
                shown = [*main, *context]
                inputs = [PageInput(n, texts.get(n, ""), n in main) for n in shown]
                images = [renderer.page_png(n, self._settings.ai_read_image_edge) for n in shown]
                try:
                    result = provider.complete_json(
                        system=ai_reading.READ_SYSTEM,
                        prompt=ai_reading.read_prompt(inputs, document.language),
                        schema=ai_reading.READ_SCHEMA,
                        max_tokens=self._settings.ai_max_output_tokens * 4,
                        images=images,
                    )
                except AIProviderError as exc:
                    failures += 1
                    self._log(session, provider, document, "error", AIResult({}), exc.reason)
                    if not exc.retryable:
                        session.commit()
                        return f"ai_{exc.reason}"[:40]
                    continue
                questions, dropped = ai_reading.validate_read(result.data, main)
                for question in questions:
                    # The question may run onto the next page: compare with both.
                    ai_reading.check_against_page(
                        question, texts.get(question.page, ""), texts.get(question.page + 1, "")
                    )
                found.extend(questions)
                self._log(
                    session,
                    provider,
                    document,
                    "ok" if not dropped else "partial",
                    result,
                    f"pages {main[0]}-{main[-1]}",
                    created=len(questions),
                    rejected=len(dropped),
                )
                document.ai_read_pages_done = main[-1]
                session.commit()  # progress is visible to the app while reading
        if failures and not found:
            return "ai_unavailable"
        self._save(session, document, found)
        return None

    # --- storing the questions -----------------------------------------------------------------

    def _save(self, session: Session, document: Document, found: list[ReadQuestion]) -> None:
        kept = session.scalars(
            select(Question).where(
                Question.document_id == document.id,
                Question.verification_status != VerificationStatus.UNVERIFIED,
            )
        ).all()
        kept_keys = {(q.section, q.source_question_number) for q in kept}
        kept_passages = {q.passage_id for q in kept if q.passage_id}
        session.execute(
            delete(Question).where(
                Question.document_id == document.id,
                Question.verification_status == VerificationStatus.UNVERIFIED,
            )
        )
        session.execute(
            delete(QuestionIssue).where(
                QuestionIssue.document_id == document.id, QuestionIssue.question_id.is_(None)
            )
        )
        stale_passages = delete(Passage).where(Passage.document_id == document.id)
        if kept_passages:
            stale_passages = stale_passages.where(Passage.id.not_in(kept_passages))
        session.execute(stale_passages)

        exam_topics = visible_topics(session, document.owner_id, document.exam_code)
        topics = [TopicCandidate(t.id, t.subject, t.name, t.keywords) for t in exam_topics]
        subjects = sorted({t.subject for t in topics})
        patterns = pattern_candidates(session)
        passages: dict[str, Passage] = {}
        created = 0
        for read in found:
            if (read.section, read.number) in kept_keys:
                continue  # a reviewer already decided on this question
            passage = None
            if read.passage:
                passage = passages.get(read.passage)
                if passage is None:
                    passage = Passage(
                        document_id=document.id, text=read.passage, source_pages=[read.page]
                    )
                    session.add(passage)
                    session.flush()
                    passages[read.passage] = passage
            subject = subject_for_section(read.section, subjects)
            suggestion = suggest_topic(read.stem, subject=subject, topics=topics)
            question = Question(
                origin=QuestionOrigin.SOURCE,  # from the paper; only the reading was AI
                extracted_by="ai",
                owner_id=document.owner_id,
                exam_code=document.exam_code,
                exam_format_id=document.exam_format_id,
                section=read.section,
                subject=subject or (suggestion.subject if suggestion else None),
                topic_id=suggestion.topic_id if suggestion else None,
                topic_status=TopicStatus.SUGGESTED if suggestion else TopicStatus.UNASSIGNED,
                topic_suggested_by="keywords" if suggestion else None,
                topic_suggestion_reason=suggestion.reason[:200] if suggestion else None,
                stem=read.stem,
                language=document.language,
                document_id=document.id,
                source_question_number=read.number,
                source_pages=[read.page],
                passage_id=passage.id if passage else None,
                correct_option_position=read.answer_position,
                answer_source="inline" if read.answer_position else None,
                image_dependent=read.has_figure,
                verification_status=VerificationStatus.UNVERIFIED,
            )
            question.options = [
                QuestionOption(position=i + 1, label=o.label, text=o.text)
                for i, o in enumerate(read.options)
            ]
            question.issues = [
                QuestionIssue(document_id=document.id, code=i.code, detail=i.detail[:500])
                for i in read.issues
            ]
            refresh_pattern(question, patterns)
            session.add(question)
            created += 1
        document.segmentation_status = "completed"
        document.questions_found = created + len(kept)
        document.segmented_at = self._now()
        session.commit()
        logger.info(
            "document read by AI",
            extra={"fields": {"document_id": str(document.id), "questions": created}},
        )

    def _log(
        self,
        session: Session,
        provider: AIProvider,
        document: Document,
        outcome: str,
        result: AIResult,
        detail: str,
        *,
        created: int = 0,
        rejected: int = 0,
    ) -> None:
        session.add(
            AIGeneration(
                owner_id=document.owner_id,
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
