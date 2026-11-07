"""Repeat analysis by shift: chapter weightage, chapters two exams share, and concept hints.

Reviewed counts use confirmed topics in counted papers only. Concept hints are read from their own
table and touch none of them. This is separate from ``/insights/repeats`` so that report keeps its
exact shape.
"""

import hashlib
import logging
import uuid
from collections import defaultdict
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Literal

from sqlalchemy import ColumnElement, and_, delete, func, or_, select
from sqlalchemy.orm import Session

from app.domain import concept_hints as hints
from app.domain.counting import MIN_PAPERS_TO_NAME, unit_key
from app.domain.errors import ConflictError, InvalidReferenceError, NotFoundError
from app.domain.shift_counts import Counted, Tally, tally
from app.domain.similarity import StemItem, similar_groups
from app.integrations.ai import AIProvider, AIProviderError, AIResult
from app.models.ai import AIGeneration
from app.models.document import Document
from app.models.library import LibraryEntry
from app.models.question import (
    Question,
    QuestionOrigin,
    QuestionPattern,
    Topic,
    TopicStatus,
    VerificationStatus,
)
from app.models.repeat_analysis import ConceptHint, ModelProposal
from app.models.taxonomy import TaxonomyLabel, TaxonomyNode, TopicTaxonomyLink
from app.models.user import User
from app.schemas.insights import (
    ChapterReport,
    ChapterWeight,
    ConceptHintQuestion,
    ConceptHintRead,
    ExamChapter,
    SessionWeight,
    SharedChapter,
    ShiftBasis,
    TopicWeight,
    YearWeight,
)
from app.schemas.library import ModelApproval, ModelProposalQuestion, ModelProposalRead
from app.services.chapter_map import unit_topics
from app.services.content import audit
from app.services.exam_profiles import profile_for
from app.services.library_service import bump_seq
from app.services.shared_bank import counted_curated, visible_question

logger = logging.getLogger(__name__)

Scope = Literal["mine", "shared", "all"]
TASK = "concept_hint"
MAX_TOKENS = 3000
EXCERPT = 300


@dataclass(frozen=True, slots=True)
class _Row:
    id: uuid.UUID
    number: int | None
    text: str  # the reading of a question printed as a picture, for staff and the AI only
    stem: str
    pictured: bool
    topic_id: uuid.UUID | None
    confirmed: bool
    pattern_confirmed: bool
    count: Counted


def _rows(session: Session, owner_id: uuid.UUID | None, exam_code: str, scope: Scope) -> list[_Row]:
    """The questions of the counted papers: rejected, translated and duplicate ones are out."""
    mine: ColumnElement[bool] = and_(Question.owner_id == owner_id, Document.owner_id == owner_id)
    which = {
        "mine": mine,
        "shared": counted_curated(),
        "all": or_(mine, counted_curated()),
    }[scope]
    found = session.execute(
        select(Question, Document)
        .join(Document, Document.id == Question.document_id)
        .where(
            Question.origin == QuestionOrigin.SOURCE,
            Question.verification_status != VerificationStatus.REJECTED,
            Question.translation_of_id.is_(None),
            Document.duplicate_of_id.is_(None),
            Question.exam_code == exam_code,
            which,
        )
        # A fixed order: the AI gets the same list each time, and clusters come out the same.
        .order_by(
            Document.exam_date.asc().nulls_last(), Document.id, Question.source_question_number
        )
    ).all()
    unit = profile_for(session, exam_code).counting_unit
    rows = []
    for question, document in found:
        dated = document.paper_date_status == "confirmed"
        rows.append(
            _Row(
                id=question.id,
                number=question.source_question_number,
                text=question.transcript or question.stem,
                stem=question.stem,
                pictured=question.image_dependent,
                topic_id=question.topic_id,
                confirmed=question.topic_id is not None
                and question.topic_status == TopicStatus.CONFIRMED,
                pattern_confirmed=question.pattern_status == TopicStatus.CONFIRMED,
                count=Counted(
                    unit=unit_key(
                        unit,
                        document.id,
                        confirmed=dated,
                        exam_date=document.exam_date,
                        exam_shift=document.exam_shift,
                        session_label=document.session_label,
                    ),
                    year=document.exam_year if dated else None,
                    session=document.session_label,
                    marks=question.marks,
                ),
            )
        )
    return rows


