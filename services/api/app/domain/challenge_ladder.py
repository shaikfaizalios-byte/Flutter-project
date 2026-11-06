"""Challenge Ladder: five questions on a topic, each harder than the last (pure parts).

The AI writes new practice questions, in the formats the exam allows, from the patterns in the
learner's own reviewed papers, with web references as a secondary source. Everything here needs no
database or network: which question type each step uses, picking example questions, the prompts,
and the checks a question must pass before it is shown. app/services/ladder_service.py runs them.

These questions are practice only. They live in their own tables, never in ``questions``, so they
can't reach the repeated-topic or repeated-model counts, and they are never called past-paper
questions or a prediction of the exam.
"""

import random
import unicodedata
from collections.abc import Collection, Hashable, Mapping, Sequence
from dataclasses import dataclass, replace
from decimal import Decimal
from pathlib import Path
from typing import Any, Literal

from app.domain import question_formats, scoring
from app.domain.ai_content import LANGUAGE_NAMES
from app.domain.exam_format import SectionMarking
from app.domain.exam_profile import ladder_times
from app.domain.similarity import THRESHOLD, normalise, stem_similarity
from app.domain.untrusted import UNTRUSTED_RULE, material

Difficulty = Literal["easy", "medium", "medium_hard", "hard", "extreme_hard"]

STEPS = 5
LEVELS: tuple[Difficulty, ...] = ("easy", "medium", "medium_hard", "hard", "extreme_hard")
FIRST_ROUND: tuple[Difficulty, ...] = ("easy", "easy", "medium", "hard", "extreme_hard")
LATER_ROUND: tuple[Difficulty, ...] = ("medium_hard", "medium_hard", "hard", "hard", "hard")

SEEDS_PER_MODEL = 3
MIN_SEEDS = 3  # with fewer, web references become the main source
WEB_REFERENCES = 5
COPY_THRESHOLD = 0.95  # numbers included: closer than this to a source is a copy
VARIETY_THRESHOLD = THRESHOLD  # numbers hidden: the worded-alike matcher's own line
MAX_REGENERATIONS = 2  # after a wrong key, a copy or a look-alike
MAX_INVALID_RETRIES = 1  # after output that doesn't fit the schema

SINGLE_CORRECT = "single_correct"
# Formats the ladder can write and check. The rest are never generated.
ONE_OPTION = (SINGLE_CORRECT, "statement", "assertion_reason")
GENERATED_FORMATS = (*ONE_OPTION, "multiple_correct", "numeric", "match")
MIN_STATEMENTS = 2
MAX_STATEMENTS = 6
MAX_STEM = 1500
MAX_OPTION = 300
MAX_SOLUTION_STEPS = 12
MAX_SOLUTION_STEP = 500
MAX_SHORTCUT = 500

# --- the exam --------------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class ExamContext:
    """What a question must fit, all of it from the exam's data."""

    name: str
    stage: str | None  # None: the exam states no stage
    next_stage: str | None
    formats: tuple[str, ...]
    options: int
    marking: SectionMarking | None  # None: no marks stated for this subject
    base_time_seconds: float


def allowed_formats(
    question_types: Sequence[str], section_formats: Sequence[str] | None = None
) -> tuple[str, ...]:
    """The formats to write in: a section's own list, else what the stage's question types name
    ("choice" is one correct option, "typed" a number). Only those the ladder can check."""
    named = list(section_formats or [])
    if not named:
        plain = {"choice": SINGLE_CORRECT, "typed": "numeric"}
        named = [plain.get(name, name) for name in question_types]
    return tuple(f for f in GENERATED_FORMATS if f in named)


def base_time(duration_minutes: int | None, questions: int | None) -> float:
    """The stage's seconds per question, or the default when it doesn't state both."""
    if duration_minutes and questions:
        return duration_minutes * 60 / questions
    return ladder_times().base_time_seconds


