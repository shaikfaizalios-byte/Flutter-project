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
from app.domain.exam_format import format_problems, section_marking
from app.domain.question_formats import (
    RESPONSE_FORMATS,
    SINGLE_ANSWER,
    SPEC_FORMATS,
    TYPED_IN,
    public_data,
    valid_response,
)
from app.domain.scoring import (
    Answer,
    ScoredItem,
    Tally,
    is_correct,
    score_session,
    tally_json,
    to_decimal,
)
from app.domain.sections import (
    PlannedSection,
    SectionClock,
    advance,
    finish_early,
    section_of,
)
from app.domain.segmentation import same_subject
from app.models.ai import AIExplanation, DraftStatus
from app.models.content import ContentRights
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
from app.schemas.content import StarterCheckAvailability
from app.schemas.practice import (
    AnswerAck,
    AnswerUpdate,
    Feedback,
    FormatRef,
    ItemSource,
    MockAvailability,
    MockCreate,
    OfflinePack,
    OfflineQuestion,
    OfflineSessionUpload,
    PracticeCreate,
    QuestionHistory,
    SectionAvailability,
    SectionRead,
    SectionResult,
    SessionItemRead,
    SessionList,
    SessionRead,
    SessionResult,
    SessionSummary,
    TallyRead,
    TopicResult,
    TranslationRead,
)
from app.schemas.question import FigureRead, OptionRead, PassageRead
from app.services.exam_formats import is_in_effect, mock_formats
from app.services.shared_bank import shared_question, visible_question
from app.services.taxonomy_service import subject_labels_by_topic

PRACTICE_MARKING_NOTE = "Practice: 1 point per correct answer, no negative marking."
STARTER_MARKING_NOTE = (
    "Starter check: 1 point per correct answer, no negative marking. It shows where to start,"
    " not an exam score. Questions come from shared papers PrepLoop may use for this check."
)
# The starter check: up to this many questions per subject, and in all.
STARTER_PER_SUBJECT = 5
STARTER_MAX = 20


class NoQuestionsAvailableError(DomainError):
    status_code = 422
    code = "no_questions_available"


class NotEnoughQuestionsError(DomainError):
    status_code = 422
    code = "not_enough_questions"


class FormatIncompleteError(DomainError):
    """The exam format does not state a fact the mock needs; nothing is filled in instead."""

    status_code = 422
    code = "format_incomplete"


class InvalidAnswerError(DomainError):
    status_code = 422
    code = "invalid_answer"


def _answered(answer: SessionAnswer | None) -> bool:
    return answer is not None and (
        answer.selected_position is not None
        or answer.typed_answer is not None
        or answer.response is not None
    )


ANSWERED = or_(
    SessionAnswer.selected_position.is_not(None),
    SessionAnswer.typed_answer.is_not(None),
    SessionAnswer.response.is_not(None),
)


def _count(value: object) -> int:
    """A section's question count as stated, or 0 (the format is then listed as incomplete)."""
    return value if isinstance(value, int) and not isinstance(value, bool) and value > 0 else 0


def _plan(practice: PracticeSession) -> list[PlannedSection]:
    """The section plan of a sectionally timed mock (empty for everything else)."""
    raw = (practice.selection or {}).get("sections")
    return [PlannedSection.from_json(p) for p in raw] if isinstance(raw, list) else []


def _canonical(labels: dict[uuid.UUID, list[str]], question: Question) -> list[str]:
    """Labels of the canonical subject of the question's topic (confirmed links only)."""
    return labels.get(question.topic_id, []) if question.topic_id else []


def _eligible(
    include_unverified: bool,
    include_ai: bool = False,
    include_typed: bool = True,
    include_new_formats: bool = False,
) -> Select[Question]:
    """Questions fit for practice: from a source document (AI questions only on request),
    answer known, at least two options, never rejected (unverified only on request), and
    not image-dependent unless the figure was cropped from the paper (then it is shown).
    Formats marked by an answer_spec only reach apps that ask for them: older ones can't show
    them, and neither mocks nor offline packs use them yet."""
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
        Question.translation_of_id.is_(None),  # shown with its question, never asked apart
        or_(
            Question.image_dependent.is_(False),
            select(QuestionFigure.id).where(QuestionFigure.question_id == Question.id).exists(),
        ),
        or_(
            and_(
                Question.format.in_(SINGLE_ANSWER),
                Question.correct_option_position.is_not(None),
                option_count >= 2,
                Question.correct_option_position <= option_count,
            ),
            # Typed-in questions need their answer; mocks leave them out (their marking
            # isn't part of any verified format yet).
            and_(Question.format == TYPED_IN, Question.typed_answer.is_not(None))
            if include_typed
            else false(),
            and_(Question.format.in_(SPEC_FORMATS), Question.answer_spec.is_not(None))
            if include_new_formats
            else false(),
        ),
    )


