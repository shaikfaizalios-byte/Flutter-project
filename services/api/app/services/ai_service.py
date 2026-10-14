"""AI assistance: explanation drafts, generated practice questions and topic suggestions.

Rules (see docs/ai.md):
- Only verified source questions (or the learner's own concept) are used as a basis;
  AI never answers unverified questions as fact.
- Everything AI produces is stored with provenance and enters as a draft / unverified
  question, then goes through the normal review workflow.
- Every call is recorded in ``ai_generations`` (task, model, outcome, tokens) without any
  prompt or output text.
"""

import logging
import uuid
from datetime import UTC, datetime

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain import ai_content
from app.domain.errors import (
    AIDisabledError,
    AIUnavailableError,
    ConflictError,
    InvalidReferenceError,
    NotEligibleError,
    NotFoundError,
)
from app.integrations.ai import AIProvider, AIProviderError, AIResult
from app.models.ai import AIExplanation, AIGeneration, DraftStatus
from app.models.exam import Exam
from app.models.question import (
    Question,
    QuestionIssue,
    QuestionOption,
    QuestionOrigin,
    Topic,
    TopicStatus,
    VerificationStatus,
)
from app.schemas.ai import (
    AIStatus,
    ExplanationReview,
    GenerateQuestionsRequest,
    GenerateQuestionsResult,
    TopicSuggestionResult,
)
from app.schemas.question import AIExplanationRead
from app.services.question_service import QuestionService

logger = logging.getLogger(__name__)

# Issue raised on AI text in Hindi so a reviewer checks the language (like OCR text).
AI_LANGUAGE_REVIEW = "ai_language_review"


