"""Question bank queries and reviewer edits."""

import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import Select, and_, exists, func, select
from sqlalchemy.orm import Session, selectinload
from sqlalchemy.sql.base import ExecutableOption

from app.domain.errors import DomainError, InvalidReferenceError, NotFoundError
from app.domain.segmentation import EXPECTED_OPTIONS, Issue, IssueCode, content_issues
from app.models.ai import AIExplanation, DraftStatus
from app.models.document import Document
from app.models.question import (
    ExamFormat,
    Question,
    QuestionIssue,
    QuestionOption,
    QuestionOrigin,
    Topic,
    TopicStatus,
    VerificationStatus,
)
from app.schemas.question import (
    AIExplanationRead,
    AIProvenance,
    ExamFormatRead,
    IssueRead,
    OptionRead,
    ParseSummary,
    PassageRead,
    QuestionList,
    QuestionRead,
    QuestionUpdate,
    TopicRead,
)

# Issues recomputed from the question's current content after every edit.
CONTENT_ISSUE_CODES = {
    IssueCode.MISSING_ANSWER,
    IssueCode.INCOMPLETE_OPTIONS,
    IssueCode.EMPTY_OPTION,
    IssueCode.ANSWER_NOT_IN_OPTIONS,
}


# A learner reported the question as wrong or unclear (resolved when it is re-verified).
LEARNER_REPORT = "learner_report"


class CannotVerifyError(DomainError):
    status_code = 422
    code = "cannot_verify"


@dataclass(frozen=True, slots=True)
class QuestionFilter:
    query: str | None = None
    exam_code: str | None = None
    section: str | None = None
    subject: str | None = None
    topic_id: uuid.UUID | None = None
    language: str | None = None
    document_id: uuid.UUID | None = None
    status: str | None = None
    has_issues: bool | None = None
    image_dependent: bool | None = None
    origin: str | None = None


