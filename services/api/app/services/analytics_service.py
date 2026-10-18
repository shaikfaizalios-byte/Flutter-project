"""Progress analytics over recorded practice and mock answers.

Which answers count: attempted answers (an option selected) in practice sessions, and in
mock tests once they are submitted (mock answers get no feedback before submission, so
they are not "results" until then). Days are the learner's local calendar days in the
requested IANA timezone, computed by PostgreSQL (``timezone(zone, answered_at)``).
"""

import uuid
import zoneinfo
from collections.abc import Callable
from datetime import UTC, date, datetime, timedelta
from typing import Any

from sqlalchemy import ColumnElement, Integer, and_, case, func, or_, select
from sqlalchemy.orm import Session

from app.domain.errors import DomainError
from app.models.practice import (
    PracticeSession,
    SessionAnswer,
    SessionItem,
    SessionMode,
    SessionStatus,
)
from app.models.question import ExamFormat, Topic
from app.schemas.analytics import (
    AnalyticsOverview,
    DailyStats,
    MockResult,
    SubjectStats,
    TopicStats,
)

MAX_MOCKS = 20


class InvalidTimezoneError(DomainError):
    status_code = 422
    code = "invalid_timezone"


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

    def overview(self, *, timezone: str, days: int, recent_days: int) -> AnalyticsOverview:
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
            return (
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
                    ),
                    _counts_as_result(),
                    PracticeSession.owner_id == self._owner_id,
                )
            )

        total = self._session.execute(
            counted(
                func.count().cast(Integer),
                correct,
                func.count(func.distinct(SessionAnswer.session_id)),
            )
        ).one()

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
            subjects=subjects,
            topics=topics,
            daily=daily,
            mocks=self._mocks(zone),
        )

    def _mocks(self, zone: zoneinfo.ZoneInfo) -> list[MockResult]:
        rows = self._session.execute(
            select(PracticeSession, ExamFormat.code, ExamFormat.name)
            .outerjoin(ExamFormat, ExamFormat.id == PracticeSession.exam_format_id)
            .where(
                PracticeSession.mode == SessionMode.MOCK,
                PracticeSession.owner_id == self._owner_id,
                PracticeSession.status == SessionStatus.SUBMITTED,
            )
            .order_by(PracticeSession.submitted_at.desc())
            .limit(MAX_MOCKS)
        ).all()
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
