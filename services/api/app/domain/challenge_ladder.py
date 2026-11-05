"""Challenge Ladder: five questions on a topic, each harder than the last (pure parts).

The AI writes new practice questions from the patterns in the learner's own reviewed papers,
with web references as a secondary source. Everything here needs no database or network: which
question type each step uses, picking example questions, the prompts, and the checks a question
must pass before it is shown. app/services/ladder_service.py runs them.

These questions are practice only. They live in their own tables, never in ``questions``, so they
can't reach the repeated-topic or repeated-model counts, and they are never called past-paper
questions or a prediction of the exam.
"""

import random
import unicodedata
from collections.abc import Collection, Hashable, Mapping, Sequence
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any, Literal

from app.domain.ai_content import LANGUAGE_NAMES
from app.domain.similarity import THRESHOLD, normalise, stem_similarity
from app.domain.untrusted import UNTRUSTED_RULE, material

Difficulty = Literal["easy", "medium", "medium_hard", "hard", "extreme_hard"]

STEPS = 5
FIRST_ROUND: tuple[Difficulty, ...] = ("easy", "easy", "medium", "hard", "extreme_hard")
LATER_ROUND: tuple[Difficulty, ...] = ("medium_hard", "medium_hard", "hard", "hard", "hard")

SEEDS_PER_MODEL = 3
MIN_SEEDS = 3  # with fewer, web references become the main source
WEB_REFERENCES = 5
COPY_THRESHOLD = 0.95  # numbers included: closer than this to a source is a copy
VARIETY_THRESHOLD = THRESHOLD  # numbers hidden: the worded-alike matcher's own line
MAX_REGENERATIONS = 2  # after a wrong key, a copy or a look-alike
MAX_INVALID_RETRIES = 1  # after output that doesn't fit the schema

MIN_TIME_TARGET = 15
MAX_TIME_TARGET = 600
MAX_STEM = 1500
MAX_OPTION = 300
MAX_SOLUTION_STEPS = 12
MAX_SOLUTION_STEP = 500
MAX_SHORTCUT = 500

# --- planning --------------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class PlanModel:
    """A question type of the topic with its repeat counts, in the repeats report's order."""

    name: str
    papers: int = 0
    questions: int = 0
    id: Hashable = None


@dataclass(frozen=True, slots=True)
class PlannedStep:
    difficulty: Difficulty
    model: PlanModel | None  # None: topic-level, the topic has no question types
    second: PlanModel | None = None  # step 5 can combine two types


def plan_round(
    models: Sequence[PlanModel], round_number: int, misses: Mapping[str, int] | None = None
) -> tuple[PlannedStep, ...]:
    """Which question type each step of a round uses.

    Round 1: the two most repeated first (high-yield and familiar), then a different one, then
    one that appears less often, and finally two combined. With fewer than three types they
    repeat, and the prompt's list of used questions pushes a different sub-pattern. Later rounds
    start from the types the learner got wrong."""
    difficulties = FIRST_ROUND if round_number == 1 else LATER_ROUND
    if not models:
        return tuple(PlannedStep(d, None) for d in difficulties)
    if round_number == 1:
        chosen = _first_round_models(models)
    else:
        missed = misses or {}
        ranked = sorted(enumerate(models), key=lambda m: (-missed.get(m[1].name, 0), m[0]))
        ordered = [m for _, m in ranked]
        chosen = [ordered[i % len(ordered)] for i in range(STEPS)]
    second = _partner(chosen[-1], models)
    return tuple(
        PlannedStep(d, model, second if index == STEPS - 1 else None)
        for index, (d, model) in enumerate(zip(difficulties, chosen, strict=True))
    )


def _first_round_models(models: Sequence[PlanModel]) -> list[PlanModel]:
    if len(models) == 1:
        return [models[0]] * STEPS
    if len(models) == 2:
        return [models[0], models[1], models[0], models[1], models[0]]
    return [models[0], models[1], models[2], models[-1], models[0]]


def _partner(model: PlanModel, models: Sequence[PlanModel]) -> PlanModel | None:
    """A second type to combine with [model]: the least repeated other one."""
    others = [m for m in models if m != model]
    return others[-1] if others else None


# --- example questions -----------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Seed:
    id: Hashable
    stem: str
    options: tuple[str, ...]
    paper_id: Hashable
    paper: str
    year: int | None = None