def _allowed_formats(exam_format: ExamFormat) -> set[str]:
    """The question formats a mock of this format may use, from what the format states."""
    types = set(exam_format.question_types or [])
    allowed = types & set(SPEC_FORMATS)
    if "choice" in types:
        allowed |= set(SINGLE_ANSWER)
    if "typed" in types:
        allowed.add(TYPED_IN)
    return allowed


def _needs_new_formats(exam_format: ExamFormat) -> bool:
    return bool(set(exam_format.question_types or []) & set(SPEC_FORMATS))


def _section_values(exam_format: ExamFormat, key: str) -> dict[str, Any]:
    """What the format's sections state for ``key``, by section name."""
    return {s["subject"]: s[key] for s in exam_format.sections if s.get(key) is not None}


def _cutoff_fields(practice: PracticeSession, section: str, tally: Tally) -> dict[str, object]:
    """A section's cutoff and whether this attempt reached it; nothing without a cutoff."""
    cutoff = (practice.selection.get("cutoffs") or {}).get(section)
    if cutoff is None:
        return {}
    return {"cutoff": float(cutoff), "cleared": float(tally.score) >= float(cutoff)}


def _aware(value: datetime) -> datetime:
    """Device times without a zone are taken as UTC."""
    return value if value.tzinfo else value.replace(tzinfo=UTC)


