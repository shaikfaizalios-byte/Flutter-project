"""What makes one exam different from another, read from data, never written in code.

Each exam's own values live in ``data/exam_templates`` (with a source for each); anything an
exam leaves unset comes from ``defaults.json``. An exam's sections, timing and marking stay in
its versioned formats (app/domain/exam_format.py).
"""

import json
from dataclasses import dataclass
from functools import cache
from pathlib import Path
from typing import Any

DATA_DIR = Path(__file__).resolve().parents[2] / "data"
TEMPLATES_DIR = DATA_DIR / "exam_templates"
FORMATS_DIR = DATA_DIR / "exam_formats"
DEFAULTS_FILE = "defaults.json"

KINDS = ("mcq", "descriptive", "mixed")
COUNTING_UNITS = ("paper", "session")
# Stored in ``exams.options_per_question``: the number of options differs from paper to paper.
VARIABLE_OPTIONS = 0


@dataclass(frozen=True, slots=True)
class ExamProfile:
    kind: str
    options_per_question: int | None  # None: differs from paper to paper
    repeat_share: float  # "seen in most papers": at least this share of them...
    min_papers: int  # ...once there are at least this many
    reliable_papers: int  # fewer than this is shown as a small sample
    counting_unit: str

    @property
    def expected_options(self) -> int:
        """The option count to check papers against and to write questions with."""
        return self.options_per_question or int(_defaults()["options_per_question"])


@cache
def _defaults() -> dict[str, Any]:
    data: dict[str, Any] = json.loads((TEMPLATES_DIR / DEFAULTS_FILE).read_text(encoding="utf-8"))
    return data


def resolve(
    *,
    kind: str | None = None,
    options_per_question: int | None = None,
    repeat_share: float | None = None,
    min_papers: int | None = None,
    reliable_papers: int | None = None,
    counting_unit: str | None = None,
) -> ExamProfile:
    """The stored values of an exam, with the defaults for what it leaves unset."""
    base = _defaults()
    options = base["options_per_question"] if options_per_question is None else options_per_question
    return ExamProfile(
        kind=kind or base["kind"],
        options_per_question=None if options == VARIABLE_OPTIONS else int(options),
        repeat_share=base["repeat_share"] if repeat_share is None else repeat_share,
        min_papers=base["min_papers"] if min_papers is None else min_papers,
        reliable_papers=base["reliable_papers"] if reliable_papers is None else reliable_papers,
        counting_unit=counting_unit or base["counting_unit"],
    )
