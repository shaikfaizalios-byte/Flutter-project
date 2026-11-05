"""Exam catalog and exam formats (operator tool; docs/question-bank.md "Exam formats").

    python -m app.cli.exam_formats exam SSC_CGL --country IN --authority "<from the notice>"
    python -m app.cli.exam_formats exam SSC_CGL --languages en,hi   # as the notice states
    python -m app.cli.exam_formats exam NEW_EXAM --name "<official name>" \\
        --short-name "<short>" --category "<group>" --country IN
    python -m app.cli.exam_formats list [--exam SSC_CGL] [--drafts]
    python -m app.cli.exam_formats import format.json      # creates a draft
    python -m app.cli.exam_formats check SSC_CGL_2027_TIER1
    python -m app.cli.exam_formats publish SSC_CGL_2027_TIER1 --reviewer "A. Reviewer"
    python -m app.cli.exam_formats retire SSC_CGL_2026_TIER1 --on 2027-03-31

A format is a version: it is never edited once published. A new official notice is imported as
a new draft (``"supersedes": "<old code>"``), checked against the notice, and published by a
named reviewer; publishing it ends the old one the day before the new one takes effect. Past
attempts keep the format they were taken with. Nothing here guesses a fact: a draft with a
missing mark, count, timer or source cannot be published.
"""

import argparse
import json
import re
import sys
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Annotated, Any

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.database.session import build_engine, build_sessionmaker
from app.models.exam import CUSTOM_EXAM_PREFIX, Exam
from app.models.question import ExamFormat, FormatStatus
from app.services.content import audit
from app.services.exam_formats import publish_problems

Text = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1)]


