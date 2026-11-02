"""Reports about shared content, takedowns and the audit log (operator tool).

    python -m app.cli.content reports [--all]
    python -m app.cli.content resolve REPORT_ID --uphold|--dismiss --note "..." --by "A. Operator"
    python -m app.cli.content takedown DOCUMENT_ID --reason "..." --by "A. Operator"
    python -m app.cli.content audit [--limit 50]

A takedown withdraws the paper from the shared bank (its questions stop being visible to other
learners at once; the paper stays in its owner's account) and upholds the paper's open reports.
Every decision is written to the audit log with who made it and why.
"""

import argparse
import sys
import uuid

from sqlalchemy import select

from app.core.config import get_settings
from app.database.session import build_engine, build_sessionmaker
from app.domain.errors import DomainError
from app.models.content import AuditEvent, ContentReport
from app.services import content


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli.content")
    commands = parser.add_subparsers(dest="command", required=True)
    reports = commands.add_parser("reports", help="open reports (all with --all)")
    reports.add_argument("--all", action="store_true")
    resolve = commands.add_parser("resolve", help="uphold or dismiss a report")
    resolve.add_argument("report_id", type=uuid.UUID)
    outcome = resolve.add_mutually_exclusive_group(required=True)
    outcome.add_argument("--uphold", action="store_true")
    outcome.add_argument("--dismiss", action="store_true")
    resolve.add_argument("--note", required=True)
    resolve.add_argument("--by", required=True, help="who decided")
    takedown = commands.add_parser("takedown", help="withdraw a paper from the shared bank")
    takedown.add_argument("document_id", type=uuid.UUID)
    takedown.add_argument("--reason", required=True)
    takedown.add_argument("--by", required=True, help="who decided")
    log = commands.add_parser("audit", help="recent operator decisions")
    log.add_argument("--limit", type=int, default=50)
    args = parser.parse_args(argv)

    engine = build_engine(get_settings())
    if engine is None:
        print("PREPLOOP_DATABASE_URL is not set.", file=sys.stderr)
        return 2
    with build_sessionmaker(engine)() as session:
        try:
            if args.command == "reports":
                stmt = select(ContentReport).order_by(ContentReport.created_at)
                if not args.all:
                    stmt = stmt.where(ContentReport.status == "open")
                for r in session.scalars(stmt):
                    when = f"{r.created_at:%Y-%m-%d}"
                    print(f"{r.id}  {r.status:9} {r.kind:6} paper {r.document_id}  {when}")
                    print(f"    {r.text[:300]}")
                return 0
            if args.command == "resolve":
                report = content.resolve(
                    session, args.report_id, upheld=args.uphold, note=args.note, actor=args.by
                )
                session.commit()
                print(f"Report {report.id} {report.status}.")
                return 0
            if args.command == "takedown":
                closed = content.takedown(
                    session, args.document_id, reason=args.reason, actor=args.by
                )
                print(f"Withdrawn from the shared bank; {closed} open report(s) upheld.")
                return 0
            events = session.scalars(
                select(AuditEvent).order_by(AuditEvent.at.desc()).limit(max(1, args.limit))
            )
            for e in events:
                target = f"{e.target_type} {e.target_id}"
                print(f"{e.at:%Y-%m-%d %H:%M}  {e.actor:20} {e.action:16} {target}")
                if e.detail:
                    print(f"    {e.detail}")
            return 0
        except DomainError as error:
            session.rollback()
            print(f"Not done: {error}", file=sys.stderr)
            return 1


if __name__ == "__main__":
    raise SystemExit(main())