def _escape_like(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


_OPEN_ISSUE = exists().where(
    and_(QuestionIssue.question_id == Question.id, QuestionIssue.resolved.is_(False))
)


class QuestionService:
    def __init__(self, session: Session, owner_id: uuid.UUID) -> None:
        self._session = session
        self._owner_id = owner_id

    # --- reads ------------------------------------------------------------------------

    def search(self, filters: QuestionFilter, *, limit: int, offset: int) -> QuestionList:
        stmt = self._apply(select(Question), filters)
        total = self._session.scalar(self._apply(select(func.count(Question.id)), filters)) or 0
        rows = self._session.scalars(
            stmt.options(*self._load_options())
            .order_by(
                Question.document_id, Question.section, Question.source_question_number, Question.id
            )
            .limit(limit)
            .offset(offset)
        ).all()
        return QuestionList(items=self._reads(rows), total=total, limit=limit, offset=offset)

    def by_ids(self, ids: list[uuid.UUID]) -> QuestionList:
        """Questions in the given order (missing ids are skipped)."""
        if not ids:
            return QuestionList(items=[], total=0, limit=len(ids), offset=0)
        rows = self._session.scalars(
            select(Question)
            .where(Question.id.in_(ids), Question.owner_id == self._owner_id)
            .options(*self._load_options())
        ).all()
        by_id = {q.id: q for q in rows}
        ordered = [by_id[i] for i in ids if i in by_id]
        return QuestionList(
            items=self._reads(ordered),
            total=len(ordered),
            limit=len(ids),
            offset=0,
        )

    def get(self, question_id: uuid.UUID) -> QuestionRead:
        return self._reads([self._get_or_404(question_id)])[0]

    def topics(self, subject: str | None) -> list[TopicRead]:
        stmt = select(Topic).order_by(Topic.subject, Topic.name)
        if subject:
            stmt = stmt.where(Topic.subject == subject)
        return [TopicRead.model_validate(t) for t in self._session.scalars(stmt).all()]

    def exam_formats(self, exam_code: str | None) -> list[ExamFormatRead]:
        stmt = select(ExamFormat).order_by(ExamFormat.exam_code, ExamFormat.code)
        if exam_code:
            stmt = stmt.where(ExamFormat.exam_code == exam_code)
        return [ExamFormatRead.model_validate(f) for f in self._session.scalars(stmt).all()]

    def parse_summary(self, document_id: uuid.UUID) -> ParseSummary:
        document = self._session.get(Document, document_id)
        if document is None or document.owner_id != self._owner_id:
            raise NotFoundError("Document not found.")
        questions = self._session.scalars(
            select(Question)
            .where(Question.document_id == document_id)
            .options(selectinload(Question.issues))
        ).all()
        sections: list[str] = []
        for q in sorted(questions, key=lambda q: q.source_question_number or 0):
            if q.section and q.section not in sections:
                sections.append(q.section)
        doc_issues = self._session.scalars(
            select(QuestionIssue).where(
                QuestionIssue.document_id == document_id, QuestionIssue.question_id.is_(None)
            )
        ).all()
        exam_format = (
            self._session.get(ExamFormat, document.exam_format_id)
            if document.exam_format_id
            else None
        )
        return ParseSummary(
            document_id=document_id,
            segmentation_status=document.segmentation_status,
            questions_found=len(questions),
            verified=sum(q.verification_status == VerificationStatus.VERIFIED for q in questions),
            rejected=sum(q.verification_status == VerificationStatus.REJECTED for q in questions),
            with_open_issues=sum(any(not i.resolved for i in q.issues) for q in questions),
            missing_answers=sum(q.correct_option_position is None for q in questions),
            image_dependent=sum(q.image_dependent for q in questions),
            sections=sections,
            exam_format=ExamFormatRead.model_validate(exam_format) if exam_format else None,
            document_issues=[IssueRead.model_validate(i) for i in doc_issues],
        )

    # --- reviewer edits ---------------------------------------------------------------

    def update(self, question_id: uuid.UUID, data: QuestionUpdate) -> QuestionRead:
        question = self._get_or_404(question_id)
        changes = data.model_dump(exclude_unset=True)
        status = changes.pop("verification_status", None)

        if "options" in changes:
            question.options = [
                QuestionOption(position=i + 1, label=o["label"], text=o["text"])
                for i, o in enumerate(changes.pop("options"))
            ]
        if "correct_option_position" in changes:
            position = changes.pop("correct_option_position")
            if position != question.correct_option_position:
                question.correct_option_position = position
                question.answer_source = "manual" if position is not None else None
        if "topic_id" in changes:
            topic_id = changes.pop("topic_id")
            if topic_id is not None and self._session.get(Topic, topic_id) is None:
                raise InvalidReferenceError("Unknown topic.")
            question.topic_id = topic_id
            question.topic_status = TopicStatus.CONFIRMED if topic_id else TopicStatus.UNASSIGNED
            question.topic_suggested_by = None
        for field_name, value in changes.items():
            setattr(question, field_name, value)

        content_changed = bool(data.model_fields_set - {"verification_status"})
        self._refresh_content_issues(question)

        if status == VerificationStatus.VERIFIED:
            self._verify(question)
        elif status is not None:
            question.verification_status = status
            question.verified_at = None
        elif content_changed and question.verification_status == VerificationStatus.VERIFIED:
            # An edited question must be re-checked before it counts as verified again.
            question.verification_status = VerificationStatus.UNVERIFIED
            question.verified_at = None

        self._session.commit()
        return self.get(question_id)

    def report(self, question_id: uuid.UUID, reason: str, note: str) -> QuestionRead:
        """A learner flags a question. It gets an open "learner_report" issue and, if it was
        verified, goes back to review (out of practice until re-approved)."""
        question = self._get_or_404(question_id)
        detail = f"{reason}: {note}" if note else reason
        question.issues.append(
            QuestionIssue(
                document_id=question.document_id, code=LEARNER_REPORT, detail=detail[:500]
            )
        )
        if question.verification_status == VerificationStatus.VERIFIED:
            question.verification_status = VerificationStatus.UNVERIFIED
            question.verified_at = None
        self._session.commit()
        return self.get(question_id)

    def _verify(self, question: Question) -> None:
        blocking = [
            i.code for i in question.issues if not i.resolved and i.code in CONTENT_ISSUE_CODES
        ]
        if blocking:
            raise CannotVerifyError(
                "Fix these before verifying: " + ", ".join(sorted(set(blocking))) + "."
            )
        question.verification_status = VerificationStatus.VERIFIED
        question.verified_at = datetime.now(UTC)
        if question.topic_status == TopicStatus.SUGGESTED:
            question.topic_status = TopicStatus.CONFIRMED  # the reviewer saw and kept it
        for issue in question.issues:
            issue.resolved = True

    def _refresh_content_issues(self, question: Question) -> None:
        question.issues = [i for i in question.issues if i.code not in CONTENT_ISSUE_CODES]
        found = content_issues(
            option_texts=[o.text for o in question.options],
            answer_position=question.correct_option_position,
            expected_options=EXPECTED_OPTIONS,
        )
        position = question.correct_option_position
        if position is not None and position > len(question.options):
            found.append(Issue(IssueCode.ANSWER_NOT_IN_OPTIONS, f"answer {position}"))
        for issue in found:
            question.issues.append(
                QuestionIssue(
                    document_id=question.document_id, code=issue.code, detail=issue.detail
                )
            )

    # --- helpers ----------------------------------------------------------------------

    def _get_or_404(self, question_id: uuid.UUID) -> Question:
        question = self._session.scalars(
            select(Question)
            .where(Question.id == question_id, Question.owner_id == self._owner_id)
            .options(*self._load_options())
        ).first()
        if question is None:
            raise NotFoundError("Question not found.")
        return question

    @staticmethod
    def _load_options() -> list[ExecutableOption]:
        return [
            selectinload(Question.options),
            selectinload(Question.issues),
            selectinload(Question.passage),
            selectinload(Question.topic),
        ]

    def _filenames(self, ids: set[uuid.UUID | None]) -> dict[uuid.UUID, str]:
        valid = {i for i in ids if i is not None}
        if not valid:
            return {}
        rows = self._session.execute(
            select(Document.id, Document.original_filename).where(Document.id.in_(valid))
        ).all()
        return {row[0]: row[1] for row in rows}

    def _apply[*Ts](self, stmt: Select[*Ts], f: QuestionFilter) -> Select[*Ts]:
        stmt = stmt.where(Question.owner_id == self._owner_id)
        if f.exam_code:
            stmt = stmt.where(Question.exam_code == f.exam_code)
        if f.section:
            stmt = stmt.where(Question.section == f.section)
        if f.subject:
            stmt = stmt.where(Question.subject == f.subject)
        if f.topic_id:
            stmt = stmt.where(Question.topic_id == f.topic_id)
        if f.language:
            stmt = stmt.where(Question.language == f.language)
        if f.document_id:
            stmt = stmt.where(Question.document_id == f.document_id)
        if f.status:
            stmt = stmt.where(Question.verification_status == f.status)
        if f.origin:
            stmt = stmt.where(Question.origin == f.origin)
        if f.image_dependent is not None:
            stmt = stmt.where(Question.image_dependent.is_(f.image_dependent))
        if f.has_issues is not None:
            stmt = stmt.where(_OPEN_ISSUE if f.has_issues else ~_OPEN_ISSUE)
        if f.query:
            stmt = stmt.where(Question.stem.ilike(f"%{_escape_like(f.query)}%", escape="\\"))
        return stmt

    def _reads(self, questions: Sequence[Question]) -> list[QuestionRead]:
        filenames = self._filenames({q.document_id for q in questions if q.document_id})
        explanations: dict[uuid.UUID, AIExplanation] = {}
        ids = [q.id for q in questions]
        if ids:
            for row in self._session.scalars(
                select(AIExplanation)
                .where(
                    AIExplanation.question_id.in_(ids), AIExplanation.status != DraftStatus.REJECTED
                )
                .order_by(AIExplanation.created_at)
            ):
                explanations[row.question_id] = row  # latest wins
        return [self._read(q, filenames, explanations.get(q.id)) for q in questions]

    @staticmethod
    def _read(
        question: Question,
        filenames: dict[uuid.UUID, str],
        ai_explanation: AIExplanation | None = None,
    ) -> QuestionRead:
        return QuestionRead(
            id=question.id,
            origin=question.origin,
            exam_code=question.exam_code,
            section=question.section,
            subject=question.subject,
            topic=TopicRead.model_validate(question.topic) if question.topic else None,
            topic_status=question.topic_status,
            topic_suggested_by=question.topic_suggested_by
            if question.topic_status == TopicStatus.SUGGESTED
            else None,
            stem=question.stem,
            language=question.language,
            document_id=question.document_id,
            document_filename=filenames.get(question.document_id) if question.document_id else None,
            source_question_number=question.source_question_number,
            source_pages=question.source_pages,
            passage=PassageRead.model_validate(question.passage) if question.passage else None,
            options=[OptionRead.model_validate(o) for o in question.options],
            correct_option_position=question.correct_option_position,
            answer_source=question.answer_source,
            explanation=question.explanation,
            image_dependent=question.image_dependent,
            verification_status=question.verification_status,
            verified_at=question.verified_at,
            issues=[IssueRead.model_validate(i) for i in question.issues],
            open_issue_count=sum(not i.resolved for i in question.issues),
            ai=AIProvenance(
                provider=question.ai_provider or "",
                model=question.ai_model or "",
                prompt_version=question.ai_prompt_version or "",
                source_question_id=question.ai_source_question_id,
                source_note=question.ai_source_note,
            )
            if question.origin == QuestionOrigin.AI
            else None,
            ai_explanation=AIExplanationRead.model_validate(ai_explanation)
            if ai_explanation
            else None,
            created_at=question.created_at,
            updated_at=question.updated_at,
        )
