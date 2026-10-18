"""Practice sessions and mock tests.

Integrity rules:
* All times are server times. The deadline is fixed at creation, and a mock test past its
  deadline is auto-submitted with the answers saved so far (when it is read, answered or
  submitted), so closing the app cannot extend or reset the timer.
* Answers carry a client sequence number; an update is applied only if it is newer than the
  stored one, so offline replays are idempotent and order-safe.
* Practice answers are final once given (feedback is immediate); mock answers can change
  until submission.
* Submission is idempotent: submitting again returns the same result.
* Mock marking comes only from the verified exam format.
"""

import random
import uuid
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from typing import Any, Literal

from sqlalchemy import Select, and_, false, func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.domain import typed_answers
from app.domain.errors import ConflictError, DomainError, InvalidReferenceError, NotFoundError
from app.domain.scoring import ScoredItem, is_correct, score_session, tally_json, to_decimal
from app.domain.segmentation import same_subject
from app.models.ai import AIExplanation, DraftStatus
from app.models.document import Document
from app.models.practice import (
    Bookmark,
    PracticeSession,
    SessionAnswer,
    SessionItem,
    SessionMode,
    SessionStatus,
)
from app.models.question import (
    ExamFormat,
    Question,
    QuestionFigure,
    QuestionOption,
    QuestionOrigin,
    Topic,
    VerificationStatus,
)
from app.schemas.practice import (
    AnswerAck,
    AnswerUpdate,
    Feedback,
    FormatRef,
    ItemSource,
    MockAvailability,
    MockCreate,
    PracticeCreate,
    QuestionHistory,
    SectionAvailability,
    SectionResult,
    SessionItemRead,
    SessionList,
    SessionRead,
    SessionResult,
    SessionSummary,
    TallyRead,
    TopicResult,
)
from app.schemas.question import FigureRead, OptionRead, PassageRead

PRACTICE_MARKING_NOTE = "Practice: 1 point per correct answer, no negative marking."


class NoQuestionsAvailableError(DomainError):
    status_code = 422
    code = "no_questions_available"


class NotEnoughQuestionsError(DomainError):
    status_code = 422
    code = "not_enough_questions"


class InvalidAnswerError(DomainError):
    status_code = 422
    code = "invalid_answer"


def _answered(answer: SessionAnswer | None) -> bool:
    return answer is not None and (
        answer.selected_position is not None or answer.typed_answer is not None
    )


ANSWERED = or_(
    SessionAnswer.selected_position.is_not(None), SessionAnswer.typed_answer.is_not(None)
)


def _eligible(
    include_unverified: bool, include_ai: bool = False, include_typed: bool = True
) -> Select[Question]:
    """Questions fit for practice: from a source document (AI questions only on request),
    answer known, at least two options, never rejected (unverified only on request), and
    not image-dependent unless the figure was cropped from the paper (then it is shown)."""
    option_count = (
        select(func.count())
        .select_from(QuestionOption)
        .where(QuestionOption.question_id == Question.id)
        .scalar_subquery()
    )
    statuses = [VerificationStatus.VERIFIED]
    if include_unverified:
        statuses.append(VerificationStatus.UNVERIFIED)
    origins = [QuestionOrigin.SOURCE]
    if include_ai:
        origins.append(QuestionOrigin.AI)
    return select(Question).where(
        Question.origin.in_(origins),
        Question.verification_status.in_(statuses),
        or_(
            Question.image_dependent.is_(False),
            select(QuestionFigure.id).where(QuestionFigure.question_id == Question.id).exists(),
        ),
        or_(
            and_(
                Question.answer_type == "choice",
                Question.correct_option_position.is_not(None),
                option_count >= 2,
                Question.correct_option_position <= option_count,
            ),
            # Typed-in questions need their answer; mocks leave them out (their marking
            # isn't part of any verified format yet).
            and_(Question.answer_type == "typed", Question.typed_answer.is_not(None))
            if include_typed
            else false(),
        ),
    )


def _scored(item: SessionItem) -> ScoredItem:
    return ScoredItem(
        position=item.position,
        section=item.section,
        topic_id=str(item.topic_id) if item.topic_id else None,
        correct_position=item.correct_position,
        marks_correct=to_decimal(item.marks_correct),
        marks_wrong=to_decimal(item.marks_wrong),
        typed_answer=item.typed_answer if item.answer_type == "typed" else None,
    )