def time_target(difficulty: Difficulty, base_seconds: float) -> int:
    times = ladder_times()
    seconds = base_seconds * times.factors[difficulty]
    rounded = int(seconds / times.round_to + 0.5) * times.round_to
    return min(times.max_seconds, max(times.min_seconds, rounded))


def marking_text(marking: SectionMarking | None) -> str:
    if marking is None:
        return "not stated"
    text = f"+{marking.marks_correct:g} for a correct answer, "
    text += f"-{marking.marks_wrong:g} for a wrong one"
    if marking.partial:
        text += ", with partial marks for some of the correct options and no wrong one"
    return text


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
    "You write original practice questions for learners. Never claim or imply "
    "that a question comes from an official or previous-year paper, and never invent exam "
    "patterns, cut-offs, marks or statistics. Every question must have one definite correct "
    "answer, which you have worked out yourself." + UNTRUSTED_RULE
)

GENERATED_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "step": {"type": "integer"},
        "difficulty": {"type": "string"},
        "model": {"type": "string"},
        "basis": {"type": "string"},
        "format": {"type": "string"},
        "question": {"type": "string"},
        "statements": {"type": "array", "items": {"type": "string"}},
        "options": {"type": "array", "items": {"type": "string"}},
        "answer_index": {"type": "integer"},
        "correct_indices": {"type": "array", "items": {"type": "integer"}},
        "numeric_answer": {"type": "string"},
        "tolerance": {"type": "string"},
        "match_left": {"type": "array", "items": {"type": "string"}},
        "match_right": {"type": "array", "items": {"type": "string"}},
        "match_pairs": {
            "type": "array",
            "items": {"type": "array", "items": {"type": "integer"}},
        },
        "solution": {"type": "string"},
        "shortcut": {"type": "string"},
    },
    "required": [
        "step",
        "difficulty",
        "model",
        "basis",
        "format",
        "question",
        "solution",
        "shortcut",
    ],
    "additionalProperties": False,
}

SOLVE_SYSTEM = "You solve exam questions carefully." + UNTRUSTED_RULE
_SOLVE_ANSWERS: dict[str, tuple[str, dict[str, Any]]] = {
    "multiple_correct": ("correct_indices", {"type": "array", "items": {"type": "integer"}}),
    "numeric": ("numeric_answer", {"type": "string"}),
    "match": (
        "match_pairs",
        {"type": "array", "items": {"type": "array", "items": {"type": "integer"}}},
    ),
}


