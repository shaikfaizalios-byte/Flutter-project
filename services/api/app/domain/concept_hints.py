"""Grouping questions by meaning with AI. Pure: the prompt, and reading the answer.

The result is a hint. It lives apart from topics and models, never changes a count, and is labelled
as AI wherever it is shown.
"""

from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any

from app.domain.untrusted import UNTRUSTED_RULE, material

PROMPT_VERSION = "concept-hint-1"
MAX_QUESTIONS = 80  # per request
MAX_TEXT = 400  # characters of each question
MAX_LABEL = 200
MIN_TEXT = 15  # less than this can't say what a question tests

SYSTEM = (
    "You group exam questions that test the same concept, even when their numbers or wording "
    "differ. You never solve them and never add questions." + UNTRUSTED_RULE
)
SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "groups": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "label": {"type": "string"},
                    "questions": {"type": "array", "items": {"type": "integer"}},
                },
                "required": ["label", "questions"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["groups"],
    "additionalProperties": False,
}


@dataclass(frozen=True, slots=True)
class HintGroup:
    label: str
    positions: tuple[int, ...]  # from 0, in the order the questions were sent


def prompt(texts: Sequence[str]) -> str:
    numbered = "\n".join(
        f"{i}. {' '.join(text.split())[:MAX_TEXT]}" for i, text in enumerate(texts, start=1)
    )
    return (
        "These are numbered exam questions on one topic. Group those that test the same concept. "
        "Leave out any that fit no group. Name each group's concept in a few words. "
        'Return JSON only: {"groups": [{"label": "...", "questions": [1, 4]}]}\n'
        + material(numbered)
    )


def read_groups(data: dict[str, Any], count: int) -> list[HintGroup]:
    """Keeps only what can be trusted: known numbers, each question once, two or more a group."""
    groups = data.get("groups")
    if not isinstance(groups, list):
        return []
    used: set[int] = set()
    found = []
    for group in groups:
        if not isinstance(group, dict):
            continue
        label = group.get("label")
        numbers = group.get("questions")
        if not isinstance(label, str) or not label.strip() or not isinstance(numbers, list):
            continue
        positions = []
        for number in numbers:
            if type(number) is int and 1 <= number <= count and number not in used:
                used.add(number)
                positions.append(number - 1)
        if len(positions) >= 2:
            found.append(HintGroup(" ".join(label.split())[:MAX_LABEL], tuple(positions)))
    return found