def _years(counted: Tally) -> list[YearWeight]:
    return [
        YearWeight(year=y.year, questions=y.questions, shifts=y.shifts, marks=y.marks)
        for y in counted.years
    ]


def _sessions(counted: Tally) -> list[SessionWeight]:
    return [
        SessionWeight(session=s.session, questions=s.questions, shifts=s.shifts)
        for s in counted.sessions
    ]


class RepeatAnalysis:
    def __init__(self, session: Session, owner_id: uuid.UUID) -> None:
        self._session = session
        self._owner_id = owner_id

    def chapters(self, exam_code: str, scope: Scope) -> ChapterReport:
        rows = _rows(self._session, self._owner_id, exam_code, scope)
        reviewed = [r for r in rows if r.confirmed]
        everything = tally(r.count for r in rows)
        counted = tally(r.count for r in reviewed)
        questions_by_year = {y.year: y for y in counted.years}
        questions_by_session = {s.session: s for s in counted.sessions}
        units = unit_topics(self._session, exam_code, self._owner_id)
        topics = {
            t.id: t
            for t in self._session.scalars(
                select(Topic).where(Topic.id.in_({r.topic_id for r in reviewed}))
            )
        }
        by_chapter: dict[tuple[str, str], dict[uuid.UUID, list[_Row]]] = defaultdict(
            lambda: defaultdict(list)
        )
        for row in reviewed:
            assert row.topic_id is not None  # noqa: S101 - reviewed rows have a topic
            topic = topics.get(row.topic_id)
            if topic is None:
                continue
            chapter, subject = units.get(row.topic_id, (topic.name, topic.subject))
            by_chapter[(subject or topic.subject, chapter)][row.topic_id].append(row)
        chapters = []
        for (subject, name), members in by_chapter.items():
            all_rows = [r for group in members.values() for r in group]
            total = tally(r.count for r in all_rows)
            shown = []
            for topic_id, group in members.items():
                one = tally(r.count for r in group)
                shown.append(
                    TopicWeight(
                        topic_id=topic_id,
                        name=topics[topic_id].name,
                        questions=one.questions,
                        shifts=one.shifts,
                    )
                )
            shown.sort(key=lambda t: (-t.shifts, -t.questions, t.name))
            chapters.append(
                ChapterWeight(
                    subject=subject,
                    name=name,
                    questions=total.questions,
                    shifts=total.shifts,
                    marks=total.marks,
                    years=_years(total),
                    sessions=_sessions(total),
                    topics=shown,
                )
            )
        chapters.sort(key=lambda c: (-c.shifts, -c.questions, c.subject, c.name))
        return ChapterReport(
            exam_code=exam_code,
            scope=scope,
            basis=ShiftBasis(
                shifts=everything.shifts,
                questions=counted.questions,
                unreviewed=len(rows) - len(reviewed),
                years=[
                    YearWeight(
                        year=y.year,
                        shifts=y.shifts,
                        questions=questions_by_year[y.year].questions
                        if y.year in questions_by_year
                        else 0,
                        marks=questions_by_year[y.year].marks
                        if y.year in questions_by_year
                        else None,
                    )
                    for y in everything.years
                ],
                sessions=[
                    SessionWeight(
                        session=s.session,
                        shifts=s.shifts,
                        questions=questions_by_session[s.session].questions
                        if s.session in questions_by_session
                        else 0,
                    )
                    for s in everything.sessions
                ],
            ),
            chapters=chapters,
        )

    def shared_chapters(self, exams: Sequence[str], scope: Scope) -> list[SharedChapter]:
        """Canonical chapters at least two of these exams have. Only reviewed links count, and only
        topics named for the exam: a topic of every exam says nothing about what two share."""
        links = self._session.execute(
            select(Topic.id, Topic.exam_codes, TaxonomyNode.id, TaxonomyNode.parent_id)
            .join(TopicTaxonomyLink, TopicTaxonomyLink.topic_id == Topic.id)
            .join(TaxonomyNode, TaxonomyNode.id == TopicTaxonomyLink.node_id)
            .where(
                TopicTaxonomyLink.status == "confirmed",
                or_(Topic.owner_id.is_(None), Topic.owner_id == self._owner_id),
                Topic.exam_codes.is_not(None),
            )
        ).all()
        members: dict[uuid.UUID, dict[str, set[uuid.UUID]]] = defaultdict(lambda: defaultdict(set))
        parents: dict[uuid.UUID, uuid.UUID | None] = {}
        for topic_id, exam_codes, node_id, parent_id in links:
            parents[node_id] = parent_id
            for exam in exams:
                if exam in (exam_codes or []):
                    members[node_id][exam].add(topic_id)
        shared = {n: by_exam for n, by_exam in members.items() if len(by_exam) >= 2}
        if not shared:
            return []
        wanted = set(shared) | {p for n, p in parents.items() if n in shared and p}
        labels = dict(
            self._session.execute(
                select(TaxonomyLabel.node_id, TaxonomyLabel.label).where(
                    TaxonomyLabel.node_id.in_(wanted),
                    TaxonomyLabel.is_alias.is_(False),
                    TaxonomyLabel.language == "en",
                )
            )
            .tuples()
            .all()
        )
        rows = {exam: _rows(self._session, self._owner_id, exam, scope) for exam in exams}
        totals = {exam: tally(r.count for r in found).shifts for exam, found in rows.items()}
        result = []
        for node_id, by_exam in shared.items():
            parts = []
            for exam, topic_ids in sorted(by_exam.items()):
                one = tally(r.count for r in rows[exam] if r.confirmed and r.topic_id in topic_ids)
                parts.append(
                    ExamChapter(
                        exam_code=exam,
                        questions=one.questions,
                        shifts=one.shifts,
                        total_shifts=totals[exam],
                    )
                )
            parent = parents[node_id]
            result.append(
                SharedChapter(
                    name=labels.get(node_id, ""),
                    subject=labels.get(parent, "") if parent else "",
                    exams=parts,
                )
            )
        result.sort(key=lambda c: (-sum(e.questions for e in c.exams), c.subject, c.name))
        return result

    def hints(self, exam_code: str) -> list[ConceptHintRead]:
        """AI groupings, limited to questions this learner can see."""
        stored = self._session.scalars(
            select(ConceptHint).where(ConceptHint.exam_code == exam_code)
        ).all()
        ids = {uuid.UUID(i) for hint in stored for i in hint.question_ids}
        if not ids:
            return []
        rows = {r.id: r for r in _rows(self._session, self._owner_id, exam_code, "all")}
        visible = set(
            self._session.scalars(
                select(Question.id).where(Question.id.in_(ids), visible_question(self._owner_id))
            )
        )
        topics = dict(
            self._session.execute(
                select(Topic.id, Topic.name).where(Topic.id.in_({h.topic_id for h in stored}))
            )
            .tuples()
            .all()
        )
        result = []
        for hint in stored:
            members = [
                rows[uuid.UUID(i)]
                for i in hint.question_ids
                if uuid.UUID(i) in rows and uuid.UUID(i) in visible
            ]
            shifts = len({m.count.unit for m in members})
            if shifts < 2:
                continue
            result.append(
                ConceptHintRead(
                    topic_id=hint.topic_id,
                    topic_name=topics.get(hint.topic_id, ""),
                    label=hint.label,
                    shifts=shifts,
                    questions=[
                        ConceptHintQuestion(
                            question_id=m.id,
                            year=m.count.year,
                            number=m.number,
                            # A reading of a picture is never shown to learners.
                            excerpt=None if m.pictured else m.stem[:EXCERPT],
                        )
                        for m in members
                    ],
                )
            )
        result.sort(key=lambda h: (-h.shifts, h.topic_name, h.label))
        return result


