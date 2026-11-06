"""Checks that a change left real imported papers untouched (read-only, operator's machine).

    python -m app.cli.characterize save --exam EXAM_CODE [--exam EXAM_CODE ...]
    python -m app.cli.characterize compare

``save`` records, per account and exam, the repeats report and a fresh parser run over the
stored page text; ``compare`` repeats that and reports any difference. Only counts and hashes
are written, never question text or file names, and only outside the repository
(``~/.preploop/characterization``). Reviewing papers between the two runs also shows up as a
difference, so compare on data nobody touched.
"""

import argparse
import hashlib
import json
import sys
import uuid
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.database.session import build_engine, build_sessionmaker
from app.domain.segmentation import PageText, segment
from app.models.document import Document, DocumentPage
from app.services.exam_profiles import profile_for
from app.services.insights_service import InsightsService
from app.services.topic_service import visible_topics

BASELINE = Path.home() / ".preploop" / "characterization" / "baseline.json"


def _digest(value: Any) -> str:
    text = json.dumps(value, ensure_ascii=False, sort_keys=True, default=str)
    return hashlib.sha256(text.encode()).hexdigest()[:16]


def _comparable(value: Any) -> Any:
    """Leaves out ``dropped: false``, added after the first baselines. A true one still counts."""
    if isinstance(value, dict):
        return {k: _comparable(v) for k, v in value.items() if not (k == "dropped" and v is False)}
    if isinstance(value, list):
        return [_comparable(v) for v in value]
    return value


def _parsed(session: Session, document: Document) -> dict[str, Any]:
    pages = session.scalars(
        select(DocumentPage)
        .where(DocumentPage.document_id == document.id)
        .order_by(DocumentPage.page_number)
    ).all()
    result = segment(
        [PageText(p.page_number, p.text, p.needs_review) for p in pages],
        expected_options=profile_for(session, document.exam_code).expected_options,
        extra_headings=sorted(
            {t.subject for t in visible_topics(session, document.owner_id, document.exam_code)}
        ),
    )
    shape = [
        [q.section, q.number, len(q.options), sorted(str(i.code) for i in q.issues)]
        for q in result.questions
    ]
    return {"questions": len(shape), "digest": _digest(shape)}


def snapshot(session: Session, exams: list[str]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for exam in exams:
        documents = session.scalars(
            select(Document).where(Document.exam_code == exam).order_by(Document.id)
        ).all()
        owners: set[uuid.UUID] = {d.owner_id for d in documents if d.owner_id}
        for owner in sorted(owners):
            report = InsightsService(session, owner).repeats(exam)
            result[f"{exam}/{_digest(str(owner))}"] = {
                "papers": report.papers.total,
                "topics": len(report.topics),
                "models": sum(len(t.patterns) for t in report.topics),
                "worded_alike": len(report.similar_groups),
                "not_seen": len(report.not_repeated.not_seen),
                "report": _digest(_comparable(report.model_dump(mode="json"))),
            }
        for document in documents:
            result[f"{exam}/paper/{_digest(str(document.id))}"] = _parsed(session, document)
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["save", "compare"])
    parser.add_argument("--exam", action="append", default=[])
    args = parser.parse_args(argv)
    saved: dict[str, Any] = (
        json.loads(BASELINE.read_text(encoding="utf-8")) if BASELINE.is_file() else {}
    )
    if args.action == "save" and not args.exam:
        parser.error("name at least one --exam")
    if args.action == "compare" and not saved:
        parser.error("nothing saved yet")
    exams = args.exam if args.action == "save" else saved["exams"]

    engine = build_engine(get_settings())
    if engine is None:
        parser.error("no database is configured")
    with build_sessionmaker(engine)() as session:
        current = snapshot(session, exams)
        session.rollback()
    if args.action == "save":
        BASELINE.parent.mkdir(parents=True, exist_ok=True)
        BASELINE.write_text(
            json.dumps({"exams": exams, "entries": current}, indent=1), encoding="utf-8"
        )
        print(f"Saved {len(current)} entries to {BASELINE}")
        return 0
    expected = saved["entries"]
    different = sorted(
        k for k in expected.keys() | current.keys() if expected.get(k) != current.get(k)
    )
    for key in different:
        print(f"DIFFERENT {key}: {expected.get(key)} -> {current.get(key)}")
    print(f"{len(current) - len(different)} of {len(expected)} entries unchanged")
    return 1 if different else 0


if __name__ == "__main__":
    sys.exit(main())
