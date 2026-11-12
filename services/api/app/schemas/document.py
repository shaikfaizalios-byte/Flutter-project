import uuid
from datetime import date, datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

from app.schemas.language import Language

DocumentStatusLiteral = Literal["queued", "processing", "completed", "failed"]


class DocumentRead(BaseModel):
    """Public view of an uploaded document. Internal storage details are never exposed."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    exam_code: str
    language: Language
    original_filename: str
    size_bytes: int
    sha256: str
    page_count: int
    pages_processed: int
    needs_review_count: int
    status: DocumentStatusLiteral
    extraction_summary: Literal["text", "ocr", "mixed", "none"] | None
    error_code: str | None
    exam_format_id: uuid.UUID | None
    segmentation_status: Literal["pending", "completed", "failed"]
    questions_found: int
    # Questions that still have an open review issue (not rejected): "9 need a look".
    questions_to_check: int = 0
    # Reading with AI (asked by the learner when the rules found too little).
    ai_read_status: Literal["none", "queued", "running", "completed", "failed"]
    ai_read_pages_done: int
    ai_read_error: str | None
    # When the paper was held: suggested from the file name / first page, then confirmed.
    exam_year: int | None
    exam_date: date | None
    exam_shift: int | None
    paper_date_status: Literal["unknown", "suggested", "confirmed"]
    stage: str | None = None
    session_label: str | None = None
    set_code: str | None = None
    extra_languages: list[str] = []
    duplicate_of_id: uuid.UUID | None = None
    # PrepLoop's made-up sample paper, not a real exam paper (always labelled in the app).
    is_sample: bool = False
    paper_date_reason: str | None
    created_at: datetime
    updated_at: datetime
    processing_started_at: datetime | None
    processing_finished_at: datetime | None


class PaperDetailsUpdate(BaseModel):
    """Only what the request states changes. ``duplicate_of_id``: this paper is another set of
    that one, and counts once."""

    model_config = ConfigDict(extra="forbid")

    stage: Annotated[str, StringConstraints(strip_whitespace=True, max_length=60)] | None = None
    session_label: (
        Annotated[str, StringConstraints(strip_whitespace=True, max_length=40)] | None
    ) = None
    set_code: Annotated[str, StringConstraints(strip_whitespace=True, max_length=20)] | None = None
    extra_languages: list[Annotated[str, StringConstraints(pattern=r"^[a-z]{2,3}$")]] = Field(
        default=[], max_length=20
    )
    duplicate_of_id: uuid.UUID | None = None


class AnswerKeyText(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=50_000)]


class AnswerKeyResult(BaseModel):
    read_by: str  # text, ocr, mixed, none or typed
    applied: int
    agreed: int  # already had the same answer
    conflicts: int  # flagged for a person; nothing was overwritten
    unmatched: list[int]  # key numbers with no such question
    ambiguous: bool  # numbers repeat in the paper, so nothing could be matched
    without_answer: int  # questions still without one
    problems: list[str]


class DuplicateSuggestion(BaseModel):
    document_id: uuid.UUID
    filename: str
    set_code: str | None
    shared_share: float


class PaperDateUpdate(BaseModel):
    """The reviewer's confirmed date of the paper. All null = "date unknown" (confirmed)."""

    model_config = ConfigDict(extra="forbid")

    exam_year: int | None = Field(default=None, ge=1990, le=2100)
    exam_date: date | None = None
    exam_shift: int | None = Field(default=None, ge=1, le=9)

    @model_validator(mode="after")
    def _date_matches_year(self) -> "PaperDateUpdate":
        if self.exam_date is not None:
            if self.exam_year is None:
                self.exam_year = self.exam_date.year
            elif self.exam_year != self.exam_date.year:
                raise ValueError("exam_date must be in exam_year")
        return self


class DocumentPageList(BaseModel):
    items: list[DocumentRead]
    total: int
    limit: int
    offset: int


class PageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    page_number: int
    method: Literal["text", "ocr", "none"]
    text: str
    char_count: int
    ocr_confidence: float | None
    needs_review: bool
    review_reasons: list[str]
    # devanagari | latin | mixed | none; null for pages read before scripts were recorded.
    script: str | None = None


class PageList(BaseModel):
    items: list[PageRead]
    total: int
    limit: int
    offset: int
