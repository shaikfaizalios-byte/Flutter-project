"""Current affairs cards from the learner's own sources. Pure.

The learner pastes text or imports a PDF (PrepLoop never fetches a page). The AI drafts revision
cards, each naming the part of the material it comes from and quoting it. A card is kept only when
its quote is really in that part, so every card can be traced back to what the learner gave; the
learner then approves each one before it is saved. Cards are always labelled AI-generated.
"""

import re
import unicodedata
from dataclasses import dataclass
from typing import Any

from app.domain.ai_content import LANGUAGE_NAMES
from app.domain.untrusted import UNTRUSTED_RULE, material

MAX_CARDS = 15
FRONT_MAX = 200  # a concept's title
BACK_MAX = 800
QUOTE_MIN = 12  # shorter quotes prove little
QUOTE_MAX = 300
MATERIAL_MAX = 60_000  # characters sent to the AI; the rest is left out and the app says so
TEXT_MAX = 20_000  # pasted text

SYSTEM = (
    "You turn news and current affairs material that a learner gives you into revision cards "
    "for a competitive exam. Use ONLY the facts in the material: never add facts, dates, "
    "numbers or names from your own knowledge, and never guess. Each card names its source "
    "part and quotes the words it comes from, exactly as they appear." + UNTRUSTED_RULE
)

SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "cards": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "front": {"type": "string"},
                    "back": {"type": "string"},
                    "source": {"type": "string"},
                    "quote": {"type": "string"},
                },
                "required": ["front", "back", "source", "quote"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["cards"],
    "additionalProperties": False,
}


@dataclass(frozen=True, slots=True)
class SourcePart:
    key: str  # "P1", "P2", ... the name the model cites
    label: str  # shown to the learner: "Pasted text", "news.pdf, page 3"
    text: str


@dataclass(frozen=True, slots=True)
class Card:
    front: str  # a question or prompt
    back: str  # the answer, from the material
    source_label: str
    quote: str  # the words of the material it comes from


def parts_within_limit(parts: list[SourcePart]) -> tuple[list[SourcePart], bool]:
    """The parts that fit in [MATERIAL_MAX] characters, in order, and whether any were left
    out."""
    kept: list[SourcePart] = []
    used = 0
    for part in parts:
        if not part.text.strip():
            continue
        if used + len(part.text) > MATERIAL_MAX:
            if not kept:  # one very long part: its start
                kept.append(SourcePart(part.key, part.label, part.text[:MATERIAL_MAX]))
            return kept, True
        kept.append(part)
        used += len(part.text)
    return kept, False


def prompt(parts: list[SourcePart], *, language: str) -> str:
    blocks = "\n\n".join(f"Part {p.key} ({p.label}):\n{material(p.text)}" for p in parts)
    return (
        f"Make up to {MAX_CARDS} revision cards in {LANGUAGE_NAMES[language]} from the material "
        "below: the facts an exam could ask about (who, what, where, when, how many).\n"
        "- front: a short question or prompt.\n"
        "- back: the answer, using the material's facts only.\n"
        "- source: the part it comes from, like P1.\n"
        f"- quote: {QUOTE_MIN} to {QUOTE_MAX} characters copied exactly from that part, "
        "showing the fact.\n"
        "Skip anything the material doesn't state clearly. Return no cards if it has no such "
        "facts.\n\n" + blocks
    )


def validate(data: Any, parts: list[SourcePart]) -> tuple[list[Card], int]:
    """The usable cards, and how many were dropped (wrong shape, unknown part, a quote not in
    its part, repeats)."""
    raw = data.get("cards") if isinstance(data, dict) else None
    if not isinstance(raw, list):
        return [], 0
    by_key = {p.key: p for p in parts}
    cards: list[Card] = []
    seen: set[str] = set()
    dropped = 0
    for item in raw[: MAX_CARDS * 2]:
        card = _card(item, by_key)
        if card is None or _fold(card.front) in seen or len(cards) >= MAX_CARDS:
            dropped += 1
            continue
        seen.add(_fold(card.front))
        cards.append(card)
    return cards, dropped


def _card(item: Any, parts: dict[str, SourcePart]) -> Card | None:
    if not isinstance(item, dict):
        return None
    values = [item.get(k) for k in ("front", "back", "source", "quote")]
    if not all(isinstance(v, str) for v in values):
        return None
    front, back, source, quote = (_clean(str(v)) for v in values)
    part = parts.get(source.upper())
    if (
        part is None
        or not 0 < len(front) <= FRONT_MAX
        or not 0 < len(back) <= BACK_MAX
        or not QUOTE_MIN <= len(quote) <= QUOTE_MAX
        or _fold(quote) not in _fold(part.text)
    ):
        return None
    return Card(front=front, back=back, source_label=part.label, quote=quote)


def _clean(text: str) -> str:
    return " ".join(unicodedata.normalize("NFC", text).split())


def _fold(text: str) -> str:
    """For comparing a quote with its part: case, spacing and quote marks don't matter."""
    text = unicodedata.normalize("NFKC", text).casefold()
    text = re.sub("[\u2018\u2019\u201c\u201d\"']", "", text)
    return " ".join(text.split())
