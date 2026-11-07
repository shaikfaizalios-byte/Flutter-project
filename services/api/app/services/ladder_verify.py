"""The stricter checks a generated question must pass, used by the ladder and the benchmark.

Working first: what can be recalculated must give the key. Then independent solves, as many as its
level needs, and any disagreement discards the question.
"""

from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from app.domain import challenge_ladder as ladder
from app.domain import ladder_rules, recompute
from app.integrations.ai import AIResult

Ask = Callable[[str, str, str, dict[str, Any]], AIResult | None]
Log = Callable[[str, str, AIResult, str], None]
SOLVE_TASK = "ladder_solve"


@dataclass(frozen=True, slots=True)
class Verdict:
    passed: bool
    problem: str | None  # why not; "unavailable" when the AI service failed
    checks: dict[str, Any]


def verify(
    question: ladder.GeneratedQuestion,
    difficulty: str,
    ask: Ask,
    log: Log,
) -> Verdict:
    structured = question.structured or {}
    recheck = recompute.recheck(
        format_name=question.format,
        options=question.options,
        answer_index=question.answer_index,
        spec=question.answer_spec,
        structured=structured,
        tolerance=ladder_rules.tolerance(),
    )
    if recheck.problem:
        return Verdict(False, recheck.problem, {})
    kind = structured.get("kind")
    needed = ladder_rules.solves_needed(difficulty, kind if isinstance(kind, str) else None)
    for _ in range(needed):
        solved = ask(
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
            return Verdict(False, "unavailable", {})
        if not ladder.solver_agrees(solved.data, question):
            log(SOLVE_TASK, "invalid", solved, "key_disagrees")
            return Verdict(False, "key_disagrees", {})
        log(SOLVE_TASK, "ok", solved, "agrees")
    return Verdict(True, None, {"solves": needed, "recalculated": recheck.recalculated})
