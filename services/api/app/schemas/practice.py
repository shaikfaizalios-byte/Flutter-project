import uuid
from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

from app.schemas.question import OptionRead, PassageRead


class PracticeCreate(BaseModel):
    """Untimed practice. Without filters it is a mixed session."""

    model_config = ConfigDict(extra="forbid")

    exam_code: Annotated[str, StringConstraints(max_length=32)] | None = None
    subject: Annotated[str, StringConstraints(max_length=100)] | None = None
    section: Annotated[str, StringConstraints(max_length=120)] | None = None
    topic_id: uuid.UUID | None = None
    # Questions not yet reviewed are excluded unless the learner opts in (and are labelled).
    include_unverified: bool = False
    count: int = Field(default=10, ge=1, le=100)


class MockCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_format_code: Annotated[str, StringConstraints(min_length=1, max_length=64)]


class AnswerUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    selected_position: int | None = Field(default=None, ge=1, le=6)
    # Monotonic per device (e.g. microseconds since epoch). Older updates are ignored.
    client_seq: int = Field(ge=0)
    time_spent_ms: int | None = Field(default=None, ge=0, le=24 * 3600 * 1000)


class Feedback(BaseModel):
    correct_position: int
    is_correct: bool | None
    explanation: str | None


class ItemSource(BaseModel):
    document_filename: str | None
    page: int | None
    question_number: int | None


class SessionItemRead(BaseModel):
    position: int
    question_id: uuid.UUID | None
    section: str | None
    subject: str | None
    stem: str | None  # None if the question was deleted after the session started
    options: list[OptionRead]
    passage: PassageRead | None
    origin: Literal["source", "ai"] | None
    verified: bool
    source: ItemSource
    bookmarked: bool
    selected_position: int | None
    # Practice: shown once answered. Mock: shown only after submission.
    feedback: Feedback | None


class TallyRead(BaseModel):
    correct: int
    wrong: int
    unattempted: int
    score: float
    max_score: float
    accuracy: float | None
    explanation: str


class SectionResult(TallyRead):
    name: str


class TopicResult(TallyRead):
    topic_id: str
    name: str


class SessionResult(TallyRead):
    time_taken_seconds: int
    marking_note: str
    sections: list[SectionResult]
    topics: list[TopicResult]


class FormatRef(BaseModel):
    code: str
    name: str


class SessionRead(BaseModel):
    id: uuid.UUID
    mode: Literal["practice", "mock"]
    status: Literal["active", "submitted"]
    exam_code: str | None
    exam_format: FormatRef | None
    started_at: datetime
    deadline_at: datetime | None
    submitted_at: datetime | None
    submit_reason: Literal["user", "time_up"] | None
    server_now: datetime
    remaining_seconds: int | None
    item_count: int
    answered_count: int
    items: list[SessionItemRead]
    result: SessionResult | None


class SessionSummary(BaseModel):
    id: uuid.UUID
    mode: Literal["practice", "mock"]
    status: Literal["active", "submitted"]
    exam_code: str | None
    exam_format_name: str | None
    started_at: datetime
    submitted_at: datetime | None
    item_count: int
    score: float | None
    max_score: float | None


class SessionList(BaseModel):
    items: list[SessionSummary]
    total: int


class AnswerAck(BaseModel):
    position: int
    selected_position: int | None
    applied: bool  # False when the update was older than the stored one or the answer is locked
    feedback: Feedback | None


class SectionAvailability(BaseModel):
    subject: str
    needed: int
    available: int


class MockAvailability(BaseModel):
    exam_format_code: str
    exam_code: str
    name: str
    available: bool
    total_questions: int
    duration_minutes: int | None
    negative_marks_per_wrong: float | None
    sections: list[SectionAvailability]


class QuestionHistory(BaseModel):
    question_id: uuid.UUID
    attempts: int
    correct: int
    wrong: int
    last_result: Literal["correct", "wrong"] | None
    last_answered_at: datetime | None
    bookmarked: bool
