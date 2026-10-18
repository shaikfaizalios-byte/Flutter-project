"""The shared Repeat Radar: topic and question-type repetition pooled over learners who opted
in. Counts are read live from their confirmed classifications (nothing is copied), pooled by
``app.domain.radar`` and published only where enough accounts agree. No question text, no
account or paper identifiers leave this service.
"""

import uuid
from collections import Counter, defaultdict
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.domain.errors import NotFoundError
from app.domain.radar import MIN_ACCOUNTS, Contribution, PooledShift, ShiftKey, pool
from app.models.document import Document
from app.models.question import (
    Question,
    QuestionOrigin,
    QuestionPattern,
    Topic,
    TopicStatus,
    VerificationStatus,
)
from app.models.user import User
from app.schemas.radar import (
    RadarBasis,
    RadarCounts,
    RadarPattern,
    RadarReport,
    RadarSettings,
    RadarTopic,
    RadarYear,
)


def _eligible_questions() -> Any:  # a Select of the columns below
    """Source questions with a confirmed topic in papers with a confirmed date and shift."""
    return (
        select(
            Question.owner_id,
            Question.document_id,
            Document.exam_code,
            Document.exam_date,
            Document.exam_shift,
            Question.topic_id,
            Question.pattern_id,
            Question.pattern_status,
        )
        .join(Document, Document.id == Question.document_id)
        .where(
            Document.owner_id == Question.owner_id,
            Document.paper_date_status == "confirmed",
            Document.exam_date.is_not(None),
            Document.exam_shift.is_not(None),
            Question.origin == QuestionOrigin.SOURCE,
            Question.verification_status != VerificationStatus.REJECTED,
            Question.topic_status == TopicStatus.CONFIRMED,
            Question.topic_id.is_not(None),
        )
    )


class RadarService:
    def __init__(self, session: Session, owner_id: uuid.UUID) -> None:
        self._session = session
        self._owner_id = owner_id

    # --- settings ----------------------------------------------------------------------

    def settings(self) -> RadarSettings:
        user = self._user()
        mine = _eligible_questions().where(Question.owner_id == self._owner_id).subquery()
        eligible = self._session.scalar(select(func.count(func.distinct(mine.c.document_id))))
        return RadarSettings(
            share=user.radar_opt_in, eligible_papers=eligible or 0, min_accounts=MIN_ACCOUNTS
        )

    def set_share(self, share: bool) -> RadarSettings:
        user = self._user()
        if share != user.radar_opt_in:
            user.radar_opt_in = share
            user.radar_opt_in_at = datetime.now(UTC) if share else None
            self._session.commit()
        return self.settings()

    def _user(self) -> User:
        user = self._session.get(User, self._owner_id)
        if user is None:
            raise NotFoundError("Account not found.")
        return user

    # --- report ------------------------------------------------------------------------

    def report(self, exam_code: str | None) -> RadarReport:
        stmt = (
            _eligible_questions()
            .join(User, User.id == Question.owner_id)
            .where(User.radar_opt_in.is_(True))
        )
        if exam_code:
            stmt = stmt.where(Document.exam_code == exam_code)

        topics: dict[tuple[uuid.UUID, uuid.UUID], Counter[uuid.UUID]] = defaultdict(Counter)
        patterns: dict[tuple[uuid.UUID, uuid.UUID], Counter[uuid.UUID]] = defaultdict(Counter)
        shifts: dict[tuple[uuid.UUID, uuid.UUID], ShiftKey] = {}
        for (
            owner,
            document,
            exam,
            date,
            shift,
            topic_id,
            pattern_id,
            pattern_status,
        ) in self._session.execute(stmt).all():
            key = (owner, document)
            shifts[key] = ShiftKey(exam, date, shift)
            topics[key][topic_id] += 1
            if pattern_id is not None and pattern_status == TopicStatus.CONFIRMED:
                patterns[key][pattern_id] += 1

        pooled = pool(
            Contribution(
                account=owner,
                shift=shift_key,
                topics=dict(topics[(owner, document)]),
                patterns=dict(patterns[(owner, document)]),
            )
            for (owner, document), shift_key in shifts.items()
        )
        return RadarReport(
            exam_code=exam_code,
            basis=RadarBasis(
                shifts=len(pooled),
                years=sorted({p.shift.date.year for p in pooled}),
                min_accounts=MIN_ACCOUNTS,
                withheld=sum(p.withheld for p in pooled),
            ),
            topics=self._topics(pooled),
        )

    def _topics(self, pooled: list[PooledShift]) -> list[RadarTopic]:
        topic_rows = {t.id: t for t in self._session.scalars(select(Topic)).all()}
        pattern_rows = {p.id: p for p in self._session.scalars(select(QuestionPattern)).all()}

        def counts(entries: list[tuple[PooledShift, int]]) -> RadarCounts:
            years = Counter(p.shift.date.year for p, _ in entries)
            return RadarCounts(
                shifts=len(entries),
                questions=sum(n for _, n in entries),
                years=[RadarYear(year=y, shifts=n) for y, n in sorted(years.items())],
            )

        by_topic: dict[uuid.UUID, list[tuple[PooledShift, int]]] = defaultdict(list)
        by_pattern: dict[uuid.UUID, list[tuple[PooledShift, int]]] = defaultdict(list)
        for p in pooled:
            for topic_id, n in p.topics.items():
                by_topic[topic_id].append((p, n))  # type: ignore[index]
            for pattern_id, n in p.patterns.items():
                by_pattern[pattern_id].append((p, n))  # type: ignore[index]

        result = []
        for topic_id, entries in by_topic.items():
            topic = topic_rows.get(topic_id)
            if topic is None:
                continue
            pattern_items = [
                RadarPattern(pattern_id=pid, name=pattern_rows[pid].name, counts=counts(e))
                for pid, e in by_pattern.items()
                if pid in pattern_rows and pattern_rows[pid].topic_id == topic_id
            ]
            pattern_items.sort(key=lambda r: (-r.counts.shifts, -r.counts.questions, r.name))
            result.append(
                RadarTopic(
                    topic_id=topic_id,
                    subject=topic.subject,
                    name=topic.name,
                    counts=counts(entries),
                    patterns=pattern_items,
                )
            )
        result.sort(key=lambda t: (-t.counts.shifts, -t.counts.questions, t.name))
        return result
