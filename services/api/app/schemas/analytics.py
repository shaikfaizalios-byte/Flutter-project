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


class TopicStats(AnswerCounts):
    topic_id: uuid.UUID
    name: str
    subject: str


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


class AnalyticsOverview(BaseModel):
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
