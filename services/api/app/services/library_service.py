"""The curated question library.

Content staff write, solve and approve here; learners search it and take chapter packs. A question
reaches learners only through ``library_question()``: approved, with rights settled. Learners'
imports never enter it, because staff can only add questions from their own account.
"""

import base64
import uuid
from collections import Counter, defaultdict
from collections.abc import Sequence
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import ColumnElement, and_, func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.domain import challenge_ladder as ladder
from app.domain import library, typed_answers
from app.domain.challenge_ladder import NUMBERS
from app.domain.errors import ConflictError, InvalidReferenceError, NotFoundError
from app.domain.ladder_rules import library_level
from app.domain.question_formats import SINGLE_ANSWER, SPEC_FORMATS, is_correct
from app.domain.taxonomy import slug
from app.domain.typed_answers import is_numeric
from app.models.content import ContentReport
from app.models.ladder import GeneratedReview
from app.models.library import LIBRARY_SEQ, LibraryEntry, LibraryVersion
from app.models.practice import SessionAnswer, SessionItem
from app.models.question import (
    Question,
    QuestionFigure,
    QuestionOption,
    QuestionOrigin,
    QuestionPattern,
    Topic,
    TopicStatus,
    VerificationStatus,
)
from app.models.user import User
from app.repositories.exam_repository import ExamRepository
from app.schemas.library import (
    CorrectionResult,
    GeneratedReviewRead,
    LibraryCorrection,
    LibraryCreate,
    LibraryEntryRead,
    LibraryHit,
    LibraryPage,
    LibraryQuestionRead,
    LibraryReportRead,
    LibraryRights,
    LibrarySolve,
    LibraryVersionRead,
    PackDelta,
    PackFigure,
    PackQuestion,
    PackRead,
    SolveResult,
)
from app.schemas.question import FigureRead, OptionRead, PassageRead
from app.services.chapter_map import unit_topics
from app.services.content import audit, resolve
from app.services.exam_formats import mock_formats
from app.services.practice_service import apply_final_key
from app.services.question_history import add_first_revision, current_snapshot, record_edit
from app.services.shared_bank import library_question

OTHER_PACK = "other"
# As the offline pack: formats marked by an answer_spec stay online.
PACK_FORMATS = ("single_correct", "statement", "assertion_reason", "true_false", "typed_in")


def bump_seq(session: Session, entry: LibraryEntry) -> None:
    """Devices pick up a change by this number rising."""
    entry.seq = session.scalar(select(LIBRARY_SEQ.next_value())) or entry.seq


def _read(entry: LibraryEntry) -> LibraryEntryRead:
    return LibraryEntryRead.model_validate(entry)


