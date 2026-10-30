import uuid
from typing import Annotated, Literal, Self

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

from app.domain.ai_content import (
    MAX_EXPLANATION,
    MAX_GENERATED,
    MIN_QUIZ_QUESTIONS,
    QUICK_ANSWER_MAX_QUERY,
    TOPIC_NAME_MAX,
)
from app.schemas.question import AIExplanationRead, QuestionRead


class AIStatus(BaseModel):
    enabled: bool
    provider: str | None
    model: str | None
    # Features available while enabled.
    features: list[
        Literal["explanations", "questions", "topics", "quick_answers", "search_answers"]
    ]
    # PrepLoop Plus: whether AI requests need a subscription, whether this account may make
    # one now, and how many are left this month (null when Plus isn't required).
    requires_plus: bool = False
    plus_active: bool = False
    ai_left_this_month: int | None = None


class ConceptInput(BaseModel):
    """A learner's own concept (device data) used as the basis for practice questions.
    It is sent to the AI provider; only the title is stored (as the source note)."""

    model_config = ConfigDict(extra="forbid")

    title: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
    notes: Annotated[str, StringConstraints(max_length=4000)] = ""
    subject: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
    topic: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]


class GenerateQuestionsRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_code: Annotated[str, StringConstraints(min_length=1, max_length=32)]
    language: Literal["en", "hi"]
    count: int = Field(default=3, ge=1, le=MAX_GENERATED)
    # Exactly one basis: a verified source question, or the learner's concept.
    source_question_id: uuid.UUID | None = None
    concept: ConceptInput | None = None

    @model_validator(mode="after")
    def _one_basis(self) -> Self:
        if (self.source_question_id is None) == (self.concept is None):
            raise ValueError("Give either source_question_id or concept.")
        return self


class GenerateQuestionsResult(BaseModel):
    # Stored as AI-generated and unverified; they need review before practice.
    created: list[QuestionRead]
    rejected: int
    # Why rejected items failed validation (codes such as "bad_answer").
    rejection_reasons: list[str]


class ExplanationReview(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: Literal["approved", "rejected"]
    # Optional corrected text (approving an edited draft).
    text: (
        Annotated[
            str, StringConstraints(strip_whitespace=True, min_length=1, max_length=MAX_EXPLANATION)
        ]
        | None
    ) = None


class DraftTopicRead(BaseModel):
    name: str
    keywords: list[str]


class DraftSubjectRead(BaseModel):
    name: str
    topics: list[DraftTopicRead]


class TopicDraft(BaseModel):
    """An AI-proposed topic list for an exam. Nothing is saved: the learner edits it and saves
    the topics they keep (POST /topics/bulk)."""

    exam_code: str
    model: str
    questions_considered: int
    subjects: list[DraftSubjectRead]


class PaperTopicsResult(BaseModel):
    # Questions sent to the AI in this request (at most a few batches per request).
    considered: int
    # Topics suggested (unverified until a reviewer accepts them).
    suggested: int
    # Questions the AI left without a usable topic (null, unknown or wrong-subject answer).
    no_match: int
    # Questions of the paper still without a topic and not yet sent; call again for them.
    remaining: int


class TopicSuggestionResult(BaseModel):
    question: QuestionRead
    # False when the model found no fitting topic in the taxonomy (nothing changed).
    suggested: bool


class QuestionReport(BaseModel):
    """A learner flags a question (any origin) as wrong or unclear. The question goes back
    to review."""

    model_config = ConfigDict(extra="forbid")

    reason: Literal["wrong_answer", "unclear", "incorrect_content", "other"]
    note: Annotated[str, StringConstraints(strip_whitespace=True, max_length=300)] = ""


__all__ = [
    "AIExplanationRead",
    "AIStatus",
    "ConceptInput",
    "ExplanationReview",
    "GenerateQuestionsRequest",
    "GenerateQuestionsResult",
    "QuestionReport",
    "TopicSuggestionResult",
]


class QuickAnswerRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: Annotated[
        str,
        StringConstraints(strip_whitespace=True, min_length=2, max_length=QUICK_ANSWER_MAX_QUERY),
    ]
    exam_code: str | None = None


class QuickAnswer(BaseModel):
    """A short AI answer to a search. Not stored and not checked by anyone."""

    answer: str
    confident: bool
    model: str
    prompt_version: str


class SearchAnswerRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: Annotated[
        str,
        StringConstraints(strip_whitespace=True, min_length=2, max_length=QUICK_ANSWER_MAX_QUERY),
    ]
    exam_code: str


class SearchAnswerSource(BaseModel):
    """One piece of the learner's material the answer may cite."""

    key: str  # "S1", ... as used in the answer's markers
    kind: Literal["page", "question", "concept"]
    label: str
    snippet: str
    verified: bool
    cited: bool
    document_id: uuid.UUID | None = None
    page_number: int | None = None
    question_id: uuid.UUID | None = None
    concept_id: str | None = None


class SearchAnswer(BaseModel):
    """An answer written only from the learner's material (RAG), with its sources.
    found=false: nothing in the material answers the search (answer is null)."""

    found: bool
    answer: str | None  # what the material says, with [S#] markers
    simple: str | None = None  # the same in simple words (AI; may use general knowledge)
    confident: bool
    sources: list[SearchAnswerSource]
    model: str | None  # null when no AI call was needed (no matching material)
    prompt_version: str


class TopicRequest(BaseModel):
    """A topic to learn or be tested on: any name (a syllabus topic or typed by the learner)."""

    model_config = ConfigDict(extra="forbid")

    exam_code: Annotated[str, StringConstraints(min_length=1, max_length=32)]
    topic: Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=2, max_length=TOPIC_NAME_MAX)
    ]
    subject: (
        Annotated[
            str, StringConstraints(strip_whitespace=True, min_length=1, max_length=TOPIC_NAME_MAX)
        ]
        | None
    ) = None
    language: Literal["en", "hi"] = "en"


class TopicLessonRead(BaseModel):
    """A short AI lesson on a topic. Not stored and not checked by anyone."""

    topic: str
    subject: str | None
    overview: str
    key_points: list[str]
    example_question: str | None
    example_answer: str | None
    common_mistakes: list[str]
    confident: bool
    model: str
    prompt_version: str


class TopicQuizRequest(TopicRequest):
    count: int = Field(default=MAX_GENERATED, ge=MIN_QUIZ_QUESTIONS, le=MAX_GENERATED)


class QuizQuestionRead(BaseModel):
    stem: str
    options: list[str]
    correct_option: int  # 1-based
    explanation: str


class TopicQuizRead(BaseModel):
    """AI questions to check a topic. Not stored: the app marks them on the device and never
    counts them as practice or progress."""

    topic: str
    subject: str | None
    questions: list[QuizQuestionRead]
    rejected: int
    model: str
    prompt_version: str
