"""Descriptive practice: plans the five levels, writes and checks each question, marks answers.

The learner's answer and a photo of it go to the AI service, and example questions come only from
their own reviewed papers. A photo is read in the request and never stored. See
app/domain/descriptive.py.
"""

import io
import logging
import uuid
from collections.abc import Callable, Sequence
from dataclasses import asdict
from datetime import UTC, datetime
from typing import Any, BinaryIO

from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain import challenge_ladder as ladder
from app.domain import descriptive
from app.domain.ai_content import PROMPT_VERSION
from app.domain.errors import (
    AIDisabledError,
    AIUnavailableError,
    ConflictError,
    InvalidReferenceError,
    NotFoundError,
)
from app.integrations.ai import AIProvider, AIProviderError, AIResult
from app.models.ai import AIGeneration
from app.models.descriptive import DescriptiveSession, DescriptiveStep
from app.models.document import Document
from app.models.exam import Exam
from app.models.question import Question, QuestionOrigin, VerificationStatus
from app.repositories.exam_repository import ExamRepository
from app.schemas.descriptive import (
    DescriptiveAnswer,
    DescriptiveOverview,
    DescriptivePhotoRead,
    DescriptivePointRead,
    DescriptiveResult,
    DescriptiveSessionRead,
    DescriptiveStart,
    DescriptiveStepRead,
    DescriptiveTopic,
)
from app.services.exam_profiles import profile_of
from app.services.ladder_exam import exam_context
from app.services.topic_service import visible_topics

logger = logging.getLogger(__name__)

QUESTION_TASK = "written_question"
MARK_TASK = "written_mark"
READ_TASK = "written_read"
MAX_TOKENS = 4000
MAX_SEEDS = 3
MAX_PHOTO_BYTES = 10 * 1024 * 1024
MAX_PHOTO_PIXELS = 50_000_000
PHOTO_SIDE = 2000  # longest side sent to the AI service


