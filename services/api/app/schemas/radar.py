import uuid

from pydantic import BaseModel, ConfigDict


class RadarSettings(BaseModel):
    share: bool
    # This account's papers that could join (confirmed date and shift, classified questions).
    eligible_papers: int
    # Accounts that must agree before a shift is counted.
    min_accounts: int


class RadarSettingsUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    share: bool


class RadarYear(BaseModel):
    year: int
    shifts: int


class RadarCounts(BaseModel):
    shifts: int  # published shifts it appeared in
    questions: int  # agreed questions over those shifts
    years: list[RadarYear]


class RadarPattern(BaseModel):
    pattern_id: uuid.UUID
    name: str
    counts: RadarCounts


class RadarTopic(BaseModel):
    topic_id: uuid.UUID
    subject: str
    name: str
    counts: RadarCounts
    patterns: list[RadarPattern]


class RadarBasis(BaseModel):
    shifts: int  # published shifts (each agreed by >= min_accounts accounts)
    years: list[int]
    min_accounts: int
    # Topic/pattern counts withheld across those shifts because accounts disagreed.
    withheld: int


class RadarReport(BaseModel):
    exam_code: str | None
    basis: RadarBasis
    topics: list[RadarTopic]
