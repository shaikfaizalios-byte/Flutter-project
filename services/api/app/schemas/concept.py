import uuid
from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator

Language = Literal["en", "hi"]
Title = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
Label = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
OptionalLabel = Annotated[str, StringConstraints(strip_whitespace=True, max_length=100)]
Tag = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=50)]
Notes = Annotated[str, StringConstraints(max_length=20_000)]
SourceReference = Annotated[str, StringConstraints(strip_whitespace=True, max_length=500)]

MAX_TAGS = 20


def _normalise_tags(tags: list[str]) -> list[str]:
    """Lower-case and de-duplicate while keeping the user's order."""
    seen: dict[str, None] = {}
    for tag in tags:
        seen.setdefault(tag.lower(), None)
    return list(seen)


def _blank_to_none(value: str | None) -> str | None:
    return value or None


class ConceptCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_code: Annotated[str, StringConstraints(min_length=1, max_length=32)]
    title: Title
    notes: Notes = ""
    subject: Label
    topic: Label
    subtopic: OptionalLabel | None = None
    language: Language
    tags: list[Tag] = Field(default_factory=list, max_length=MAX_TAGS)
    source_reference: SourceReference | None = None

    _tags = field_validator("tags")(_normalise_tags)
    _optional = field_validator("subtopic", "source_reference")(_blank_to_none)


class ConceptUpdate(BaseModel):
    """Partial update: only fields present in the request body are changed."""

    model_config = ConfigDict(extra="forbid")

    exam_code: Annotated[str, StringConstraints(min_length=1, max_length=32)] | None = None
    title: Title | None = None
    notes: Notes | None = None
    subject: Label | None = None
    topic: Label | None = None
    subtopic: OptionalLabel | None = None
    language: Language | None = None
    tags: list[Tag] | None = Field(default=None, max_length=MAX_TAGS)
    source_reference: SourceReference | None = None

    @field_validator("tags")
    @classmethod
    def _tags(cls, tags: list[str] | None) -> list[str] | None:
        return None if tags is None else _normalise_tags(tags)

    _optional = field_validator("subtopic", "source_reference")(_blank_to_none)

    @field_validator("exam_code", "title", "subject", "topic", "language", "tags", "notes")
    @classmethod
    def _not_null(cls, value: object) -> object:
        # These columns are required; an explicit null would be ambiguous.
        if value is None:
            raise ValueError("may not be null")
        return value


class ConceptRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    exam_code: str
    title: str
    notes: str
    subject: str
    topic: str
    subtopic: str | None
    language: Language
    tags: list[str]
    source_reference: str | None
    archived_at: datetime | None
    created_at: datetime
    updated_at: datetime


class ConceptPage(BaseModel):
    items: list[ConceptRead]
    total: int
    limit: int
    offset: int
