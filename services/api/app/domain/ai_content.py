"""Prompts, output schemas and validation for AI assistance (pure; no provider calls).

Prompt versions are stored with every AI item so a change in wording is traceable.
Generated content is validated before storage; anything invalid is rejected and counted,
never "repaired" silently.
"""

import unicodedata
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any

PROMPT_VERSION = "p9.1"
OPTIONS_PER_QUESTION = 4  # SSC CGL/CHSL objective questions have four options
MAX_GENERATED = 5

LANGUAGE_NAMES = {"en": "English", "hi": "Hindi (Devanagari script)"}

SYSTEM = (
    "You help Indian students prepare for SSC CGL and SSC CHSL exams. You write original "
    "practice material only. Never claim or imply that anything you write is from an "
    "official or previous-year paper, and never invent exam patterns, cut-offs, marks or "
    "statistics. If you are not sure something is correct, say so in the explanation "
    "instead of guessing."
)

EXPLANATION_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "explanation": {"type": "string"},
        "confident": {"type": "boolean"},
    },
    "required": ["explanation", "confident"],
    "additionalProperties": False,
}

QUESTIONS_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "questions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "stem": {"type": "string"},
                    "options": {"type": "array", "items": {"type": "string"}},
                    "correct_option": {"type": "integer"},
                    "explanation": {"type": "string"},
                },
                "required": ["stem", "options", "correct_option", "explanation"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["questions"],
    "additionalProperties": False,
}

TOPIC_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {"topic": {"anyOf": [{"type": "string"}, {"type": "null"}]}},
    "required": ["topic"],
    "additionalProperties": False,
}


def _fmt_options(options: list[str]) -> str:
    return "\n".join(f"({i}) {text}" for i, text in enumerate(options, start=1))


def explanation_prompt(
    *, stem: str, options: list[str], correct: int, subject: str | None, language: str
) -> str:
    return (
        f"Subject: {subject or 'not given'}\n"
        f"Question:\n{stem}\n\nOptions:\n{_fmt_options(options)}\n\n"
        f"The correct answer is option ({correct}).\n\n"
        f"Write a short step-by-step explanation (at most 150 words) of why option "
        f"({correct}) is correct, in {LANGUAGE_NAMES[language]}. Set confident to false if "
        "you think the given answer may be wrong or the question is unclear."
    )


def questions_from_question_prompt(
    *,
    stem: str,
    options: list[str],
    correct: int,
    subject: str | None,
    topic: str | None,
    language: str,
    count: int,
) -> str:
    return (
        f"Subject: {subject or 'not given'}. Topic: {topic or 'not given'}.\n"
        f"Example question (do not copy it):\n{stem}\n{_fmt_options(options)}\n"
        f"Answer: ({correct})\n\n"
        f"Write {count} new, different multiple-choice practice questions on the same "
        f"topic and level, in {LANGUAGE_NAMES[language]}. Each has exactly "
        f"{OPTIONS_PER_QUESTION} distinct options, exactly one correct option "
        "(correct_option is 1-based) and a short explanation."
    )


def questions_from_notes_prompt(
    *, title: str, notes: str, subject: str, topic: str, language: str, count: int
) -> str:
    return (
        f"Subject: {subject}. Topic: {topic}.\n"
        f"The student's own notes on '{title}':\n{notes or '(no notes)'}\n\n"
        f"Write {count} multiple-choice practice questions that test this concept at SSC "
        f"CGL/CHSL level, in {LANGUAGE_NAMES[language]}. Each has exactly "
        f"{OPTIONS_PER_QUESTION} distinct options, exactly one correct option "
        "(correct_option is 1-based) and a short explanation. If the notes contain a "
        "mistake, do not repeat it."
    )


def topic_prompt(*, stem: str, subject: str, topics: list[str]) -> str:
    listed = "\n".join(f"- {t}" for t in topics)
    return (
        f"Subject: {subject}\nQuestion:\n{stem}\n\n"
        f"Choose the single best topic for this question from this list, copying the name "
        f"exactly:\n{listed}\n\nUse null if none fits."
    )


# --- validation -----------------------------------------------------------------------

MAX_STEM = 2000
MAX_OPTION = 500
MAX_EXPLANATION = 3000
MIN_STEM = 10


def _norm(text: str) -> str:
    return " ".join(unicodedata.normalize("NFC", text).split()).casefold()


@dataclass(frozen=True, slots=True)
class GeneratedQuestion:
    stem: str
    options: list[str]
    correct_option: int
    explanation: str


def validate_generated(
    item: Any, *, avoid_stems: Sequence[str] = ()
) -> tuple[GeneratedQuestion | None, list[str]]:
    """Checks one generated question. Returns the cleaned question, or None with the
    reasons it was rejected (codes, safe to store and show)."""
    problems: list[str] = []
    if not isinstance(item, dict):
        return None, ["not_an_object"]
    stem = item.get("stem")
    options = item.get("options")
    correct = item.get("correct_option")
    explanation = item.get("explanation")

    if not isinstance(stem, str) or not (MIN_STEM <= len(stem.strip()) <= MAX_STEM):
        problems.append("bad_stem")
    if not isinstance(options, list) or len(options) != OPTIONS_PER_QUESTION:
        problems.append("wrong_option_count")
    elif not all(isinstance(o, str) and 0 < len(o.strip()) <= MAX_OPTION for o in options):
        problems.append("bad_option")
    elif len({_norm(o) for o in options}) != len(options):
        problems.append("duplicate_options")
    if (
        isinstance(correct, bool)
        or not isinstance(correct, int)
        or not 1 <= correct <= OPTIONS_PER_QUESTION
    ):
        problems.append("bad_answer")
    if not isinstance(explanation, str) or not (0 < len(explanation.strip()) <= MAX_EXPLANATION):
        problems.append("bad_explanation")
    if isinstance(stem, str) and _norm(stem) in {_norm(s) for s in avoid_stems}:
        problems.append("copied_source")
    if problems:
        return None, problems
    assert isinstance(stem, str) and isinstance(options, list)  # noqa: S101 - checked above
    assert isinstance(correct, int) and isinstance(explanation, str)  # noqa: S101
    clean = [unicodedata.normalize("NFC", o.strip()) for o in options]
    return (
        GeneratedQuestion(
            stem=unicodedata.normalize("NFC", stem.strip()),
            options=clean,
            correct_option=correct,
            explanation=unicodedata.normalize("NFC", explanation.strip()),
        ),
        [],
    )


def validate_explanation(data: dict[str, Any]) -> tuple[str | None, bool]:
    """Returns (explanation or None if unusable, whether the model was confident)."""
    text = data.get("explanation")
    confident = data.get("confident") is True
    if not isinstance(text, str) or not (0 < len(text.strip()) <= MAX_EXPLANATION):
        return None, confident
    return unicodedata.normalize("NFC", text.strip()), confident


def pick_topic(data: dict[str, Any], topics: list[str]) -> str | None:
    """The chosen topic if it is exactly one of [topics] (case-insensitive), else None."""
    choice = data.get("topic")
    if not isinstance(choice, str):
        return None
    by_key = {_norm(t): t for t in topics}
    return by_key.get(_norm(choice))
