"""Which topics and question types (patterns) repeat across the learner's own papers.

Counts come only from source questions in papers this account imported (never AI questions,
never rejected ones), so every number states its basis: how many papers, which years.
Reviewed classifications (confirmed topic / pattern) are counted apart from unreviewed
suggestions, and year breakdowns use confirmed paper dates only. Wording-similarity groups
are reported separately as suggestions.
"""

import uuid
from collections import Counter, defaultdict
from collections.abc import Iterable
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.similarity import THRESHOLD, StemItem, similar_groups
from app.models.document import Document
from app.models.question import (
    Question,
    QuestionOrigin,
    QuestionPattern,
    Topic,
    TopicStatus,
    VerificationStatus,
)
from app.schemas.insights import (
    PapersBasis,
    PatternRepeat,
    RepeatCounts,
    RepeatsReport,
    SimilarGroup,
    SimilarQuestion,
    TopicRepeat,
    YearCount,
)

MAX_SIMILAR_GROUPS = 50
EXCERPT_CHARS = 160


@dataclass(frozen=True, slots=True)
class _Row:
    id: uuid.UUID
    document_id: uuid.UUID
    number: int | None
    stem: str
    subject: str | None
    topic_id: uuid.UUID | None
    topic_status: str
    pattern_id: uuid.UUID | None
    pattern_status: str
    verified: bool


def _counts(rows: Iterable[_Row], years: dict[uuid.UUID, int]) -> RepeatCounts:
    rows = list(rows)
    per_year = Counter(years[r.document_id] for r in rows if r.document_id in years)
    return RepeatCounts(
        questions=len(rows),
        papers=len({r.document_id for r in rows}),
        years=[YearCount(year=y, questions=n) for y, n in sorted(per_year.items())],
    )


def _excerpt(stem: str) -> str:
    flat = " ".join(stem.split())
    return flat if len(flat) <= EXCERPT_CHARS else flat[: EXCERPT_CHARS - 1].rstrip() + "…"


