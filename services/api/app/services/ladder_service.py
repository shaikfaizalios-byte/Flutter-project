"""Challenge Ladder: plans a round, writes and checks each question, marks the answers.

A round is planned without AI. The app then asks for its steps one at a time, so the loading
ladder fills in as each question passes its checks (and no single request runs for long). A
step's question passes only if it fits the schema, isn't a copy of a paper or web reference, is
unlike the session's other questions, and an independent solve reaches the same answer. A
question that keeps failing is replaced by a real reviewed question from the learner's papers.

Only the learner's own papers are used as examples or fallbacks: shared-bank papers are licensed
for practice, not for sending to an AI service. See app/domain/challenge_ladder.py.
"""

import logging
import random
import uuid
from collections import Counter
from collections.abc import Callable, Sequence
from datetime import UTC, datetime
from typing import Any, cast

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.config import Settings
from app.domain import challenge_ladder as ladder
from app.domain import question_formats
from app.domain.ai_content import PROMPT_VERSION
from app.domain.errors import (
    AIDisabledError,
    AIUnavailableError,
    ConflictError,
    InvalidReferenceError,
    NotFoundError,
)
from app.domain.scoring import Answer
from app.domain.similarity import StemItem, similar_groups
from app.integrations.ai import AIProvider, AIProviderError, AIResult
from app.models.ai import AIGeneration
from app.models.document import Document
from app.models.exam import Exam
from app.models.ladder import LadderSession, LadderStep
from app.models.question import Question, QuestionOrigin, QuestionPattern, VerificationStatus
from app.repositories.exam_repository import ExamRepository
from app.schemas.insights import RepeatsReport, TopicRepeat
from app.schemas.ladder import (
    LadderAnswer,
    LadderBest,
    LadderOverview,
    LadderResult,
    LadderRoundRead,
    LadderStart,
    LadderStepRead,
    LadderTopic,
)
from app.services.exam_profiles import profile_of
from app.services.insights_service import InsightsService
from app.services.ladder_exam import exam_context
from app.services.patterns import visible_pattern
from app.services.topic_service import visible_topics

logger = logging.getLogger(__name__)

SEARCH_TASK = "ladder_search"
QUESTION_TASK = "ladder_question"
SOLVE_TASK = "ladder_solve"
MAX_TOKENS = 4000


