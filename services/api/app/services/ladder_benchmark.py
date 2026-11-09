"""The held-out benchmark: runs the checks on past questions with known answers.

Internal only. The file stays with the operator: its questions are sent to the AI and read here, but
nothing about them is stored except totals per subject and format, and nothing reaches learners.
Each question is treated as a generated one: the AI writes its answer and working without the key,
the checks run, and an accepted answer is compared with the known one.
"""

import logging
import uuid
from collections import defaultdict
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain import challenge_ladder as ladder
from app.domain import ladder_rules
from app.domain.ai_content import PROMPT_VERSION
from app.integrations.ai import AIProvider, AIProviderError, AIResult
from app.models.ai import AIGeneration
from app.models.ladder import LadderBenchmarkRun, LadderGate
from app.services.ladder_verify import verify

logger = logging.getLogger(__name__)

TASK = "ladder_question"
MAX_TOKENS = 4000


@dataclass(frozen=True, slots=True)
class BenchItem:
    subject: str
    format: str
    level: str
    stem: str
    options: tuple[str, ...]
    key: Mapping[str, Any]  # answer_index, correct_indices or numeric_answer


@dataclass(frozen=True, slots=True)
class BenchRow:
    subject: str
    format: str
    items: int
    accepted: int
    correct: int


def read_items(data: Iterable[Mapping[str, Any]]) -> list[BenchItem]:
    return [
        BenchItem(
            subject=str(item["subject"]),
            format=str(item["format"]),
            level=str(item.get("level", "hard")),
            stem=str(item["stem"]),
            options=tuple(str(o) for o in item.get("options", [])),
            key={k: item[k] for k in ladder.KEY_FIELDS if k in item},
        )
        for item in data
    ]


def _same_answer(question: ladder.GeneratedQuestion, key: Mapping[str, Any]) -> bool:
    return ladder.solver_agrees(dict(key), question)


def run(
    session: Session,
    provider: AIProvider,
    exam_code: str,
    items: Sequence[BenchItem],
) -> list[BenchRow]:
    """Runs every item and stores the totals of this run."""

    def log(task: str, outcome: str, result: AIResult, detail: str) -> None:
        session.add(
            AIGeneration(
                task=task,
                provider=provider.name,
                model=provider.model,
                prompt_version=PROMPT_VERSION,
                outcome=outcome,
                detail=detail[:300],
                input_tokens=result.input_tokens,
                output_tokens=result.output_tokens,
            )
        )

    def ask(task: str, system: str, prompt: str, schema: dict[str, Any]) -> AIResult | None:
        try:
            return provider.complete_json(
                system=system, prompt=prompt, schema=dict(schema), max_tokens=MAX_TOKENS
            )
        except AIProviderError as exc:
            logger.warning("A benchmark call failed: %s", exc.reason)
            log(task, "error", AIResult({}), exc.reason)
            return None

    totals: dict[tuple[str, str], list[int]] = defaultdict(lambda: [0, 0, 0])
    for item in items:
        row = totals[(item.subject, item.format)]
        row[0] += 1
        answered = ask(
            TASK,
            ladder.SOLVE_SYSTEM,
            ladder.benchmark_prompt(item.stem, item.options, item.format),
            ladder.benchmark_schema(),
        )
        if answered is None:
            continue
        candidate = ladder.candidate(answered.data, item.stem, item.options, item.format)
        if candidate is None:
            log(TASK, "invalid", answered, "schema")
            continue
        log(TASK, "ok", answered, "benchmark")
        if not verify(candidate, item.level, ask, log).passed:
            continue
        row[1] += 1
        row[2] += _same_answer(candidate, item.key)
        session.commit()
    run_id = uuid.uuid4()
    rows = [
        BenchRow(subject, format_name, *counts) for (subject, format_name), counts in totals.items()
    ]
    session.add_all(
        LadderBenchmarkRun(
            run_id=run_id,
            exam_code=exam_code,
            subject=r.subject,
            format=r.format,
            items=r.items,
            accepted=r.accepted,
            correct=r.correct,
            model=provider.model,
        )
        for r in rows
    )
    session.commit()
    return sorted(rows, key=lambda r: (r.subject, r.format))


def subject_open(session: Session, exam_code: str, subject: str) -> bool:
    """A subject's generated hard questions stay off until its newest run passes the threshold the
    owner set for it."""
    threshold = session.scalar(
        select(LadderGate.threshold).where(
            LadderGate.exam_code == exam_code, LadderGate.subject == subject
        )
    )
    if threshold is None:
        return False
    newest = session.scalar(
        select(LadderBenchmarkRun.run_id)
        .where(LadderBenchmarkRun.exam_code == exam_code, LadderBenchmarkRun.subject == subject)
        .order_by(LadderBenchmarkRun.created_at.desc())
        .limit(1)
    )
    if newest is None:
        return False
    rows = session.scalars(
        select(LadderBenchmarkRun).where(
            LadderBenchmarkRun.run_id == newest, LadderBenchmarkRun.subject == subject
        )
    ).all()
    return ladder_rules.gate_open(
        sum(r.accepted for r in rows), sum(r.correct for r in rows), threshold
    )
