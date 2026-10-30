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
from sqlalchemy.orm import Session, selectinload

from app.core.config import Settings
from app.domain import ai_content, rag
from app.domain.errors import (
    AIDisabledError,
    AIUnavailableError,
    ConflictError,
    InvalidReferenceError,
    NotEligibleError,
    NotFoundError,
)
from app.domain.segmentation import same_subject
from app.integrations.ai import AIProvider, AIProviderError, AIResult
from app.models.ai import AIExplanation, AIGeneration, DraftStatus
from app.models.document import Document
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
from app.repositories.exam_repository import ExamRepository
from app.schemas.ai import (
    AIStatus,
    AnswerCheckRead,
    AnswerCheckRequest,
    DraftSubjectRead,
    DraftTopicRead,
    ExplanationReview,
    GenerateQuestionsRequest,
    GenerateQuestionsResult,
    PaperTopicsResult,
    QuickAnswer,
    QuickAnswerRequest,
    QuizQuestionRead,
    SearchAnswer,
    SearchAnswerRequest,
    SearchAnswerSource,
    TopicDraft,
    TopicLessonRead,
    TopicQuizRead,
    TopicQuizRequest,
    TopicRequest,
    TopicSuggestionResult,
)
from app.schemas.document import DocumentRead
from app.schemas.question import AIExplanationRead
from app.services.patterns import pattern_candidates, refresh_pattern
from app.services.plus_service import PlusService
from app.services.question_service import QuestionService
from app.services.rag_service import RagRetriever
from app.services.topic_service import topic_scope, visible_topics

MIN_TAXONOMY_QUESTIONS = 5
logger = logging.getLogger(__name__)

# Issue raised on AI text in Hindi so a reviewer checks the language (like OCR text).
AI_LANGUAGE_REVIEW = "ai_language_review"


