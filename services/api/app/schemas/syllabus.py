import uuid
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

from app.domain.syllabus_tree import MAX_DEPTH, MAX_NODES, outline_size

NodeName = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
Keyword = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=60)]
LevelLabel = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=30)]
EffectiveYear = Annotated[int, Field(ge=1900, le=2100)]


class SyllabusNodeInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: NodeName
    level_label: LevelLabel | None = None
    keywords: list[Keyword] = Field(default=[], max_length=60)
    aliases: list[NodeName] = Field(default=[], max_length=20)
    children: list["SyllabusNodeInput"] = []


class SyllabusTreeInput(BaseModel):
    """A whole tree, within the limits of app/domain/syllabus_tree.py."""

    model_config = ConfigDict(extra="forbid")

    tree: list[SyllabusNodeInput] = Field(min_length=1)

    @model_validator(mode="after")
    def _fits(self) -> "SyllabusTreeInput":
        count, depth = outline_size(self.tree)
        if count > MAX_NODES or depth > MAX_DEPTH:
            raise ValueError(f"At most {MAX_NODES} items, {MAX_DEPTH} levels deep.")
        return self


class SyllabusVersionCreate(SyllabusTreeInput):
    """A learner's own syllabus: built by hand, or reviewed from a PDF."""

    name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
    effective_year: EffectiveYear | None = None
    source_kind: Literal["pdf", "manual"] = "manual"


class SyllabusNodeRead(BaseModel):
    id: uuid.UUID
    name: str
    level_label: str | None
    keywords: list[str]
    aliases: list[str]
    topic_id: uuid.UUID | None
    children: list["SyllabusNodeRead"] = []


class SyllabusVersionRead(BaseModel):
    id: uuid.UUID
    exam_code: str
    effective_year: int | None  # null: from the start, no year recorded
    name: str
    source_kind: str
    source_title: str | None
    source_url: str | None
    own: bool
    in_force: bool  # the version that applies this year
    tree: list[SyllabusNodeRead]
