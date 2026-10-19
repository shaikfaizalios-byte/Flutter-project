"""Publish papers to the shared bank, or withdraw them.

Run on the server as the operator:

    python -m app.cli.shared_bank list
    python -m app.cli.shared_bank publish DOCUMENT_ID --rights "..." --source "..."
    python -m app.cli.shared_bank unpublish DOCUMENT_ID

Only share papers you have the right to share (for example a paper the exam body published
itself, or content licensed to you); --rights records that basis and --source where the
paper came from. Only the paper's verified questions become visible to other learners.
"""

import argparse
import sys
import uuid

from app.core.config import get_settings
from app.database.session import build_engine, build_sessionmaker
from app.domain.errors import DomainError
from app.services import shared_bank


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli.shared_bank")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("list", help="papers in the shared bank")
    publish = commands.add_parser("publish", help="share a paper's verified questions")
    publish.add_argument("document_id", type=uuid.UUID)
    publish.add_argument("--rights", required=True, help="why you may share this paper")
    publish.add_argument("--source", required=True, help="where the paper came from")
    unpublish = commands.add_parser("unpublish", help="withdraw a paper from the shared bank")
    unpublish.add_argument("document_id", type=uuid.UUID)
    args = parser.parse_args(argv)

    engine = build_engine(get_settings())
    if engine is None:
        print("PREPLOOP_DATABASE_URL is not set.", file=sys.stderr)
        return 2
    with build_sessionmaker(engine)() as session:
        try:
            if args.command == "list":
                for d in shared_bank.shared_documents(session):
                    print(f"{d.id}  {d.original_filename}  shared {d.shared_at:%Y-%m-%d}")
                    print(f"    rights: {d.shared_rights_basis}")
                    print(f"    source: {d.shared_source}")
                return 0
            if args.command == "publish":
                result = shared_bank.publish(
                    session, args.document_id, rights_basis=args.rights, source=args.source
                )
                print(
                    f"Shared {result.filename}: {result.verified_questions} verified questions "
                    "are now visible to every learner."
                )
                return 0
            result = shared_bank.unpublish(session, args.document_id)
            print(f"Withdrawn {result.filename} from the shared bank.")
            return 0
        except DomainError as error:
            print(f"Not done: {error}", file=sys.stderr)
            return 1


if __name__ == "__main__":
    raise SystemExit(main())