class DescriptiveService:
    def __init__(
        self,
        session: Session,
        owner_id: uuid.UUID,
        provider: AIProvider | None,
        settings: Settings,
        *,
        now: Callable[[], datetime] | None = None,
    ) -> None:
        self._session = session
        self._owner_id = owner_id
        self._provider = provider
        self._settings = settings
        self._now = now or (lambda: datetime.now(UTC))

    def overview(self, exam_code: str) -> DescriptiveOverview:
        exam = self._exam(exam_code)
        if profile_of(exam).kind == "mcq":
            return DescriptiveOverview(topics=[], available=False)
        topics = sorted(
            visible_topics(self._session, self._owner_id, exam_code),
            key=lambda t: (t.subject, t.name),
        )
        return DescriptiveOverview(
            topics=[
                DescriptiveTopic(topic_id=t.id, name=t.name, subject=t.subject) for t in topics
            ],
            available=True,
        )

    def start(self, request: DescriptiveStart) -> DescriptiveSessionRead:
        """Plans the five levels. No AI call yet."""
        self._require_provider()
        exam = self._exam(request.exam_code)
        if profile_of(exam).kind == "mcq":
            raise ConflictError("descriptive_not_offered", "This exam has no written paper.")
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
        practice = DescriptiveSession(
            owner_id=self._owner_id,
            exam_code=exam.code,
            topic_id=topic.id,
            topic_name=topic.name,
            subject=topic.subject,
            language=request.language,
        )
        self._session.add(practice)
        self._session.flush()
        context = self._context(practice, exam)
        stated = context.marking.marks_correct if context.marking else None
        top = descriptive.question_marks(stated)
        steps = []
        for number, level in enumerate(descriptive.levels(), start=1):
            marks = descriptive.level_marks(level, top)
            steps.append(
                DescriptiveStep(
                    session_id=practice.id,
                    step=number,
                    level=level.key,
                    marks=marks,
                    word_limit=descriptive.word_limit(marks),
                )
            )
        self._session.add_all(steps)
        self._session.commit()
        return self._read(practice, steps)

    def read(self, session_id: uuid.UUID) -> DescriptiveSessionRead:
        practice = self._load(session_id)
        return self._read(practice, self._steps(session_id))

    def generate(self, session_id: uuid.UUID, number: int) -> DescriptiveStepRead:
        """Fills one level with a question that passed its checks. Safe to repeat."""
        provider = self._require_provider()
        practice = self._load(session_id)
        steps = self._steps(session_id)
        step = next((s for s in steps if s.step == number), None)
        if step is None:
            raise NotFoundError("Step not found.")
        if step.stem is not None:
            return _step_read(step)
        written = self._written(provider, practice, step, steps)
        if written is None:
            raise AIUnavailableError("This question could not be checked. Please try again.")
        step.stem = written.stem
        step.rubric = [asdict(p) for p in written.rubric]
        step.model_answer = written.model_answer
        self._session.commit()
        return _step_read(step)

    def _written(
        self,
        provider: AIProvider,
        practice: DescriptiveSession,
        step: DescriptiveStep,
        steps: Sequence[DescriptiveStep],
    ) -> descriptive.WrittenQuestion | None:
        exam = self._exam(practice.exam_code)
        others = [s.stem for s in steps if s.stem]
        seeds = self._seeds(practice)
        level = next(item for item in descriptive.levels() if item.key == step.level)
        prompt = descriptive.question_prompt(
            exam_name=exam.name,
            stage=self._context(practice, exam).stage,
            topic=practice.topic_name,
            level=level,
            marks=step.marks,
            words=step.word_limit,
            seeds=seeds,
            avoid=others,
            language=practice.language,
        )
        for _ in range(ladder.MAX_REGENERATIONS + 1):
            result = self._ask(
                provider,
                QUESTION_TASK,
                descriptive.QUESTION_SYSTEM,
                prompt,
                descriptive.QUESTION_SCHEMA,
            )
            if result is None:
                return None
            written = descriptive.validate_question(result.data, step.marks)
            if written is None:
                self._log(provider, QUESTION_TASK, "invalid", result, "schema")
                continue
            if ladder.is_copy(written.stem, seeds) or ladder.too_alike(written.stem, others):
                self._log(provider, QUESTION_TASK, "invalid", result, "alike")
                continue
            self._log(provider, QUESTION_TASK, "ok", result, "generated", created=1)
            check = self._marking(
                provider,
                stem=written.stem,
                rubric=written.rubric,
                answer=written.model_answer,
                suggested=step.word_limit,
                language=practice.language,
            )
            if check is None:
                return None
            if descriptive.rubric_holds(check, step.marks):
                return written
            self._log(provider, MARK_TASK, "invalid", AIResult({}), "rubric_disagrees")
        return None

    def answer(
        self, session_id: uuid.UUID, number: int, body: DescriptiveAnswer
    ) -> DescriptiveStepRead:
        """Marks an answer. The first marked answer is final; a failed marking saves nothing."""
        provider = self._require_provider()
        practice = self._load(session_id)
        step = self._session.get(DescriptiveStep, (session_id, number))
        if step is None:
            raise NotFoundError("Step not found.")
        if step.stem is None or step.rubric is None:
            raise ConflictError("step_not_ready", "This question isn't ready yet.")
        if step.marking is not None:
            return _step_read(step)
        rubric = [descriptive.RubricPoint(p["point"], p["marks"]) for p in step.rubric]
        verdict = self._verdict(provider, practice, step, rubric, body.text)
        step.answer_text = body.text
        step.answer_source = body.source
        step.word_count = descriptive.count_words(body.text)
        step.marking = asdict(verdict.marking)
        step.marks_awarded = verdict.marks
        step.marks_low = verdict.low
        step.marks_high = verdict.high
        step.runs = verdict.runs
        step.answered_at = self._now()
        self._session.commit()
        return _step_read(step)

    def _verdict(
        self,
        provider: AIProvider,
        practice: DescriptiveSession,
        step: DescriptiveStep,
        rubric: Sequence[descriptive.RubricPoint],
        text: str,
    ) -> descriptive.Verdict:
        def run() -> descriptive.Marking:
            marking = self._marking(
                provider,
                stem=step.stem or "",
                rubric=rubric,
                answer=text,
                suggested=step.word_limit,
                language=practice.language,
            )
            if marking is None:
                self._session.commit()  # keep the log; the answer stays with the learner
                raise AIUnavailableError("Your answer could not be marked. Please try again.")
            return marking

        markings = [run(), run()]
        if descriptive.needs_third(markings[0], markings[1], step.marks):
            markings.append(run())
        return descriptive.combine(markings)

    def _marking(
        self,
        provider: AIProvider,
        *,
        stem: str,
        rubric: Sequence[descriptive.RubricPoint],
        answer: str,
        suggested: int,
        language: str,
    ) -> descriptive.Marking | None:
        """One separate marking, with one retry for output that doesn't fit."""
        prompt = descriptive.mark_prompt(
            stem=stem,
            rubric=rubric,
            answer=answer,
            words=descriptive.count_words(answer),
            suggested_words=suggested,
            language=language,
        )
        for _ in range(descriptive.MAX_INVALID_RETRIES + 1):
            result = self._ask(
                provider, MARK_TASK, descriptive.MARK_SYSTEM, prompt, descriptive.MARK_SCHEMA
            )
            if result is None:
                return None
            marking = descriptive.validate_marking(result.data, rubric)
            if marking is not None:
                self._log(provider, MARK_TASK, "ok", result, "marked")
                return marking
            self._log(provider, MARK_TASK, "invalid", result, "schema")
        return None

    def read_photo(self, photo: BinaryIO) -> DescriptivePhotoRead:
        """Reads handwriting for the learner to correct. Nothing is stored."""
        provider = self._require_provider()
        png = _photo_png(photo)
        try:
            result = provider.complete_json(
                system=descriptive.READ_SYSTEM,
                prompt=descriptive.READ_PROMPT,
                schema=dict(descriptive.READ_SCHEMA),
                max_tokens=MAX_TOKENS,
                images=[png],
            )
        except AIProviderError as exc:
            logger.warning("Descriptive photo read failed: %s", exc.reason)
            self._log(provider, READ_TASK, "error", AIResult({}), exc.reason)
            self._session.commit()
            raise AIUnavailableError("The photo could not be read. Please try again.") from exc
        reading = descriptive.validate_reading(result.data)
        self._log(provider, READ_TASK, "ok" if reading else "invalid", result, "read")
        self._session.commit()
        if reading is None:
            raise AIUnavailableError("No writing could be read from this photo.")
        return DescriptivePhotoRead(text=reading[0], unclear=reading[1])

    # --- helpers -----------------------------------------------------------------------------

    def _require_provider(self) -> AIProvider:
        if self._provider is None:
            raise AIDisabledError("AI assistance is not configured on this server.")
        return self._provider

    def _exam(self, code: str) -> Exam:
        exam = ExamRepository(self._session).get_visible(code, self._owner_id)
        if exam is None:
            raise InvalidReferenceError(f"Unknown exam '{code}'.")
        return exam

    def _context(self, practice: DescriptiveSession, exam: Exam) -> ladder.ExamContext:
        return exam_context(
            self._session,
            exam,
            subject=practice.subject,
            topic_id=practice.topic_id,
            new_formats=False,
            today=self._now().date(),
        )

    def _load(self, session_id: uuid.UUID) -> DescriptiveSession:
        practice = self._session.get(DescriptiveSession, session_id)
        if practice is None or practice.owner_id != self._owner_id:
            raise NotFoundError("Session not found.")
        return practice

    def _steps(self, session_id: uuid.UUID) -> list[DescriptiveStep]:
        return list(
            self._session.scalars(
                select(DescriptiveStep)
                .where(DescriptiveStep.session_id == session_id)
                .order_by(DescriptiveStep.step)
            )
        )

    def _seeds(self, practice: DescriptiveSession) -> list[str]:
        """The learner's own reviewed written questions on the topic, never the shared bank."""
        if practice.topic_id is None:
            return []
        rows = self._session.scalars(
            select(Question.stem)
            .join(Document, Document.id == Question.document_id)
            .where(
                Question.owner_id == self._owner_id,
                Document.owner_id == self._owner_id,
                Question.exam_code == practice.exam_code,
                Question.topic_id == practice.topic_id,
                Question.origin == QuestionOrigin.SOURCE,
                Question.verification_status == VerificationStatus.VERIFIED,
                Question.answer_type == "written",
            )
            .order_by(Question.created_at, Question.id)
            .limit(MAX_SEEDS)
        )
        return list(rows)

    def _read(
        self, practice: DescriptiveSession, steps: Sequence[DescriptiveStep]
    ) -> DescriptiveSessionRead:
        return DescriptiveSessionRead(
            session_id=practice.id,
            topic_name=practice.topic_name,
            subject=practice.subject,
            steps=[_step_read(s) for s in steps],
        )

    def _ask(
        self, provider: AIProvider, task: str, system: str, prompt: str, schema: dict[str, Any]
    ) -> AIResult | None:
        try:
            return provider.complete_json(
                system=system, prompt=prompt, schema=dict(schema), max_tokens=MAX_TOKENS
            )
        except AIProviderError as exc:
            logger.warning("Descriptive %s call failed: %s", task, exc.reason)
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