def _signature(ids: Iterable[uuid.UUID]) -> str:
    return hashlib.sha256(",".join(sorted(str(i) for i in ids)).encode()).hexdigest()


def propose_models(session: Session, exam_code: str) -> int:
    """Clusters alike questions of curated papers, never learners' private ones. Open proposals are
    rebuilt; rejected clusters stay rejected. Returns how many are now open."""
    rows = [
        r
        for r in _rows(session, None, exam_code, "shared")
        if r.confirmed and not r.pattern_confirmed
    ]
    by_id = {r.id: r for r in rows}
    session.execute(
        delete(ModelProposal).where(
            ModelProposal.exam_code == exam_code, ModelProposal.status == "proposed"
        )
    )
    decided = set(
        session.execute(
            select(ModelProposal.topic_id, ModelProposal.signature).where(
                ModelProposal.exam_code == exam_code
            )
        )
        .tuples()
        .all()
    )
    made = 0
    items = [StemItem(r.id, r.count.unit, r.topic_id, r.text) for r in rows]
    for ids in similar_groups(items):
        group = [by_id[i] for i in ids]  # type: ignore[index]
        shifts = len({m.count.unit for m in group})
        topic_id = group[0].topic_id
        signature = _signature(m.id for m in group)
        if shifts < MIN_PAPERS_TO_NAME or topic_id is None or (topic_id, signature) in decided:
            continue
        session.add(
            ModelProposal(
                exam_code=exam_code,
                topic_id=topic_id,
                signature=signature,
                question_ids=[str(m.id) for m in group],
                shifts=shifts,
            )
        )
        made += 1
    session.commit()
    return made


