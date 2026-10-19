import uuid
from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

from app.schemas.question import FigureRead, OptionRead, PassageRead


class PracticeCreate(BaseModel):
    """Untimed practice. Without filters it is a mixed session."""

    model_config = ConfigDict(extra="forbid")

    exam_code: Annotated[str, StringConstraints(max_length=32)] | None = None
    subject: Annotated[str, StringConstraints(max_length=100)] | None = None
    section: Annotated[str, StringConstraints(max_length=120)] | None = None
    topic_id: uuid.UUID | None = None
    pattern_id: uuid.UUID | None = None
    # Questions not yet reviewed are excluded unless the learner opts in (and are labelled).
    include_unverified: bool = False
    # AI-generated questions are excluded unless the learner opts in (and are labelled).
    # Mock tests never use them.
    include_ai: bool = False
    # Verified questions from the shared bank (papers the operator shared, labelled as such).
    include_shared: bool = True
    count: int = Field(default=10, ge=1, le=100)


class OfflineQuestion(BaseModel):
    """A practice question saved on the device, with its answer, for practising offline."""

    id: uuid.UUID
    exam_code: str
    section: str | None
    subject: str | None
    topic_id: uuid.UUID | None
    pattern_id: uuid.UUID | None
    stem: str
    passage: PassageRead | None
    options: list[OptionRead]
    answer_type: Literal["choice", "typed"]
    correct_position: int | None
    typed_answer: str | None
    typed_answer_numeric: bool
    explanation: str | None  # from the paper (AI explanations stay online)
    shared: bool
    shared_source: str | None
    document_filename: str | None
    page: int | None
    question_number: int | None


class OfflinePack(BaseModel):
    questions: list[OfflineQuestion]
    limit: int
    generated_at: datetime


class OfflineAnswer(BaseModel):
    model_config = ConfigDict(extra="forbid")

    question_id: uuid.UUID
    selected_position: int | None = Field(default=None, ge=1, le=6)
    typed_answer: (
        Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
        | None
    ) = None
    answered_at: datetime | None = None
    time_spent_ms: int | None = Field(default=None, ge=0, le=24 * 3600 * 1000)


class OfflineSessionUpload(BaseModel):
    """A practice session done offline on the device. The server checks every answer again;
    the device's own marking is never trusted."""

    model_config = ConfigDict(extra="forbid")

    client_id: uuid.UUID  # made on the device; re-uploads of the same session are ignored
    exam_code: Annotated[str, StringConstraints(max_length=32)] | None = None
    started_at: datetime
    finished_at: datetime
    items: list[OfflineAnswer] = Field(min_length=1, max_length=100)


class MockCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_format_code: Annotated[str, StringConstraints(min_length=1, max_length=64)]


class AnswerUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    selected_position: int | None = Field(default=None, ge=1, le=6)
    # The answer of a typed-in question (instead of selected_position).
    typed_answer: (
        Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
        | None
    ) = None
    # Monotonic per device (e.g. microseconds since epoch). Older updates are ignored.
    client_seq: int = Field(ge=0)
    time_spent_ms: int | None = Field(default=None, ge=0, le=24 * 3600 * 1000)


class Feedback(BaseModel):
    correct_position: int | None  # None for a typed-in question
    correct_typed_answer: str | None = None  # the expected answer of a typed-in question
    is_correct: bool | None
    explanation: str | None
    # "source": from the paper (or the reviewer); "ai": AI-generated (an AI question's own
    # explanation, or an approved AI explanation for a source question).
    explanation_origin: Literal["source", "ai"] | None


class ItemSource(BaseModel):
    document_filename: str | None
    page: int | None
    question_number: int | None
    # Shared bank question: where the shared paper came from (the file name is not shown).
    shared_source: str | None = None


class SessionItemRead(BaseModel):
    position: int
    question_id: uuid.UUID | None
    section: str | None
    subject: str | None
    stem: str | None  # None if the question was deleted after the session started
    options: list[OptionRead]
    # Figures cropped from the source paper (fetch via /questions/{question_id}/figures/{id}).
    figures: list[FigureRead]
    passage: PassageRead | None
    origin: Literal["source", "ai"] | None
    verified: bool
    source: ItemSource
    bookmarked: bool
    # From the shared bank (another account's paper): read-only, can't be bookmarked.
    shared: bool = False
    selected_position: int | None
    answer_type: Literal["choice", "typed"] = "choice"
    typed_answer: str | None = None  # what the learner typed
    # Whether the expected typed answer is a number (show a number keyboard).
    typed_answer_numeric: bool = False
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
    submit_reason: Literal["user", "time_up", "offline"] | None
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
    typed_answer: str | None = None
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