class AIService:
    def __init__(
        self,
        session: Session,
        owner_id: uuid.UUID,
        provider: AIProvider | None,
        settings: Settings,
    ) -> None:
        self._owner_id = owner_id
        self._session = session
        self._provider = provider
        self._settings = settings

    def status(self) -> AIStatus:
        if self._provider is None:
            return AIStatus(enabled=False, provider=None, model=None, features=[])
        required = self._settings.plus_required_for_ai
        plus = PlusService(self._session, self._owner_id, self._settings).status()
        return AIStatus(
            enabled=True,
            provider=self._provider.name,
            model=self._provider.model,
            features=["explanations", "questions", "topics", "quick_answers", "search_answers"],
            requires_plus=required,
            plus_active=plus.active,
            ai_left_this_month=(
                max(plus.ai_monthly_allowance - plus.ai_used_this_month, 0) if required else None
            ),
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
        if draft is not None and self._question_owner(draft.question_id) != self._owner_id:
            draft = None  # another account's draft looks exactly like a missing one
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
            if ExamRepository(self._session).get_visible(request.exam_code, self._owner_id) is None:
                raise InvalidReferenceError(f"Unknown exam '{request.exam_code}'.")
            exam_code, subject, section = request.exam_code, concept.subject, concept.subject
            topic = self._session.scalars(
                select(Topic).where(
                    *topic_scope(self._owner_id, request.exam_code),
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
                owner_id=self._owner_id,
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
            created=QuestionService(self._session, self._owner_id).by_ids(created).items,
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
            .where(
                *topic_scope(self._owner_id, question.exam_code),
                func.lower(Topic.subject) == question.subject.lower(),
            )
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
            refresh_pattern(question, pattern_candidates(self._session))
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
            question=QuestionService(self._session, self._owner_id).get(question.id),
            suggested=chosen is not None,
        )

    def draft_topics(self, exam_code: str) -> TopicDraft:
        """Proposes a topic list for an exam from samples of the learner's own imported
        questions (spread across their papers). Nothing is saved."""
        provider = self._require_provider()
        exam = ExamRepository(self._session).get_visible(exam_code, self._owner_id)
        if exam is None:
            raise InvalidReferenceError(f"Unknown exam '{exam_code}'.")
        stems = self._session.scalars(
            select(Question.stem)
            .where(
                Question.owner_id == self._owner_id,
                Question.exam_code == exam_code,
                Question.origin == QuestionOrigin.SOURCE,
                Question.verification_status != VerificationStatus.REJECTED,
            )
            .order_by(Question.document_id, Question.source_question_number)
        ).all()
        if len(stems) < MIN_TAXONOMY_QUESTIONS:
            raise NotEligibleError("Import at least one paper of this exam first.")
        step = max(1, len(stems) // ai_content.TAXONOMY_SAMPLE)
        sample = list(stems[::step])[: ai_content.TAXONOMY_SAMPLE]
        existing = [
            f"{t.subject}{ai_content.TOPIC_SEPARATOR}{t.name}"
            for t in visible_topics(self._session, self._owner_id, exam_code)
        ]
        result = self._call(
            provider,
            task="taxonomy",
            question_id=None,
            prompt=ai_content.taxonomy_prompt(exam.name, sample, existing),
            schema=ai_content.TAXONOMY_SCHEMA,
        )
        drafted = ai_content.validate_taxonomy(result.data, existing)
        self._record(
            provider,
            "taxonomy",
            "ok" if drafted else "invalid",
            result,
            None,
            f"{len(sample)} questions",
            created=len(drafted),
        )
        self._session.commit()
        subjects: dict[str, list[DraftTopicRead]] = {}
        for topic in drafted:
            subjects.setdefault(topic.subject, []).append(
                DraftTopicRead(name=topic.name, keywords=list(topic.keywords))
            )
        return TopicDraft(
            exam_code=exam_code,
            model=provider.model,
            questions_considered=len(sample),
            subjects=[DraftSubjectRead(name=n, topics=t) for n, t in subjects.items()],
        )

    def suggest_paper_topics(self, document_id: uuid.UUID) -> PaperTopicsResult:
        """AI topic suggestions for a paper's questions that have none (the keyword rules found
        nothing). Up to ``MAX_PAPER_TOPIC_BATCHES`` batches per request; ``remaining`` says
        how many are left for another request."""
        provider = self._require_provider()
        document = self._session.get(Document, document_id)
        if document is None or document.owner_id != self._owner_id:
            raise NotFoundError("Document not found.")
        # Questions the AI already found no topic for keep topic_suggested_by = "ai" while
        # unassigned, so they are not sent again.
        pending = self._session.scalars(
            select(Question)
            .where(
                Question.document_id == document_id,
                Question.owner_id == self._owner_id,
                Question.topic_status == TopicStatus.UNASSIGNED,
                Question.topic_suggested_by.is_(None),
                Question.verification_status != VerificationStatus.REJECTED,
            )
            .order_by(Question.section, Question.source_question_number, Question.id)
            .options(selectinload(Question.options))
        ).all()
        topics = visible_topics(self._session, self._owner_id, document.exam_code)
        if not topics:
            raise NotEligibleError("There are no topics for this exam yet.")
        labels = {f"{t.subject}{ai_content.TOPIC_SEPARATOR}{t.name}": t for t in topics}
        exam = self._session.get(Exam, document.exam_code)
        exam_name = exam.name if exam else document.exam_code

        patterns = pattern_candidates(self._session)
        size = ai_content.PAPER_TOPICS_BATCH
        batches = [pending[i : i + size] for i in range(0, len(pending), size)]
        considered = suggested = 0
        for batch in batches[:MAX_PAPER_TOPIC_BATCHES]:
            items = [
                ai_content.TopicQuestion(
                    number=n,
                    stem=q.stem,
                    options=[o.text for o in q.options],
                    subject=q.subject,
                )
                for n, q in enumerate(batch, start=1)
            ]
            result = self._call(
                provider,
                task="topic",
                question_id=None,
                prompt=ai_content.paper_topics_prompt(items, list(labels), exam_name),
                schema=ai_content.PAPER_TOPICS_SCHEMA,
            )
            chosen = ai_content.pick_paper_topics(
                result.data, [i.number for i in items], list(labels)
            )
            batch_suggested = 0
            for number, question in enumerate(batch, start=1):
                topic = labels.get(chosen.get(number, ""))
                question.topic_suggested_by = "ai"
                if topic is not None and (
                    question.subject is None or same_subject(question.subject, topic.subject)
                ):
                    question.topic_id = topic.id
                    question.topic_status = TopicStatus.SUGGESTED
                    question.topic_suggestion_reason = f"AI suggestion ({provider.model})"[:200]
                    question.subject = question.subject or topic.subject
                    refresh_pattern(question, patterns)
                    batch_suggested += 1
            self._record(
                provider,
                "topic",
                "ok" if batch_suggested == len(batch) else "partial",
                result,
                None,
                f"paper batch of {len(batch)}",
                created=batch_suggested,
                rejected=len(batch) - batch_suggested,
            )
            self._session.commit()
            considered += len(batch)
            suggested += batch_suggested
        return PaperTopicsResult(
            considered=considered,
            suggested=suggested,
            no_match=considered - suggested,
            remaining=len(pending) - considered,
        )

    # --- quick answers ----------------------------------------------------------------------

    def quick_answer(self, request: QuickAnswerRequest) -> QuickAnswer:
        """A short answer to a search no imported question matched. Nothing is stored (the
        call is logged without its text); the app labels it as unchecked AI."""
        provider = self._require_provider()
        exam_name: str | None = None
        if request.exam_code is not None:
            exam = ExamRepository(self._session).get_visible(request.exam_code, self._owner_id)
            if exam is None:
                raise InvalidReferenceError(f"Unknown exam '{request.exam_code}'.")
            exam_name = exam.name
        result = self._call(
            provider,
            task="quick_answer",
            question_id=None,
            prompt=ai_content.quick_answer_prompt(query=request.text, exam_name=exam_name),
            schema=ai_content.QUICK_ANSWER_SCHEMA,
            system=ai_content.QUICK_ANSWER_SYSTEM,
        )
        answer, confident = ai_content.validate_quick_answer(result.data)
        self._record(
            provider,
            "quick_answer",
            "ok" if answer else "invalid",
            result,
            None,
            created=1 if answer else 0,
            rejected=0 if answer else 1,
        )
        self._session.commit()
        if answer is None:
            raise AIUnavailableError("The AI gave no usable answer. Please try again.")
        return QuickAnswer(
            answer=answer,
            confident=confident,
            model=provider.model,
            prompt_version=ai_content.PROMPT_VERSION,
        )

    # --- learning and checking a topic -------------------------------------------------------

    def topic_lesson(self, request: TopicRequest) -> TopicLessonRead:
        """A short lesson for a learner new to a topic. Nothing is stored (the call is logged
        without its text); the app labels it as unchecked AI."""
        provider = self._require_provider()
        exam = self._visible_exam(request.exam_code)
        result = self._call(
            provider,
            task="topic_lesson",
            question_id=None,
            prompt=ai_content.topic_lesson_prompt(
                topic=request.topic,
                subject=request.subject,
                exam_name=exam.name,
                language=request.language,
            ),
            schema=ai_content.LESSON_SCHEMA,
            system=ai_content.TOPIC_SYSTEM,
        )
        lesson = ai_content.validate_lesson(result.data)
        self._record(
            provider,
            "topic_lesson",
            "ok" if lesson else "invalid",
            result,
            None,
            created=1 if lesson else 0,
            rejected=0 if lesson else 1,
        )
        self._session.commit()
        if lesson is None:
            raise AIUnavailableError("The AI lesson was not usable. Please try again.")
        return TopicLessonRead(
            topic=request.topic,
            subject=request.subject,
            overview=lesson.overview,
            key_points=lesson.key_points,
            example_question=lesson.example_question,
            example_answer=lesson.example_answer,
            common_mistakes=lesson.common_mistakes,
            confident=lesson.confident,
            model=provider.model,
            prompt_version=ai_content.PROMPT_VERSION,
        )

    def topic_quiz(self, request: TopicQuizRequest) -> TopicQuizRead:
        """Questions that check a topic the learner says they know. Validated like generated
        practice questions but not stored: they never enter the question bank, practice
        or progress."""
        provider = self._require_provider()
        exam = self._visible_exam(request.exam_code)
        result = self._call(
            provider,
            task="topic_quiz",
            question_id=None,
            prompt=ai_content.topic_quiz_prompt(
                topic=request.topic,
                subject=request.subject,
                exam_name=exam.name,
                language=request.language,
                count=request.count,
            ),
            schema=ai_content.QUESTIONS_SCHEMA,
            system=ai_content.TOPIC_SYSTEM,
        )
        raw = result.data.get("questions")
        items = raw[: request.count] if isinstance(raw, list) else []
        questions: list[QuizQuestionRead] = []
        reasons: set[str] = set()
        stems: list[str] = []
        for item in items:
            valid, problems = ai_content.validate_generated(item, avoid_stems=stems)
            if valid is None:
                reasons.update(problems)
                continue
            stems.append(valid.stem)  # no duplicates within one quiz
            questions.append(
                QuizQuestionRead(
                    stem=valid.stem,
                    options=valid.options,
                    correct_option=valid.correct_option,
                    explanation=valid.explanation,
                )
            )
        rejected = len(items) - len(questions)
        # Too few usable questions can't judge a topic: nothing is returned (not counted as ok).
        usable_too_few = len(questions) < ai_content.MIN_QUIZ_QUESTIONS
        self._record(
            provider,
            "topic_quiz",
            "invalid" if usable_too_few else ("partial" if rejected else "ok"),
            result,
            None,
            ",".join(sorted(reasons)),
            created=len(questions),
            rejected=rejected,
        )
        self._session.commit()
        if usable_too_few:
            raise AIUnavailableError("The AI questions were not usable. Please try again.")
        return TopicQuizRead(
            topic=request.topic,
            subject=request.subject,
            questions=questions,
            rejected=rejected,
            model=provider.model,
            prompt_version=ai_content.PROMPT_VERSION,
        )

    def check_answer(self, question_id: uuid.UUID, request: AnswerCheckRequest) -> AnswerCheckRead:
        """Judges the learner's own answer against the AI's answer and the paper's printed one.
        Nothing is stored (the call is logged without text); the app labels it as unchecked AI."""
        provider = self._require_provider()
        question = self._question(question_id)
        if question.image_dependent or question.figures:
            # The AI only gets the text: it can't judge an answer to a question it can't see.
            raise NotEligibleError("This question depends on a figure, so AI can't check it.")
        paper_answer = _paper_answer(question)
        result = self._call(
            provider,
            task="answer_check",
            question_id=question.id,
            prompt=ai_content.answer_check_prompt(
                stem=question.stem,
                passage=question.passage.text if question.passage else None,
                paper_answer=paper_answer,
                answer=request.answer,
                language=question.language,
            ),
            schema=ai_content.ANSWER_CHECK_SCHEMA,
            system=ai_content.TOPIC_SYSTEM,
        )
        check = ai_content.validate_answer_check(
            result.data, has_paper_answer=paper_answer is not None
        )
        self._record(
            provider,
            "answer_check",
            "ok" if check else "invalid",
            result,
            question.id,
            created=1 if check else 0,
            rejected=0 if check else 1,
        )
        self._session.commit()
        if check is None:
            raise AIUnavailableError("The AI check was not usable. Please try again.")
        return AnswerCheckRead(
            verdict=check.verdict,
            feedback=check.feedback,
            ideal_answer=check.ideal_answer,
            paper_answer=paper_answer,
            paper_agreement=check.paper_answer,
            confident=check.confident,
            model=provider.model,
            prompt_version=ai_content.PROMPT_VERSION,
        )

    def _visible_exam(self, code: str) -> Exam:
        exam = ExamRepository(self._session).get_visible(code, self._owner_id)
        if exam is None:
            raise InvalidReferenceError(f"Unknown exam '{code}'.")
        return exam

    # --- reading a paper with AI --------------------------------------------------------------

    def queue_paper_read(self, document_id: uuid.UUID) -> DocumentRead:
        """Ask the worker to read this paper's questions with AI (pages go to the provider).
        Reviewed questions are kept; the rules' unreviewed ones are replaced."""
        self._require_provider()
        document = self._session.get(Document, document_id)
        if document is None or document.owner_id != self._owner_id:
            raise NotFoundError("Document not found.")
        if document.status != "completed":
            raise ConflictError("not_processed", "Wait until the paper has been processed.")
        if document.ai_read_status in ("queued", "running"):
            raise ConflictError("ai_read_in_progress", "AI is already reading this paper.")
        document.ai_read_status = "queued"
        document.ai_read_pages_done = 0
        document.ai_read_error = None
        self._session.commit()
        return DocumentRead.model_validate(document)

    # --- answers from the learner's material (RAG) ------------------------------------------

    def search_answer(self, request: SearchAnswerRequest) -> SearchAnswer:
        """Retrieve the best-matching material, let the AI answer only from it, and check every
        citation. No matching material: "not found" without an AI call (nothing is spent)."""
        provider = self._require_provider()
        exam = ExamRepository(self._session).get_visible(request.exam_code, self._owner_id)
        if exam is None:
            raise InvalidReferenceError(f"Unknown exam '{request.exam_code}'.")
        # 1. RETRIEVE
        sources = RagRetriever(self._session, self._owner_id).retrieve(
            rag.query_terms(request.text), request.exam_code
        )
        if not sources:
            return SearchAnswer(
                found=False,
                answer=None,
                confident=True,
                sources=[],
                model=None,
                prompt_version=ai_content.PROMPT_VERSION,
            )
        # 2. AUGMENT + 3. GENERATE
        result = self._call(
            provider,
            task="rag_answer",
            question_id=None,
            prompt=rag.rag_prompt(query=request.text, exam_name=exam.name, sources=sources),
            schema=rag.RAG_SCHEMA,
            system=rag.RAG_SYSTEM,
        )
        # 4. CHECK
        answer = rag.validate_rag(result.data, [s.key for s in sources])
        detail = f"{len(sources)} sources"
        if answer is not None:
            detail += f", {len(answer.cited)} cited"
        self._record(
            provider,
            "rag_answer",
            "invalid" if answer is None else "ok",
            result,
            None,
            detail,
            created=0 if answer is None else 1,
            rejected=1 if answer is None else 0,
        )
        self._session.commit()
        if answer is None:
            raise AIUnavailableError("The AI answer did not cite your material correctly.")
        cited = set(answer.cited)
        return SearchAnswer(
            found=answer.found,
            answer=answer.answer,
            simple=answer.simple,
            confident=answer.confident,
            sources=[
                SearchAnswerSource(
                    key=s.key,
                    kind=s.kind,
                    label=s.label,
                    snippet=s.text,
                    verified=s.verified,
                    cited=s.key in cited,
                    document_id=uuid.UUID(s.document_id) if s.document_id else None,
                    page_number=s.page_number,
                    question_id=uuid.UUID(s.question_id) if s.question_id else None,
                    concept_id=s.concept_id,
                )
                for s in sources
            ],
            model=provider.model,
            prompt_version=ai_content.PROMPT_VERSION,
        )

    # --- helpers --------------------------------------------------------------------------

    def _require_provider(self) -> AIProvider:
        if self._provider is None:
            raise AIDisabledError("AI assistance is not configured on this server.")
        return self._provider

    def _question_owner(self, question_id: uuid.UUID) -> uuid.UUID | None:
        return self._session.scalar(select(Question.owner_id).where(Question.id == question_id))

    def _question(self, question_id: uuid.UUID) -> Question:
        question = self._session.get(Question, question_id)
        if question is None or question.owner_id != self._owner_id:
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
        system: str = ai_content.SYSTEM,
    ) -> AIResult:
        try:
            return provider.complete_json(
                system=system,
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
                owner_id=self._owner_id,
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


def _paper_answer(question: Question) -> str | None:
    """The answer printed in the paper, as text: the written answer, the typed-in answer or the
    correct option."""
    if question.answer_type == "written":
        return question.model_answer
    if question.answer_type == "typed":
        return question.typed_answer
    position = question.correct_option_position
    for option in question.options:
        if option.position == position:
            return f"({position}) {option.text}"
    return None


MAX_PAPER_TOPIC_BATCHES = 3


def _summarise(reasons: list[str]) -> str:
    counts: dict[str, int] = {}
    for reason in reasons:
        counts[reason] = counts.get(reason, 0) + 1
    return ", ".join(f"{r} x{n}" if n > 1 else r for r, n in sorted(counts.items()))