def _photo_png(photo: BinaryIO) -> bytes:
    """A checked, upright, reduced PNG of the upload, or an error when it isn't a photo."""
    data = photo.read(MAX_PHOTO_BYTES + 1)
    if len(data) > MAX_PHOTO_BYTES:
        raise InvalidReferenceError("That photo is too large.")
    try:
        with Image.open(io.BytesIO(data)) as image:
            if image.format not in ("JPEG", "PNG"):
                raise InvalidReferenceError("Choose a JPEG or PNG photo.")
            if image.width * image.height > MAX_PHOTO_PIXELS:
                raise InvalidReferenceError("That photo is too large.")
            upright = ImageOps.exif_transpose(image).convert("RGB")
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise InvalidReferenceError("Choose a JPEG or PNG photo.") from exc
    upright.thumbnail((PHOTO_SIDE, PHOTO_SIDE))
    out = io.BytesIO()
    upright.save(out, format="PNG")
    return out.getvalue()


def _step_read(step: DescriptiveStep) -> DescriptiveStepRead:
    """The rubric and model answer appear only once the answer has been marked."""
    return DescriptiveStepRead(
        step=step.step,
        level=step.level,
        marks=step.marks,
        word_limit=step.word_limit,
        ready=step.stem is not None,
        stem=step.stem,
        result=_result(step) if step.marking is not None else None,
    )


def _result(step: DescriptiveStep) -> DescriptiveResult:
    marking = step.marking or {}
    points = [
        DescriptivePointRead(
            point=rubric["point"],
            marks=rubric["marks"],
            awarded=mark["awarded"],
            comment=mark["comment"],
        )
        for rubric, mark in zip(step.rubric or [], marking.get("points", []), strict=True)
    ]
    return DescriptiveResult(
        marks=step.marks_awarded or 0,
        marks_possible=step.marks,
        low=step.marks_low,
        high=step.marks_high,
        runs=step.runs or 0,
        points=points,
        missing_points=marking.get("missing", []),
        structure=marking.get("structure", ""),
        relevance=marking.get("relevance", ""),
        length=marking.get("length", ""),
        word_count=step.word_count or 0,
        answer_text=step.answer_text or "",
        model_answer=step.model_answer or "",
    )
