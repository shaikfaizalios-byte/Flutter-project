"""Official pages where a learner can get papers for an exam (data/paper_sources; pure).

Each page is entered by a person who opened it and saw what it offers, with the date. The app
only opens these pages in the browser; PrepLoop never fetches them.
"""

import json
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

FOLDER = Path(__file__).resolve().parents[2] / "data" / "paper_sources"
REQUIRED = ("title", "url", "publisher", "offers", "checked_on", "checked_by")


@dataclass(frozen=True, slots=True)
class PaperSource:
    title: str
    url: str
    publisher: str
    offers: str
    checked_on: date


def source_problems(entry: dict[str, Any]) -> list[str]:
    """What is missing or unsafe in one listed page; [] when it can be shown."""
    problems = [f"missing {name}" for name in REQUIRED if not str(entry.get(name) or "").strip()]
    url = urlsplit(str(entry.get("url") or ""))
    if url.scheme != "https" or not url.netloc:
        problems.append("url must be https")
    try:
        date.fromisoformat(str(entry.get("checked_on")))
    except ValueError:
        problems.append("checked_on must be a date (YYYY-MM-DD)")
    return problems


def read_sources(data: dict[str, Any]) -> dict[str, tuple[PaperSource, ...]]:
    """Every exam's pages. Raises ValueError naming the first entry with a problem."""
    result: dict[str, tuple[PaperSource, ...]] = {}
    for code, entries in (data.get("exams") or {}).items():
        pages = []
        for entry in entries:
            problems = source_problems(entry)
            if problems:
                raise ValueError(f"{code}: {entry.get('title')!r}: {', '.join(problems)}")
            pages.append(
                PaperSource(
                    title=entry["title"].strip(),
                    url=entry["url"].strip(),
                    publisher=entry["publisher"].strip(),
                    offers=entry["offers"].strip(),
                    checked_on=date.fromisoformat(entry["checked_on"]),
                )
            )
        result[code] = tuple(pages)
    return result


def load_sources() -> dict[str, tuple[PaperSource, ...]]:
    text = (FOLDER / "paper_sources.json").read_text(encoding="utf-8")
    return read_sources(json.loads(text))
