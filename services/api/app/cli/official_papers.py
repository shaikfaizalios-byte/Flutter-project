"""Operator tools for papers with official IDs.

    python -m app.cli.official_papers transcribe DOCUMENT_ID --limit 75

Reads pictured questions into hidden search text. It costs one AI request per question, so it is
run on purpose, never as part of an import.
"""

import argparse
import sys
import uuid

from app.core.config import get_settings
from app.database.session import build_engine, build_sessionmaker
from app.integrations.ai import provider_from_settings
from app.services.question_transcriber import transcribe_document


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli.official_papers")
    parser.add_argument("action", choices=["transcribe"])
    parser.add_argument("document_id", type=uuid.UUID)
    parser.add_argument("--limit", type=int, default=100)
    args = parser.parse_args(argv)
    settings = get_settings()
    engine = build_engine(settings)
    provider = provider_from_settings(settings)
    if engine is None or provider is None:
        print("A database and PREPLOOP_AI_API_KEY are needed.", file=sys.stderr)
        return 2
    with build_sessionmaker(engine)() as session:
        read, failed = transcribe_document(session, provider, args.document_id, args.limit)
    print(f"Read {read} question(s); {failed} failed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