class ModelReview:
    """A subject reviewer's decisions. Until one is made, a proposal changes nothing."""

    def __init__(self, session: Session, user: User) -> None:
        self._session = session
        self._user = user

    def _proposal(self, proposal_id: uuid.UUID) -> ModelProposal:
        proposal = self._session.get(ModelProposal, proposal_id)
        if proposal is None:
            raise NotFoundError("Proposal not found.")
        if proposal.status != "proposed":
            raise ConflictError("proposal_decided", "This proposal has already been decided.")
        return proposal

    def listing(self, exam_code: str) -> list[ModelProposalRead]:
        proposals = self._session.scalars(
            select(ModelProposal)
            .where(ModelProposal.exam_code == exam_code, ModelProposal.status == "proposed")
            .order_by(ModelProposal.shifts.desc(), ModelProposal.created_at)
            .limit(100)
        ).all()
        ids = {uuid.UUID(i) for p in proposals for i in p.question_ids}
        questions = {
            q.id: q for q in self._session.scalars(select(Question).where(Question.id.in_(ids)))
        }
        names = dict(
            self._session.execute(
                select(Topic.id, Topic.name).where(Topic.id.in_({p.topic_id for p in proposals}))
            )
            .tuples()
            .all()
        )
        return [
            ModelProposalRead(
                id=p.id,
                topic_id=p.topic_id,
                topic_name=names.get(p.topic_id, ""),
                shifts=p.shifts,
                questions=[
                    ModelProposalQuestion(question_id=q.id, text=(q.transcript or q.stem)[:EXCERPT])
                    for q in (questions.get(uuid.UUID(i)) for i in p.question_ids)
                    if q is not None
                ],
            )
            for p in proposals
        ]

    def approve(self, proposal_id: uuid.UUID, data: ModelApproval) -> int:
        """Names the model, on the shared list, and confirms it on the questions the reviewer
        kept. Returns how many questions it now covers."""
        proposal = self._proposal(proposal_id)
        kept = {uuid.UUID(i) for i in proposal.question_ids}
        if data.question_ids is not None:
            if not set(data.question_ids) <= kept:
                raise InvalidReferenceError("Those questions aren't in this proposal.")
            kept = set(data.question_ids)
        if len(kept) < 2:
            raise InvalidReferenceError("A model needs at least two questions.")
        pattern = self._session.scalar(
            select(QuestionPattern).where(
                QuestionPattern.topic_id == proposal.topic_id,
                QuestionPattern.owner_id.is_(None),
                func.lower(QuestionPattern.name) == data.name.lower(),
            )
        )
        if pattern is None:
            pattern = QuestionPattern(topic_id=proposal.topic_id, name=data.name, keywords=[])
            self._session.add(pattern)
            self._session.flush()
        covered = 0
        for question in self._session.scalars(select(Question).where(Question.id.in_(kept))):
            if question.topic_id != proposal.topic_id:
                continue
            if question.pattern_status == TopicStatus.CONFIRMED:
                continue
            question.pattern_id = pattern.id
            question.pattern_status = TopicStatus.CONFIRMED
            entry = self._session.get(LibraryEntry, question.id)
            if entry is not None:
                bump_seq(self._session, entry)
            covered += 1
        self._decide(proposal, "approved", None)
        proposal.pattern_id = pattern.id
        audit(self._session, self._user.email, "model_approved", "pattern", pattern.id, data.name)
        self._session.commit()
        return covered

    def reject(self, proposal_id: uuid.UUID, reason: str) -> None:
        self._decide(self._proposal(proposal_id), "rejected", reason)
        self._session.commit()

    def _decide(self, proposal: ModelProposal, status: str, note: str | None) -> None:
        proposal.status = status
        proposal.review_note = note
        proposal.reviewed_by = self._user.email
        proposal.reviewed_at = datetime.now(UTC)


