"""Operator tools for the question library.

    python -m app.cli.library role EMAIL editor    (or "none")
    python -m app.cli.library calibrate
    python -m app.cli.library propose EXAM
    python -m app.cli.library hints EXAM --limit 20 [--refresh]

Calibration counts real attempts and re-bands questions with enough of them. Run it on a schedule.
Propose clusters alike questions of curated papers for a subject reviewer. Hints sends curated
questions to the AI, a topic per request, so --limit caps the cost.
"""

import argparse
import sys

from sqlalchemy import select

from app.core.config import get_settings
from app.database.session import build_engine, build_sessionmaker
from app.integrations.ai import provider_from_settings
from app.models.user import User
from app.services.library_service import calibrate
from app.services.repeat_analysis import build_hints, propose_models


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli.library")
    commands = parser.add_subparsers(dest="command", required=True)
    role = commands.add_parser("role")
    role.add_argument("email")
    role.add_argument("role", choices=["editor", "none"])
    commands.add_parser("calibrate")
    commands.add_parser("propose").add_argument("exam")
    hints = commands.add_parser("hints")
    hints.add_argument("exam")
    hints.add_argument("--limit", type=int, default=20)
    hints.add_argument("--refresh", action="store_true")
    args = parser.parse_args(argv)
    engine = build_engine(get_settings())
    if engine is None:
        print("PREPLOOP_DATABASE_URL is not set.", file=sys.stderr)
        return 2
    with build_sessionmaker(engine)() as session:
        if args.command == "calibrate":
            print(f"{calibrate(session)} question(s) changed level.")
            return 0
        if args.command == "propose":
            print(f"{propose_models(session, args.exam)} proposal(s) open.")
            return 0
        if args.command == "hints":
            provider = provider_from_settings(get_settings())
            if provider is None:
                print("PREPLOOP_AI_API_KEY is not set.", file=sys.stderr)
                return 2
            read, saved = build_hints(
                session, provider, args.exam, limit=args.limit, refresh=args.refresh
            )
            print(f"{read} topic(s) read, {saved} hint(s) saved.")
            return 0
        user = session.scalar(select(User).where(User.email == args.email.strip().lower()))
        if user is None:
            print("No such account.", file=sys.stderr)
            return 1
        user.content_role = None if args.role == "none" else args.role
        session.commit()
    print("Saved.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
