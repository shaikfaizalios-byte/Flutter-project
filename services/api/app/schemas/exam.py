import uuid
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
Subject = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
Keyword = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=60)]


class ExamRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    code: str
    name: str
    short_name: str = ""  # display name: the short name, else the name
    category: str | None = None
    featured: bool = False
    # True for an exam the learner created (private to them).
    custom: bool = False


class CustomExamCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: Name


class CustomExamUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: Name


class TopicCreate(BaseModel):
    """A learner's own topic for one exam (catalog or own)."""

    model_config = ConfigDict(extra="forbid")

    exam_code: Annotated[str, StringConstraints(min_length=1, max_length=32)]
    subject: Subject
    name: Name
    keywords: list[Keyword] = Field(default_factory=list, max_length=30)


class TopicUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    subject: Subject | None = None
    name: Name | None = None
    keywords: list[Keyword] | None = Field(default=None, max_length=30)


class OwnTopicRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    subject: str
    name: str
    keywords: list[str]
    # False for shared taxonomy topics (read-only for learners).
    own: bool
    exam_codes: list[str] | None


class TopicsBulkCreate(BaseModel):
    """Saving an accepted (and edited) topic draft in one step."""

    model_config = ConfigDict(extra="forbid")

    exam_code: Annotated[str, StringConstraints(min_length=1, max_length=32)]
    topics: list[TopicCreate] = Field(min_length=1, max_length=120)


class PatternCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    topic_id: uuid.UUID
    name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
    keywords: list[Keyword] = Field(default_factory=list, max_length=30)
