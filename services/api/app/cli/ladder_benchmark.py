"""The held-out benchmark for generated ladder questions. Internal: nothing here reaches learners.

    python -m app.cli.ladder_benchmark run EXAM FILE.json
    python -m app.cli.ladder_benchmark threshold EXAM SUBJECT 0.95 --by NAME
    python -m app.cli.ladder_benchmark status EXAM SUBJECT

FILE is a JSON list of questions: subject, format, stem, options, level (default hard), and the
known answer as answer_index, correct_indices or numeric_answer. Keep it outside the repository.
Only totals are stored. A run costs several AI calls per question.
"""

import argparse
import json
import sys
from pathlib import Path

from app.core.config import get_settings
from app.database.session import build_engine, build_sessionmaker
from app.integrations.ai import provider_from_settings
from app.models.ladder import LadderGate
from app.services.ladder_benchmark import read_items, run, subject_open


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli.ladder_benchmark")
    commands = parser.add_subparsers(dest="command", required=True)
    running = commands.add_parser("run")
    running.add_argument("exam")
    running.add_argument("file", type=Path)
    threshold = commands.add_parser("threshold")
    threshold.add_argument("exam")
    threshold.add_argument("subject")
    threshold.add_argument("value", type=float)
    threshold.add_argument("--by", required=True)
    status = commands.add_parser("status")
    status.add_argument("exam")
    status.add_argument("subject")
    args = parser.parse_args(argv)
    settings = get_settings()
    engine = build_engine(settings)
    if engine is None:
        print("PREPLOOP_DATABASE_URL is not set.", file=sys.stderr)
        return 2
    with build_sessionmaker(engine)() as session:
        if args.command == "threshold":
            if not 0 < args.value <= 1:
                print("The threshold is a share, above 0 and up to 1.", file=sys.stderr)
                return 2
            session.merge(
                LadderGate(
                    exam_code=args.exam,
                    subject=args.subject,
                    threshold=args.value,
                    set_by=args.by,
                )
            )
            session.commit()
            print("Saved.")
            return 0
        if args.command == "status":
            is_open = subject_open(session, args.exam, args.subject)
            print("on" if is_open else "off")
            return 0
        provider = provider_from_settings(settings)
        if provider is None:
            print("PREPLOOP_AI_API_KEY is not set.", file=sys.stderr)
            return 2
        items = read_items(json.loads(args.file.read_text(encoding="utf-8")))
        for row in run(session, provider, args.exam, items):
            accuracy = f"{row.correct / row.accepted:.1%}" if row.accepted else "none accepted"
            print(f"{row.subject} / {row.format}: {row.items} items, {row.accepted} accepted, ")
            print(f"  {row.correct} correct ({accuracy})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
