"""Question history: what a question looked like when it was read from its paper, and every
change made to it since. Pure.

A revision stores a snapshot of the tracked fields after the action. Revisions are only ever
added, so the answer as the paper gave it stays known after a reviewer changes it, and a
learner's correction is never presented as the paper's own answer.
"""

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Any, Literal

# What a revision snapshots: the question's wording and its answer.
TRACKED_FIELDS = (
    "stem",
    "options",
    "answer_type",
    "correct_option_position",
    "typed_answer",
    "model_answer",
    "answer_source",
    "explanation",
    "format",
    "answer_spec",
)
ANSWER_FIELDS = (
    "answer_type",
    "correct_option_position",
    "typed_answer",
    "model_answer",
    "format",
    "answer_spec",
)
# The fields that hold an answer. ``answer_type`` and ``format`` always have a value.
ANSWER_VALUES = ("correct_option_position", "typed_answer", "model_answer", "answer_spec")

# extracted: read from the paper (by PrepLoop's rules or by AI); generated: an AI question;
# baseline: the state when history began (questions read before it; earlier edits unknown);
# edited: a reviewer changed it.
Action = Literal["extracted", "generated", "baseline", "edited"]
Actor = Literal["rules", "ai", "reviewer", "migration"]

# Where the current answer comes from.
AnswerOrigin = Literal["paper", "reviewer", "ai", "none"]


def snapshot(
    *,
    stem: str,
    options: Sequence[tuple[str, str]],
    answer_type: str,
    correct_option_position: int | None,
    typed_answer: str | None,
    model_answer: str | None,
    answer_source: str | None,
    explanation: str | None,
    format_name: str,
    answer_spec: Mapping[str, Any] | None,
) -> dict[str, Any]:
    return {
        "stem": stem,
        "options": [{"label": label, "text": text} for label, text in options],
        "answer_type": answer_type,
        "correct_option_position": correct_option_position,
        "typed_answer": typed_answer,
        "model_answer": model_answer,
        "answer_source": answer_source,
        "explanation": explanation,
        "format": format_name,
        "answer_spec": answer_spec,
    }


def changed_fields(before: Mapping[str, Any] | None, after: Mapping[str, Any]) -> list[str]:
    """Tracked fields whose value differs (all of them when there is no earlier snapshot)."""
    if before is None:
        return list(TRACKED_FIELDS)
    return [f for f in TRACKED_FIELDS if before.get(f) != after.get(f)]


def has_answer(snap: Mapping[str, Any]) -> bool:
    return any(snap.get(f) is not None for f in ANSWER_VALUES)


def answer_origin(*, origin: str, answer_source: str | None, answered: bool) -> AnswerOrigin:
    """``answer_source`` "answer_key" / "inline" = as read from the paper; "manual" = set or
    changed by a reviewer. AI-generated questions carry the AI's own answer."""
    if origin == "ai":
        return "ai"
    if not answered:
        return "none"
    if answer_source in ("answer_key", "inline"):
        return "paper"
    return "reviewer"


@dataclass(frozen=True, slots=True)
class PaperAnswer:
    """The answer the paper gave when the question was first read (all None: no answer)."""

    source: str | None  # "answer_key" | "inline" | None
    option_position: int | None
    option_label: str | None
    option_text: str | None
    typed_answer: str | None
    written_answer: str | None


def paper_answer(extracted: Mapping[str, Any] | None) -> PaperAnswer | None:
    """The paper's answer from the question's "extracted" snapshot; None when that snapshot
    does not exist (read before history began, or not from a paper)."""
    if extracted is None:
        return None
    source = extracted.get("answer_source")
    if source not in ("answer_key", "inline"):
        return PaperAnswer(None, None, None, None, None, None)
    position = extracted.get("correct_option_position")
    options = extracted.get("options") or []
    option = (
        options[position - 1]
        if isinstance(position, int) and 0 < position <= len(options)
        else None
    )
    return PaperAnswer(
        source=str(source),
        option_position=position if isinstance(position, int) else None,
        option_label=option["label"] if option else None,
        option_text=option["text"] if option else None,
        typed_answer=extracted.get("typed_answer"),
        written_answer=extracted.get("model_answer"),
    )
