"""Descriptive practice. A step never carries its rubric or model answer before it is marked."""

import uuid
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, StringConstraints

from app.domain.descriptive import MAX_ANSWER
from app.schemas.language import Language


class DescriptiveStart(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_code: str
    topic_id: uuid.UUID
    language: Language = "en"


class DescriptiveAnswer(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=1, max_length=MAX_ANSWER)
    ]
    source: Literal["typed", "photo"] = "typed"


class DescriptivePhotoRead(BaseModel):
    """What the AI read from a photo, for the learner to correct. Nothing is stored."""

    text: str
    unclear: bool


class DescriptivePointRead(BaseModel):
    point: str
    marks: float
    awarded: float
    comment: str


class DescriptiveResult(BaseModel):
    """Estimated marks from AI feedback, not an official grade."""

    marks: float
    marks_possible: float
    low: float | None  # set only when the markings disagreed
    high: float | None
    runs: int
    points: list[DescriptivePointRead]
    missing_points: list[str]
    structure: str
    relevance: str
    length: str
    word_count: int
    answer_text: str
    model_answer: str


class DescriptiveStepRead(BaseModel):
    step: int
    level: str
    marks: float
    word_limit: int  # PrepLoop's suggestion, not an exam rule
    ready: bool
    stem: str | None
    result: DescriptiveResult | None


class DescriptiveSessionRead(BaseModel):
    session_id: uuid.UUID
    topic_name: str
    subject: str
    steps: list[DescriptiveStepRead]


class DescriptiveTopic(BaseModel):
    topic_id: uuid.UUID
    name: str
    subject: str


class DescriptiveOverview(BaseModel):
    topics: list[DescriptiveTopic]
    available: bool  # false: the exam has no written paper
