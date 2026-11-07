"""Adds a shared syllabus version from a data file (data/syllabi).

    python -m app.cli.syllabus check FILE.json
    python -m app.cli.syllabus import FILE.json --reviewer "A. Reviewer"

A new version needs an official source and an effective year. Leaves become topics of the exam,
reusing the ones it has, so a topic keeps its history from one version to the next.
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Annotated, Any

from pydantic import BaseModel, ConfigDict, StringConstraints, ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.database.session import build_engine, build_sessionmaker
from app.models.exam import Exam
from app.models.syllabus import SyllabusVersion
from app.schemas.syllabus import EffectiveYear, SyllabusTreeInput
from app.services.content import audit
from app.services.syllabus_tree_service import save_tree


class _Source(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=300)]
    url: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=500)]
    reference: Annotated[str, StringConstraints(strip_whitespace=True, max_length=300)] = ""


class SyllabusFile(SyllabusTreeInput):
    exam_codes: list[str]
    effective_year: EffectiveYear | None = None
    name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
    note: str | None = None
    source: _Source | None = None


def file_problems(spec: SyllabusFile) -> list[str]:
    """What stops a file from being imported as a new version (empty: it can be)."""
    problems = []
    if spec.source is None:
        problems.append("it has no official source")
    if spec.effective_year is None:
        problems.append("it has no effective year")
    if not spec.exam_codes:
        problems.append("it names no exam")
    return problems


def import_file(session: Session, data: dict[str, Any], reviewer: str) -> list[SyllabusVersion]:
    spec = SyllabusFile.model_validate(data)
    if not reviewer.strip():
        raise ValueError("Name the reviewer who checked it against the official source.")
    problems = file_problems(spec)
    if problems:
        raise ValueError("Not importable:\n- " + "\n- ".join(problems))
    assert spec.source is not None  # noqa: S101 - checked above
    created = []
    for code in spec.exam_codes:
        exam = session.get(Exam, code)
        if exam is None or exam.owner_id is not None:
            raise ValueError(f"{code} is not a catalog exam.")
        taken = session.scalar(
            select(SyllabusVersion.id).where(
                SyllabusVersion.exam_code == code,
                SyllabusVersion.owner_id.is_(None),
                SyllabusVersion.effective_year == spec.effective_year,
            )
        )
        if taken is not None:
            raise ValueError(f"{code} already has a version for {spec.effective_year}.")
        version = SyllabusVersion(
            exam_code=code,
            effective_year=spec.effective_year,
            name=spec.name,
            source_kind="template",
            source_title=spec.source.title,
            source_url=spec.source.url,
        )
        session.add(version)
        session.flush()
        save_tree(session, version, spec.tree, None)
        audit(session, reviewer, "syllabus_imported", "exam", code, str(spec.effective_year))
        created.append(version)
    return created


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli.syllabus")
    parser.add_argument("action", choices=["check", "import"])
    parser.add_argument("file")
    parser.add_argument("--reviewer", default="")
    args = parser.parse_args(argv)
    try:
        data = json.loads(Path(args.file).read_text(encoding="utf-8"))
        if args.action == "check":
            problems = file_problems(SyllabusFile.model_validate(data))
            print("Can be imported." if not problems else "- " + "\n- ".join(problems))
            return 0 if not problems else 1
    except (ValueError, ValidationError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    engine = build_engine(get_settings())
    if engine is None:
        print("PREPLOOP_DATABASE_URL is not set.", file=sys.stderr)
        return 2
    with build_sessionmaker(engine)() as session:
        try:
            versions = import_file(session, data, args.reviewer)
            session.commit()
        except (ValueError, ValidationError) as exc:
            session.rollback()
            print(str(exc), file=sys.stderr)
            return 1
    print(f"Added {len(versions)} version(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
