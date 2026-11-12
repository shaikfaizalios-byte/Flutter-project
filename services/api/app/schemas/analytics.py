"""Progress analytics: raw counts only. Accuracy, thresholds and "weak" decisions are made
by the client from these counts (see docs/analytics.md), so no ratio is ever invented for
a topic with no data."""

import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel


class AnswerCounts(BaseModel):
    """Attempted answers (unanswered questions are not counted) and how many were right,
    overall and within the recent window."""

    answered: int
    correct: int
    recent_answered: int
    recent_correct: int


class SubjectStats(AnswerCounts):
    name: str


class TimedCounts(BaseModel):
    """Answers that recorded the time spent on the question, and their total time. Speed
    is judged by the client from these (never from answers without a time)."""

    timed_answered: int = 0
    time_spent_ms: int = 0


class ExamCounts(BaseModel):
    exam_code: str
    answered: int
    correct: int


class CanonicalTopicStats(BaseModel):
    """One canonical topic: ``answered`` and ``correct`` are all the exams together."""

    key: str
    name: str
    answered: int
    correct: int
    exams: list[ExamCounts]


class TopicStats(AnswerCounts, TimedCounts):
    topic_id: uuid.UUID
    name: str
    subject: str
    # The learner's local day of the latest counted answer in this topic.
    last_answered_on: date | None = None
    # Questions of this topic answered wrong in two or more sessions.
    repeated_mistakes: int = 0
    # Wrong answers by the learner's own reason (only the reasons given).
    mistake_reasons: dict[str, int] = {}


class DailyStats(BaseModel):
    """One local calendar day (in the requested timezone)."""

    date: date
    answered: int
    correct: int


class MockResult(BaseModel):
    session_id: uuid.UUID
    exam_format_code: str | None
    name: str | None
    submitted_at: datetime
    local_date: date
    submit_reason: str | None
    score: float
    max_score: float
    marking_note: str | None


class AnalyticsOverview(TimedCounts):
    timezone: str
    today: date
    days: int
    recent_days: int
    answered: int
    correct: int
    sessions: int
    subjects: list[SubjectStats]
    topics: list[TopicStats]
    daily: list[DailyStats]
    mocks: list[MockResult]
    # Wrong answers by the learner's own reason: all counted, and in the last 7 local days
    # (today included; the weekly review's week).
    mistake_reasons: dict[str, int] = {}
    week_mistake_reasons: dict[str, int] = {}


class SpeedTargetRead(BaseModel):
    """Seconds per question: from the verified format, or the learner's own when it has none."""

    source: Literal["format", "own"]
    format_name: str | None  # the verified format it comes from
    seconds: float | None  # the whole paper's
    by_section: dict[str, float]  # timed sections, their own


class TypeSpeedRead(BaseModel):
    """Raw counts for one question type (model)."""

    pattern_id: uuid.UUID
    name: str
    topic: str | None
    subject: str | None
    answered: int
    correct: int
    timed_answered: int
    time_spent_ms: int
    # Right answers that took more than slow_factor times the target.
    slow_correct: int
    target_seconds: float | None  # this type's target, when all its questions share one


class SpeedReport(BaseModel):
    target: SpeedTargetRead | None  # None: no verified format and no own target
    slow_factor: float
    types: list[TypeSpeedRead]
