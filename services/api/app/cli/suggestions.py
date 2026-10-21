"""Read learners' suggestions and mark their status.

    python -m app.cli.suggestions list [--status new]
    python -m app.cli.suggestions mark SUGGESTION_ID planned

Statuses: new, read, planned, done, declined (the learner sees the status in the app). Account
details are not printed; suggestions are identified by their id only.
"""

import argparse
import sys
import uuid

from sqlalchemy import select

from app.core.config import get_settings
from app.database.session import build_engine, build_sessionmaker
from app.models.feedback import Suggestion

STATUSES = ("new", "read", "planned", "done", "declined")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli.suggestions")
    commands = parser.add_subparsers(dest="command", required=True)
    listing = commands.add_parser("list", help="suggestions, newest first")
    listing.add_argument("--status", choices=STATUSES)
    listing.add_argument("--limit", type=int, default=100)
    mark = commands.add_parser("mark", help="set a suggestion's status")
    mark.add_argument("suggestion_id", type=uuid.UUID)
    mark.add_argument("status", choices=STATUSES)
    args = parser.parse_args(argv)

    engine = build_engine(get_settings())
    if engine is None:
        print("PREPLOOP_DATABASE_URL is not set.", file=sys.stderr)
        return 2
    with build_sessionmaker(engine)() as session:
        if args.command == "list":
            query = select(Suggestion).order_by(Suggestion.created_at.desc()).limit(args.limit)
            if args.status:
                query = query.where(Suggestion.status == args.status)
            for s in session.scalars(query):
                print(f"{s.id}  {s.created_at:%Y-%m-%d}  [{s.kind}/{s.status}]")
                print("    " + s.text.replace("\n", "\n    "))
            return 0
        suggestion = session.get(Suggestion, args.suggestion_id)
        if suggestion is None:
            print("No such suggestion.", file=sys.stderr)
            return 1
        suggestion.status = args.status
        session.commit()
        print(f"Marked {suggestion.id} as {args.status}.")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