class LibraryEditor:
    """Content staff. Every action names who took it."""

    def __init__(self, session: Session, user: User) -> None:
        self._session = session
        self._user = user

    def _entry(self, question_id: uuid.UUID) -> LibraryEntry:
        entry = self._session.get(LibraryEntry, question_id)
        if entry is None:
            raise NotFoundError("Library question not found.")
        return entry

    def _version(self, entry: LibraryEntry, question: Question, reason: str) -> None:
        self._session.add(
            LibraryVersion(
                question_id=entry.question_id,
                version=entry.version,
                snapshot=current_snapshot(question),
                changed_by=self._user.email,
                reason=reason[:500],
            )
        )

    def question(self, question_id: uuid.UUID) -> LibraryQuestionRead:
        entry = self._entry(question_id)
        question = self._session.get(Question, question_id)
        assert question is not None  # noqa: S101 - an entry's question exists (foreign key)
        hidden = entry.status == library.DRAFT and entry.author_id != self._user.id
        return LibraryQuestionRead(
            question_id=question.id,
            exam_code=question.exam_code,
            stem=question.stem,
            format=question.format,
            options=[OptionRead.model_validate(o) for o in question.options],
            figures=[FigureRead.model_validate(f) for f in question.figures],
            correct_position=None if hidden else question.correct_option_position,
            typed_answer=None if hidden else question.typed_answer,
            explanation=None if hidden else question.explanation,
        )

    def figure(self, question_id: uuid.UUID, figure_id: uuid.UUID) -> QuestionFigure:
        self._entry(question_id)
        figure = self._session.get(QuestionFigure, figure_id)
        if figure is None or figure.question_id != question_id:
            raise NotFoundError("Figure not found.")
        return figure

    def queue(self, status: str | None) -> list[LibraryEntryRead]:
        stmt = select(LibraryEntry).order_by(LibraryEntry.created_at).limit(200)
        if status:
            stmt = stmt.where(LibraryEntry.status == status)
        return [_read(e) for e in self._session.scalars(stmt)]

    def create(self, data: LibraryCreate) -> LibraryEntryRead:
        question = self._existing(data) if data.question_id else self._written(data)
        if self._session.get(LibraryEntry, question.id) is not None:
            raise ConflictError("already_in_library", "This question is already in the library.")
        entry = LibraryEntry(
            question_id=question.id,
            source_type=data.source_type,
            rights_status=data.rights_status,
            rights_note=data.rights_note,
            author_id=self._user.id,
            author_name=self._user.email,
            status=library.DRAFT,
            exam_year=data.exam_year,
            difficulty=data.difficulty,
        )
        self._session.add(entry)
        self._session.flush()
        self._version(entry, question, "Added to the library")
        self._session.commit()
        return _read(entry)

    def _existing(self, data: LibraryCreate) -> Question:
        """Staff add their own imported questions only, so no learner's paper can enter."""
        question = self._session.get(Question, data.question_id)
        if question is None or question.owner_id != self._user.id:
            raise NotFoundError("Question not found.")
        if question.origin == QuestionOrigin.AI and data.source_type != "original_ai_verified":
            raise InvalidReferenceError("An AI question can only be original_ai_verified.")
        if data.source_type == "official_pyq" and question.origin != QuestionOrigin.SOURCE:
            raise InvalidReferenceError("Only a question from a paper can be official_pyq.")
        return question

    def _written(self, data: LibraryCreate) -> Question:
        if data.source_type == "official_pyq":
            raise InvalidReferenceError("An official question must come from its paper.")
        if not data.exam_code or not data.stem or len(data.options) < 2:
            raise InvalidReferenceError("Give the exam, the question and its options.")
        if data.correct_option_position is None:
            raise InvalidReferenceError("Give the correct option.")
        if data.correct_option_position > len(data.options):
            raise InvalidReferenceError("That option doesn't exist.")
        if ExamRepository(self._session).get_visible(data.exam_code, self._user.id) is None:
            raise InvalidReferenceError("Unknown exam.")
        topic = self._session.get(Topic, data.topic_id) if data.topic_id else None
        question = Question(
            origin=QuestionOrigin.LIBRARY,
            owner_id=self._user.id,
            exam_code=data.exam_code,
            stem=data.stem,
            language=data.language,
            subject=topic.subject if topic else None,
            topic_id=topic.id if topic else None,
            topic_status=TopicStatus.CONFIRMED if topic else TopicStatus.UNASSIGNED,
            correct_option_position=data.correct_option_position,
            explanation=data.explanation,
            answer_source="manual",
            verification_status=VerificationStatus.UNVERIFIED,
        )
        question.options = [
            QuestionOption(position=i, label=o.label, text=o.text)
            for i, o in enumerate(data.options, start=1)
        ]
        add_first_revision(question, "generated", "reviewer")
        self._session.add(question)
        self._session.flush()
        return question

    def solve(self, question_id: uuid.UUID, data: LibrarySolve) -> SolveResult:
        """A second person answers without seeing the key. Agreement moves it on; a disagreement
        leaves it a draft, so someone looks again."""
        entry = self._entry(question_id)
        problem = library.solve_problem(
            status=entry.status, author_id=entry.author_id, solver_id=self._user.id
        )
        if problem:
            raise ConflictError("library_solve_refused", problem)
        question = self._session.get(Question, question_id)
        assert question is not None  # noqa: S101 - an entry's question exists (foreign key)
        agrees = _matches(question, data)
        if agrees:
            entry.status = library.SOLVED
            entry.solved_by_id = self._user.id
            entry.solved_by_name = self._user.email
        audit(
            self._session,
            self._user.email,
            "library_solved" if agrees else "library_solve_differs",
            "question",
            question_id,
            "",
        )
        self._session.commit()
        return SolveResult(agrees=agrees, entry=_read(entry))

    def approve(self, question_id: uuid.UUID) -> LibraryEntryRead:
        entry = self._entry(question_id)
        problem = library.approve_problem(
            status=entry.status, author_id=entry.author_id, approver_id=self._user.id
        )
        if problem:
            raise ConflictError("library_approve_refused", problem)
        question = self._session.get(Question, question_id)
        assert question is not None  # noqa: S101 - an entry's question exists (foreign key)
        self._refuse_private_labels(question)
        entry.status = library.APPROVED
        entry.approved_by_id = self._user.id
        entry.approved_by_name = self._user.email
        question.verification_status = VerificationStatus.VERIFIED
        question.verified_at = datetime.now(UTC)
        bump_seq(self._session, entry)
        audit(self._session, self._user.email, "library_approved", "question", question_id, "")
        self._session.commit()
        return _read(entry)

    def _refuse_private_labels(self, question: Question) -> None:
        """Learners couldn't see a topic or model private to the author."""
        topic = self._session.get(Topic, question.topic_id) if question.topic_id else None
        pattern = (
            self._session.get(QuestionPattern, question.pattern_id) if question.pattern_id else None
        )
        if (topic and topic.owner_id) or (pattern and pattern.owner_id):
            raise ConflictError(
                "library_private_label", "Give it a shared topic and model before approving."
            )

    def set_rights(self, question_id: uuid.UUID, data: LibraryRights) -> LibraryEntryRead:
        """Rights are a decision someone answers for, so a note is required."""
        entry = self._entry(question_id)
        entry.rights_status = data.rights_status
        entry.rights_note = data.rights_note
        bump_seq(self._session, entry)
        audit(
            self._session,
            self._user.email,
            "library_rights",
            "question",
            question_id,
            f"{data.rights_status}: {data.rights_note}",
        )
        self._session.commit()
        return _read(entry)

    def withdraw(self, question_id: uuid.UUID, reason: str) -> LibraryEntryRead:
        entry = self._entry(question_id)
        entry.status = library.WITHDRAWN
        bump_seq(self._session, entry)
        audit(self._session, self._user.email, "library_withdrawn", "question", question_id, reason)
        self._session.commit()
        return _read(entry)

    def correct(self, question_id: uuid.UUID, data: LibraryCorrection) -> CorrectionResult:
        """A new version, with its reason. Attempts are marked again against it."""
        entry = self._entry(question_id)
        question = self._session.get(Question, question_id)
        assert question is not None  # noqa: S101 - an entry's question exists (foreign key)
        before = current_snapshot(question)
        key_before = (question.correct_option_position, question.typed_answer, question.answer_spec)
        if data.stem is not None:
            question.stem = data.stem
        if data.explanation is not None:
            question.explanation = data.explanation
        if data.correct_option_position is not None:
            if data.correct_option_position > len(question.options):
                raise InvalidReferenceError("That option doesn't exist.")
            question.correct_option_position = data.correct_option_position
        if data.typed_answer is not None:
            question.typed_answer = data.typed_answer
        if data.answer_spec is not None:
            question.answer_spec = data.answer_spec
        if key_before != (
            question.correct_option_position,
            question.typed_answer,
            question.answer_spec,
        ):
            question.key_changed = True
        record_edit(self._session, question, before)
        entry.version += 1
        self._version(entry, question, data.reason)
        bump_seq(self._session, entry)
        self._session.flush()
        remarked = apply_final_key(self._session, question)
        if data.report_id is not None:
            resolve(
                self._session,
                data.report_id,
                upheld=True,
                note=f"Corrected in version {entry.version}",
                actor=self._user.email,
            )
        self._session.commit()
        return CorrectionResult(entry=_read(entry), sessions_remarked=remarked)

    def versions(self, question_id: uuid.UUID) -> list[LibraryVersionRead]:
        self._entry(question_id)
        rows = self._session.scalars(
            select(LibraryVersion)
            .where(LibraryVersion.question_id == question_id)
            .order_by(LibraryVersion.version)
        )
        return [LibraryVersionRead.model_validate(r) for r in rows]

    def reports(self) -> list[LibraryReportRead]:
        """The "Report a mistake" queue."""
        rows = self._session.scalars(
            select(ContentReport)
            .where(
                ContentReport.status == "open",
                ContentReport.question_id.in_(select(LibraryEntry.question_id)),
            )
            .order_by(ContentReport.created_at)
            .limit(200)
        )
        return [
            LibraryReportRead(id=r.id, question_id=r.question_id, kind=r.kind, text=r.text)
            for r in rows
        ]

    def dismiss_report(self, report_id: uuid.UUID, note: str) -> None:
        resolve(self._session, report_id, upheld=False, note=note, actor=self._user.email)
        self._session.commit()


