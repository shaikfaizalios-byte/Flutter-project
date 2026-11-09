"""Which exams use the stricter ladder, and how strict. Pure.

Each file in ``data/ladder_rules`` names one exam: what its levels mean and the formats to write.
The numbers are in defaults.json ``ladder.strict``. They are product choices, and a new exam or a
changed rule needs no code. An exam with no file keeps the ordinary ladder.
"""

import json
from collections.abc import Mapping
from dataclasses import dataclass
from functools import cache
from pathlib import Path
from typing import Any

from app.domain.exam_profile import ladder_strict_settings

RULES_DIR = Path(__file__).resolve().parents[2] / "data" / "ladder_rules"


@dataclass(frozen=True, slots=True)
class LadderRules:
    formats: tuple[str, ...]
    anchors: Mapping[str, str]


@cache
def _all_rules() -> dict[str, LadderRules]:
    found = {}
    for path in sorted(RULES_DIR.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        found[data["exam_code"]] = LadderRules(
            formats=tuple(data["formats"]), anchors=dict(data["anchors"])
        )
    return found


def rules_for(exam_code: str) -> LadderRules | None:
    return _all_rules().get(exam_code)


def _strict() -> dict[str, Any]:
    return ladder_strict_settings()


def solves_needed(level: str, kind: str | None) -> int:
    """Independent solves that must all agree. Fact recall can't be recalculated, so it always
    has at least the fact-recall number."""
    settings = _strict()
    needed = int(settings["solves"][level])
    return max(needed, int(settings["fact_recall_solves"])) if kind == "fact_recall" else needed


def is_gated(level: str) -> bool:
    return level in _strict()["gated_levels"]


def needs_human_review(level: str) -> bool:
    return level in _strict()["review_levels"]


def library_level(level: str) -> str:
    level_map: dict[str, str] = _strict()["library_levels"]
    return level_map[level]


def tolerance() -> float:
    return float(_strict()["option_tolerance"])


def gate_open(accepted: int, correct: int, threshold: float | None) -> bool:
    """Open only with a threshold set and enough accepted items at or above it."""
    if threshold is None or accepted < int(_strict()["gate_min_accepted"]):
        return False
    return correct / accepted >= threshold
