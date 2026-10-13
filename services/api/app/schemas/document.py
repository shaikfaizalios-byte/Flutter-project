import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict

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
    created_at: datetime
    updated_at: datetime
    processing_started_at: datetime | None
    processing_finished_at: datetime | None


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