class PracticeService:
    def __init__(
        self,
        session: Session,
        *,
        owner_id: uuid.UUID,
        now: Callable[[], datetime] | None = None,
    ) -> None:
        self._owner_id = owner_id
        self._session = session
        self._now = now or (lambda: datetime.now(UTC))

    # --- creating sessions ----------------------------------------------------------

    def start_practice(self, request: PracticeCreate) -> SessionRead:
        stmt = _eligible(request.include_unverified, request.include_ai).where(
            Question.owner_id == self._owner_id
        )
        if request.exam_code:
            stmt = stmt.where(Question.exam_code == request.exam_code)
        if request.subject:
            stmt = stmt.where(Question.subject == request.subject)
        if request.section:
            stmt = stmt.where(Question.section == request.section)
        if request.topic_id:
            stmt = stmt.where(Question.topic_id == request.topic_id)
        if request.pattern_id:
            stmt = stmt.where(Question.pattern_id == request.pattern_id)
        questions = self._session.scalars(stmt.order_by(func.random()).limit(request.count)).all()
        if not questions:
            raise NoQuestionsAvailableError(
                "No reviewed questions match. Approve questions in the question bank, "
                "or include questions that are not yet reviewed."
            )
        practice = PracticeSession(
            owner_id=self._owner_id,
            mode=SessionMode.PRACTICE,
            exam_code=request.exam_code,
            selection=request.model_dump(mode="json"),
            status=SessionStatus.ACTIVE,
            started_at=self._now(),
        )
        practice.items = [
            self._item(i + 1, q, marks_correct=1.0, marks_wrong=0.0)
            for i, q in enumerate(questions)
        ]
        self._session.add(practice)
        self._session.commit()
        return self.get(practice.id)

    def mock_availability(self, exam_code: str | None) -> list[MockAvailability]:
        stmt = select(ExamFormat).order_by(ExamFormat.code)
        if exam_code:
            stmt = stmt.where(ExamFormat.exam_code == exam_code)
        return [self._availability(f)[0] for f in self._session.scalars(stmt).all()]

    def start_mock(self, request: MockCreate) -> SessionRead:
        exam_format = self._session.scalars(
            select(ExamFormat).where(ExamFormat.code == request.exam_format_code)
        ).first()
        if exam_format is None:
            raise InvalidReferenceError(f"Unknown paper format '{request.exam_format_code}'.")
        availability, pools = self._availability(exam_format)
        if not availability.available:
            short = [
                f"{s.subject}: {s.available} of {s.needed}"
                for s in availability.sections
                if s.available < s.needed
            ]
            raise NotEnoughQuestionsError(
                "Not enough reviewed questions for this mock test (" + "; ".join(short) + ")."
            )
        if exam_format.duration_minutes is None:
            raise NotEnoughQuestionsError("This format has no verified duration.")

        seed = random.SystemRandom().randrange(2**31)
        rng = random.Random(seed)  # noqa: S311 - question sampling, recorded for reproducibility
        started = self._now()
        mock = PracticeSession(
            owner_id=self._owner_id,
            mode=SessionMode.MOCK,
            exam_code=exam_format.exam_code,
            exam_format_id=exam_format.id,
            selection={"exam_format_code": exam_format.code, "seed": seed},
            status=SessionStatus.ACTIVE,
            started_at=started,
            deadline_at=started + timedelta(minutes=exam_format.duration_minutes),
        )
        position = 0
        items: list[SessionItem] = []
        negative = exam_format.negative_marks_per_wrong or 0.0
        for section, pool in zip(exam_format.sections, pools, strict=True):
            needed = int(section["questions"])
            per_question = float(section["max_marks"]) / needed if section.get("max_marks") else 1.0
            for question in rng.sample(pool, needed):
                position += 1
                item = self._item(
                    position, question, marks_correct=per_question, marks_wrong=negative
                )
                item.section = section["subject"]
                items.append(item)
        mock.items = items
        self._session.add(mock)
        self._session.commit()
        return self.get(mock.id)

    def _availability(
        self, exam_format: ExamFormat
    ) -> tuple[MockAvailability, list[list[Question]]]:
        candidates = self._session.scalars(
            _eligible(include_unverified=False, include_typed=False).where(
                Question.exam_code == exam_format.exam_code,
                Question.owner_id == self._owner_id,
            )
        ).all()
        pools: list[list[Question]] = []
        sections: list[SectionAvailability] = []
        for section in exam_format.sections:
            subject = str(section["subject"])
            pool = [
                q
                for q in candidates
                if same_subject(q.subject or "", subject) or same_subject(q.section or "", subject)
            ]
            pools.append(pool)
            sections.append(
                SectionAvailability(
                    subject=subject, needed=int(section["questions"]), available=len(pool)
                )
            )
        availability = MockAvailability(
            exam_format_code=exam_format.code,
            exam_code=exam_format.exam_code,
            name=exam_format.name,
            available=all(s.available >= s.needed for s in sections),
            total_questions=exam_format.total_questions,
            duration_minutes=exam_format.duration_minutes,
            negative_marks_per_wrong=exam_format.negative_marks_per_wrong,
            sections=sections,
        )
        return availability, pools

    @staticmethod
    def _item(
        position: int, question: Question, *, marks_correct: float, marks_wrong: float
    ) -> SessionItem:
        typed = question.answer_type == "typed"
        return SessionItem(
            position=position,
            question_id=question.id,
            section=question.section,
            subject=question.subject,
            topic_id=question.topic_id,
            correct_position=None if typed else question.correct_option_position,
            option_count=0 if typed else len(question.options),
            answer_type=question.answer_type,
            typed_answer=question.typed_answer if typed else None,
            marks_correct=marks_correct,
            marks_wrong=marks_wrong,
            question_verified=question.verification_status == VerificationStatus.VERIFIED,
        )

    # --- answering & submitting -----------------------------------------------------

    def answer(self, session_id: uuid.UUID, position: int, update: AnswerUpdate) -> AnswerAck:
        practice = self._load(session_id)
        self._expire_if_due(practice)
        if practice.status != SessionStatus.ACTIVE:
            raise ConflictError("session_closed", "This session has already been submitted.")
        item = next((i for i in practice.items if i.position == position), None)
        if item is None:
            raise InvalidAnswerError(f"No question at position {position}.")
        typed = item.answer_type == "typed"
        if typed and update.selected_position is not None:
            raise InvalidAnswerError("This question takes a typed answer.")
        if not typed and update.typed_answer is not None:
            raise InvalidAnswerError("This question takes an option.")
        if update.selected_position is not None and update.selected_position > item.option_count:
            raise InvalidAnswerError("That option does not exist for this question.")

        existing = next((a for a in practice.answers if a.position == position), None)
        locked = practice.mode == SessionMode.PRACTICE and _answered(existing)
        applied = not locked and (existing is None or update.client_seq > existing.client_seq)
        if applied:
            if existing is None:
                existing = SessionAnswer(session_id=practice.id, position=position)
                practice.answers.append(existing)
            existing.question_id = item.question_id
            existing.selected_position = update.selected_position
            existing.typed_answer = (
                typed_answers.clean(update.typed_answer) if update.typed_answer else None
            )
            given: int | str | None = existing.typed_answer if typed else existing.selected_position
            existing.is_correct = None if given is None else is_correct(_scored(item), given)
            existing.client_seq = update.client_seq
            existing.time_spent_ms = update.time_spent_ms
            existing.answered_at = self._now()
            self._session.commit()
        assert existing is not None  # noqa: S101 - set above when applied; else pre-existing
        return AnswerAck(
            position=position,
            selected_position=existing.selected_position,
            typed_answer=existing.typed_answer,
            applied=applied,
            feedback=self._feedback(practice, item, existing),
        )

    def submit(self, session_id: uuid.UUID, *, reason: str = "user") -> SessionRead:
        practice = self._load(session_id)
        self._expire_if_due(practice)
        if practice.status == SessionStatus.ACTIVE:
            self._finalize(practice, reason=reason)
        return self.get(session_id)

    def _expire_if_due(self, practice: PracticeSession) -> None:
        if (
            practice.status == SessionStatus.ACTIVE
            and practice.deadline_at is not None
            and self._now() >= practice.deadline_at
        ):
            self._finalize(practice, reason="time_up")

    def _finalize(self, practice: PracticeSession, *, reason: str) -> None:
        now = self._now()
        if reason == "time_up" and practice.deadline_at is not None:
            now = min(now, practice.deadline_at)
        selections: dict[int, int | str | None] = {
            a.position: a.typed_answer if a.typed_answer is not None else a.selected_position
            for a in practice.answers
        }
        items = [_scored(i) for i in practice.items]
        scored = score_session(items, selections)
        topic_names = self._topic_names({i.topic_id for i in practice.items if i.topic_id})
        practice.status = SessionStatus.SUBMITTED
        practice.submitted_at = now
        practice.submit_reason = reason
        practice.score = float(scored.total.score)
        practice.max_score = float(scored.total.max_score)
        practice.result = {
            "total": tally_json(scored.total),
            "sections": [{"name": name, **tally_json(t)} for name, t in scored.sections.items()],
            "topics": [
                {"topic_id": tid, "name": topic_names.get(tid, ""), **tally_json(t)}
                for tid, t in scored.topics.items()
            ],
            "time_taken_seconds": max(0, int((now - practice.started_at).total_seconds())),
            "marking_note": self._marking_note(practice),
        }
        self._session.commit()

    def _marking_note(self, practice: PracticeSession) -> str:
        if practice.mode == SessionMode.PRACTICE:
            return PRACTICE_MARKING_NOTE
        exam_format = self._session.get(ExamFormat, practice.exam_format_id)
        if exam_format is None:
            return "Marking from the exam format used when this test started."
        parts = [
            f"{s['subject']}: {s['questions']} questions, {s.get('max_marks', '?')} marks"
            for s in exam_format.sections
        ]
        negative = exam_format.negative_marks_per_wrong
        return (
            f"{exam_format.name}. "
            + "; ".join(parts)
            + (f". Wrong answer: -{negative:.2f}." if negative else ". No negative marking.")
            + f" Source: {exam_format.source_reference}."
        )

    # --- reading --------------------------------------------------------------------

    def get(self, session_id: uuid.UUID) -> SessionRead:
        practice = self._load(session_id)
        self._expire_if_due(practice)
        now = self._now()
        questions = self._questions({i.question_id for i in practice.items if i.question_id})
        filenames = self._filenames({q.document_id for q in questions.values() if q.document_id})
        bookmarks = self._bookmarked(set(questions))
        answers = {a.position: a for a in practice.answers}
        exam_format = (
            self._session.get(ExamFormat, practice.exam_format_id)
            if practice.exam_format_id
            else None
        )
        remaining = None
        if practice.deadline_at is not None and practice.status == SessionStatus.ACTIVE:
            remaining = max(0, int((practice.deadline_at - now).total_seconds()))

        items: list[SessionItemRead] = []
        for item in practice.items:
            question = questions.get(item.question_id) if item.question_id else None
            answer = answers.get(item.position)
            items.append(
                SessionItemRead(
                    position=item.position,
                    question_id=item.question_id,
                    section=item.section,
                    subject=item.subject,
                    stem=question.stem if question else None,
                    options=[OptionRead.model_validate(o) for o in question.options]
                    if question and item.answer_type != "typed"
                    else [],
                    figures=[FigureRead.model_validate(f) for f in question.figures]
                    if question
                    else [],
                    passage=PassageRead.model_validate(question.passage)
                    if question and question.passage
                    else None,
                    origin=question.origin if question else None,
                    verified=item.question_verified,
                    source=ItemSource(
                        document_filename=filenames.get(question.document_id)
                        if question and question.document_id
                        else None,
                        page=question.source_pages[0]
                        if question and question.source_pages
                        else None,
                        question_number=question.source_question_number if question else None,
                    ),
                    bookmarked=bool(item.question_id and item.question_id in bookmarks),
                    selected_position=answer.selected_position if answer else None,
                    answer_type=item.answer_type,
                    typed_answer=answer.typed_answer if answer else None,
                    typed_answer_numeric=bool(item.typed_answer)
                    and typed_answers.is_numeric(item.typed_answer or ""),
                    feedback=self._feedback(practice, item, answer, question),
                )
            )
        return SessionRead(
            id=practice.id,
            mode=practice.mode,
            status=practice.status,
            exam_code=practice.exam_code,
            exam_format=FormatRef(code=exam_format.code, name=exam_format.name)
            if exam_format
            else None,
            started_at=practice.started_at,
            deadline_at=practice.deadline_at,
            submitted_at=practice.submitted_at,
            submit_reason=practice.submit_reason,
            server_now=now,
            remaining_seconds=remaining,
            item_count=len(practice.items),
            answered_count=sum(_answered(a) for a in practice.answers),
            items=items,
            result=self._result(practice.result) if practice.result else None,
        )

    def list_sessions(self, *, limit: int, offset: int) -> SessionList:
        rows = self._session.scalars(
            select(PracticeSession)
            .where(PracticeSession.owner_id == self._owner_id)
            .options(selectinload(PracticeSession.items))
            .order_by(PracticeSession.started_at.desc())
            .limit(limit)
            .offset(offset)
        ).all()
        for row in rows:
            self._expire_if_due(row)
        names = {
            f.id: f.name
            for f in self._session.scalars(
                select(ExamFormat).where(
                    ExamFormat.id.in_({r.exam_format_id for r in rows if r.exam_format_id})
                )
            ).all()
        }
        total = self._session.scalar(select(func.count(PracticeSession.id))) or 0
        return SessionList(
            items=[
                SessionSummary(
                    id=r.id,
                    mode=r.mode,
                    status=r.status,
                    exam_code=r.exam_code,
                    exam_format_name=names.get(r.exam_format_id) if r.exam_format_id else None,
                    started_at=r.started_at,
                    submitted_at=r.submitted_at,
                    item_count=len(r.items),
                    score=r.score,
                    max_score=r.max_score,
                )
                for r in rows
            ],
            total=total,
        )

    # --- bookmarks, incorrect answers, history ----------------------------------------

    def set_bookmark(self, question_id: uuid.UUID, *, bookmarked: bool) -> None:
        self._owned_question(question_id)
        existing = self._session.get(Bookmark, question_id)
        if bookmarked and existing is None:
            self._session.add(Bookmark(question_id=question_id))
        elif not bookmarked and existing is not None:
            self._session.delete(existing)
        self._session.commit()

    def bookmarked_ids(self) -> list[uuid.UUID]:
        return list(
            self._session.scalars(
                select(Bookmark.question_id)
                .join(Question, Question.id == Bookmark.question_id)
                .where(Question.owner_id == self._owner_id)
                .order_by(Bookmark.created_at.desc())
            )
        )

    def incorrect_ids(self) -> list[uuid.UUID]:
        """Questions whose most recent answer (in any submitted or practice session) was wrong."""
        latest = (
            select(
                SessionAnswer.question_id,
                func.max(SessionAnswer.answered_at).label("last"),
            )
            .join(PracticeSession, PracticeSession.id == SessionAnswer.session_id)
            .where(
                SessionAnswer.question_id.is_not(None),
                ANSWERED,
                PracticeSession.owner_id == self._owner_id,
            )
            .group_by(SessionAnswer.question_id)
            .subquery()
        )
        rows = self._session.execute(
            select(SessionAnswer.question_id, PracticeSession.mode, PracticeSession.status)
            .join(
                latest,
                and_(
                    latest.c.question_id == SessionAnswer.question_id,
                    latest.c.last == SessionAnswer.answered_at,
                ),
            )
            .join(PracticeSession, PracticeSession.id == SessionAnswer.session_id)
            .where(SessionAnswer.is_correct.is_(False), PracticeSession.owner_id == self._owner_id)
            .order_by(SessionAnswer.answered_at.desc())
        ).all()
        # Mock answers count only once the test is submitted (no hints during a test).
        return [
            row[0]
            for row in rows
            if row[0] is not None
            and (row[1] == SessionMode.PRACTICE or row[2] == SessionStatus.SUBMITTED)
        ]

    def history(self, question_id: uuid.UUID) -> QuestionHistory:
        self._owned_question(question_id)
        rows = self._session.execute(
            select(SessionAnswer.is_correct, SessionAnswer.answered_at)
            .join(PracticeSession, PracticeSession.id == SessionAnswer.session_id)
            .where(
                SessionAnswer.question_id == question_id,
                ANSWERED,
                PracticeSession.owner_id == self._owner_id,
                (PracticeSession.mode == SessionMode.PRACTICE)
                | (PracticeSession.status == SessionStatus.SUBMITTED),
            )
            .order_by(SessionAnswer.answered_at)
        ).all()
        last = rows[-1] if rows else None
        return QuestionHistory(
            question_id=question_id,
            attempts=len(rows),
            correct=sum(bool(r[0]) for r in rows),
            wrong=sum(r[0] is False for r in rows),
            last_result=None if last is None else ("correct" if last[0] else "wrong"),
            last_answered_at=last[1] if last else None,
            bookmarked=self._session.get(Bookmark, question_id) is not None,
        )

    # --- helpers ----------------------------------------------------------------------

    def _owned_question(self, question_id: uuid.UUID) -> Question:
        question = self._session.get(Question, question_id)
        if question is None or question.owner_id != self._owner_id:
            raise NotFoundError("Question not found.")
        return question

    def _load(self, session_id: uuid.UUID) -> PracticeSession:
        practice = self._session.scalars(
            select(PracticeSession)
            .where(PracticeSession.id == session_id, PracticeSession.owner_id == self._owner_id)
            .options(selectinload(PracticeSession.items), selectinload(PracticeSession.answers))
            .with_for_update(of=PracticeSession)
        ).first()
        if practice is None:
            raise NotFoundError("Session not found.")
        return practice

    def _feedback(
        self,
        practice: PracticeSession,
        item: SessionItem,
        answer: SessionAnswer | None,
        question: Question | None = None,
    ) -> Feedback | None:
        reveal = practice.status == SessionStatus.SUBMITTED or (
            practice.mode == SessionMode.PRACTICE and _answered(answer)
        )
        if not reveal:
            return None
        if question is None and item.question_id is not None:
            question = self._session.get(Question, item.question_id)
        explanation: str | None = None
        origin: Literal["source", "ai"] | None = None
        if question is not None and question.explanation:
            explanation = question.explanation
            origin = "ai" if question.origin == QuestionOrigin.AI else "source"
        elif question is not None:
            approved = self._session.scalars(
                select(AIExplanation)
                .where(
                    AIExplanation.question_id == question.id,
                    AIExplanation.status == DraftStatus.APPROVED,
                )
                .order_by(AIExplanation.created_at.desc())
                .limit(1)
            ).first()
            if approved is not None:
                explanation, origin = approved.text, "ai"
        return Feedback(
            correct_position=item.correct_position,
            correct_typed_answer=item.typed_answer,
            is_correct=answer.is_correct if answer else None,
            explanation=explanation,
            explanation_origin=origin,
        )

    def _questions(self, ids: set[uuid.UUID]) -> dict[uuid.UUID, Question]:
        if not ids:
            return {}
        rows = self._session.scalars(
            select(Question)
            .where(Question.id.in_(ids))
            .options(
                selectinload(Question.options),
                selectinload(Question.passage),
                selectinload(Question.figures),
            )
        ).all()
        return {q.id: q for q in rows}

    def _filenames(self, ids: set[uuid.UUID]) -> dict[uuid.UUID, str]:
        if not ids:
            return {}
        rows = self._session.execute(
            select(Document.id, Document.original_filename).where(Document.id.in_(ids))
        ).all()
        return {r[0]: r[1] for r in rows}

    def _bookmarked(self, ids: set[uuid.UUID]) -> set[uuid.UUID]:
        if not ids:
            return set()
        return set(
            self._session.scalars(select(Bookmark.question_id).where(Bookmark.question_id.in_(ids)))
        )

    def _topic_names(self, ids: set[uuid.UUID]) -> dict[str, str]:
        if not ids:
            return {}
        rows = self._session.execute(select(Topic.id, Topic.name).where(Topic.id.in_(ids))).all()
        return {str(r[0]): r[1] for r in rows}

    @staticmethod
    def _result(data: dict[str, Any]) -> SessionResult:
        total = data["total"]
        return SessionResult(
            **{k: total[k] for k in TallyRead.model_fields},
            time_taken_seconds=data["time_taken_seconds"],
            marking_note=data["marking_note"],
            sections=[SectionResult(**s) for s in data["sections"]],
            topics=[TopicResult(**t) for t in data["topics"]],
        )
