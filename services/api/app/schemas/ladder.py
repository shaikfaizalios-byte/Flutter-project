"""Challenge Ladder. A step never carries its answer before the learner has answered it."""

import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.language import Language

Difficulty = Literal["easy", "medium", "medium_hard", "hard", "extreme_hard"]


class LadderStart(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_code: str
    topic_id: uuid.UUID
    language: Language = "en"


class LadderAnswer(BaseModel):
    model_config = ConfigDict(extra="forbid")

    selected_index: int = Field(ge=0, le=9)
    time_spent_ms: int | None = Field(default=None, ge=0, le=24 * 3600 * 1000)


class LadderResult(BaseModel):
    """What the learner sees once they have answered."""

    selected_index: int
    correct: bool
    answer_index: int
    solution: list[str]
    shortcut: str
    time_spent_ms: int | None


class LadderStepRead(BaseModel):
    round_number: int
    step: int
    difficulty: Difficulty
    model_name: str | None
    second_model_name: str | None
    ready: bool
    source: Literal["ai", "paper"] | None
    basis_papers: int
    basis_web: bool
    paper_label: str | None
    stem: str | None
    options: list[str] | None
    time_target_seconds: int | None
    result: LadderResult | None


class LadderRoundRead(BaseModel):
    session_id: uuid.UUID
    round_number: int
    topic_name: str
    subject: str
    source_mix: Literal["papers", "web_main", "web_only"]
    steps: list[LadderStepRead]


class LadderTopic(BaseModel):
    topic_id: uuid.UUID
    name: str
    subject: str
    papers: int  # reviewed papers it appeared in (0: not in the learner's papers yet)


class LadderBest(BaseModel):
    step: int
    topic_name: str


class LadderOverview(BaseModel):
    """Topics for the exam, most repeated first; ``best`` is the learner's own best climb."""

    topics: list[LadderTopic]
    best: LadderBest | None
