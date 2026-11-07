"""The curated question library. Search and packs for learners, review for content staff."""

import uuid
from typing import Annotated, Any, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

from app.schemas.language import Language
from app.schemas.practice import OfflineQuestion
from app.schemas.question import FigureRead, OptionRead

SourceType = Literal["official_pyq", "original_expert", "original_ai_verified"]
Rights = Literal["licensed", "owned", "pending"]
Level = Literal["easy", "medium", "hard"]
Reason = Annotated[str, StringConstraints(strip_whitespace=True, min_length=3, max_length=500)]
Stem = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=10_000)]


class NewOption(BaseModel):
    model_config = ConfigDict(extra="forbid")

    label: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=8)]
    text: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=2000)]


class LibraryCreate(BaseModel):
    """A question of the editor's own imported paper, or a new one written for the library."""

    model_config = ConfigDict(extra="forbid")

    question_id: uuid.UUID | None = None
    source_type: SourceType
    rights_status: Rights = "pending"
    rights_note: Annotated[str, StringConstraints(max_length=500)] | None = None
    difficulty: Level
    exam_year: int | None = Field(default=None, ge=1950, le=2100)
    exam_code: str | None = None
    topic_id: uuid.UUID | None = None
    language: Language = "en"
    stem: Stem | None = None
    options: list[NewOption] = Field(default=[], max_length=10)
    correct_option_position: int | None = Field(default=None, ge=1, le=10)
    explanation: Annotated[str, StringConstraints(max_length=10_000)] | None = None


class LibrarySolve(BaseModel):
    """The second reviewer's own answer, given without seeing the key."""

    model_config = ConfigDict(extra="forbid")

    selected_position: int | None = Field(default=None, ge=1, le=10)
    typed_answer: Annotated[str, StringConstraints(max_length=100)] | None = None
    response: dict[str, Any] | None = None


class LibraryRights(BaseModel):
    model_config = ConfigDict(extra="forbid")

    rights_status: Rights
    rights_note: Reason


class LibraryCorrection(BaseModel):
    """Only what changes. The reason is kept with the new version."""

    model_config = ConfigDict(extra="forbid")

    reason: Reason
    stem: Stem | None = None
    explanation: Annotated[str, StringConstraints(max_length=10_000)] | None = None
    correct_option_position: int | None = Field(default=None, ge=1, le=10)
    typed_answer: Annotated[str, StringConstraints(max_length=100)] | None = None
    answer_spec: dict[str, Any] | None = None
    report_id: uuid.UUID | None = None  # the report this answers


class LibraryWithdraw(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reason: Reason


class LibraryVersionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    version: int
    changed_by: str
    reason: str


class LibraryEntryRead(BaseModel):
    """What staff see. The key is left out, so a second solve stays independent."""

    model_config = ConfigDict(from_attributes=True)

    question_id: uuid.UUID
    source_type: SourceType
    rights_status: Rights
    rights_note: str | None
    author_name: str
    status: Literal["draft", "solved", "approved", "withdrawn"]
    solved_by_name: str | None
    approved_by_name: str | None
    version: int
    exam_year: int | None
    difficulty: Level
    observed_difficulty: Level | None
    attempts: int


class SolveResult(BaseModel):
    agrees: bool
    entry: LibraryEntryRead


class CorrectionResult(BaseModel):
    entry: LibraryEntryRead
    sessions_remarked: int


class LibraryQuestionRead(BaseModel):
    """A question as a reviewer sees it. The key stays hidden until a second person has solved it,
    so that solve is independent."""

    question_id: uuid.UUID
    exam_code: str
    stem: str
    format: str
    options: list[OptionRead]
    figures: list[FigureRead]
    correct_position: int | None
    typed_answer: str | None
    explanation: str | None


class LibraryReportRead(BaseModel):
    id: uuid.UUID
    question_id: uuid.UUID | None
    kind: str
    text: str


class ModelProposalQuestion(BaseModel):
    question_id: uuid.UUID
    text: str


class ModelProposalRead(BaseModel):
    id: uuid.UUID
    topic_id: uuid.UUID
    topic_name: str
    shifts: int
    questions: list[ModelProposalQuestion]


class ModelApproval(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=3, max_length=120)]
    question_ids: list[uuid.UUID] | None = None  # the ones to keep; none = all


class ModelsProposed(BaseModel):
    proposed: int


class ModelApproved(BaseModel):
    questions: int


class LibraryHit(BaseModel):
    question_id: uuid.UUID
    exam_code: str
    stem: str
    format: str
    source_type: SourceType
    exam_year: int | None
    difficulty: Level
    subject: str | None
    topic: str | None
    pictured: bool  # printed as a picture: open it to see the question
    percent_right: int | None  # from real attempts only


class LibraryPage(BaseModel):
    items: list[LibraryHit]
    total: int


class PackRead(BaseModel):
    key: str
    name: str
    subject: str
    questions: int
    seq: int  # the newest change: a device with this has nothing to fetch


class PackFigure(BaseModel):
    id: uuid.UUID
    question_id: uuid.UUID
    data: str  # PNG, base64


class PackQuestion(OfflineQuestion):
    library_source: SourceType
    figures: list[dict[str, Any]] = Field(default_factory=list)


class PackDelta(BaseModel):
    seq: int
    questions: list[PackQuestion]
    figures: list[PackFigure]
    removed: list[uuid.UUID]
