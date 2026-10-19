import uuid
from datetime import date, datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

VerificationLiteral = Literal["unverified", "verified", "rejected"]


class TopicRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    subject: str
    name: str


class PatternRead(BaseModel):
    """A named question type within a topic."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    topic_id: uuid.UUID
    name: str


class ExamFormatSection(BaseModel):
    part: str
    subject: str
    questions: int
    max_marks: int | None = None
    # Sectional timer from the notice, when it sets one (mocks keep one overall timer).
    timer_minutes: int | None = None


class ExamFormatRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    code: str
    exam_code: str
    tier: str
    name: str
    sections: list[ExamFormatSection]
    sections_in_fixed_order: bool
    total_questions: int
    duration_minutes: int | None
    negative_marks_per_wrong: float | None
    source_title: str
    source_url: str
    source_reference: str
    source_published_on: date
    verified_on: date


class OptionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    position: int
    label: str
    text: str


class FigureRead(BaseModel):
    """An image cropped from the question's source PDF page (fetch it from
    ``/questions/{question_id}/figures/{id}``)."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    # stem: a figure in the question; option: an option that is a figure;
    # original: the whole question as printed (its text could not be read in full).
    kind: Literal["stem", "option", "original"]
    option_position: int | None
    page_number: int
    width: int
    height: int


class IssueRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    code: str
    detail: str
    resolved: bool


class PassageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    text: str
    first_question: int | None
    last_question: int | None
    source_pages: list[int]


class AIProvenance(BaseModel):
    """How an AI question was made. AI questions are never official questions."""

    provider: str
    model: str
    prompt_version: str
    source_question_id: uuid.UUID | None
    source_note: str | None


class AIExplanationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    question_id: uuid.UUID
    text: str
    language: Literal["en", "hi"]
    model_confident: bool
    provider: str
    model: str
    prompt_version: str
    status: Literal["draft", "approved", "rejected"]
    edited: bool
    created_at: datetime
    reviewed_at: datetime | None


class VerifyCleanResult(BaseModel):
    verified: int  # questions verified now
    left_for_review: int  # unverified questions that still need a reviewer


class QuestionRead(BaseModel):
    id: uuid.UUID
    origin: Literal["source", "ai"]
    exam_code: str
    section: str | None
    subject: str | None
    topic: TopicRead | None
    topic_status: Literal["unassigned", "suggested", "confirmed"]
    topic_suggested_by: Literal["keywords", "ai"] | None
    # Why it was suggested ("Matched ..." or the AI model), while the topic is suggested.
    topic_suggestion_reason: str | None
    # Question type within the topic; suggested by keyword rules, confirmed by a reviewer.
    pattern: PatternRead | None
    pattern_status: Literal["unassigned", "suggested", "confirmed"]
    pattern_suggestion_reason: str | None
    stem: str
    language: Literal["en", "hi"]
    document_id: uuid.UUID | None
    document_filename: str | None
    source_question_number: int | None
    source_pages: list[int]
    passage: PassageRead | None
    options: list[OptionRead]
    correct_option_position: int | None
    # "choice": pick an option; "typed": type the answer in (TITA), see typed_answer.
    answer_type: Literal["choice", "typed"]
    typed_answer: str | None
    # Whether typed_answer is a number (the app shows a number keyboard).
    typed_answer_numeric: bool
    answer_source: str | None
    explanation: str | None
    image_dependent: bool
    figures: list[FigureRead]
    verification_status: VerificationLiteral
    verified_at: datetime | None
    issues: list[IssueRead]
    open_issue_count: int
    # Set for origin = ai.
    ai: AIProvenance | None
    # Latest AI explanation that is not rejected (source questions without an explanation).
    ai_explanation: AIExplanationRead | None
    created_at: datetime
    updated_at: datetime
    # Shared bank: a question from a paper the operator shared with every learner. It is
    # read-only for everyone but its owner; `shared_source` says where the paper came from.
    read_only: bool = False
    shared_source: str | None = None


class QuestionList(BaseModel):
    items: list[QuestionRead]
    total: int
    limit: int
    offset: int


OptionText = Annotated[str, StringConstraints(strip_whitespace=True, max_length=2000)]
Label = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=8)]


class OptionInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    label: Label
    text: OptionText


class QuestionUpdate(BaseModel):
    """Reviewer edits. Only fields present are changed; null clears nullable fields."""

    model_config = ConfigDict(extra="forbid")

    stem: (
        Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=10_000)]
        | None
    ) = None
    options: list[OptionInput] | None = Field(default=None, min_length=2, max_length=6)
    correct_option_position: int | None = Field(default=None, ge=1, le=6)
    answer_type: Literal["choice", "typed"] | None = None
    typed_answer: (
        Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
        | None
    ) = None
    explanation: Annotated[str, StringConstraints(max_length=10_000)] | None = None
    section: Annotated[str, StringConstraints(strip_whitespace=True, max_length=120)] | None = None
    subject: Annotated[str, StringConstraints(strip_whitespace=True, max_length=100)] | None = None
    topic_id: uuid.UUID | None = None
    # Must belong to the question's topic (after any topic change in the same request).
    pattern_id: uuid.UUID | None = None
    image_dependent: bool | None = None
    verification_status: VerificationLiteral | None = None


class PaperDateRead(BaseModel):
    exam_year: int | None
    exam_date: date | None
    exam_shift: int | None
    status: Literal["unknown", "suggested", "confirmed"]
    reason: str | None  # why it was suggested (while suggested)


class ParseSummary(BaseModel):
    document_id: uuid.UUID
    segmentation_status: Literal["pending", "completed", "failed"]
    questions_found: int
    verified: int
    rejected: int
    with_open_issues: int
    missing_answers: int
    image_dependent: int
    with_figures: int
    unreadable_text: int
    topics_suggested: int
    topics_unassigned: int
    # Unassigned questions the AI has not been asked about yet.
    topics_ai_pending: int
    # Questions with a suggested (not yet accepted) pattern.
    patterns_suggested: int
    sections: list[str]
    paper_date: PaperDateRead
    exam_format: ExamFormatRead | None
    document_issues: list[IssueRead]


class TopicAcceptResult(BaseModel):
    accepted: int  # topics confirmed
    patterns_accepted: int = 0


class DocumentFormatUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_format_code: str | None