class LadderService:
    def __init__(
        self,
        session: Session,
        owner_id: uuid.UUID,
        provider: AIProvider | None,
        settings: Settings,
        *,
        rng: random.Random | None = None,
        now: Callable[[], datetime] | None = None,
    ) -> None:
        self._session = session
        self._owner_id = owner_id
        self._provider = provider
        self._settings = settings
        self._rng = rng or random.SystemRandom()
        self._now = now or (lambda: datetime.now(UTC))

    # --- overview ----------------------------------------------------------------------------

    def overview(self, exam_code: str) -> LadderOverview:
        exam = self._exam(exam_code)
        if profile_of(exam).kind == "descriptive":
            return LadderOverview(topics=[], best=None, available=False)
        report = self._repeats(exam_code)
        papers = {t.topic_id: t.confirmed.papers for t in report.topics}
        order = {t.topic_id: index for index, t in enumerate(report.topics)}
        topics = sorted(
            visible_topics(self._session, self._owner_id, exam_code),
            key=lambda t: (order.get(t.id, len(order)), t.subject, t.name),
        )
        return LadderOverview(
            topics=[
                LadderTopic(
                    topic_id=t.id, name=t.name, subject=t.subject, papers=papers.get(t.id, 0)
                )
                for t in topics
            ],
            best=self._best(exam_code),
        )

    def _best(self, exam_code: str) -> LadderBest | None:
        """The highest first-round climb on this exam."""
        rows = self._session.execute(
            select(
                LadderStep.session_id, LadderStep.step, LadderStep.correct, LadderSession.topic_name
            )
            .join(LadderSession, LadderSession.id == LadderStep.session_id)
            .where(
                LadderSession.owner_id == self._owner_id,
                LadderSession.exam_code == exam_code,
                LadderStep.round_number == 1,
            )
        ).all()
        climbs: dict[uuid.UUID, list[tuple[int, bool | None]]] = {}
        names: dict[uuid.UUID, str] = {}
        for session_id, step, correct, topic_name in rows:
            climbs.setdefault(session_id, []).append((step, correct))
            names[session_id] = topic_name
        heights = [(ladder.climbed(steps), names[sid]) for sid, steps in climbs.items()]
        best = max(heights, key=lambda h: h[0], default=(0, ""))
        return LadderBest(step=best[0], topic_name=best[1]) if best[0] > 0 else None

    # --- rounds ------------------------------------------------------------------------------

    def start(self, request: LadderStart) -> LadderRoundRead:
        """Plans round 1. No AI call yet."""
        self._require_provider()
        exam = self._exam(request.exam_code)
        if profile_of(exam).kind == "descriptive":
            raise ConflictError("ladder_mcq_only", "The ladder is for multiple-choice exams.")
        topic = next(
            (
                t
                for t in visible_topics(self._session, self._owner_id, request.exam_code)
                if t.id == request.topic_id
            ),
            None,
        )
        if topic is None:
            raise InvalidReferenceError("Unknown topic for this exam.")
        seeds = len(self._topic_questions(request.exam_code, topic.id))
        practice = LadderSession(
            owner_id=self._owner_id,
            exam_code=request.exam_code,
            topic_id=topic.id,
            topic_name=topic.name,
            subject=topic.subject,
            language=request.language,
            new_formats=request.include_new_formats,
            source_mix=(
                "web_only" if seeds == 0 else "web_main" if seeds < ladder.MIN_SEEDS else "papers"
            ),
        )
        self._session.add(practice)
        self._session.flush()
        if not self._context(practice).formats:
            self._session.rollback()
            raise ConflictError(
                "ladder_no_format", "The ladder can't write this exam's question formats yet."
            )
        steps = self._plan(practice, 1, {})
        self._session.commit()
        return self._round(practice, 1, steps)

    def next_round(self, session_id: uuid.UUID) -> LadderRoundRead:
        """ "Test me more": a harder round, weighted to the question types got wrong so far."""
        self._require_provider()
        practice = self._load(session_id)
        steps = self._steps(session_id)
        last = max(s.round_number for s in steps)
        if any(s.round_number == last and s.correct is None for s in steps):
            raise ConflictError("round_unfinished", "Finish this round first.")
        misses = Counter(s.model_name for s in steps if s.correct is False and s.model_name)
        planned = self._plan(practice, last + 1, misses)
        self._session.commit()
        return self._round(practice, last + 1, planned)

    def read_round(self, session_id: uuid.UUID, round_number: int) -> LadderRoundRead:
        practice = self._load(session_id)
        steps = [s for s in self._steps(session_id) if s.round_number == round_number]
        if not steps:
            raise NotFoundError("Round not found.")
        return self._round(practice, round_number, steps)

    def _plan(
        self, practice: LadderSession, round_number: int, misses: dict[str, int] | Counter[str]
    ) -> list[LadderStep]:
        models = self._models(practice)
        plan = ladder.plan_round(models, round_number, misses)
        steps = [
            LadderStep(
                session_id=practice.id,
                round_number=round_number,
                step=number,
                difficulty=item.difficulty,
                pattern_id=_pattern_id(item.model),
                model_name=item.model.name if item.model else None,
                second_pattern_id=_pattern_id(item.second),
                second_model_name=item.second.name if item.second else None,
                basis_papers=item.model.papers if item.model else 0,
            )
            for number, item in enumerate(plan, start=1)
        ]
        self._session.add_all(steps)
        self._session.flush()
        return steps

    def _models(self, practice: LadderSession) -> list[ladder.PlanModel]:
        """The topic's question types with their repeat counts, in the report's order; types not
        seen in the learner's papers follow."""
        if practice.topic_id is None:
            return []
        report = self._repeats(practice.exam_code)
        repeat: TopicRepeat | None = next(
            (t for t in report.topics if t.topic_id == practice.topic_id), None
        )
        counted = [
            ladder.PlanModel(p.name, p.confirmed.papers, p.confirmed.questions, p.pattern_id)
            for p in (repeat.patterns if repeat else [])
        ]
        seen = {m.id for m in counted}
        rest = self._session.scalars(
            select(QuestionPattern)
            .where(QuestionPattern.topic_id == practice.topic_id, visible_pattern(self._owner_id))
            .order_by(QuestionPattern.sort_order, QuestionPattern.name)
        ).all()
        return counted + [ladder.PlanModel(p.name, 0, 0, p.id) for p in rest if p.id not in seen]

    def _repeats(self, exam_code: str) -> RepeatsReport:
        return InsightsService(self._session, self._owner_id).repeats(exam_code, "mine")

    # --- generating a step -------------------------------------------------------------------

    def generate(self, session_id: uuid.UUID, round_number: int, number: int) -> LadderStepRead:
        """Fills one step with a question that passed every check. Safe to repeat."""
        provider = self._require_provider()
        practice = self._load(session_id)
        steps = self._steps(session_id)
        step = next((s for s in steps if s.round_number == round_number and s.step == number), None)
        if step is None:
            raise NotFoundError("Step not found.")
        if step.source is not None:
            return _step_read(step)

        topic_questions = self._topic_questions(practice.exam_code, practice.topic_id)
        wanted = {step.pattern_id, step.second_pattern_id} - {None}
        same_model = [(q, d) for q, d in topic_questions if q.pattern_id in wanted]
        seeds = self._seeds(same_model or topic_questions)
        web = self._web_references(provider, practice, steps)
        if not seeds and not web:
            # Nothing to base a question on, and nothing real to fall back on either.
            raise AIUnavailableError("No references could be found for this topic.")
        others = [s.stem for s in steps if s.stem]
        sources = [q.stem for q, _ in topic_questions] + [r.snippet for r in web]
        exam = self._context(practice)
        if exam.marking is not None:
            step.marks_correct = exam.marking.marks_correct
            step.marks_wrong = exam.marking.marks_wrong
            step.partial_rule = dict(exam.marking.partial) if exam.marking.partial else None
        question = self._written_question(
            provider, exam, practice, step, steps, seeds, web, others, sources
        )
        if question is not None:
            shown = ladder.shuffled(question, self._rng)
            step.source = "ai"
            step.stem = shown.stem
            step.options = list(shown.options)
            step.answer_index = shown.answer_index
            step.solution = list(shown.solution)
            step.shortcut = shown.shortcut
            step.time_target_seconds = shown.time_target_seconds
            step.format = shown.format
            step.answer_spec = dict(shown.answer_spec) if shown.answer_spec else None
            step.basis_papers = max(step.basis_papers, len({s.paper_id for s in seeds}))
            step.basis_web = bool(web)
        else:
            self._use_paper_question(step, steps, same_model, topic_questions)
        self._session.commit()
        return _step_read(step)

    def _written_question(
        self,
        provider: AIProvider,
        exam: ladder.ExamContext,
        practice: LadderSession,
        step: LadderStep,
        all_steps: Sequence[LadderStep],
        seeds: Sequence[ladder.Seed],
        web: Sequence[ladder.WebReference],
        others: Sequence[str],
        sources: Sequence[str],
    ) -> ladder.GeneratedQuestion | None:
        """A question that passed the checks, or None when the attempts ran out."""
        rounds = [x for x in all_steps if x.round_number == step.round_number]
        missed = Counter(x.model_name for x in all_steps if x.correct is False and x.model_name)
        prompt = ladder.generator_prompt(
            exam=exam,
            topic=practice.topic_name,
            round_number=step.round_number,
            plan=[_planned(x) for x in rounds],
            number=step.step,
            seeds=seeds,
            web=web,
            avoid=others,
            missed=[name for name, _ in missed.most_common()],
            language=practice.language,
        )
        regenerations = invalid = 0
        while regenerations <= ladder.MAX_REGENERATIONS and invalid <= ladder.MAX_INVALID_RETRIES:
            result = self._ask(
                provider, QUESTION_TASK, ladder.LADDER_SYSTEM, prompt, ladder.GENERATED_SCHEMA
            )
            if result is None:
                return None  # the AI service failed: a real question takes the step
            difficulty = cast("ladder.Difficulty", step.difficulty)
            question = ladder.validate_generated(result.data, exam, difficulty)
            if question is None:
                invalid += 1
                self._log(provider, QUESTION_TASK, "invalid", result, "schema")
                continue
            if ladder.is_copy(question.stem, sources):
                regenerations += 1
                self._log(provider, QUESTION_TASK, "invalid", result, "copy")
                continue
            if ladder.too_alike(question.stem, others):
                regenerations += 1
                self._log(provider, QUESTION_TASK, "invalid", result, "alike")
                continue
            self._log(provider, QUESTION_TASK, "ok", result, "generated", created=1)
            solved = self._ask(
                provider,
                SOLVE_TASK,
                ladder.SOLVE_SYSTEM,
                ladder.solve_prompt(
                    stem=question.stem,
                    options=question.options,
                    format_name=question.format,
                    spec=question.answer_spec,
                ),
                ladder.solve_schema(question.format),
            )
            if solved is None:
                return None
            if ladder.solver_agrees(solved.data, question):
                self._log(provider, SOLVE_TASK, "ok", solved, "agrees")
                return question
            regenerations += 1
            self._log(provider, SOLVE_TASK, "invalid", solved, "key_disagrees")
        return None

    def _use_paper_question(
        self,
        step: LadderStep,
        steps: Sequence[LadderStep],
        same_model: Sequence[tuple[Question, Document]],
        topic_questions: Sequence[tuple[Question, Document]],
    ) -> None:
        """Puts a real reviewed question on the step, same type first."""
        used = {s.question_id for s in steps}
        candidates = [
            (q, d)
            for q, d in [*same_model, *topic_questions]
            if q.id not in used and q.correct_option_position is not None and len(q.options) >= 2
        ]
        if not candidates:
            raise AIUnavailableError("This question could not be checked. Please try again.")
        question, document = candidates[0]
        ordered = sorted(question.options, key=lambda o: o.position)
        step.source = "paper"
        step.question_id = question.id
        step.stem = question.stem
        step.options = [o.text for o in ordered]
        step.answer_index = next(
            i for i, o in enumerate(ordered) if o.position == question.correct_option_position
        )
        step.solution = [question.explanation] if question.explanation else []
        step.shortcut = ""
        step.time_target_seconds = None
        step.paper_label = _paper_label(document)[:300]
        step.basis_papers = max(step.basis_papers, 1)

    def _topic_questions(
        self, exam_code: str, topic_id: uuid.UUID | None
    ) -> list[tuple[Question, Document]]:
        """The learner's own reviewed, text-only questions of the topic with their papers."""
        if topic_id is None:
            return []
        rows = self._session.execute(
            select(Question, Document)
            .join(Document, Document.id == Question.document_id)
            .options(selectinload(Question.options))
            .where(
                Question.owner_id == self._owner_id,
                Document.owner_id == self._owner_id,
                Question.exam_code == exam_code,
                Question.topic_id == topic_id,
                Question.origin == QuestionOrigin.SOURCE,
                Question.verification_status == VerificationStatus.VERIFIED,
                Question.image_dependent.is_(False),
                Question.stem != "",  # printed as a picture: nothing to send or show as text
            )
            .order_by(Question.created_at, Question.id)
        ).all()
        return [(q, d) for q, d in rows]

    def _seeds(self, questions: Sequence[tuple[Question, Document]]) -> list[ladder.Seed]:
        groups = similar_groups(
            [StemItem(id=q.id, paper_id=d.id, block="topic", stem=q.stem) for q, d in questions]
        )
        clustered = {member for group in groups for member in group}
        seeds = [
            ladder.Seed(
                id=q.id,
                stem=q.stem,
                options=tuple(o.text for o in sorted(q.options, key=lambda o: o.position)),
                paper_id=d.id,
                paper=d.original_filename,
                year=d.exam_year if d.paper_date_status == "confirmed" else None,
            )
            for q, d in questions
        ]
        return ladder.pick_seeds(seeds, clustered)

    def _web_references(
        self, provider: AIProvider, practice: LadderSession, steps: Sequence[LadderStep]
    ) -> list[ladder.WebReference]:
        """Fetched once per session. A failed search just means papers only."""
        if practice.web_references is None:
            names = list(dict.fromkeys(s.model_name for s in steps if s.model_name))
            query = ladder.web_query(
                exam_name=self._exam(practice.exam_code).short_name
                or self._exam(practice.exam_code).name,
                stage=self._context(practice).stage,
                topic=practice.topic_name,
                models=names,
            )
            hits = []
            try:
                hits = provider.search_web(query=query, max_results=ladder.WEB_REFERENCES)
                self._log(provider, SEARCH_TASK, "ok", AIResult({}), f"{len(hits)} results")
            except AIProviderError as exc:
                logger.warning("Ladder web search failed: %s", exc.reason)
                self._log(provider, SEARCH_TASK, "error", AIResult({}), exc.reason)
            practice.web_references = [
                {"title": h.title, "url": h.url, "snippet": h.snippet} for h in hits
            ]
            self._session.commit()
        return [
            ladder.WebReference(r["title"], r["url"], r["snippet"])
            for r in practice.web_references or []
        ]

    # --- answering ---------------------------------------------------------------------------

    def answer(
        self, session_id: uuid.UUID, round_number: int, number: int, body: LadderAnswer
    ) -> LadderStepRead:
        """Marks the step. The first answer is final, as in practice."""
        self._load(session_id)
        step = self._session.get(LadderStep, (session_id, round_number, number))
        if step is None:
            raise NotFoundError("Step not found.")
        if step.source is None:
            raise ConflictError("step_not_ready", "This question isn't ready yet.")
        if step.correct is None:
            answer = _answer_of(step, body)
            step.selected_index = body.selected_index
            step.response = {"text": body.typed_answer} if body.typed_answer else body.response
            step.correct, step.marks_awarded = ladder.mark(
                format_name=step.format,
                spec=step.answer_spec,
                answer_index=step.answer_index,
                answer=answer,
                marking=_marking(step),
            )
            step.time_spent_ms = body.time_spent_ms
            step.answered_at = self._now()
            self._session.commit()
        return _step_read(step)

    # --- helpers -----------------------------------------------------------------------------

    def _require_provider(self) -> AIProvider:
        if self._provider is None:
            raise AIDisabledError("AI assistance is not configured on this server.")
        return self._provider

    def _context(self, practice: LadderSession) -> ladder.ExamContext:
        return exam_context(
            self._session,
            self._exam(practice.exam_code),
            subject=practice.subject,
            topic_id=practice.topic_id,
            new_formats=practice.new_formats,
            today=self._now().date(),
        )

    def _exam(self, code: str) -> Exam:
        exam = ExamRepository(self._session).get_visible(code, self._owner_id)
        if exam is None:
            raise InvalidReferenceError(f"Unknown exam '{code}'.")
        return exam

    def _load(self, session_id: uuid.UUID) -> LadderSession:
        practice = self._session.get(LadderSession, session_id)
        if practice is None or practice.owner_id != self._owner_id:
            raise NotFoundError("Ladder not found.")
        return practice

    def _steps(self, session_id: uuid.UUID) -> list[LadderStep]:
        return list(
            self._session.scalars(
                select(LadderStep)
                .where(LadderStep.session_id == session_id)
                .order_by(LadderStep.round_number, LadderStep.step)
            )
        )

    def _round(
        self, practice: LadderSession, number: int, steps: Sequence[LadderStep]
    ) -> LadderRoundRead:
        return LadderRoundRead(
            session_id=practice.id,
            round_number=number,
            topic_name=practice.topic_name,
            subject=practice.subject,
            source_mix=practice.source_mix,
            steps=[_step_read(s) for s in steps],
        )

    def _ask(
        self, provider: AIProvider, task: str, system: str, prompt: str, schema: dict[str, Any]
    ) -> AIResult | None:
        """One AI call; None when the provider failed (logged)."""
        try:
            return provider.complete_json(
                system=system, prompt=prompt, schema=dict(schema), max_tokens=MAX_TOKENS
            )
        except AIProviderError as exc:
            logger.warning("Ladder %s call failed: %s", task, exc.reason)
            self._log(provider, task, "error", AIResult({}), exc.reason)
            return None

    def _log(
        self,
        provider: AIProvider,
        task: str,
        outcome: str,
        result: AIResult,
        detail: str,
        *,
        created: int = 0,
    ) -> None:
        self._session.add(
            AIGeneration(
                owner_id=self._owner_id,
                task=task,
                provider=provider.name,
                model=provider.model,
                prompt_version=PROMPT_VERSION,
                outcome=outcome,
                detail=detail[:300],
                input_tokens=result.input_tokens,
                output_tokens=result.output_tokens,
                items_created=created,
                items_rejected=1 if outcome == "invalid" else 0,
            )
        )
        self._session.flush()


