"""Operator tools for the question library.

    python -m app.cli.library role EMAIL editor    (or "none")
    python -m app.cli.library calibrate

Calibration counts real attempts and re-bands questions with enough of them. Run it on a schedule.
"""

import argparse
import sys

from sqlalchemy import select

from app.core.config import get_settings
from app.database.session import build_engine, build_sessionmaker
from app.models.user import User
from app.services.library_service import calibrate


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli.library")
    commands = parser.add_subparsers(dest="command", required=True)
    role = commands.add_parser("role")
    role.add_argument("email")
    role.add_argument("role", choices=["editor", "none"])
    commands.add_parser("calibrate")
    args = parser.parse_args(argv)
    engine = build_engine(get_settings())
    if engine is None:
        print("PREPLOOP_DATABASE_URL is not set.", file=sys.stderr)
        return 2
    with build_sessionmaker(engine)() as session:
        if args.command == "calibrate":
            print(f"{calibrate(session)} question(s) changed level.")
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
