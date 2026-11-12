"""Progress analytics over recorded practice and mock answers.

Which answers count: attempted answers (an option selected) in practice sessions, and in
mock tests once they are submitted (mock answers get no feedback before submission, so
they are not "results" until then). Days are the learner's local calendar days in the
requested IANA timezone, computed by PostgreSQL (``timezone(zone, answered_at)``).
"""

import uuid
import zoneinfo
from collections.abc import Callable, Sequence
from datetime import UTC, date, datetime, timedelta
from typing import Any

from sqlalchemy import ColumnElement, Integer, and_, case, func, or_, select
from sqlalchemy.orm import Session

from app.domain import speed
from app.domain.errors import DomainError
from app.models.practice import (
    PracticeSession,
    SessionAnswer,
    SessionItem,
    SessionMode,
    SessionStatus,
)
from app.models.question import ExamFormat, Question, QuestionPattern, Topic
from app.models.taxonomy import TaxonomyLabel, TaxonomyNode, TopicTaxonomyLink
from app.schemas.analytics import (
    AnalyticsOverview,
    CanonicalTopicStats,
    DailyStats,
    ExamCounts,
    MockResult,
    SpeedReport,
    SpeedTargetRead,
    SubjectStats,
    TopicStats,
    TypeSpeedRead,
)
from app.services.exam_formats import mock_formats

MAX_MOCKS = 20


class InvalidTimezoneError(DomainError):
    status_code = 422
    code = "invalid_timezone"


# The weekly review's week: the last 7 local days, today included.
WEEK_DAYS = 7


def _zone(name: str) -> zoneinfo.ZoneInfo:
    if name not in zoneinfo.available_timezones():
        raise InvalidTimezoneError(
            f"Unknown timezone '{name}'. Use an IANA name like Asia/Kolkata."
        )
    return zoneinfo.ZoneInfo(name)