class AIService:
    def __init__(self, session: Session, provider: AIProvider | None, settings: Settings) -> None:
        self._session = session
        self._provider = provider
        self._settings = settings

    def status(self) -> AIStatus:
        if self._provider is None:
            return AIStatus(enabled=False, provider=None, model=None, features=[])
        return AIStatus(
            enabled=True,
            provider=self._provider.name,
            model=self._provider.model,
            features=["explanations", "questions", "topics"],
        )

    # --- explanations -------------------------------------------------------------------

    def draft_explanation(self, question_id: uuid.UUID) -> AIExplanationRead:
        provider = self._require_provider()
        question = self._question(question_id)
        self._require_verified_source(question)
        if question.explanation:
            raise ConflictError("explanation_exists", "This question already has an explanation.")
        if self._approved_explanation(question.id) is not None:
            raise ConflictError("explanation_exists", "An approved AI explanation already exists.")

        result = self._call(
            provider,
            task="explanation",
            question_id=question.id,
            prompt=ai_content.explanation_prompt(
                stem=question.stem,
                options=[o.text for o in question.options],
                correct=question.correct_option_position or 0,
                subject=question.subject,
                language=question.language,
            ),
            schema=ai_content.EXPLANATION_SCHEMA,
        )
        text, confident = ai_content.validate_explanation(result.data)
        if text is None:
            self._record(provider, "explanation", "invalid", result, question.id, "bad_explanation")
            self._session.commit()
            raise AIUnavailableError("The AI explanation was not usable. Please try again.")

        # A new draft replaces earlier drafts.
        self._session.execute(
            update(AIExplanation)
            .where(
                AIExplanation.question_id == question.id,
                AIExplanation.status == DraftStatus.DRAFT,
            )
            .values(status=DraftStatus.REJECTED, reviewed_at=func.now())
        )
        draft = AIExplanation(
            question_id=question.id,
            text=text,
            language=question.language,
            model_confident=confident,
            provider=provider.name,
            model=provider.model,
            prompt_version=ai_content.PROMPT_VERSION,
            status=DraftStatus.DRAFT,
        )
        self._session.add(draft)
        self._record(provider, "explanation", "ok", result, question.id, created=1)
        self._session.commit()
        return AIExplanationRead.model_validate(draft)

    def review_explanation(
        self, explanation_id: uuid.UUID, review: ExplanationReview
    ) -> AIExplanationRead:
        draft = self._session.get(AIExplanation, explanation_id)
        if draft is None:
            raise NotFoundError("AI explanation not found.")
        if review.status == "approved":
            question = self._question(draft.question_id)
            if question.explanation:
                raise ConflictError(
                    "explanation_exists", "The question now has its own explanation."
                )
            # Only one approved AI explanation per question.
            self._session.execute(
                update(AIExplanation)
                .where(
                    AIExplanation.question_id == draft.question_id,
                    AIExplanation.id != draft.id,
                    AIExplanation.status == DraftStatus.APPROVED,
                )
                .values(status=DraftStatus.REJECTED, reviewed_at=func.now())
            )
        if review.text is not None and review.text != draft.text:
            draft.text = review.text
            draft.edited = True
        draft.status = review.status
        draft.reviewed_at = datetime.now(UTC)
        self._session.commit()
        return AIExplanationRead.model_validate(draft)

    # --- generated questions --------------------------------------------------------------

    def generate_questions(self, request: GenerateQuestionsRequest) -> GenerateQuestionsResult:
        provider = self._require_provider()
        source: Question | None = None
        topic: Topic | None = None
        if request.source_question_id is not None:
            source = self._question(request.source_question_id)
            self._require_verified_source(source)
            exam_code, subject, section = source.exam_code, source.subject, source.section
            topic = source.topic
            prompt = ai_content.questions_from_question_prompt(
                stem=source.stem,
                options=[o.text for o in source.options],
                correct=source.correct_option_position or 0,
                subject=source.subject,
                topic=topic.name if topic else None,
                language=request.language,
                count=request.count,
            )
            note = None
        else:
            concept = request.concept
            assert concept is not None  # noqa: S101 - guaranteed by the request validator
            if self._session.get(Exam, request.exam_code) is None:
                raise InvalidReferenceError(f"Unknown exam '{request.exam_code}'.")
            exam_code, subject, section = request.exam_code, concept.subject, concept.subject
            topic = self._session.scalars(
                select(Topic).where(
                    func.lower(Topic.subject) == concept.subject.lower(),
                    func.lower(Topic.name) == concept.topic.lower(),
                )
            ).first()
            prompt = ai_content.questions_from_notes_prompt(
                title=concept.title,
                notes=concept.notes,
                subject=concept.subject,
                topic=concept.topic,
                language=request.language,
                count=request.count,
            )
            note = f"Concept: {concept.title}"[:300]

        result = self._call(
            provider,
            task="questions",
            question_id=source.id if source else None,
            prompt=prompt,
            schema=ai_content.QUESTIONS_SCHEMA,
        )
        raw = result.data.get("questions")
        items = raw if isinstance(raw, list) else []
        created: list[uuid.UUID] = []
        reasons: list[str] = []
        avoid = [source.stem] if source else []
        for item in items[: request.count]:
            valid, problems = ai_content.validate_generated(item, avoid_stems=avoid)
            if valid is None:
                reasons.extend(problems)
                continue
            avoid.append(valid.stem)  # no duplicates within one batch
            question = Question(
                origin=QuestionOrigin.AI,
                exam_code=exam_code,
                section=section,
                subject=subject,
                topic_id=topic.id if topic else None,
                topic_status=TopicStatus.SUGGESTED if topic else TopicStatus.UNASSIGNED,
                topic_suggested_by="ai" if topic else None,
                stem=valid.stem,
                language=request.language,
                correct_option_position=valid.correct_option,
                answer_source="ai",
                explanation=valid.explanation,
                verification_status=VerificationStatus.UNVERIFIED,
                ai_provider=provider.name,
                ai_model=provider.model,
                ai_prompt_version=ai_content.PROMPT_VERSION,
                ai_source_question_id=source.id if source else None,
                ai_source_note=note,
            )
            question.options = [
                QuestionOption(position=i, label=str(i), text=text)
                for i, text in enumerate(valid.options, start=1)
            ]
            if request.language == "hi":
                question.issues = [
                    QuestionIssue(
                        code=AI_LANGUAGE_REVIEW,
                        detail="AI-written Hindi: check spelling and terms before approving.",
                    )
                ]
            self._session.add(question)
            self._session.flush()
            created.append(question.id)

        missing = max(0, request.count - len(items))
        rejected = len(items[: request.count]) - len(created) + missing
        if missing:
            reasons.append("too_few_returned")
        outcome = "ok" if not rejected else ("partial" if created else "invalid")
        self._record(
            provider,
            "questions",
            outcome,
            result,
            source.id if source else None,
            _summarise(reasons),
            created=len(created),
            rejected=rejected,
        )
        self._session.commit()
        return GenerateQuestionsResult(
            created=QuestionService(self._session).by_ids(created).items,
            rejected=rejected,
            rejection_reasons=sorted(set(reasons)),
        )

    # --- topic suggestions ----------------------------------------------------------------

    def suggest_topic(self, question_id: uuid.UUID) -> TopicSuggestionResult:
        provider = self._require_provider()
        question = self._question(question_id)
        if question.topic_status != TopicStatus.UNASSIGNED:
            raise ConflictError("topic_already_set", "This question already has a topic.")
        if not question.subject:
            raise NotEligibleError("Set the question's subject first.")
        topics = self._session.scalars(
            select(Topic)
            .where(func.lower(Topic.subject) == question.subject.lower())
            .order_by(Topic.name)
        ).all()
        if not topics:
            raise NotEligibleError("There are no topics for this subject yet.")

        result = self._call(
            provider,
            task="topic",
            question_id=question.id,
            prompt=ai_content.topic_prompt(
                stem=question.stem, subject=question.subject, topics=[t.name for t in topics]
            ),
            schema=ai_content.TOPIC_SCHEMA,
        )
        chosen = ai_content.pick_topic(result.data, [t.name for t in topics])
        if chosen is not None:
            topic = next(t for t in topics if t.name == chosen)
            question.topic_id = topic.id
            question.topic_status = TopicStatus.SUGGESTED
            question.topic_suggested_by = "ai"
        self._record(
            provider,
            "topic",
            "ok" if chosen else "invalid",
            result,
            question.id,
            "" if chosen else "no_matching_topic",
        )
        self._session.commit()
        return TopicSuggestionResult(
            question=QuestionService(self._session).get(question.id), suggested=chosen is not None
        )

    # --- helpers --------------------------------------------------------------------------

    def _require_provider(self) -> AIProvider:
        if self._provider is None:
            raise AIDisabledError("AI assistance is not configured on this server.")
        return self._provider

    def _question(self, question_id: uuid.UUID) -> Question:
        question = self._session.get(Question, question_id)
        if question is None:
            raise NotFoundError("Question not found.")
        return question

    @staticmethod
    def _require_verified_source(question: Question) -> None:
        if (
            question.origin != QuestionOrigin.SOURCE
            or question.verification_status != VerificationStatus.VERIFIED
            or question.correct_option_position is None
            or question.image_dependent
        ):
            raise NotEligibleError(
                "AI can only work from verified questions from your papers that have an "
                "answer and no figure."
            )

    def _approved_explanation(self, question_id: uuid.UUID) -> AIExplanation | None:
        return self._session.scalars(
            select(AIExplanation).where(
                AIExplanation.question_id == question_id,
                AIExplanation.status == DraftStatus.APPROVED,
            )
        ).first()

    def _call(
        self,
        provider: AIProvider,
        *,
        task: str,
        question_id: uuid.UUID | None,
        prompt: str,
        schema: dict[str, object],
    ) -> AIResult:
        try:
            return provider.complete_json(
                system=ai_content.SYSTEM,
                prompt=prompt,
                schema=dict(schema),
                max_tokens=self._settings.ai_max_output_tokens,
            )
        except AIProviderError as exc:
            logger.warning("AI %s call failed: %s", task, exc.reason)
            self._record(provider, task, "error", AIResult({}), question_id, exc.reason)
            self._session.commit()
            message = (
                "The AI service is not available right now. Please try again in a moment."
                if exc.retryable
                else "The AI service could not handle this request."
            )
            raise AIUnavailableError(message) from exc

    def _record(
        self,
        provider: AIProvider,
        task: str,
        outcome: str,
        result: AIResult,
        question_id: uuid.UUID | None,
        detail: str = "",
        *,
        created: int = 0,
        rejected: int = 0,
    ) -> None:
        self._session.add(
            AIGeneration(
                task=task,
                provider=provider.name,
                model=provider.model,
                prompt_version=ai_content.PROMPT_VERSION,
                outcome=outcome,
                detail=detail[:300],
                input_tokens=result.input_tokens,
                output_tokens=result.output_tokens,
                items_created=created,
                items_rejected=rejected,
                question_id=question_id,
            )
        )


def _summarise(reasons: list[str]) -> str:
    counts: dict[str, int] = {}
    for reason in reasons:
        counts[reason] = counts.get(reason, 0) + 1
    return ", ".join(f"{r} x{n}" if n > 1 else r for r, n in sorted(counts.items()))
