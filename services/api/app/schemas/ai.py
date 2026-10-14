import uuid
from typing import Annotated, Literal, Self

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

from app.domain.ai_content import MAX_EXPLANATION, MAX_GENERATED
from app.schemas.question import AIExplanationRead, QuestionRead


class AIStatus(BaseModel):
    enabled: bool
    provider: str | None
    model: str | None
    # Features available while enabled.
    features: list[Literal["explanations", "questions", "topics"]]


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