def _marking(step: LadderStep) -> tuple[float, float, dict[str, Any] | None] | None:
    if step.marks_correct is None or step.marks_wrong is None:
        return None
    return step.marks_correct, step.marks_wrong, step.partial_rule


def _answer_of(step: LadderStep, body: LadderAnswer) -> Answer:
    """The answer in the shape its format takes, or an error when it can't be one."""
    if step.format in question_formats.TYPED_SPEC_FORMATS:
        if body.typed_answer is None:
            raise InvalidReferenceError("Type your answer.")
        return body.typed_answer
    if step.format in question_formats.RESPONSE_FORMATS:
        spec = step.answer_spec or {}
        count = len(step.options or [])
        if not question_formats.valid_response(step.format, spec, body.response, count):
            raise InvalidReferenceError("That answer doesn't fit this question.")
        return body.response or {}
    if body.selected_index is None or body.selected_index >= len(step.options or []):
        raise InvalidReferenceError("That option doesn't exist.")
    return body.selected_index


def _planned(step: LadderStep) -> ladder.PlannedStep:
    return ladder.PlannedStep(
        cast("ladder.Difficulty", step.difficulty),
        ladder.PlanModel(step.model_name) if step.model_name else None,
        ladder.PlanModel(step.second_model_name) if step.second_model_name else None,
    )