def _scored(item: SessionItem) -> ScoredItem:
    return ScoredItem(
        position=item.position,
        section=item.section,
        topic_id=str(item.topic_id) if item.topic_id else None,
        correct_position=item.correct_position,
        marks_correct=to_decimal(item.marks_correct),
        marks_wrong=to_decimal(item.marks_wrong),
        typed_answer=item.typed_answer if item.answer_type == "typed" else None,
        format=item.format,
        answer_spec=item.answer_spec,
        marks_unanswered=to_decimal(item.marks_unanswered),
        partial_rule=item.partial_rule,
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
        stmt = _eligible(
            request.include_unverified,
            request.include_ai,
            include_new_formats=request.include_new_formats,
        ).where(visible_question(self._owner_id, include_shared=request.include_shared))
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

    # --- offline practice -------------------------------------------------------------

    def offline_pack(self, limit: int) -> OfflinePack:
        """Practice questions to keep on the device: verified, answer known, visible to the
        learner (own + shared bank), without figures (images aren't stored offline)."""
        stmt = (
            _eligible(include_unverified=False)
            .where(
                visible_question(self._owner_id),
                ~select(QuestionFigure.id)
                .where(QuestionFigure.question_id == Question.id)
                .exists(),
            )
            .options(selectinload(Question.options), selectinload(Question.passage))
            .order_by(Question.updated_at.desc())
            .limit(limit)
        )
        questions = self._session.scalars(stmt).all()
        documents = {q.document_id for q in questions if q.document_id}
        filenames = self._filenames(documents)
        sources = self._shared_sources(
            {q.document_id for q in questions if q.document_id and q.owner_id != self._owner_id}
        )
        items = []
        for q in questions:
            shared = q.owner_id != self._owner_id
            typed = q.answer_type == "typed"
            items.append(
                OfflineQuestion(
                    id=q.id,
                    exam_code=q.exam_code,
                    section=q.section,
                    subject=q.subject,
                    topic_id=q.topic_id,
                    pattern_id=q.pattern_id,
                    stem=q.stem,
                    passage=PassageRead.model_validate(q.passage) if q.passage else None,
                    options=[] if typed else [OptionRead.model_validate(o) for o in q.options],
                    answer_type=q.answer_type,
                    correct_position=None if typed else q.correct_option_position,
                    typed_answer=q.typed_answer if typed else None,
                    typed_answer_numeric=typed and typed_answers.is_numeric(q.typed_answer or ""),
                    explanation=q.explanation,
                    shared=shared,
                    shared_source=sources.get(q.document_id) if shared and q.document_id else None,
                    document_filename=None
                    if shared or not q.document_id
                    else filenames.get(q.document_id),
                    page=q.source_pages[0] if q.source_pages else None,
                    question_number=q.source_question_number,
                )
            )
        return OfflinePack(questions=items, limit=limit, generated_at=self._now())

    def import_offline(self, upload: OfflineSessionUpload) -> SessionRead:
        """Records a practice session done offline. Idempotent by ``client_id``. Every answer
        is checked again against the current question; questions the learner can no longer
        see are left out; times are kept within the session and never in the future."""
        existing = self._session.get(PracticeSession, upload.client_id)
        if existing is not None:
            if existing.owner_id != self._owner_id:
                raise ConflictError("session_exists", "That session id is already used.")
            return self.get(existing.id)
        now = self._now()
        started = min(_aware(upload.started_at), now)
        finished = min(max(_aware(upload.finished_at), started), now)
        ids = {a.question_id for a in upload.items}
        visible = {
            q.id: q
            for q in self._session.scalars(
                _eligible(include_unverified=False)
                .where(Question.id.in_(ids), visible_question(self._owner_id))
                .options(selectinload(Question.options))
            ).all()
        }
        practice = PracticeSession(
            id=upload.client_id,
            owner_id=self._owner_id,
            mode=SessionMode.PRACTICE,
            exam_code=upload.exam_code,
            selection={"offline": True},
            status=SessionStatus.ACTIVE,
            started_at=started,
        )
        position = 0
        for given in upload.items:
            question = visible.get(given.question_id)
            if question is None:
                continue
            position += 1
            item = self._item(position, question, marks_correct=1.0, marks_wrong=0.0)
            practice.items.append(item)
            typed = item.answer_type == "typed"
            answer: int | str | None
            if typed:
                answer = typed_answers.clean(given.typed_answer) if given.typed_answer else None
            elif given.selected_position is not None and given.selected_position <= (
                item.option_count or 0
            ):
                answer = given.selected_position
            else:
                answer = None
            if answer is None:
                continue
            answered = _aware(given.answered_at) if given.answered_at else finished
            practice.answers.append(
                SessionAnswer(
                    position=position,
                    question_id=question.id,
                    selected_position=None if typed else int(answer),
                    typed_answer=str(answer) if typed else None,
                    is_correct=is_correct(_scored(item), answer),
                    client_seq=0,
                    time_spent_ms=given.time_spent_ms,
                    answered_at=min(max(answered, started), finished),
                )
            )
        if position == 0:
            raise NoQuestionsAvailableError(
                "None of these questions can be practised any more (removed or no longer shared)."
            )
        self._session.add(practice)
        self._session.flush()
        self._finalize(practice, reason="offline", at=finished)
        return self.get(practice.id)

    # --- the starter check (no papers of one's own yet) --------------------------------

    def _starter_pool(self, exam_code: str) -> dict[str, list[Question]]:
        """Shared-bank questions whose recorded rights allow the starter check, by subject."""
        allowed = select(ContentRights.document_id).where(
            ContentRights.permitted_uses.contains(["diagnostic"])
        )
        rows = self._session.scalars(
            _eligible(include_unverified=False, include_typed=False)
            .where(
                Question.exam_code == exam_code,
                shared_question(),
                Question.document_id.in_(allowed),
                Question.owner_id != self._owner_id,
            )
            .options(selectinload(Question.options))
        ).all()
        pool: dict[str, list[Question]] = {}
        for q in rows:
            pool.setdefault(q.subject or q.section or "", []).append(q)
        return dict(sorted(pool.items()))

    def starter_check_availability(self, exam_code: str) -> StarterCheckAvailability:
        pool = self._starter_pool(exam_code)
        count = min(STARTER_MAX, sum(min(STARTER_PER_SUBJECT, len(q)) for q in pool.values()))
        return StarterCheckAvailability(
            exam_code=exam_code,
            available_questions=sum(len(q) for q in pool.values()),
            question_count=count,
            subjects=[s for s in pool if s],
        )

    def start_starter_check(self, exam_code: str) -> SessionRead:
        """A short check across subjects for a learner without papers: untimed, answers
        hidden until submitted; its results feed the same progress and study plan."""
        pool = self._starter_pool(exam_code)
        if not pool:
            raise NoQuestionsAvailableError("No starter check is available for this exam yet.")
        seed = random.SystemRandom().randrange(2**31)
        rng = random.Random(seed)  # noqa: S311 - question sampling, recorded for reproducibility
        chosen: list[Question] = []
        for questions in pool.values():
            take = min(STARTER_PER_SUBJECT, len(questions), STARTER_MAX - len(chosen))
            chosen.extend(rng.sample(questions, take))
        check = PracticeSession(
            owner_id=self._owner_id,
            mode=SessionMode.DIAGNOSTIC,
            exam_code=exam_code,
            selection={"starter_check": True, "seed": seed},
            status=SessionStatus.ACTIVE,
            started_at=self._now(),
        )
        check.items = [
            self._item(position, q, marks_correct=1.0, marks_wrong=0.0)
            for position, q in enumerate(chosen, start=1)
        ]
        self._session.add(check)
        self._session.commit()
        return self.get(check.id)

    def mock_availability(self, exam_code: str | None) -> list[MockAvailability]:
        """Verified formats in effect today (drafts and retired versions are not offered)."""
        today = self._now().date()
        return [self._availability(f)[0] for f in mock_formats(self._session, exam_code, today)]

    def start_mock(self, request: MockCreate) -> SessionRead:
        exam_format = self._session.scalars(
            select(ExamFormat).where(ExamFormat.code == request.exam_format_code)
        ).first()
        if exam_format is None or not is_in_effect(exam_format, self._now().date()):
            raise InvalidReferenceError(f"Unknown paper format '{request.exam_format_code}'.")
        if _needs_new_formats(exam_format) and not request.include_new_formats:
            raise InvalidReferenceError("This paper format needs a newer version of the app.")
        availability, pools = self._availability(exam_format)
        if availability.format_problems:
            raise FormatIncompleteError(
                "This paper format is incomplete: " + " ".join(availability.format_problems)
            )
        if not availability.available:
            short = [
                f"{s.subject}: {s.available} of {s.needed}"
                for s in availability.sections
                if s.available < s.needed
            ]
            raise NotEnoughQuestionsError(
                "Not enough reviewed questions for this mock test (" + "; ".join(short) + ")."
            )
        # format_problems() has checked these; nothing below falls back to a default.
        duration = exam_format.duration_minutes
        if duration is None:  # pragma: no cover - guarded above
            raise FormatIncompleteError("This paper format is incomplete.")

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
            deadline_at=started + timedelta(minutes=duration),
        )
        position = 0
        items: list[SessionItem] = []
        plan: list[PlannedSection] = []
        for section, pool in zip(exam_format.sections, pools, strict=True):
            needed = int(section["questions"])
            marking = section_marking(
                section,
                negative_marks_per_wrong=exam_format.negative_marks_per_wrong,
                penalty_fraction=exam_format.penalty_fraction,
            )
            first = position + 1
            for question in rng.sample(pool, needed):
                position += 1
                item = self._item(
                    position,
                    question,
                    marks_correct=marking.marks_correct,
                    marks_wrong=marking.marks_wrong,
                )
                item.marks_unanswered = marking.marks_unanswered
                item.partial_rule = dict(marking.partial) if marking.partial else None
                item.section = section["subject"]
                items.append(item)
            if exam_format.sectional_timing:
                plan.append(
                    PlannedSection(
                        name=str(section["subject"]),
                        first_position=first,
                        last_position=position,
                        minutes=int(section["timer_minutes"]),
                    )
                )
        mock.items = items
        limits = _section_values(exam_format, "attempt_limit")
        cutoffs = _section_values(exam_format, "cutoff")
        if limits or cutoffs:
            # Copied into the attempt, like the marks.
            mock.selection = {**mock.selection, "attempt_limits": limits, "cutoffs": cutoffs}
        if plan:
            # Copied into the attempt: later format changes never change it.
            mock.selection = {**mock.selection, "sections": [p.to_json() for p in plan]}
            mock.current_section = 0
            mock.section_started_at = started
        self._session.add(mock)
        self._session.commit()
        return self.get(mock.id)

    def _availability(
        self, exam_format: ExamFormat
    ) -> tuple[MockAvailability, list[list[Question]]]:
        allowed = _allowed_formats(exam_format)
        candidates = [
            q
            for q in self._session.scalars(
                _eligible(
                    include_unverified=False,
                    include_typed=TYPED_IN in allowed,
                    include_new_formats=_needs_new_formats(exam_format),
                ).where(
                    Question.exam_code == exam_format.exam_code,
                    visible_question(self._owner_id),
                )
            ).all()
            if q.format in allowed
        ]
        problems = format_problems(
            sections=exam_format.sections,
            total_questions=exam_format.total_questions,
            duration_minutes=exam_format.duration_minutes,
            negative_marks_per_wrong=exam_format.negative_marks_per_wrong,
            penalty_fraction=exam_format.penalty_fraction,
        )
        canonical = subject_labels_by_topic(
            self._session, {q.topic_id for q in candidates if q.topic_id}
        )
        pools: list[list[Question]] = []
        sections: list[SectionAvailability] = []
        for section in exam_format.sections or []:
            subject = str(section.get("subject") or "")
            pool = [
                q
                for q in candidates
                if same_subject(q.subject or "", subject)
                or same_subject(q.section or "", subject)
                or any(same_subject(label, subject) for label in _canonical(canonical, q))
            ]
            if section.get("formats"):
                pool = [q for q in pool if q.format in section["formats"]]
            pools.append(pool)
            sections.append(
                SectionAvailability(
                    subject=subject, needed=_count(section.get("questions")), available=len(pool)
                )
            )
        availability = MockAvailability(
            exam_format_code=exam_format.code,
            exam_code=exam_format.exam_code,
            name=exam_format.name,
            available=not problems and all(s.available >= s.needed for s in sections),
            format_problems=problems,
            total_questions=exam_format.total_questions,
            duration_minutes=exam_format.duration_minutes,
            negative_marks_per_wrong=exam_format.negative_marks_per_wrong,
            penalty_fraction=exam_format.penalty_fraction,
            sections=sections,
            section_counts_indicative=exam_format.section_counts_indicative,
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
            format=question.format,
            answer_spec=question.answer_spec,
            marks_correct=marks_correct,
            marks_wrong=marks_wrong,
            marks_unanswered=0.0,
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
        plan = _plan(practice)
        if plan and section_of(plan, position) != practice.current_section:
            raise ConflictError(
                "section_closed", "This question's section is not open (sections are timed)."
            )
        typed = item.answer_type == "typed"
        by_response = item.format in RESPONSE_FORMATS
        if by_response and (update.selected_position or update.typed_answer):
            raise InvalidAnswerError("This question takes a fuller answer.")
        if update.response is not None and (
            not by_response
            or not valid_response(
                item.format, item.answer_spec or {}, update.response, item.option_count
            )
        ):
            raise InvalidAnswerError("That answer doesn't fit this question.")
        if typed and update.selected_position is not None:
            raise InvalidAnswerError("This question takes a typed answer.")
        if not typed and update.typed_answer is not None:
            raise InvalidAnswerError("This question takes an option.")
        if update.selected_position is not None and update.selected_position > item.option_count:
            raise InvalidAnswerError("That option does not exist for this question.")

        existing = next((a for a in practice.answers if a.position == position), None)
        self._check_attempt_limit(practice, item, existing, update)
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
            existing.response = update.response
            given: Answer | None = (
                update.response
                if by_response
                else existing.typed_answer
                if typed
                else existing.selected_position
            )
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
            response=existing.response,
            applied=applied,
            feedback=self._feedback(practice, item, existing),
        )

    def submit(self, session_id: uuid.UUID, *, reason: str = "user") -> SessionRead:
        practice = self._load(session_id)
        self._expire_if_due(practice)
        if practice.status == SessionStatus.ACTIVE:
            self._finalize(practice, reason=reason)
        return self.get(session_id)

    def finish_section(self, session_id: uuid.UUID, from_section: int) -> SessionRead:
        """Closes the open section early (sectionally timed mocks); the next one opens now.
        Closing the last section submits the mock. Does nothing unless ``from_section`` is
        still the open section, so a retried request can't skip a section."""
        practice = self._load(session_id)
        self._expire_if_due(practice)
        plan = _plan(practice)
        if not plan:
            raise InvalidAnswerError("This test has no timed sections.")
        if practice.status == SessionStatus.ACTIVE and practice.current_section == from_section:
            clock = finish_early(plan, self._clock(practice), self._now())
            practice.current_section, practice.section_started_at = clock.current, clock.started_at
            if clock.finished(plan):
                self._finalize(practice, reason="user")
            else:
                self._session.commit()
        return self.get(session_id)

    def _expire_if_due(self, practice: PracticeSession) -> None:
        if practice.status != SessionStatus.ACTIVE:
            return
        plan = _plan(practice)
        if plan:
            before = self._clock(practice)
            clock = advance(plan, before, self._now())
            if clock != before:
                practice.current_section = clock.current
                practice.section_started_at = clock.started_at
                if clock.finished(plan):
                    # The last section's own time ran out: that is when the mock ended.
                    self._finalize(practice, reason="time_up", at=clock.started_at)
                    return
                self._session.commit()
        if practice.deadline_at is not None and self._now() >= practice.deadline_at:
            self._finalize(practice, reason="time_up")

    @staticmethod
    def _clock(practice: PracticeSession) -> SectionClock:
        return SectionClock(
            practice.current_section or 0, practice.section_started_at or practice.started_at
        )

    @staticmethod
    def _check_attempt_limit(
        practice: PracticeSession,
        item: SessionItem,
        existing: SessionAnswer | None,
        update: AnswerUpdate,
    ) -> None:
        """ "Attempt any n of these": a new answer past the limit is refused. Changing or
        clearing an answer is always fine."""
        limit = (practice.selection.get("attempt_limits") or {}).get(item.section or "")
        clearing = (
            update.selected_position is None
            and update.typed_answer is None
            and update.response is None
        )
        if limit is None or clearing or _answered(existing):
            return
        section = {i.position for i in practice.items if i.section == item.section}
        attempted = sum(a.position in section and _answered(a) for a in practice.answers)
        if attempted >= int(limit):
            raise ConflictError(
                "section_limit", f"Only {limit} questions can be attempted in this section."
            )

    def _finalize(
        self, practice: PracticeSession, *, reason: str, at: datetime | None = None
    ) -> None:
        now = at or self._now()
        if reason == "time_up" and practice.deadline_at is not None:
            now = min(now, practice.deadline_at)
        selections: dict[int, Answer | None] = {
            a.position: a.response
            if a.response is not None
            else a.typed_answer
            if a.typed_answer is not None
            else a.selected_position
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
            "sections": [
                {"name": name, **tally_json(t), **_cutoff_fields(practice, name, t)}
                for name, t in scored.sections.items()
            ],
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
        if practice.mode == SessionMode.DIAGNOSTIC:
            return STARTER_MARKING_NOTE
        exam_format = self._session.get(ExamFormat, practice.exam_format_id)
        if exam_format is None:
            return "Marking from the exam format used when this test started."
        parts = [
            f"{s['subject']}: {s['questions']} questions, {s.get('max_marks', '?')} marks"
            for s in exam_format.sections
        ]
        negative = exam_format.negative_marks_per_wrong
        fraction = exam_format.penalty_fraction
        timers = {int(s["timer_minutes"]) for s in exam_format.sections if s.get("timer_minutes")}
        minutes = ", ".join(map(str, sorted(timers)))
        if _plan(practice):
            sectional = (
                f" Each section had its own timer ({minutes} min each, from the format) and the"
                " sections were taken in order. In this mock a section could be finished early;"
                " a closed section could not be reopened."
            )
        elif timers:
            # Mocks started before sectional timers were enforced kept one overall timer.
            sectional = (
                f" The exam times each section separately ({minutes} min each); this mock used"
                " one overall timer."
            )
        else:
            sectional = ""
        indicative = (
            " The notice gives this section split as only indicative: real papers may vary."
            if exam_format.section_counts_indicative
            else ""
        )
        return (
            f"{exam_format.name}. "
            + "; ".join(parts)
            + (
                f". Wrong answer: minus {fraction:.2f} of the question's marks."
                if fraction
                else f". Wrong answer: -{negative:.2f}."
                if negative
                else ". No negative marking."
            )
            + sectional
            + indicative
            + f" Source: {exam_format.source_reference}."
        )

    # --- reading --------------------------------------------------------------------

    def get(self, session_id: uuid.UUID) -> SessionRead:
        practice = self._load(session_id)
        self._expire_if_due(practice)
        now = self._now()
        questions = self._questions({i.question_id for i in practice.items if i.question_id})
        translations = self._translations(set(questions))
        filenames = self._filenames({q.document_id for q in questions.values() if q.document_id})
        sources = self._shared_sources(
            {
                q.document_id
                for q in questions.values()
                if q.document_id and q.owner_id != self._owner_id
            }
        )
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
        plan = _plan(practice)
        active = practice.status == SessionStatus.ACTIVE
        open_section = practice.current_section if plan and active else None

        items: list[SessionItemRead] = []
        for item in practice.items:
            question = questions.get(item.question_id) if item.question_id else None
            index = section_of(plan, item.position) if plan else None
            if active and open_section is not None and index is not None and index > open_section:
                question = None  # a section that hasn't opened yet: nothing to peek at
            answer = answers.get(item.position)
            shared = question is not None and question.owner_id != self._owner_id
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
                    format=item.format,
                    format_data=public_data(item.format, item.answer_spec),
                    translations=translations.get(item.question_id, []) if item.question_id else [],
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
                        if question and question.document_id and not shared
                        else None,
                        shared_source=sources.get(question.document_id)
                        if question and question.document_id and shared
                        else None,
                        page=question.source_pages[0]
                        if question and question.source_pages
                        else None,
                        question_number=question.source_question_number if question else None,
                    ),
                    bookmarked=bool(item.question_id and item.question_id in bookmarks),
                    shared=shared,
                    selected_position=answer.selected_position if answer else None,
                    answer_type=item.answer_type,
                    typed_answer=answer.typed_answer if answer else None,
                    response=answer.response if answer else None,
                    typed_answer_numeric=item.format == "numeric"
                    or (
                        bool(item.typed_answer)
                        and typed_answers.is_numeric(item.typed_answer or "")
                    ),
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
            sections=[SectionRead(**p.to_json()) for p in plan],
            current_section=practice.current_section if plan else None,
            section_deadline_at=self._clock(practice).deadline(plan) if plan and active else None,
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
        visible = select(Question.id).where(
            Question.id == question_id, visible_question(self._owner_id)
        )
        if self._session.scalar(visible) is None:
            raise NotFoundError("Question not found.")
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
            correct_spec=item.answer_spec,
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

    def _translations(self, ids: set[uuid.UUID]) -> dict[uuid.UUID, list[TranslationRead]]:
        """Linked translations by question. No answers: a translation shares its question's."""
        found: dict[uuid.UUID, list[TranslationRead]] = {}
        if not ids:
            return found
        rows = self._session.scalars(
            select(Question)
            .where(Question.translation_of_id.in_(ids), visible_question(self._owner_id))
            .options(selectinload(Question.options))
            .order_by(Question.language)
        ).all()
        for row in rows:
            if row.translation_of_id is not None:
                found.setdefault(row.translation_of_id, []).append(
                    TranslationRead(
                        language=row.language,
                        stem=row.stem,
                        options=[o.text for o in row.options],
                    )
                )
        return found

    def _filenames(self, ids: set[uuid.UUID]) -> dict[uuid.UUID, str]:
        if not ids:
            return {}
        rows = self._session.execute(
            select(Document.id, Document.original_filename).where(Document.id.in_(ids))
        ).all()
        return {r[0]: r[1] for r in rows}

    def _shared_sources(self, ids: set[uuid.UUID]) -> dict[uuid.UUID, str]:
        if not ids:
            return {}
        rows = self._session.execute(
            select(Document.id, Document.shared_source).where(
                Document.id.in_(ids), Document.shared_at.is_not(None)
            )
        ).all()
        return {r[0]: r[1] or "" for r in rows}

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
            # Results saved before a field existed leave it to its default.
            **{k: total[k] for k in TallyRead.model_fields if k in total},
            time_taken_seconds=data["time_taken_seconds"],
            marking_note=data["marking_note"],
            sections=[SectionResult(**s) for s in data["sections"]],
            topics=[TopicResult(**t) for t in data["topics"]],
        )
