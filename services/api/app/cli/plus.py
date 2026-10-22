"""Grant, end or show PrepLoop Plus for an account (operator tool, e.g. for beta testers).

    python -m app.cli.plus grant learner@example.com --days 30 --note "beta tester"
    python -m app.cli.plus revoke learner@example.com
    python -m app.cli.plus show learner@example.com

A grant replaces any test subscription; store purchases (play/web) are left alone.
"""

import argparse
import sys
from datetime import UTC, datetime, timedelta

from sqlalchemy import select

from app.core.config import get_settings
from app.database.session import build_engine, build_sessionmaker
from app.models.plus import Subscription
from app.models.user import User


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli.plus")
    commands = parser.add_subparsers(dest="command", required=True)
    grant = commands.add_parser("grant", help="give an account Plus for some days")
    grant.add_argument("email")
    grant.add_argument("--days", type=int, required=True)
    grant.add_argument("--note", default=None)
    for name in ("revoke", "show"):
        commands.add_parser(name).add_argument("email")
    args = parser.parse_args(argv)

    engine = build_engine(get_settings())
    if engine is None:
        print("PREPLOOP_DATABASE_URL is not set.", file=sys.stderr)
        return 2
    with build_sessionmaker(engine)() as session:
        email = args.email.strip().lower()
        user = session.scalars(select(User).where(User.email == email)).first()
        if user is None:
            print("No account with that email.", file=sys.stderr)
            return 1
        sub = session.get(Subscription, user.id)
        now = datetime.now(UTC)
        if args.command == "show":
            if sub is None:
                print("No subscription.")
            else:
                state = "active" if sub.active_until > now else "ended"
                print(
                    f"{sub.plan} ({sub.source}) {state} until {sub.active_until:%Y-%m-%d %H:%M} UTC"
                )
            return 0
        if sub is not None and sub.source in ("play", "web"):
            print("This account has a store purchase; change it in the store.", file=sys.stderr)
            return 1
        if args.command == "revoke":
            if sub is not None:
                session.delete(sub)
                session.commit()
            print("Plus ended.")
            return 0
        if not 1 <= args.days <= 366:
            print("--days must be between 1 and 366.", file=sys.stderr)
            return 2
        if sub is None:
            sub = Subscription(owner_id=user.id, plan="plus", source="operator")
            session.add(sub)
        sub.source = "operator"
        sub.active_until = now + timedelta(days=args.days)
        sub.note = args.note[:200] if args.note else None
        session.commit()
        print(f"Plus granted until {sub.active_until:%Y-%m-%d %H:%M} UTC.")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