class AnalyticsService:
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

    def overview(
        self, *, timezone: str, days: int, recent_days: int, exam: str | None = None
    ) -> AnalyticsOverview:
        """Counts for one exam when ``exam`` is given (by each question's exam, so older
        sessions that mixed exams are split correctly), else for all exams."""
        zone = _zone(timezone)
        today = self._now().astimezone(zone).date()
        recent_from = today - timedelta(days=recent_days - 1)
        daily_from = today - timedelta(days=days - 1)

        local_day = func.date(func.timezone(timezone, SessionAnswer.answered_at))
        correct = func.coalesce(func.sum(case((SessionAnswer.is_correct.is_(True), 1), else_=0)), 0)
        recent = local_day >= recent_from
        recent_answered = func.coalesce(func.sum(case((recent, 1), else_=0)), 0)
        recent_correct = func.coalesce(
            func.sum(case((and_(recent, SessionAnswer.is_correct.is_(True)), 1), else_=0)), 0
        )

        def counted(*columns: Any) -> Any:
            query = (
                select(*columns)
                .select_from(SessionAnswer)
                .join(
                    SessionItem,
                    and_(
                        SessionItem.session_id == SessionAnswer.session_id,
                        SessionItem.position == SessionAnswer.position,
                    ),
                )
                .join(PracticeSession, PracticeSession.id == SessionAnswer.session_id)
                .where(
                    or_(
                        SessionAnswer.selected_position.is_not(None),
                        SessionAnswer.typed_answer.is_not(None),
                        SessionAnswer.response.is_not(None),
                    ),
                    _counts_as_result(),
                    PracticeSession.owner_id == self._owner_id,
                )
            )
            if exam is not None:
                query = query.join(Question, Question.id == SessionAnswer.question_id).where(
                    Question.exam_code == exam
                )
            return query

        timed = SessionAnswer.time_spent_ms.is_not(None)
        timed_answered = func.coalesce(func.sum(case((timed, 1), else_=0)), 0)
        time_spent = func.coalesce(func.sum(SessionAnswer.time_spent_ms), 0)

        total = self._session.execute(
            counted(
                func.count().cast(Integer),
                correct,
                func.count(func.distinct(SessionAnswer.session_id)),
                timed_answered,
                time_spent,
            )
        ).one()

        # Questions answered wrong in two or more sessions, per topic.
        wrong_twice = (
            counted(SessionItem.topic_id.label("topic_id"))
            .where(
                SessionAnswer.is_correct.is_(False),
                SessionItem.topic_id.is_not(None),
                SessionAnswer.question_id.is_not(None),
            )
            .group_by(SessionItem.topic_id, SessionAnswer.question_id)
            .having(func.count(func.distinct(SessionAnswer.session_id)) >= 2)
            .subquery()
        )
        repeated: dict[uuid.UUID, int] = {
            topic_id: count
            for topic_id, count in self._session.execute(
                select(wrong_twice.c.topic_id, func.count()).group_by(wrong_twice.c.topic_id)
            )
        }

        # The learner's reasons for wrong answers, per topic and in total.
        reason = SessionAnswer.mistake_reason
        by_topic: dict[uuid.UUID, dict[str, int]] = {}
        reasons: dict[str, int] = {}
        week_reasons: dict[str, int] = {}
        this_week = func.coalesce(
            func.sum(case((local_day >= today - timedelta(days=WEEK_DAYS - 1), 1), else_=0)), 0
        )
        for topic_id, why, count, week_count in self._session.execute(
            counted(SessionItem.topic_id, reason, func.count(), this_week)
            .where(SessionAnswer.is_correct.is_(False), reason.is_not(None))
            .group_by(SessionItem.topic_id, reason)
        ):
            reasons[why] = reasons.get(why, 0) + count
            if week_count:
                week_reasons[why] = week_reasons.get(why, 0) + week_count
            if topic_id is not None:
                by_topic.setdefault(topic_id, {})[why] = count

        subject_name = func.coalesce(SessionItem.subject, SessionItem.section, "")
        subjects = [
            SubjectStats(
                name=row[0],
                answered=row[1],
                correct=row[2],
                recent_answered=row[3],
                recent_correct=row[4],
            )
            for row in self._session.execute(
                counted(subject_name, func.count(), correct, recent_answered, recent_correct)
                .group_by(subject_name)
                .order_by(subject_name)
            )
            if row[0]
        ]

        topics = [
            TopicStats(
                topic_id=row[0],
                name=row[1],
                subject=row[2],
                answered=row[3],
                correct=row[4],
                recent_answered=row[5],
                recent_correct=row[6],
                timed_answered=row[7],
                time_spent_ms=row[8],
                last_answered_on=row[9],
                repeated_mistakes=repeated.get(row[0], 0),
                mistake_reasons=by_topic.get(row[0], {}),
            )
            for row in self._session.execute(
                counted(
                    Topic.id,
                    Topic.name,
                    Topic.subject,
                    func.count(),
                    correct,
                    recent_answered,
                    recent_correct,
                    timed_answered,
                    time_spent,
                    func.max(local_day),
                )
                .join(Topic, Topic.id == SessionItem.topic_id)
                .group_by(Topic.id, Topic.name, Topic.subject)
                .order_by(Topic.subject, Topic.name)
            )
        ]

        daily = [
            DailyStats(date=row[0], answered=row[1], correct=row[2])
            for row in self._session.execute(
                counted(local_day, func.count(), correct)
                .where(local_day >= daily_from)
                .group_by(local_day)
                .order_by(local_day)
            )
        ]

        return AnalyticsOverview(
            timezone=timezone,
            today=today,
            days=days,
            recent_days=recent_days,
            answered=total[0],
            correct=total[1],
            sessions=total[2],
            timed_answered=total[3],
            time_spent_ms=total[4],
            subjects=subjects,
            topics=topics,
            daily=daily,
            mocks=self._mocks(zone, exam),
            mistake_reasons=reasons,
            week_mistake_reasons=week_reasons,
        )

    def canonical(self, exams: Sequence[str]) -> list[CanonicalTopicStats]:
        """Raw counts per canonical topic. Only confirmed links count."""
        correct = func.coalesce(func.sum(case((SessionAnswer.is_correct.is_(True), 1), else_=0)), 0)
        rows = self._session.execute(
            select(
                TaxonomyNode.key,
                Question.exam_code,
                func.count().cast(Integer),
                correct,
            )
            .select_from(SessionAnswer)
            .join(
                SessionItem,
                and_(
                    SessionItem.session_id == SessionAnswer.session_id,
                    SessionItem.position == SessionAnswer.position,
                ),
            )
            .join(PracticeSession, PracticeSession.id == SessionAnswer.session_id)
            .join(Question, Question.id == SessionAnswer.question_id)
            .join(TopicTaxonomyLink, TopicTaxonomyLink.topic_id == SessionItem.topic_id)
            .join(TaxonomyNode, TaxonomyNode.id == TopicTaxonomyLink.node_id)
            .where(
                TopicTaxonomyLink.status == "confirmed",
                or_(
                    SessionAnswer.selected_position.is_not(None),
                    SessionAnswer.typed_answer.is_not(None),
                    SessionAnswer.response.is_not(None),
                ),
                _counts_as_result(),
                PracticeSession.owner_id == self._owner_id,
                Question.exam_code.in_(exams),
            )
            .group_by(TaxonomyNode.key, Question.exam_code)
            .order_by(TaxonomyNode.key, Question.exam_code)
        ).all()
        by_key: dict[str, list[ExamCounts]] = {}
        for key, exam_code, answered, right in rows:
            by_key.setdefault(key, []).append(
                ExamCounts(exam_code=exam_code, answered=answered, correct=int(right))
            )
        names: dict[str, str] = {
            key: label
            for key, label in self._session.execute(
                select(TaxonomyNode.key, TaxonomyLabel.label)
                .join(TaxonomyLabel, TaxonomyLabel.node_id == TaxonomyNode.id)
                .where(
                    TaxonomyNode.key.in_(by_key),
                    TaxonomyLabel.is_alias.is_(False),
                    TaxonomyLabel.language == "en",
                )
            )
        }
        return [
            CanonicalTopicStats(
                key=key,
                name=names.get(key, key),
                answered=sum(e.answered for e in counts),
                correct=sum(e.correct for e in counts),
                exams=counts,
            )
            for key, counts in by_key.items()
        ]

    def speed(
        self, exam: str, *, own_target_seconds: float | None, slow_factor: float
    ) -> SpeedReport:
        """Speed per question type for one exam. The target comes from the verified format in
        effect today; the learner's own target is used only when there is none."""
        today = self._now().date()
        verified = next(iter(mock_formats(self._session, exam, today)), None)
        target = (
            speed.format_target(
                name=verified.name,
                duration_minutes=verified.duration_minutes,
                total_questions=verified.total_questions,
                sections=verified.sections or [],
                sectional_timing=verified.sectional_timing,
            )
            if verified is not None
            else None
        ) or speed.own_target(own_target_seconds)
        rows = self._session.execute(
            select(
                QuestionPattern.id,
                QuestionPattern.name,
                Topic.name,
                SessionItem.subject,
                SessionAnswer.is_correct,
                SessionAnswer.time_spent_ms,
            )
            .select_from(SessionAnswer)
            .join(
                SessionItem,
                and_(
                    SessionItem.session_id == SessionAnswer.session_id,
                    SessionItem.position == SessionAnswer.position,
                ),
            )
            .join(PracticeSession, PracticeSession.id == SessionAnswer.session_id)
            .join(Question, Question.id == SessionAnswer.question_id)
            .join(QuestionPattern, QuestionPattern.id == Question.pattern_id)
            .outerjoin(Topic, Topic.id == QuestionPattern.topic_id)
            .where(
                or_(
                    SessionAnswer.selected_position.is_not(None),
                    SessionAnswer.typed_answer.is_not(None),
                    SessionAnswer.response.is_not(None),
                ),
                _counts_as_result(),
                PracticeSession.owner_id == self._owner_id,
                Question.exam_code == exam,
            )
        ).all()
        types = speed.speed_by_type((speed.Answered(*row) for row in rows), target, slow_factor)
        return SpeedReport(
            target=SpeedTargetRead(
                source=target.source,
                format_name=target.format_name,
                seconds=target.seconds,
                by_section=dict(target.by_section),
            )
            if target
            else None,
            slow_factor=slow_factor,
            types=[
                TypeSpeedRead(
                    pattern_id=t.pattern_id,
                    name=t.name,
                    topic=t.topic,
                    subject=t.subject,
                    answered=t.answered,
                    correct=t.correct,
                    timed_answered=t.timed_answered,
                    time_spent_ms=t.time_spent_ms,
                    slow_correct=t.slow_correct,
                    target_seconds=t.target_seconds,
                )
                for t in types
            ],
        )

    def _mocks(self, zone: zoneinfo.ZoneInfo, exam: str | None) -> list[MockResult]:
        query = (
            select(PracticeSession, ExamFormat.code, ExamFormat.name)
            .outerjoin(ExamFormat, ExamFormat.id == PracticeSession.exam_format_id)
            .where(
                PracticeSession.mode == SessionMode.MOCK,
                PracticeSession.owner_id == self._owner_id,
                PracticeSession.status == SessionStatus.SUBMITTED,
            )
            .order_by(PracticeSession.submitted_at.desc())
            .limit(MAX_MOCKS)
        )
        if exam is not None:
            query = query.where(PracticeSession.exam_code == exam)
        rows = self._session.execute(query).all()
        results: list[MockResult] = []
        for mock, code, name in rows:
            if mock.submitted_at is None or mock.score is None or mock.max_score is None:
                continue
            results.append(
                MockResult(
                    session_id=mock.id,
                    exam_format_code=code,
                    name=name,
                    submitted_at=mock.submitted_at,
                    local_date=mock.submitted_at.astimezone(zone).date(),
                    submit_reason=mock.submit_reason,
                    score=mock.score,
                    max_score=mock.max_score,
                    marking_note=(mock.result or {}).get("marking_note"),
                )
            )
        return results


def _counts_as_result() -> ColumnElement[bool]:
    return or_(
        PracticeSession.mode == SessionMode.PRACTICE,
        PracticeSession.status == SessionStatus.SUBMITTED,
    )


def local_date(moment: datetime, timezone: str) -> date:
    """The calendar date of [moment] in [timezone] (helper for tests and callers)."""
    return moment.astimezone(_zone(timezone)).date()