def _pattern_id(model: ladder.PlanModel | None) -> uuid.UUID | None:
    return model.id if model is not None and isinstance(model.id, uuid.UUID) else None


def _paper_label(document: Document) -> str:
    year = document.exam_year if document.paper_date_status == "confirmed" else None
    return f"{document.original_filename} {year}" if year else document.original_filename


def _step_read(step: LadderStep) -> LadderStepRead:
    """The answer and solution appear only once the learner has answered."""
    answered = step.correct is not None
    marks = step.marks_awarded
    return LadderStepRead(
        round_number=step.round_number,
        step=step.step,
        difficulty=step.difficulty,
        model_name=step.model_name,
        second_model_name=step.second_model_name,
        ready=step.source is not None,
        source=step.source,
        basis_papers=step.basis_papers,
        basis_web=step.basis_web,
        paper_label=step.paper_label,
        stem=step.stem,
        options=step.options,
        time_target_seconds=step.time_target_seconds,
        format=step.format,
        format_data=cast(
            "dict[str, list[str]] | None",
            question_formats.public_data(step.format, step.answer_spec),
        ),
        result=LadderResult(
            selected_index=step.selected_index,
            correct=step.correct is True,
            answer_index=step.answer_index,
            solution=step.solution or [],
            shortcut=step.shortcut or "",
            time_spent_ms=step.time_spent_ms,
            response=step.response,
            answer_lines=ladder.answer_lines(step.format, step.answer_spec, step.options or []),
            partly_right=step.correct is False and marks is not None and marks > 0,
            marks=marks,
            marks_possible=step.marks_correct,
        )
        if answered
        else None,
    )