class _Source(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Annotated[str, StringConstraints(strip_whitespace=True, max_length=300)]
    url: Annotated[str, StringConstraints(strip_whitespace=True, max_length=500)]
    reference: Annotated[str, StringConstraints(strip_whitespace=True, max_length=300)]
    published_on: date


class FormatFile(BaseModel):
    """A draft format as the operator writes it. Unknown keys are refused; facts the notice
    doesn't state are left null and stop publishing."""

    model_config = ConfigDict(extra="forbid")

    code: Annotated[str, StringConstraints(pattern=r"^[A-Z0-9_]{3,64}$")]
    exam_code: Annotated[str, StringConstraints(min_length=1, max_length=32)]
    stage: Annotated[str, StringConstraints(strip_whitespace=True, max_length=32)]
    name: Annotated[str, StringConstraints(strip_whitespace=True, max_length=200)]
    sections: list[dict[str, Any]]
    sections_in_fixed_order: bool
    total_questions: int = Field(ge=0)
    duration_minutes: int | None = None
    negative_marks_per_wrong: float | None = None
    sectional_timing: bool = False
    # True when the notice says its section-wise question counts are only indicative.
    section_counts_indicative: bool = False
    question_types: list[str] = ["choice"]
    effective_from: date | None = None
    effective_to: date | None = None
    supersedes: str | None = None
    source: _Source
    review_notes: Annotated[str, StringConstraints(max_length=500)] | None = None


ISO_639 = re.compile(r"[a-z]{2,3}")


def import_format(session: Session, data: dict[str, Any]) -> tuple[ExamFormat, list[str]]:
    """Creates a draft from ``data``; returns it with what still stops it from publishing."""
    spec = FormatFile.model_validate(data)
    if session.scalar(select(ExamFormat.id).where(ExamFormat.code == spec.code)):
        raise ValueError(f"A format {spec.code} already exists; import a new version instead.")
    exam = session.get(Exam, spec.exam_code)
    if exam is None or exam.owner_id is not None:
        raise ValueError(f"{spec.exam_code} is not a catalog exam.")
    supersedes = None
    if spec.supersedes:
        supersedes = session.scalar(select(ExamFormat).where(ExamFormat.code == spec.supersedes))
        if supersedes is None or supersedes.exam_code != spec.exam_code:
            raise ValueError(f"{spec.supersedes} is not a format of {spec.exam_code}.")
    draft = ExamFormat(
        code=spec.code,
        exam_code=spec.exam_code,
        stage=spec.stage,
        name=spec.name,
        sections=spec.sections,
        sections_in_fixed_order=spec.sections_in_fixed_order,
        total_questions=spec.total_questions,
        duration_minutes=spec.duration_minutes,
        negative_marks_per_wrong=spec.negative_marks_per_wrong,
        sectional_timing=spec.sectional_timing,
        section_counts_indicative=spec.section_counts_indicative,
        question_types=spec.question_types,
        effective_from=spec.effective_from,
        effective_to=spec.effective_to,
        supersedes_id=supersedes.id if supersedes else None,
        source_title=spec.source.title,
        source_url=spec.source.url,
        source_reference=spec.source.reference,
        source_published_on=spec.source.published_on,
        review_notes=spec.review_notes,
        status=FormatStatus.DRAFT,
    )
    session.add(draft)
    session.flush()
    return draft, publish_problems(draft)


def publish(session: Session, code: str, reviewer: str, today: date) -> ExamFormat:
    """Publishes a checked draft; the format it supersedes ends the day before it starts."""
    draft = _format(session, code)
    if draft.status != FormatStatus.DRAFT:
        raise ValueError(f"{code} is {draft.status}; only drafts are published.")
    if not reviewer.strip():
        raise ValueError("Name the reviewer who checked it against the official source.")
    problems = publish_problems(draft)
    if problems:
        raise ValueError("Not publishable:\n- " + "\n- ".join(problems))
    draft.status = FormatStatus.VERIFIED
    draft.verified_on = today
    draft.reviewed_by = reviewer.strip()[:100]
    audit(session, reviewer, "format_publish", "exam_format", draft.code, draft.source_reference)
    if draft.supersedes_id is not None:
        old = session.get(ExamFormat, draft.supersedes_id)
        if old is not None and old.effective_to is None:
            old.effective_to = (draft.effective_from or today) - timedelta(days=1)
            if old.effective_from and old.effective_to < old.effective_from:
                old.effective_to = old.effective_from
    return draft


def retire(session: Session, code: str, on: date) -> ExamFormat:
    """Stops a published format from being used for new mocks after ``on``."""
    found = _format(session, code)
    if found.status == FormatStatus.DRAFT:
        raise ValueError("A draft is not used anywhere; it needs no retiring.")
    if found.effective_from and on < found.effective_from:
        raise ValueError("A format can't end before it starts.")
    found.status = FormatStatus.RETIRED
    found.effective_to = on
    audit(session, "operator", "format_retire", "exam_format", found.code, f"after {on}")
    return found


def set_exam(
    session: Session,
    code: str,
    *,
    name: str | None,
    short_name: str | None,
    category: str | None,
    country: str | None,
    authority: str | None,
    aliases: list[str] | None,
    languages: list[str] | None = None,
) -> Exam:
    """Creates a catalog exam (needs ``name``) or updates the details given."""
    if code.startswith(CUSTOM_EXAM_PREFIX) or not code.replace("_", "").isalnum():
        raise ValueError("Catalog exam codes use A-Z, 0-9 and _, and don't start with MY_.")
    exam = session.get(Exam, code)
    if exam is not None and exam.owner_id is not None:
        raise ValueError(f"{code} is a learner's own exam.")
    if exam is None:
        if not name:
            raise ValueError("A new catalog exam needs --name.")
        exam = Exam(code=code, name=name, owner_id=None)
        session.add(exam)
    if name:
        exam.name = name[:100]
    if short_name is not None:
        exam.short_name = short_name[:40] or None
    if category is not None:
        exam.category = category[:40] or None
    if country is not None:
        if country and (len(country) != 2 or not country.isalpha() or not country.isupper()):
            raise ValueError("--country is an ISO 3166-1 alpha-2 code, e.g. IN.")
        exam.country_code = country or None
    if authority is not None:
        exam.authority = authority[:120] or None
    if aliases is not None:
        exam.aliases = [a.strip()[:60] for a in aliases if a.strip()]
    if languages is not None:
        # The exam's own languages, as the notice states them: any ISO 639 code, whether or not
        # PrepLoop supports content in it (app/domain/languages.py is about PrepLoop's content).
        invalid = [code for code in languages if not ISO_639.fullmatch(code)]
        if invalid:
            raise ValueError(
                f"Not an ISO 639 language code: {', '.join(invalid)} (use e.g. en, hi, kok)."
            )
        exam.languages = list(dict.fromkeys(languages))
    return exam


def _format(session: Session, code: str) -> ExamFormat:
    found = session.scalar(select(ExamFormat).where(ExamFormat.code == code))
    if found is None:
        raise ValueError(f"No format {code}.")
    return found


def _describe(f: ExamFormat) -> str:
    dates = f"{f.effective_from or '…'} to {f.effective_to or '…'}"
    timing = "sectional timers" if f.sectional_timing else "one overall timer"
    return f"{f.code:28} {f.status:9} {f.exam_code:14} {dates:26} {timing}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli.exam_formats")
    commands = parser.add_subparsers(dest="command", required=True)
    listing = commands.add_parser("list", help="formats, newest code last")
    listing.add_argument("--exam")
    listing.add_argument("--drafts", action="store_true", help="drafts only")
    commands.add_parser("import", help="create a draft from a JSON file").add_argument("file")
    commands.add_parser("check", help="what stops a format from publishing").add_argument("code")
    pub = commands.add_parser("publish", help="publish a checked draft")
    pub.add_argument("code")
    pub.add_argument("--reviewer", required=True)
    ret = commands.add_parser("retire", help="no new mocks after a date")
    ret.add_argument("code")
    ret.add_argument("--on", type=date.fromisoformat, required=True)
    ex = commands.add_parser("exam", help="create or update a catalog exam")
    ex.add_argument("code")
    for option in ("--name", "--short-name", "--category", "--country", "--authority"):
        ex.add_argument(option)
    ex.add_argument("--alias", action="append", dest="aliases")
    ex.add_argument(
        "--languages",
        help="comma-separated codes of the languages the notice offers the paper in, e.g. en,hi",
    )
    args = parser.parse_args(argv)

    engine = build_engine(get_settings())
    if engine is None:
        print("PREPLOOP_DATABASE_URL is not set.", file=sys.stderr)
        return 2
    today = datetime.now(UTC).date()
    with build_sessionmaker(engine)() as session:
        try:
            if args.command == "list":
                stmt = select(ExamFormat).order_by(ExamFormat.exam_code, ExamFormat.code)
                if args.exam:
                    stmt = stmt.where(ExamFormat.exam_code == args.exam)
                if args.drafts:
                    stmt = stmt.where(ExamFormat.status == FormatStatus.DRAFT)
                for f in session.scalars(stmt):
                    print(_describe(f))
                return 0
            if args.command == "check":
                problems = publish_problems(_format(session, args.code))
                print("Publishable." if not problems else "- " + "\n- ".join(problems))
                return 0 if not problems else 1
            if args.command == "import":
                data = json.loads(Path(args.file).read_text(encoding="utf-8"))
                draft, problems = import_format(session, data)
                session.commit()
                print(f"Draft {draft.code} created.")
                if problems:
                    print("Before publishing:\n- " + "\n- ".join(problems))
                return 0
            if args.command == "publish":
                published = publish(session, args.code, args.reviewer, today)
                session.commit()
                print(f"{published.code} published (verified {published.verified_on}).")
                return 0
            if args.command == "retire":
                retired = retire(session, args.code, args.on)
                session.commit()
                print(f"{retired.code} retired after {retired.effective_to}.")
                return 0
            exam = set_exam(
                session,
                args.code,
                name=args.name,
                short_name=args.short_name,
                category=args.category,
                country=args.country,
                authority=args.authority,
                aliases=args.aliases,
                languages=(
                    None
                    if args.languages is None
                    else [c.strip() for c in args.languages.split(",") if c.strip()]
                ),
            )
            session.commit()
            print(f"{exam.code}: {exam.name} ({exam.country_code or 'no country'}).")
            return 0
        except (ValueError, ValidationError) as exc:
            session.rollback()
            print(str(exc), file=sys.stderr)
            return 1


if __name__ == "__main__":
    raise SystemExit(main())