def _matches(question: Question, data: LibrarySolve) -> bool:
    if question.format in SINGLE_ANSWER:
        return data.selected_position == question.correct_option_position
    if question.format in SPEC_FORMATS and question.answer_spec is not None:
        answer: object = data.response if data.response is not None else data.typed_answer
        return answer is not None and is_correct(question.format, question.answer_spec, answer)
    if question.typed_answer is not None and data.typed_answer is not None:
        return typed_answers.matches(question.typed_answer, data.typed_answer)
    return False


class GeneratedQueue:
    """Generated questions waiting for a person. Accepting makes a library draft, which then goes
    through the same second solve and approval as any other; rights start pending."""

    def __init__(self, session: Session, user: User) -> None:
        self._session = session
        self._user = user

    def pending(self) -> list[GeneratedReviewRead]:
        rows = self._session.scalars(
            select(GeneratedReview)
            .where(GeneratedReview.status == "pending")
            .order_by(GeneratedReview.created_at)
            .limit(200)
        )
        return [GeneratedReviewRead.model_validate(r) for r in rows]

    def _open(self, review_id: uuid.UUID) -> GeneratedReview:
        review = self._session.get(GeneratedReview, review_id)
        if review is None:
            raise NotFoundError("Question not found.")
        if review.status != "pending":
            raise ConflictError("review_decided", "This question has already been decided.")
        return review

    def _decide(self, review: GeneratedReview, status: str, note: str | None) -> None:
        review.status = status
        review.review_note = note
        review.reviewed_by = self._user.email
        review.reviewed_at = datetime.now(UTC)

    def accept(self, review_id: uuid.UUID) -> LibraryEntryRead:
        review = self._open(review_id)
        typed = review.format in NUMBERS
        question = Question(
            origin=QuestionOrigin.LIBRARY,
            owner_id=self._user.id,
            exam_code=review.exam_code,
            stem=review.stem,
            language="en",
            subject=review.subject,
            topic_id=review.topic_id,
            topic_status=TopicStatus.CONFIRMED if review.topic_id else TopicStatus.UNASSIGNED,
            answer_type="typed" if typed else "choice",
            answer_source="manual",
            verification_status=VerificationStatus.UNVERIFIED,
        )
        question.format = review.format
        question.answer_spec = review.answer_spec
        if review.answer_index is not None:
            question.correct_option_position = review.answer_index + 1
        question.explanation = "\n".join(review.solution)
        question.options = [
            QuestionOption(position=i, label=chr(64 + i), text=text)
            for i, text in enumerate(review.options, start=1)
        ]
        add_first_revision(question, "generated", "ai")
        self._session.add(question)
        self._session.flush()
        entry = LibraryEntry(
            question_id=question.id,
            source_type="original_ai_verified",
            rights_status="pending",
            author_id=self._user.id,
            author_name=self._user.email,
            status=library.DRAFT,
            difficulty=library_level(review.difficulty),
        )
        self._session.add(entry)
        self._session.flush()
        self._session.add(
            LibraryVersion(
                question_id=question.id,
                version=1,
                snapshot=current_snapshot(question),
                changed_by=self._user.email,
                reason="Accepted from the generated queue",
            )
        )
        review.question_id = question.id
        self._decide(review, "accepted", None)
        self._session.commit()
        return _read(entry)

    def reject(self, review_id: uuid.UUID, reason: str) -> None:
        self._decide(self._open(review_id), "rejected", reason)
        self._session.commit()


