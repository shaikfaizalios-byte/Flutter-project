"""Turns a processed document's pages into question-bank rows.

Re-running is safe: questions a reviewer has verified or rejected are kept untouched, and
freshly parsed questions with the same (section, number) are skipped so human decisions are
never overwritten. Everything else from a previous run is replaced.
"""

import logging
import uuid
from datetime import UTC, datetime

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.domain.segmentation import (
    EXPECTED_OPTIONS,
    PageText,
    ParsedQuestion,
    check_against_format,
    segment,
)
from app.domain.topics import TopicCandidate, subject_for_section, suggest_topic
from app.models.document import Document, DocumentPage
from app.models.question import (
    ExamFormat,
    Passage,
    Question,
    QuestionIssue,
    QuestionOption,
    QuestionOrigin,
    Topic,
    TopicStatus,
    VerificationStatus,
)

logger = logging.getLogger("app.segmentation")


class SegmentationService:
    def __init__(self, session: Session) -> None:
        self._session = session

    def segment_document(self, document_id: uuid.UUID) -> None:
        """Segment and persist. On unexpected errors the document's segmentation_status is
        set to ``failed`` (the extraction result itself is unaffected)."""
        document = self._session.get(Document, document_id)
        if document is None:
            return
        try:
            self._run(document)
        except Exception:
            self._session.rollback()
            logger.exception(
                "segmentation failed", extra={"fields": {"document_id": str(document_id)}}
            )
            document = self._session.get(Document, document_id)
            if document is not None:
                document.segmentation_status = "failed"
                self._session.commit()

    def _run(self, document: Document) -> None:
        pages = self._session.scalars(
            select(DocumentPage)
            .where(DocumentPage.document_id == document.id)
            .order_by(DocumentPage.page_number)
        ).all()
        result = segment(
            [PageText(p.page_number, p.text, p.needs_review) for p in pages],
            expected_options=EXPECTED_OPTIONS,
        )
        exam_format = (
            self._session.get(ExamFormat, document.exam_format_id)
            if document.exam_format_id
            else None
        )
        if exam_format is not None:
            result.document_issues.extend(
                check_against_format(
                    result,
                    total_questions=exam_format.total_questions,
                    sections=[(s["subject"], int(s["questions"])) for s in exam_format.sections],
                )
            )

        kept = self._session.scalars(
            select(Question).where(
                Question.document_id == document.id,
                Question.verification_status != VerificationStatus.UNVERIFIED,
            )
        ).all()
        kept_keys = {(q.section, q.source_question_number) for q in kept}
        kept_passages = {q.passage_id for q in kept if q.passage_id}

        # Replace everything from the previous run except human-reviewed questions.
        self._session.execute(
            delete(Question).where(
                Question.document_id == document.id,
                Question.verification_status == VerificationStatus.UNVERIFIED,
            )
        )
        self._session.execute(
            delete(QuestionIssue).where(
                QuestionIssue.document_id == document.id, QuestionIssue.question_id.is_(None)
            )
        )
        self._session.execute(
            delete(Passage).where(
                Passage.document_id == document.id, Passage.id.not_in(kept_passages)
            )
            if kept_passages
            else delete(Passage).where(Passage.document_id == document.id)
        )

        passage_rows = [
            Passage(
                document_id=document.id,
                text=p.text,
                first_question=p.first_question,
                last_question=p.last_question,
                source_pages=p.pages,
            )
            for p in result.passages
        ]
        self._session.add_all(passage_rows)
        self._session.flush()

        topics = [
            TopicCandidate(t.id, t.subject, t.name, t.keywords)
            for t in self._session.scalars(select(Topic)).all()
        ]
        subjects = sorted({t.subject for t in topics})
        created = 0
        for parsed in result.questions:
            if (parsed.section, parsed.number) in kept_keys:
                continue
            self._session.add(
                self._build_question(document, exam_format, parsed, passage_rows, topics, subjects)
            )
            created += 1

        for issue in result.document_issues:
            self._session.add(
                QuestionIssue(document_id=document.id, code=issue.code, detail=issue.detail)
            )
        document.segmentation_status = "completed"
        document.questions_found = created + len(kept)
        document.segmented_at = datetime.now(UTC)
        self._session.commit()
        logger.info(
            "document segmented",
            extra={
                "fields": {
                    "document_id": str(document.id),
                    "questions": document.questions_found,
                    "kept_reviewed": len(kept),
                    "document_issues": len(result.document_issues),
                }
            },
        )

    @staticmethod
    def _build_question(
        document: Document,
        exam_format: ExamFormat | None,
        parsed: ParsedQuestion,
        passages: list[Passage],
        topics: list[TopicCandidate],
        subjects: list[str],
    ) -> Question:
        subject = subject_for_section(parsed.section, subjects)
        topic_id = suggest_topic(parsed.stem, subject=subject, topics=topics)
        question = Question(
            origin=QuestionOrigin.SOURCE,
            exam_code=document.exam_code,
            exam_format_id=exam_format.id if exam_format else None,
            section=parsed.section,
            subject=subject,
            topic_id=topic_id,
            topic_status=TopicStatus.SUGGESTED if topic_id else TopicStatus.UNASSIGNED,
            topic_suggested_by="keywords" if topic_id else None,
            stem=parsed.stem,
            language=document.language,
            document_id=document.id,
            source_question_number=parsed.number,
            source_pages=parsed.pages,
            passage_id=passages[parsed.passage_index].id
            if parsed.passage_index is not None
            else None,
            correct_option_position=parsed.answer_position,
            answer_source=parsed.answer_source,
            explanation=parsed.explanation,
            image_dependent=parsed.image_dependent,
            verification_status=VerificationStatus.UNVERIFIED,
        )
        question.options = [
            QuestionOption(position=i + 1, label=o.label, text=o.text)
            for i, o in enumerate(parsed.options)
        ]
        question.issues = [
            QuestionIssue(document_id=document.id, code=i.code, detail=i.detail)
            for i in parsed.issues
        ]
        return question
