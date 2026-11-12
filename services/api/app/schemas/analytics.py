"""Progress analytics: raw counts only. Accuracy, thresholds and "weak" decisions are made
by the client from these counts (see docs/analytics.md), so no ratio is ever invented for
a topic with no data."""

import uuid
from datetime import date, datetime

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