def solve_schema(format_name: str) -> dict[str, Any]:
    """The solver's reply for this format: only the kind of answer the format takes."""
    field, kind = _SOLVE_ANSWERS.get(format_name, ("answer_index", {"type": "integer"}))
    return {
        "type": "object",
        "properties": {field: kind, "working": {"type": "string"}},
        "required": [field, "working"],
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


def _format_rules(exam: ExamContext) -> str:
    n = exam.options
    rules = {
        SINGLE_CORRECT: f"single_correct: exactly {n} options with exactly one correct answer.",
        "statement": (
            f'statement: {MIN_STATEMENTS} to {MAX_STATEMENTS} statements in "statements", then '
            f"exactly {n} options about which of them hold, exactly one correct."
        ),
        "assertion_reason": (
            f"assertion_reason: an assertion and a reason in the question, then exactly {n} "
            "options on whether each is true and whether the reason explains it, exactly one "
            "correct."
        ),
        "multiple_correct": (
            f"multiple_correct: exactly {n} options with one or more correct, listed in "
            '"correct_indices" (counted from 0).'
        ),
        "numeric": (
            'numeric: no options. "numeric_answer" is the number, as text. "tolerance" is how '
            'far an answer may be from it, as text, "0" when it must be exact.'
        ),
        "match": (
            'match: "match_left" and "match_right" are two lists. "match_pairs" gives each left '
            "item its right item as [left, right], counted from 0."
        ),
    }
    return "\n".join(f"- {rules[name]}" for name in exam.formats)


def _answer_fields(exam: ExamContext) -> str:
    formats = set(exam.formats)
    options = ", ".join(['"..."'] * exam.options)
    lines: list[str] = []
    if "statement" in formats:
        lines.append('  "statements": ["...", "..."],')
    if formats - {"numeric", "match"}:
        lines.append(f'  "options": [{options}],')
    if formats & set(ONE_OPTION):
        lines.append('  "answer_index": 0,')
    if "multiple_correct" in formats:
        lines.append('  "correct_indices": [0, 2],')
    if "numeric" in formats:
        lines.append('  "numeric_answer": "2.5",')
        lines.append('  "tolerance": "0.01",')
    if "match" in formats:
        lines.append('  "match_left": ["...", "..."],')
        lines.append('  "match_right": ["...", "..."],')
        lines.append('  "match_pairs": [[0, 1], [1, 0]],')
    if len(formats) > 1:
        lines.append("  (leave out the fields the chosen format doesn't use)")
    return "\n".join(lines)


def generator_prompt(
    *,
    exam: ExamContext,
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
            "exam": exam.name,
            "stage": exam.stage or "exam",
            "allowed_formats": _format_rules(exam),
            "first_format": exam.formats[0],
            "options_per_question": str(exam.options),
            "marking_scheme": marking_text(exam.marking),
            "base_time_seconds": f"{exam.base_time_seconds:g}",
            "above_hard": (
                f"the level of the {exam.next_stage} stage"
                if exam.next_stage
                else "multi-concept questions that still use syllabus methods"
            ),
            "answer_fields": _answer_fields(exam),
            **{
                f"seconds_{level}": str(time_target(level, exam.base_time_seconds))
                for level in LEVELS
            },
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


def _numbered(items: Sequence[str]) -> str:
    return "\n".join(f"{index}: {item}" for index, item in enumerate(items))


def solve_prompt(
    *,
    stem: str,
    options: Sequence[str],
    format_name: str = SINGLE_CORRECT,
    spec: Mapping[str, Any] | None = None,
) -> str:
    """Only what a learner would see: the solver must not see the key or the solution."""
    question = f"Question:\n{material(stem)}\n\n"
    if format_name == "numeric":
        return (
            f"{question}Solve this question. The answer is a number. Reply with JSON only: "
            '{"numeric_answer": "the number", "working": "..."}'
        )
    if format_name == "match":
        lists = question_formats.public_data(format_name, spec) or {}
        return (
            f"{question}Left list, numbered from 0:\n{material(_numbered(lists['left']))}\n\n"
            f"Right list, numbered from 0:\n{material(_numbered(lists['right']))}\n\n"
            "Match each left item to its right item. Reply with JSON only: "
            '{"match_pairs": [[left, right], ...], "working": "..."}'
        )
    options_text = f"Options, numbered from 0:\n{material(_numbered(options))}\n\n"
    if format_name == "multiple_correct":
        return (
            f"{question}{options_text}One or more options are correct. Solve this question. "
            'Reply with JSON only: {"correct_indices": [n, ...], "working": "..."}'
        )
    return (
        f"{question}{options_text}"
        'Solve this question. Reply with JSON only: {"answer_index": n, "working": "..."}'
    )


def web_query(*, exam_name: str, stage: str | None, topic: str, models: Sequence[str]) -> str:
    return " ".join([exam_name, *([stage] if stage else []), topic, *models[:2], "questions"])


# --- checks ----------------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class GeneratedQuestion:
    stem: str
    options: tuple[str, ...]
    answer_index: int | None  # None: the format keeps its answer in answer_spec
    solution: tuple[str, ...]
    shortcut: str
    time_target_seconds: int
    format: str = SINGLE_CORRECT
    answer_spec: Mapping[str, Any] | None = None


def _clean(text: str) -> str:
    return unicodedata.normalize("NFC", text.strip())


def _options(data: Mapping[str, Any], count: int) -> tuple[str, ...] | None:
    """Exactly [count] different options, or None."""
    cleaned = _text_list(data.get("options"))
    return tuple(cleaned) if cleaned is not None and len(cleaned) == count else None


def _text_list(value: object) -> list[str] | None:
    """Different, non-empty, short texts, or None."""
    if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
        return None
    cleaned = [_clean(v) for v in value]
    if len({c.casefold() for c in cleaned}) != len(cleaned):
        return None
    return cleaned if all(0 < len(c) <= MAX_OPTION for c in cleaned) else None


def _number_text(value: object) -> str | None:
    if isinstance(value, bool) or not isinstance(value, str | int | float):
        return None
    return str(value).strip()


def _int_list(value: object) -> list[int] | None:
    if not isinstance(value, list):
        return None
    if not all(isinstance(v, int) and not isinstance(v, bool) for v in value):
        return None
    return value


def _with_statements(stem: str, statements: object) -> str | None:
    """The statements are part of the question, as they are on a printed paper."""
    cleaned = _text_list(statements)
    if cleaned is None or not MIN_STATEMENTS <= len(cleaned) <= MAX_STATEMENTS:
        return None
    return "\n".join([stem, *(f"{i}. {text}" for i, text in enumerate(cleaned, start=1))])


def _numeric_spec(data: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "value": _number_text(data.get("numeric_answer")),
        "tolerance": _number_text(data.get("tolerance", "0")),
    }


def _match_spec(data: Mapping[str, Any]) -> dict[str, Any] | None:
    """Both lists and their pairs, each left item matched exactly once."""
    left, right = _text_list(data.get("match_left")), _text_list(data.get("match_right"))
    raw = data.get("match_pairs")
    if not left or not right or not isinstance(raw, list):
        return None
    pairs = [_int_list(pair) for pair in raw]
    if not all(pair is not None and len(pair) == 2 for pair in pairs):
        return None
    if sorted(pair[0] for pair in pairs if pair) != list(range(len(left))):
        return None
    return {"left": left, "right": right, "pairs": pairs}


def _answer(
    format_name: str, data: Mapping[str, Any], count: int
) -> tuple[tuple[str, ...], int | None, dict[str, Any] | None] | None:
    """The question's options, answer index and answer_spec, or None when they don't fit."""
    if format_name in ("numeric", "match"):
        spec = _numeric_spec(data) if format_name == "numeric" else _match_spec(data)
        if spec is None or question_formats.spec_problems(format_name, spec, 0):
            return None
        return (), None, spec
    options = _options(data, count)
    if options is None:
        return None
    if format_name in ONE_OPTION:
        index = data.get("answer_index")
        if isinstance(index, bool) or not isinstance(index, int) or not 0 <= index < count:
            return None
        return options, index, None
    indices = _int_list(data.get("correct_indices"))
    if indices is None:
        return None
    spec = {"correct_positions": sorted(i + 1 for i in indices)}
    return (
        None if question_formats.spec_problems(format_name, spec, count) else (options, None, spec)
    )


def validate_generated(
    data: dict[str, Any], exam: ExamContext, difficulty: Difficulty
) -> GeneratedQuestion | None:
    """The question, or None unless it uses a format the exam allows, fits that format and has a
    solution. The step, difficulty, model and basis it states are ignored: they come from the
    plan and from what was really sent. So is any time it states: that comes from the exam."""
    stem, solution, shortcut = data.get("question"), data.get("solution"), data.get("shortcut")
    format_name = data.get("format", SINGLE_CORRECT)
    if format_name not in exam.formats:
        return None
    if not isinstance(stem, str) or not isinstance(solution, str):
        return None
    answer = _answer(format_name, data, exam.options)
    if answer is None:
        return None
    steps = tuple(_clean(line) for line in solution.splitlines() if line.strip())
    if not steps or len(steps) > MAX_SOLUTION_STEPS:
        return None
    if any(len(s) > MAX_SOLUTION_STEP for s in steps):
        return None
    full_stem: str | None = _clean(stem)
    if format_name == "statement":
        full_stem = _with_statements(full_stem or "", data.get("statements"))
    if full_stem is None or not 0 < len(full_stem) <= MAX_STEM:
        return None
    options, index, spec = answer
    return GeneratedQuestion(
        stem=full_stem,
        options=options,
        answer_index=index,
        solution=steps,
        shortcut=_clean(shortcut)[:MAX_SHORTCUT] if isinstance(shortcut, str) else "",
        time_target_seconds=time_target(difficulty, exam.base_time_seconds),
        format=format_name,
        answer_spec=spec,
    )


def solver_agrees(data: dict[str, Any], question: GeneratedQuestion) -> bool:
    """The independent solve reached the question's key: the same option, the same set of
    options, a number within the tolerance, or exactly the same pairs."""
    spec = question.answer_spec
    if spec is None:
        answer = data.get("answer_index")
        return not isinstance(answer, bool) and answer == question.answer_index
    if question.format == "numeric":
        number = _number_text(data.get("numeric_answer"))
        return number is not None and question_formats.is_correct("numeric", spec, number)
    if question.format == "match":
        return question_formats.is_correct("match", spec, {"pairs": data.get("match_pairs")})
    indices = _int_list(data.get("correct_indices"))
    if indices is None:
        return False
    positions = [i + 1 for i in indices]
    return question_formats.is_correct(question.format, spec, {"positions": positions})


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
    """Options in a new order, with the answer following its option. In a match question the
    right list moves and the pairs follow it."""
    spec = question.answer_spec
    if question.format == "match" and spec is not None:
        order = list(range(len(spec["right"])))
        rng.shuffle(order)
        pairs = [[left, order.index(right)] for left, right in spec["pairs"]]
        moved = {**spec, "right": [spec["right"][i] for i in order], "pairs": pairs}
        return replace(question, answer_spec=moved)
    order = list(range(len(question.options)))
    rng.shuffle(order)
    options = tuple(question.options[i] for i in order)
    if question.answer_index is not None:
        return replace(question, options=options, answer_index=order.index(question.answer_index))
    if spec is None or question.format != "multiple_correct":
        return replace(question, options=options)
    positions = sorted(order.index(p - 1) + 1 for p in spec["correct_positions"])
    return replace(question, options=options, answer_spec={"correct_positions": positions})


def mark(
    *,
    format_name: str,
    spec: Mapping[str, Any] | None,
    answer_index: int | None,
    answer: scoring.Answer,
    marking: tuple[float, float, Mapping[str, Any] | None] | None,
) -> tuple[bool, float | None]:
    """Whether the answer is right and what it scores, with the same scoring as a mock.
    ``marking``: marks for a correct answer, deducted for a wrong one, and the partial rule."""
    right, wrong, partial = marking or (0.0, 0.0, None)
    item = scoring.ScoredItem(
        position=1,
        section=None,
        topic_id=None,
        correct_position=answer_index,
        marks_correct=scoring.to_decimal(right),
        marks_wrong=scoring.to_decimal(wrong),
        format=format_name,
        answer_spec=spec,
        partial_rule=partial,
    )
    result = scoring.score_session([item], {1: answer})
    return result.outcomes[1] is True, None if marking is None else float(result.total.score)


def answer_lines(
    format_name: str, spec: Mapping[str, Any] | None, options: Sequence[str]
) -> list[str]:
    """The right answer in words, for formats that can't just highlight one option."""
    if spec is None:
        return []
    if format_name == "multiple_correct":
        return [options[p - 1] for p in spec["correct_positions"]]
    if format_name == "numeric":
        tolerance = Decimal(str(spec.get("tolerance") or "0"))
        return [f"{spec['value']} ± {spec['tolerance']}" if tolerance else str(spec["value"])]
    if format_name == "match":
        return [f"{spec['left'][a]} → {spec['right'][b]}" for a, b in sorted(spec["pairs"])]
    return []


def climbed(steps: Sequence[tuple[int, bool | None]]) -> int:
    """How high a ladder was climbed: the last step cleared without a miss before it."""
    height = 0
    for number, correct in sorted(steps):
        if correct is not True:
            break
        height = number
    return height
