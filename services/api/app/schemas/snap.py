"""Snap a question: a photo read with OCR, then matched against the learner's own material.
Nothing is stored."""

import uuid
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, StringConstraints

SNAP_MAX_TEXT = 2000


class SnapMatch(BaseModel):
    kind: Literal["page", "question", "concept"]
    label: str  # "paper-2024.pdf, page 7", a question's paper and number, a concept's title
    snippet: str
    verified: bool  # a reviewer checked it (questions); page text is as read
    document_id: uuid.UUID | None = None
    page_number: int | None = None
    question_id: uuid.UUID | None = None
    concept_id: str | None = None


class SnapRead(BaseModel):
    # The text read from the photo, as found (whitespace and NFC only). The learner may correct
    # it and search again.
    text: str
    # The reading is unsure (low confidence or few words): the app says so.
    low_confidence: bool
    matches: list[SnapMatch]


class SnapMatchRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_code: str
    text: Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=2, max_length=SNAP_MAX_TEXT)
    ]