def pick_seeds(
    seeds: Sequence[Seed], clustered: Collection[Hashable], limit: int = SEEDS_PER_MODEL
) -> list[Seed]:
    """Up to [limit] seeds from different papers where possible, worded-alike ones first: those
    are patterns the exam has reused."""
    ordered = sorted(seeds, key=lambda s: s.id not in clustered)
    picked: list[Seed] = []
    papers: set[Hashable] = set()
    for seed in ordered:
        if len(picked) < limit and seed.paper_id not in papers:
            picked.append(seed)
            papers.add(seed.paper_id)
    for seed in ordered:
        if len(picked) < limit and seed not in picked:
            picked.append(seed)
    return picked


# --- prompts ---------------------------------------------------------------------------------

LADDER_SYSTEM = (
    "You write original multiple-choice practice questions for learners. Never claim or imply "
    "that a question comes from an official or previous-year paper, and never invent exam "
    "patterns, cut-offs, marks or statistics. Every question must have exactly one correct "
    "option, which you have worked out yourself." + UNTRUSTED_RULE
)

GENERATED_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "step": {"type": "integer"},
        "difficulty": {"type": "string"},
        "model": {"type": "string"},
        "basis": {"type": "string"},
        "question": {"type": "string"},
        "options": {"type": "array", "items": {"type": "string"}},
        "answer_index": {"type": "integer"},
        "solution": {"type": "string"},
        "shortcut": {"type": "string"},
        "time_target_seconds": {"type": "integer"},
    },
    "required": [
        "step",
        "difficulty",
        "model",
        "basis",
        "question",
        "options",
        "answer_index",
        "solution",
        "shortcut",
        "time_target_seconds",
    ],
    "additionalProperties": False,
}

SOLVE_SYSTEM = "You solve multiple-choice questions carefully." + UNTRUSTED_RULE
SOLVE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {"answer_index": {"type": "integer"}, "working": {"type": "string"}},
    "required": ["answer_index", "working"],
    "additionalProperties": False,
}

_TEMPLATE_PATH = Path(__file__).parent / "prompts" / "challenge_ladder_generator.txt"


def fill_template(template: str, values: Mapping[str, str]) -> str:
    """Replaces every {{name}} in one pass, so text inside a value is never treated as one."""
    parts = template.split("{{")
    filled = [parts[0]]
    for part in parts[1:]:
        name, _, rest = part.partition("}}")
        filled.append(values[name] + rest)
    return "".join(filled)


@dataclass(frozen=True, slots=True)
class WebReference:
    title: str
    url: str
    snippet: str


def _seed_text(seeds: Sequence[Seed]) -> str:
    if not seeds:
        return "(none)"
    blocks = []
    for seed in seeds:
        options = "\n".join(f"- {o}" for o in seed.options)
        year = f" {seed.year}" if seed.year else ""
        blocks.append(f"{seed.paper}{year}\n{material(f'{seed.stem}{chr(10)}{options}')}")
    return "\n\n".join(blocks)


def _web_text(references: Sequence[WebReference]) -> str:
    if not references:
        return "(none)"
    return "\n\n".join(f"{r.url}\n{material(f'{r.title}: {r.snippet}')}" for r in references)


def _model_text(step: PlannedStep, topic: str) -> str:
    if step.model is None:
        return f"any type within {topic}"
    if step.second is not None:
        return f"{step.model.name} combined with {step.second.name}"
    return step.model.name


def generator_prompt(
    *,
    exam_name: str,
    topic: str,
    round_number: int,
    plan: Sequence[PlannedStep],
    number: int,
    seeds: Sequence[Seed],
    web: Sequence[WebReference],
    avoid: Sequence[str],
    missed: Sequence[str],
    language: str,
) -> str:
    """The prompt for step [number] of [plan]: one question per request, so a failed question
    is rewritten alone and the app can show the steps filling in."""
    if not seeds:
        source = "The student has no papers on this topic: use the web references."
    elif len(seeds) < MIN_SEEDS:
        source = "There are few seed questions: rely mainly on the web references."
    else:
        source = "Web references only add ideas to the seed questions."
    step_plan = "\n".join(
        f"Step {index} ({step.difficulty.replace('_', ' ')}): {_model_text(step, topic)}"
        for index, step in enumerate(plan, start=1)
    )
    return fill_template(
        _TEMPLATE_PATH.read_text(encoding="utf-8"),
        {
            "exam": exam_name,
            "topic": topic,
            "round": str(round_number),
            "language": LANGUAGE_NAMES[language],
            "step_plan": step_plan,
            "step": str(number),
            "difficulty": plan[number - 1].difficulty.replace("_", " "),
            "paper_seeds": _seed_text(seeds),
            "web_refs": _web_text(web),
            "source_rule": source,
            "previous_questions": (
                material("\n".join(f"- {a}" for a in avoid)) if avoid else "(none yet)"
            ),
            "missed_models": ", ".join(missed) if missed else "(none)",
        },
    )


