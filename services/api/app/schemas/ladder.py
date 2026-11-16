"""Challenge Ladder. A step never carries its answer before the learner has answered it."""

import uuid
from typing import Any, Literal, Self

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.schemas.language import Language

Difficulty = Literal["easy", "medium", "medium_hard", "hard", "extreme_hard"]


class LadderStart(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_code: str
    # What the ladder is on, exactly one of: a topic; one of the learner's papers; all of the
    # exam's papers; a topic the learner typed (the AI writes from web references only).
    topic_id: uuid.UUID | None = None
    document_id: uuid.UUID | None = None
    all_papers: bool = False
    topic_name: str | None = Field(default=None, max_length=100)
    language: Language = "en"
    # The app can show formats beyond one correct option. Without it, questions stay in that one.
    include_new_formats: bool = False

    @field_validator("topic_name")
    @classmethod
    def _typed_topic(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = " ".join(value.split())
        if len(value) < 2:
            raise ValueError("Type a topic of at least 2 characters.")
        return value

    @model_validator(mode="after")
    def _one_basis(self) -> Self:
        given = (
            self.topic_id is not None,
            self.document_id is not None,
            self.all_papers,
            self.topic_name is not None,
        )
        if sum(given) != 1:
            raise ValueError("Choose one: a topic, a paper, all papers or a typed topic.")
        return self


class LadderAnswer(BaseModel):
    model_config = ConfigDict(extra="forbid")

    selected_index: int | None = Field(default=None, ge=0, le=9)
    typed_answer: str | None = Field(default=None, min_length=1, max_length=100)
    response: dict[str, Any] | None = None
    time_spent_ms: int | None = Field(default=None, ge=0, le=24 * 3600 * 1000)

    @model_validator(mode="after")
    def _one_answer(self) -> Self:
        given = (self.selected_index, self.typed_answer, self.response)
        if sum(value is not None for value in given) != 1:
            raise ValueError("Give one answer.")
        return self


class LadderResult(BaseModel):
    """What the learner sees once they have answered."""

    selected_index: int | None
    correct: bool
    answer_index: int | None
    solution: list[str]
    shortcut: str
    time_spent_ms: int | None
    response: dict[str, Any] | None = None
    answer_lines: list[str] = []  # the right answer in words, when no single option shows it
    partly_right: bool = False  # not correct, but earned marks under the exam's rule
    marks: float | None = None  # null: the exam states no marks for this subject
    marks_possible: float | None = None


class LadderStepRead(BaseModel):
    round_number: int
    step: int
    difficulty: Difficulty
    model_name: str | None
    second_model_name: str | None
    ready: bool
    source: Literal["ai", "paper", "library"] | None
    # How a generated question was checked: {"solves": 3, "recalculated": true}.
    checks: dict[str, Any] | None = None
    basis_papers: int
    basis_web: bool
    paper_label: str | None
    stem: str | None
    options: list[str] | None
    time_target_seconds: int | None
    format: str = "single_correct"
    format_data: dict[str, list[str]] | None = None  # a match question's lists
    result: LadderResult | None


class LadderRoundRead(BaseModel):
    session_id: uuid.UUID
    round_number: int
    topic_name: str
    subject: str
    source_mix: Literal["papers", "web_main", "web_only"]
    basis: Literal["topic", "paper", "papers", "typed"] = "topic"
    # A paper ladder whose examples include questions nobody reviewed yet.
    unreviewed_seeds: bool = False
    steps: list[LadderStepRead]


class LadderTopic(BaseModel):
    topic_id: uuid.UUID
    name: str
    subject: str
    papers: int  # reviewed papers it appeared in (0: not in the learner's papers yet)


class LadderPaper(BaseModel):
    """One of the learner's papers for the exam, with the questions a ladder can use."""

    document_id: uuid.UUID
    name: str
    questions: int
    reviewed: int


class LadderBest(BaseModel):
    step: int
    topic_name: str


class LadderOverview(BaseModel):
    """Topics for the exam, most repeated first; ``best`` is the learner's own best climb."""

    topics: list[LadderTopic]
    # The learner's papers for the exam that have questions a ladder can use, newest first.
    papers: list[LadderPaper] = []
    best: LadderBest | None
    available: bool = True  # false: the exam has no multiple-choice paper to practise for
    # Without PrepLoop Plus: free ladders a day (one round each; the day is UTC) and how many
    # are left today. `free_left_today` is null when the account needs no free ladder (Plus
    # is on, or this server doesn't ask for Plus).
    free_per_day: int = 0
    free_left_today: int | None = None
