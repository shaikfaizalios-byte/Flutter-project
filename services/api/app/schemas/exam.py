import uuid
from datetime import datetime
from typing import Annotated, Literal

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
    # Catalog data set by the operator (null/empty when not recorded).
    country_code: str | None = None
    authority: str | None = None
    aliases: list[str] = []
    # Languages the exam's paper is offered in, from its official notice (ISO 639 codes, any
    # language, not only those PrepLoop supports for content; empty = not recorded).
    languages: list[str] = []


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


class CanonicalTopicRead(BaseModel):
    """The canonical topic an exam topic means (shared across exams and languages)."""

    node_id: uuid.UUID
    key: str
    label: str
    subject_label: str
    # confirmed: counts everywhere; suggested: a name match the learner hasn't confirmed yet.
    status: Literal["suggested", "confirmed"]
    reason: str | None = None


class TaxonomyTopicRead(BaseModel):
    node_id: uuid.UUID
    key: str
    label: str


class TaxonomySubjectRead(BaseModel):
    node_id: uuid.UUID
    key: str
    label: str
    topics: list[TaxonomyTopicRead]


class CanonicalDecision(BaseModel):
    """The learner says whether their topic means this canonical topic."""

    model_config = ConfigDict(extra="forbid")

    node_id: uuid.UUID
    confirmed: bool


class OwnTopicRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    subject: str
    name: str
    keywords: list[str]
    # False for shared taxonomy topics (read-only for learners).
    own: bool
    exam_codes: list[str] | None
    # The learner marked the topic as revised (their own progress, any topic).
    completed: bool = False
    # The syllabus import that added it (null for typed, AI-drafted and shared topics).
    syllabus_import_id: uuid.UUID | None = None
    # The canonical topic it means (shared topics: themselves), or a suggestion to confirm.
    canonical: CanonicalTopicRead | None = None


class SyllabusSource(BaseModel):
    """Where a saved draft came from: its topics form one section that can be removed."""

    model_config = ConfigDict(extra="forbid")

    name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=255)]
    kind: Literal["pdf", "typed"]


class TopicsBulkCreate(BaseModel):
    """Saving an accepted (and edited) topic draft in one step."""

    model_config = ConfigDict(extra="forbid")

    exam_code: Annotated[str, StringConstraints(min_length=1, max_length=32)]
    topics: list[TopicCreate] = Field(min_length=1, max_length=300)
    # Set when the draft was a syllabus: the topics are grouped under this import.
    source: SyllabusSource | None = None


class SyllabusImportRead(BaseModel):
    id: uuid.UUID
    name: str
    kind: Literal["pdf", "typed"]
    created_at: datetime
    topic_count: int  # its topics still present


class TopicCompletionUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    completed: bool


# A typed or pasted syllabus (a long one fits; the topic draft caps at 300 topics).
SYLLABUS_TEXT_MAX = 20_000


class SyllabusText(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=2, max_length=SYLLABUS_TEXT_MAX)
    ]


class TopicsBulkDelete(BaseModel):
    model_config = ConfigDict(extra="forbid")

    topic_ids: list[uuid.UUID] = Field(min_length=1, max_length=300)


class TopicsDeleted(BaseModel):
    deleted: int  # own topics removed (ids of shared or other learners' topics are skipped)


class SyllabusSubjectRead(BaseModel):
    name: str
    topics: list[str]


class SyllabusDraftRead(BaseModel):
    """Subjects and topics read from a syllabus PDF. Nothing is saved: the learner keeps what
    they want with POST /topics/bulk."""

    exam_code: str
    pages: int
    # "typed" = the learner wrote or pasted the syllabus (pages is then 0).
    read_by: Literal["text", "ocr", "mixed", "none", "typed"]
    unreadable_pages: int  # pages the reader couldn't read reliably (scan quality)
    subjects: list[SyllabusSubjectRead]
    topic_count: int
    truncated: bool  # the PDF listed more topics than one draft holds


class PatternCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    topic_id: uuid.UUID
    name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
    keywords: list[Keyword] = Field(default_factory=list, max_length=30)