class LibraryReader:
    """What learners get: search, and chapter packs for offline use."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def search(
        self,
        *,
        exam: str,
        unit: str | None = None,
        topic_id: uuid.UUID | None = None,
        pattern_id: uuid.UUID | None = None,
        format_name: str | None = None,
        year: int | None = None,
        difficulty: str | None = None,
        text: str | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> LibraryPage:
        conditions: list[ColumnElement[bool]] = [
            library_question(),
            Question.exam_code == exam,
            Question.translation_of_id.is_(None),
        ]
        if unit:
            units = unit_topics(self._session, exam)
            conditions.append(Question.topic_id.in_([t for t, u in units.items() if u[0] == unit]))
        if topic_id:
            conditions.append(Question.topic_id == topic_id)
        if pattern_id:
            conditions.append(Question.pattern_id == pattern_id)
        if format_name:
            conditions.append(Question.format == format_name)
        if year:
            conditions.append(LibraryEntry.exam_year == year)
        if difficulty:
            conditions.append(
                func.coalesce(LibraryEntry.observed_difficulty, LibraryEntry.difficulty)
                == difficulty
            )
        if text:
            like = f"%{text.replace('%', '').replace('_', '')}%"
            conditions.append(or_(Question.stem.ilike(like), Question.transcript.ilike(like)))
        joined = select(Question, LibraryEntry).join(
            LibraryEntry, LibraryEntry.question_id == Question.id
        )
        total = self._session.scalar(
            select(func.count())
            .select_from(Question)
            .join(LibraryEntry, LibraryEntry.question_id == Question.id)
            .where(and_(*conditions))
        )
        rows = self._session.execute(
            joined.where(and_(*conditions))
            .options(selectinload(Question.topic))
            .order_by(LibraryEntry.exam_year.desc().nulls_last(), Question.id)
            .limit(limit)
            .offset(offset)
        ).all()
        return LibraryPage(items=[_hit(q, e) for q, e in rows], total=total or 0)

    def _pack_rows(self, exam: str) -> list[tuple[Question, LibraryEntry]]:
        rows = self._session.execute(
            select(Question, LibraryEntry)
            .join(LibraryEntry, LibraryEntry.question_id == Question.id)
            .where(
                library_question(),
                Question.exam_code == exam,
                Question.format.in_(PACK_FORMATS),
                Question.key_outcome == "one",
                Question.translation_of_id.is_(None),
            )
            .options(selectinload(Question.options), selectinload(Question.passage))
        ).all()
        return [(q, e) for q, e in rows]

    def packs(self, exam: str) -> list[PackRead]:
        """Every chapter that has held a public question. One left empty stays listed, with its
        number raised, so a device holding it learns its questions have gone."""
        units = unit_topics(self._session, exam)

        def place(topic_id: uuid.UUID | None) -> tuple[str, str]:
            return units.get(topic_id, (OTHER_PACK, "")) if topic_id else (OTHER_PACK, "")

        counts = Counter(slug(" ".join(place(q.topic_id)[::-1])) for q, _ in self._pack_rows(exam))
        rows = self._session.execute(
            select(Question.topic_id, LibraryEntry.seq)
            .join(LibraryEntry, LibraryEntry.question_id == Question.id)
            .where(
                Question.exam_code == exam,
                LibraryEntry.status.in_((library.APPROVED, library.WITHDRAWN)),
            )
        ).all()
        newest: dict[str, int] = {}
        names: dict[str, tuple[str, str]] = {}
        for topic_id, seq in rows:
            unit, subject = place(topic_id)
            key = slug(f"{subject} {unit}")
            newest[key] = max(newest.get(key, 0), seq)
            names[key] = (unit, subject)
        return [
            PackRead(
                key=key,
                name=names[key][0],
                subject=names[key][1],
                questions=counts[key],
                seq=newest[key],
            )
            for key in sorted(newest)
        ]

    def pack(self, exam: str, key: str, since: int) -> PackDelta:
        """What changed in a chapter after [since]: questions to save and ids to remove."""
        units = unit_topics(self._session, exam)

        def key_of(topic_id: uuid.UUID | None) -> str:
            unit, subject = units.get(topic_id, (OTHER_PACK, "")) if topic_id else (OTHER_PACK, "")
            return slug(f"{subject} {unit}")

        rows = [(q, e) for q, e in self._pack_rows(exam) if key_of(q.topic_id) == key]
        changed = [(q, e) for q, e in rows if e.seq > since]
        shown = {q.id for q, _ in rows}
        gone = self._session.execute(
            select(Question.id, Question.topic_id)
            .join(LibraryEntry, LibraryEntry.question_id == Question.id)
            .where(Question.exam_code == exam, LibraryEntry.seq > since)
        ).all()
        removed = [qid for qid, topic in gone if qid not in shown and key_of(topic) == key]
        newest = self._session.scalar(
            select(func.max(LibraryEntry.seq))
            .join(Question, Question.id == LibraryEntry.question_id)
            .where(Question.exam_code == exam)
        )
        figures = self._session.scalars(
            select(QuestionFigure).where(QuestionFigure.question_id.in_([q.id for q, _ in changed]))
        ).all()
        by_question: dict[uuid.UUID, list[QuestionFigure]] = defaultdict(list)
        for figure in figures:
            by_question[figure.question_id].append(figure)
        return PackDelta(
            seq=newest or since,
            questions=[_pack_question(q, e, by_question[q.id]) for q, e in changed],
            figures=[
                PackFigure(
                    id=f.id,
                    question_id=f.question_id,
                    data=base64.b64encode(f.data).decode("ascii"),
                )
                for f in figures
            ],
            removed=removed,
        )


def _hit(question: Question, entry: LibraryEntry) -> LibraryHit:
    return LibraryHit(
        question_id=question.id,
        exam_code=question.exam_code,
        stem=question.stem,
        format=question.format,
        source_type=entry.source_type,
        exam_year=entry.exam_year,
        difficulty=library.shown_level(entry.difficulty, entry.observed_difficulty),
        subject=question.subject,
        topic=question.topic.name if question.topic else None,
        pictured=question.image_dependent,
        percent_right=library.percent_right(entry.attempts, entry.correct_count),
    )


def _pack_question(
    question: Question, entry: LibraryEntry, figures: Sequence[QuestionFigure]
) -> PackQuestion:
    typed = question.answer_type == "typed"
    return PackQuestion(
        id=question.id,
        exam_code=question.exam_code,
        section=question.section,
        subject=question.subject,
        topic_id=question.topic_id,
        pattern_id=question.pattern_id,
        stem=question.stem,
        passage=PassageRead.model_validate(question.passage) if question.passage else None,
        options=[] if typed else [OptionRead.model_validate(o) for o in question.options],
        answer_type=question.answer_type,
        correct_position=None if typed else question.correct_option_position,
        typed_answer=question.typed_answer if typed else None,
        typed_answer_numeric=typed and is_numeric(question.typed_answer or ""),
        explanation=question.explanation,
        shared=True,
        shared_source=None,
        document_filename=None,
        page=None,
        question_number=None,
        library_source=entry.source_type,
        figures=[FigureRead.model_validate(f).model_dump(mode="json") for f in figures],
    )


def _base_seconds(session: Session, exam_code: str, today: Any) -> float | None:
    formats = mock_formats(session, exam_code, today)
    if not formats or not formats[0].duration_minutes or not formats[0].total_questions:
        return None
    return ladder.base_time(formats[0].duration_minutes, formats[0].total_questions)


def calibrate(session: Session, now: datetime | None = None) -> int:
    """Counts real attempts per library question and re-bands those with enough. Returns how many
    changed level. Only marked answers count."""
    moment = now or datetime.now(UTC)
    rows = session.execute(
        select(
            SessionItem.question_id,
            SessionAnswer.is_correct,
            SessionAnswer.time_spent_ms,
        )
        .join(
            SessionAnswer,
            and_(
                SessionAnswer.session_id == SessionItem.session_id,
                SessionAnswer.position == SessionItem.position,
            ),
        )
        .where(
            SessionItem.question_id.in_(select(LibraryEntry.question_id)),
            SessionAnswer.is_correct.is_not(None),
        )
    ).all()
    attempts: dict[uuid.UUID, list[tuple[bool, int | None]]] = defaultdict(list)
    for question_id, right, spent in rows:
        if question_id is not None:
            attempts[question_id].append((bool(right), spent))
    changed = 0
    for question_id, answers in attempts.items():
        entry = session.get(LibraryEntry, question_id)
        question = session.get(Question, question_id)
        if entry is None or question is None:
            continue
        entry.attempts = len(answers)
        entry.correct_count = sum(right for right, _ in answers)
        entry.median_ms = library.median([t for _, t in answers if t is not None])
        level = library.calibrated(
            entry.attempts,
            entry.correct_count,
            entry.median_ms,
            _base_seconds(session, question.exam_code, moment.date()),
        )
        if level is not None and level != entry.observed_difficulty:
            entry.observed_difficulty = level
            entry.calibrated_at = moment
            changed += 1
    session.commit()
    return changed
