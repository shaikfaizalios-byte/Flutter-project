"""Compensatory time for candidates with disabilities, as a verified format states it. Pure.

The rule lives in the format's ``conduct`` as ``compensatory_time``:
``{"minutes_per_hour": 20, "reference": "Notice ..., para ..."}`` — both taken from the official
notice by the reviewer who publishes the format. PrepLoop never fills it in: a format without it
offers no compensatory time. A learner who declares it applies to them (in the app; nothing about
it is stored on the server) gets the rule's extra minutes in mocks of that format, pro rata for a
part of the paper, rounded up to the whole minute.
"""

import math
from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any

MAX_MINUTES_PER_HOUR = 60


@dataclass(frozen=True, slots=True)
class CompensatoryRule:
    minutes_per_hour: int
    reference: str

    def extra_minutes(self, minutes: int) -> int:
        """Extra time for [minutes] of the paper (a whole paper or one timed section)."""
        return math.ceil(minutes * self.minutes_per_hour / 60)

    def to_json(self) -> dict[str, Any]:
        return {"minutes_per_hour": self.minutes_per_hour, "reference": self.reference}


def compensatory_rule(conduct: Mapping[str, Any] | None) -> CompensatoryRule | None:
    """The format's rule; None when it states none (or states it incompletely)."""
    raw = (conduct or {}).get("compensatory_time")
    if not isinstance(raw, Mapping):
        return None
    minutes, reference = raw.get("minutes_per_hour"), raw.get("reference")
    if (
        not isinstance(minutes, int)
        or isinstance(minutes, bool)
        or not 0 < minutes <= MAX_MINUTES_PER_HOUR
        or not isinstance(reference, str)
        or not reference.strip()
    ):
        return None
    return CompensatoryRule(minutes, reference.strip())


def compensatory_problems(conduct: Mapping[str, Any] | None) -> list[str]:
    """Why a stated rule can't be published (missing or out-of-range value, no reference)."""
    if "compensatory_time" not in (conduct or {}):
        return []
    if compensatory_rule(conduct) is None:
        return [
            "Compensatory time needs minutes_per_hour (1-60) and the notice's reference, "
            "both from the official notice."
        ]
    return []
