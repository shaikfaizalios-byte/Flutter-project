import uuid
from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, StringConstraints


class ContentReportCreate(BaseModel):
    """A learner reports a shared paper or one of its questions."""

    model_config = ConfigDict(extra="forbid")

    document_id: uuid.UUID | None = None
    question_id: uuid.UUID | None = None
    # rights: it shouldn't be shared (copyright, permission); error: something is wrong in it.
    kind: Literal["rights", "error", "other"]
    text: Annotated[str, StringConstraints(strip_whitespace=True, min_length=10, max_length=2000)]


class ContentReportRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    document_id: uuid.UUID | None
    question_id: uuid.UUID | None
    kind: Literal["rights", "error", "other"]
    text: str
    status: Literal["open", "upheld", "dismissed"]
    resolution: str | None
    created_at: datetime
    resolved_at: datetime | None


class StarterCheckAvailability(BaseModel):
    """Whether a new learner can take a starter check for an exam (no papers of their own)."""

    exam_code: str
    # Shared-bank questions whose recorded rights allow the starter check.
    available_questions: int
    question_count: int  # how many the check would ask (0 when unavailable)
    subjects: list[str]


class StarterCheckCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_code: Annotated[str, StringConstraints(min_length=1, max_length=32)]