def solve_prompt(*, stem: str, options: Sequence[str]) -> str:
    """Only the question and its options: the solver must not see the key or the solution."""
    lines = "\n".join(f"{index}: {option}" for index, option in enumerate(options))
    return (
        f"Question:\n{material(stem)}\n\nOptions, numbered from 0:\n{material(lines)}\n\n"
        'Solve this question. Reply with JSON only: {"answer_index": n, "working": "..."}'
    )


def web_query(*, exam_name: str, topic: str, models: Sequence[str]) -> str:
    return " ".join([exam_name, topic, *models[:2], "questions"])


# --- checks ----------------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class GeneratedQuestion:
    stem: str
    options: tuple[str, ...]
    answer_index: int
    solution: tuple[str, ...]
    shortcut: str
    time_target_seconds: int


def _clean(text: str) -> str:
    return unicodedata.normalize("NFC", text.strip())


def validate_generated(data: dict[str, Any]) -> GeneratedQuestion | None:
    """The question, or None unless it has exactly 4 different options, an answer index between
    0 and 3 and a solution. The step, difficulty, model and basis it states are ignored: they
    come from the plan and from what was really sent."""
    stem, options, index = data.get("question"), data.get("options"), data.get("answer_index")
    solution, shortcut, target = (
        data.get("solution"),
        data.get("shortcut"),
        data.get("time_target_seconds"),
    )
    if not isinstance(stem, str) or not isinstance(options, list) or not isinstance(solution, str):
        return None
    if isinstance(index, bool) or not isinstance(index, int) or not 0 <= index <= 3:
        return None
    if len(options) != 4 or not all(isinstance(o, str) for o in options):
        return None
    cleaned = tuple(_clean(o) for o in options)
    if len({o.casefold() for o in cleaned}) != 4 or not all(
        0 < len(o) <= MAX_OPTION for o in cleaned
    ):
        return None
    steps = tuple(_clean(line) for line in solution.splitlines() if line.strip())
    if not steps or len(steps) > MAX_SOLUTION_STEPS:
        return None
    if any(len(s) > MAX_SOLUTION_STEP for s in steps):
        return None
    stem = _clean(stem)
    if not 0 < len(stem) <= MAX_STEM:
        return None
    seconds = target if isinstance(target, int) and not isinstance(target, bool) else 60
    return GeneratedQuestion(
        stem=stem,
        options=cleaned,
        answer_index=index,
        solution=steps,
        shortcut=_clean(shortcut)[:MAX_SHORTCUT] if isinstance(shortcut, str) else "",
        time_target_seconds=min(MAX_TIME_TARGET, max(MIN_TIME_TARGET, seconds)),
    )


def solver_agrees(data: dict[str, Any], question: GeneratedQuestion) -> bool:
    """The independent solve reached the question's key."""
    answer = data.get("answer_index")
    return not isinstance(answer, bool) and answer == question.answer_index


def is_copy(stem: str, sources: Sequence[str]) -> bool:
    """At least COPY_THRESHOLD alike a source with the numbers kept, or found inside one (a web
    snippet is longer than a question, so similarity alone would miss a pasted question)."""
    words = " ".join(normalise(stem, mask_numbers=False))
    for source in sources:
        if stem_similarity(stem, source, mask_numbers=False) >= COPY_THRESHOLD:
            return True
        if words and words in " ".join(normalise(source, mask_numbers=False)):
            return True
    return False


def too_alike(stem: str, others: Sequence[str]) -> bool:
    """At least VARIETY_THRESHOLD alike another question with the numbers hidden."""
    return any(stem_similarity(stem, other) >= VARIETY_THRESHOLD for other in others)


def shuffled(question: GeneratedQuestion, rng: random.Random) -> GeneratedQuestion:
    """Options in a new order, with the answer index following its option."""
    order = list(range(len(question.options)))
    rng.shuffle(order)
    return replace(
        question,
        options=tuple(question.options[i] for i in order),
        answer_index=order.index(question.answer_index),
    )


def climbed(steps: Sequence[tuple[int, bool | None]]) -> int:
    """How high a ladder was climbed: the last step cleared without a miss before it."""
    height = 0
    for number, correct in sorted(steps):
        if correct is not True:
            break
        height = number
    return height
