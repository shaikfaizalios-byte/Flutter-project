import uuid
from typing import Literal

from pydantic import BaseModel


class YearCount(BaseModel):
    year: int
    questions: int


class RepeatCounts(BaseModel):
    """How often something appeared in the learner's own papers."""

    questions: int
    papers: int  # distinct papers it appeared in
    # Only papers with a confirmed date; questions from undated papers count above but not here.
    years: list[YearCount]


class PatternRepeat(BaseModel):
    pattern_id: uuid.UUID
    name: str
    confirmed: RepeatCounts  # reviewed: topic and pattern confirmed
    unreviewed: int  # pattern suggested, not yet confirmed


class TopicRepeat(BaseModel):
    topic_id: uuid.UUID
    subject: str
    name: str
    confirmed: RepeatCounts  # reviewed: topic confirmed
    unreviewed: int  # topic suggested, not yet confirmed
    patterns: list[PatternRepeat]
    # Confirmed questions of the topic without a confirmed pattern.
    without_pattern: int


class SimilarQuestion(BaseModel):
    question_id: uuid.UUID
    document_id: uuid.UUID
    document_filename: str
    exam_year: int | None  # confirmed paper year only
    question_number: int | None
    stem_excerpt: str
    verified: bool


class SimilarGroup(BaseModel):
    """Questions worded alike (numbers ignored) in different papers. A suggestion based on
    wording only, not a reviewed classification."""

    subject: str | None
    topic_name: str | None
    papers: int
    years: list[int]
    questions: list[SimilarQuestion]


class PapersBasis(BaseModel):
    total: int  # papers with parsed questions
    dated: int  # with a confirmed year
    undated: int
    years: list[int]  # confirmed years present


class TopicRef(BaseModel):
    topic_id: uuid.UUID
    subject: str
    name: str


class PatternGap(BaseModel):
    pattern_id: uuid.UUID
    topic_id: uuid.UUID
    topic_name: str
    name: str


class NotRepeated(BaseModel):
    """The other side of repeats, for one exam: what these papers did not ask. Not a
    prediction: a topic missing from a few papers can still be asked."""

    # Topics of the exam (shared + the learner's own) with no question in these papers.
    not_seen: list[TopicRef] = []
    # Question types of topics that did appear, never seen in these papers.
    patterns_not_seen: list[PatternGap] = []
    # Questions without a topic yet: some may belong to topics listed as not seen.
    questions_without_topic: int = 0


class RepeatsReport(BaseModel):
    exam_code: str | None
    # Which papers were counted: the learner's own, the shared bank, or both.
    scope: Literal["mine", "shared", "all"] = "mine"
    papers: PapersBasis
    topics: list[TopicRepeat]
    similar_groups: list[SimilarGroup]
    similarity_threshold: float
    not_repeated: NotRepeated = NotRepeated()
