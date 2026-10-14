"""Sync payloads. Each entity has a strict schema with the same limits as the app, so a
device can never store malformed or oversized data on the server."""

from datetime import date, datetime
from typing import Annotated, Any, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator

Short = Annotated[str, StringConstraints(max_length=100)]
Label = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
ItemId = Annotated[
    str, StringConstraints(min_length=1, max_length=64, pattern=r"^[A-Za-z0-9_\-]+$")
]


class _Payload(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ConceptData(_Payload):
    exam_code: Annotated[str, StringConstraints(min_length=1, max_length=32)]
    title: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
    notes: Annotated[str, StringConstraints(max_length=20000)] = ""
    subject: Label
    topic: Label
    subtopic: Short | None = None
    language: Literal["en", "hi"]
    tags: list[Annotated[str, StringConstraints(max_length=50)]] = Field(default=[], max_length=20)
    source_reference: Annotated[str, StringConstraints(max_length=500)] | None = None
    archived_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class StudyProfileData(_Payload):
    exam_codes: list[Annotated[str, StringConstraints(max_length=32)]] = Field(
        default=[], max_length=10
    )
    target_exam_date: date | None = None
    daily_study_minutes: int | None = Field(default=None, ge=5, le=720)
    reminder_minutes: int | None = Field(default=None, ge=0, le=24 * 60 - 1)
    onboarding_completed_at: datetime | None = None
    updated_at: datetime


class RevisionCardData(_Payload):
    kind: Literal["concept", "question"]
    concept_id: ItemId | None = None
    question_id: ItemId | None = None
    front: Annotated[str, StringConstraints(max_length=10000)] | None = None
    back: Annotated[str, StringConstraints(max_length=10000)] | None = None
    source_filename: Annotated[str, StringConstraints(max_length=255)] | None = None
    source_page: int | None = Field(default=None, ge=1)
    exam_code: Annotated[str, StringConstraints(max_length=32)] | None = None
    subject: Short | None = None
    topic: Short | None = None
    reason: Literal["added", "incorrect_answer"] = "added"
    step: int = Field(ge=0, le=50)
    gap_days: int = Field(ge=1, le=365)
    due_on: date
    review_count: int = Field(default=0, ge=0)
    lapse_count: int = Field(default=0, ge=0)
    last_reviewed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class CardReviewData(_Payload):
    card_id: ItemId
    reviewed_at: datetime
    rating: Literal["again", "hard", "good", "easy"]
    due_before: date
    due_after: date
    gap_days: int = Field(ge=1, le=365)


class SettingData(_Payload):
    value: Annotated[str, StringConstraints(max_length=200)]


ENTITY_SCHEMAS: dict[str, type[_Payload]] = {
    "concept": ConceptData,
    "study_profile": StudyProfileData,
    "revision_card": RevisionCardData,
    "card_review": CardReviewData,
    "setting": SettingData,
}
# Singletons and settings use fixed keys instead of UUIDs.
FIXED_IDS: dict[str, set[str]] = {
    "study_profile": {"profile"},
    "setting": {"revision_day_offsets"},
}

EntityName = Literal["concept", "study_profile", "revision_card", "card_review", "setting"]


class Change(BaseModel):
    model_config = ConfigDict(extra="forbid")

    entity: EntityName
    id: ItemId
    deleted: bool = False
    # Required unless deleted; validated against the entity's schema by the service.
    data: dict[str, Any] | None = None

    @field_validator("data")
    @classmethod
    def _small(cls, value: dict[str, Any] | None) -> dict[str, Any] | None:
        if value is not None and len(str(value)) > 40_000:
            raise ValueError("Record is too large.")
        return value


class PushRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    changes: list[Change] = Field(max_length=500)


class PushResult(BaseModel):
    accepted: int
    # Records the server will not change because they were deleted (tombstones win).
    ignored_deleted: list[str]
    # Records rejected by validation, with the reason ("entity:id": message).
    rejected: dict[str, str]


class ServerChange(BaseModel):
    entity: EntityName
    id: str
    deleted: bool
    data: dict[str, Any] | None
    seq: int
    updated_at: datetime


class PullResult(BaseModel):
    changes: list[ServerChange]
    # Pass back as `cursor` on the next pull.
    cursor: int
    has_more: bool