class InsightsService:
    def __init__(self, session: Session, owner_id: uuid.UUID) -> None:
        self._session = session
        self._owner_id = owner_id

    def repeats(self, exam_code: str | None) -> RepeatsReport:
        stmt = (
            select(
                Question.id,
                Question.document_id,
                Question.source_question_number,
                Question.stem,
                Question.subject,
                Question.topic_id,
                Question.topic_status,
                Question.pattern_id,
                Question.pattern_status,
                Question.verification_status,
            )
            .join(Document, Document.id == Question.document_id)
            .where(
                Question.owner_id == self._owner_id,
                Document.owner_id == self._owner_id,
                Question.origin == QuestionOrigin.SOURCE,
                Question.verification_status != VerificationStatus.REJECTED,
            )
        )
        if exam_code:
            stmt = stmt.where(Question.exam_code == exam_code)
        rows = [
            _Row(
                id=r[0],
                document_id=r[1],  # joined on documents: never null here
                number=r[2],
                stem=r[3],
                subject=r[4],
                topic_id=r[5],
                topic_status=r[6],
                pattern_id=r[7],
                pattern_status=r[8],
                verified=r[9] == VerificationStatus.VERIFIED,
            )
            for r in self._session.execute(stmt).all()
            if r[1] is not None
        ]
        paper_ids = {r.document_id for r in rows}
        documents = (
            self._session.scalars(select(Document).where(Document.id.in_(paper_ids))).all()
            if paper_ids
            else []
        )
        years = {
            d.id: d.exam_year
            for d in documents
            if d.paper_date_status == "confirmed" and d.exam_year is not None
        }
        filenames = {d.id: d.original_filename for d in documents}
        topics = {t.id: t for t in self._session.scalars(select(Topic)).all()}
        patterns = {p.id: p for p in self._session.scalars(select(QuestionPattern)).all()}

        return RepeatsReport(
            exam_code=exam_code,
            papers=PapersBasis(
                total=len(paper_ids),
                dated=len(years),
                undated=len(paper_ids) - len(years),
                years=sorted(set(years.values())),
            ),
            topics=self._topics(rows, years, topics, patterns),
            similar_groups=self._similar(rows, years, filenames, topics),
            similarity_threshold=THRESHOLD,
        )

    @staticmethod
    def _topics(
        rows: list[_Row],
        years: dict[uuid.UUID, int],
        topics: dict[uuid.UUID, Topic],
        patterns: dict[uuid.UUID, QuestionPattern],
    ) -> list[TopicRepeat]:
        by_topic: dict[uuid.UUID, list[_Row]] = defaultdict(list)
        for row in rows:
            if row.topic_id is not None and row.topic_id in topics:
                by_topic[row.topic_id].append(row)
        result = []
        for topic_id, topic_rows in by_topic.items():
            topic = topics[topic_id]
            confirmed = [r for r in topic_rows if r.topic_status == TopicStatus.CONFIRMED]
            unreviewed = sum(r.topic_status == TopicStatus.SUGGESTED for r in topic_rows)
            pattern_rows: dict[uuid.UUID, list[_Row]] = defaultdict(list)
            for r in topic_rows:
                pattern = patterns.get(r.pattern_id) if r.pattern_id else None
                if pattern is not None and pattern.topic_id == topic_id:
                    pattern_rows[pattern.id].append(r)
            pattern_items = []
            patterned: set[uuid.UUID] = set()
            for pattern_id, p_rows in pattern_rows.items():
                p_confirmed = [
                    r
                    for r in p_rows
                    if r.pattern_status == TopicStatus.CONFIRMED
                    and r.topic_status == TopicStatus.CONFIRMED
                ]
                patterned.update(r.id for r in p_confirmed)
                pattern_items.append(
                    PatternRepeat(
                        pattern_id=pattern_id,
                        name=patterns[pattern_id].name,
                        confirmed=_counts(p_confirmed, years),
                        unreviewed=len(p_rows) - len(p_confirmed),
                    )
                )
            pattern_items.sort(
                key=lambda p: (-p.confirmed.papers, -p.confirmed.questions, -p.unreviewed, p.name)
            )
            result.append(
                TopicRepeat(
                    topic_id=topic_id,
                    subject=topic.subject,
                    name=topic.name,
                    confirmed=_counts(confirmed, years),
                    unreviewed=unreviewed,
                    patterns=pattern_items,
                    without_pattern=sum(r.id not in patterned for r in confirmed),
                )
            )
        result.sort(
            key=lambda t: (-t.confirmed.papers, -t.confirmed.questions, -t.unreviewed, t.name)
        )
        return result

    @staticmethod
    def _similar(
        rows: list[_Row],
        years: dict[uuid.UUID, int],
        filenames: dict[uuid.UUID, str],
        topics: dict[uuid.UUID, Topic],
    ) -> list[SimilarGroup]:
        by_id = {r.id: r for r in rows}
        items = [
            StemItem(
                id=r.id,
                paper_id=r.document_id,
                # Compare within a topic (suggested or confirmed), else within the subject.
                block=("topic", r.topic_id) if r.topic_id else ("subject", r.subject),
                stem=r.stem,
            )
            for r in rows
        ]
        groups = []
        for ids in similar_groups(items)[:MAX_SIMILAR_GROUPS]:
            members = [by_id[i] for i in ids]  # type: ignore[index]
            topic_ids = {m.topic_id for m in members if m.topic_id}
            topic = topics.get(next(iter(topic_ids))) if len(topic_ids) == 1 else None
            subjects = {m.subject for m in members if m.subject}
            groups.append(
                SimilarGroup(
                    subject=topic.subject if topic else (next(iter(subjects), None)),
                    topic_name=topic.name if topic else None,
                    papers=len({m.document_id for m in members}),
                    years=sorted({years[m.document_id] for m in members if m.document_id in years}),
                    questions=[
                        SimilarQuestion(
                            question_id=m.id,
                            document_id=m.document_id,
                            document_filename=filenames.get(m.document_id, ""),
                            exam_year=years.get(m.document_id),
                            question_number=m.number,
                            stem_excerpt=_excerpt(m.stem),
                            verified=m.verified,
                        )
                        for m in members
                    ],
                )
            )
        return groups
