"""Hidden text for questions printed as pictures, so they can be found by search.

Learners always see the crops, exactly as printed. The AI's reading, with maths as TeX, goes only
into ``questions.transcript``, so a misread formula can't reach a question or its marking.
"""

import logging
import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.domain.ai_content import PROMPT_VERSION
from app.domain.untrusted import UNTRUSTED_RULE
from app.integrations.ai import AIProvider, AIProviderError, AIResult
from app.models.ai import AIGeneration
from app.models.question import Question

logger = logging.getLogger(__name__)

TASK = "paper_read"
MAX_TOKENS = 2000
MAX_TRANSCRIPT = 6000

SYSTEM = (
    "You copy exam questions from pictures exactly. You never solve or correct them. Write "
    "mathematics as LaTeX between $ signs and chemistry as \\ce{...}." + UNTRUSTED_RULE
)
SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {"text": {"type": "string"}},
    "required": ["text"],
    "additionalProperties": False,
}
PROMPT = (
    "These pictures are one question and its options, in order. Copy all of their text. "
    'Return JSON only: {"text": "..."}'
)


def transcribe_document(
    session: Session,
    provider: AIProvider,
    document_id: uuid.UUID,
    limit: int,
) -> tuple[int, int]:
    """Reads up to [limit] pictured questions of a paper. Returns (read, failed)."""
    questions = session.scalars(
        select(Question)
        .where(
            Question.document_id == document_id,
            Question.external_id.is_not(None),
            Question.transcript.is_(None),
        )
        .options(selectinload(Question.figures))
        .order_by(Question.source_question_number)
        .limit(limit)
    ).all()
    read = failed = 0
    for question in questions:
        images = [f.data for f in sorted(question.figures, key=lambda f: f.sort_order)]
        if not images:
            continue
        try:
            result = provider.complete_json(
                system=SYSTEM,
                prompt=PROMPT,
                schema=dict(SCHEMA),
                max_tokens=MAX_TOKENS,
                images=images,
            )
        except AIProviderError as exc:
            logger.warning("Transcribing a question failed: %s", exc.reason)
            _log(session, provider, question, "error", AIResult({}), exc.reason)
            failed += 1
            continue
        text = result.data.get("text")
        if isinstance(text, str) and text.strip():
            question.transcript = text.strip()[:MAX_TRANSCRIPT]
            _log(session, provider, question, "ok", result, "transcribed")
            read += 1
        else:
            _log(session, provider, question, "invalid", result, "empty")
            failed += 1
        session.commit()
    return read, failed


def _log(
    session: Session,
    provider: AIProvider,
    question: Question,
    outcome: str,
    result: AIResult,
    detail: str,
) -> None:
    session.add(
        AIGeneration(
            owner_id=question.owner_id,
            task=TASK,
            provider=provider.name,
            model=provider.model,
            prompt_version=PROMPT_VERSION,
            outcome=outcome,
            detail=detail[:300],
            input_tokens=result.input_tokens,
            output_tokens=result.output_tokens,
            items_created=1 if outcome == "ok" else 0,
            items_rejected=1 if outcome == "invalid" else 0,
        )
    )
    session.flush()
