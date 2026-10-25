import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

DocumentStatusLiteral = Literal["queued", "processing", "completed", "failed"]


class DocumentRead(BaseModel):
    """Public view of an uploaded document. Internal storage details are never exposed."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    exam_code: str
    language: Literal["en", "hi"]
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
    # Reading with AI (asked by the learner when the rules found too little).
    ai_read_status: Literal["none", "queued", "running", "completed", "failed"]
    ai_read_pages_done: int
    ai_read_error: str | None
    # When the paper was held: suggested from the file name / first page, then confirmed.
    exam_year: int | None
    exam_date: date | None
    exam_shift: int | None
    paper_date_status: Literal["unknown", "suggested", "confirmed"]
    paper_date_reason: str | None
    created_at: datetime
    updated_at: datetime
    processing_started_at: datetime | None
    processing_finished_at: datetime | None


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


class PageList(BaseModel):
    items: list[PageRead]
    total: int
    limit: int
    offset: int