def build_hints(
    session: Session,
    provider: AIProvider,
    exam_code: str,
    *,
    limit: int,
    refresh: bool = False,
) -> tuple[int, int]:
    """Asks the AI to group each topic's curated questions by concept. Learners' private papers are
    never sent. Returns (topics read, hints saved)."""
    by_topic: dict[uuid.UUID, list[_Row]] = defaultdict(list)
    for row in _rows(session, None, exam_code, "shared"):
        if row.confirmed and row.topic_id and len(row.text.strip()) >= hints.MIN_TEXT:
            by_topic[row.topic_id].append(row)
    done = set(
        session.scalars(select(ConceptHint.topic_id).where(ConceptHint.exam_code == exam_code))
    )
    read = saved = 0
    for topic_id, rows in by_topic.items():
        if read >= limit:
            break
        if (topic_id in done and not refresh) or len({r.count.unit for r in rows}) < 2:
            continue
        sent = rows[: hints.MAX_QUESTIONS]
        try:
            result = provider.complete_json(
                system=hints.SYSTEM,
                prompt=hints.prompt([r.text for r in sent]),
                schema=dict(hints.SCHEMA),
                max_tokens=MAX_TOKENS,
            )
        except AIProviderError as exc:
            logger.warning("Reading concepts failed: %s", exc.reason)
            _log(session, provider, "error", AIResult({}), exc.reason)
            session.commit()
            continue
        read += 1
        session.execute(delete(ConceptHint).where(ConceptHint.topic_id == topic_id))
        kept = 0
        for group in hints.read_groups(result.data, len(sent)):
            members = [sent[p] for p in group.positions]
            if len({m.count.unit for m in members}) < 2:
                continue  # one shift says nothing about repetition
            session.add(
                ConceptHint(
                    exam_code=exam_code,
                    topic_id=topic_id,
                    label=group.label,
                    question_ids=[str(m.id) for m in members],
                    model=provider.model,
                    prompt_version=hints.PROMPT_VERSION,
                )
            )
            kept += 1
        _log(session, provider, "ok", result, f"groups {kept}")
        saved += kept
        session.commit()
    return read, saved


def _log(
    session: Session, provider: AIProvider, outcome: str, result: AIResult, detail: str
) -> None:
    session.add(
        AIGeneration(
            task=TASK,
            provider=provider.name,
            model=provider.model,
            prompt_version=hints.PROMPT_VERSION,
            outcome=outcome,
            detail=detail,
            input_tokens=result.input_tokens,
            output_tokens=result.output_tokens,
        )
    )
