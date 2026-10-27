"""Starter papers: import official previous papers for the shared bank from a folder, follow
them while they are read, and publish them once their questions are reviewed.

Run on the server as the operator:

    python -m app.cli.starter_papers import FOLDER [--process]
    python -m app.cli.starter_papers status FOLDER
    python -m app.cli.starter_papers publish FOLDER

FOLDER holds the PDFs and a ``manifest.json``::

    {
      "operator": "papers@example.com",
      "papers": [
        {
          "file": "ssc-chsl-2024-07-01-shift-1.pdf",
          "exam": "SSC_CHSL",
          "language": "en",
          "source": "SSC CHSL 2024 Tier-I, 1 July 2024, shift 1 (official paper, ssc.gov.in, ...)",
          "rights": "Published by the exam body for candidates; ...",
          "exam_date": "2024-07-01",
          "shift": 1
        }
      ]
    }

Only list papers you have the right to share; ``source`` and ``rights`` are recorded with each
paper and required to publish it. The operator account must exist (sign up in the app). Papers
are imported into that account; review and verify their questions there (each paper's review
screen), then run ``publish``: only verified questions become visible to other learners, and a
paper with nothing verified is left out with a reason. Importing again skips files already
imported (same content), so the command can be re-run safely.
"""

import argparse
import hashlib
import json
import sys
from collections.abc import Callable
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import Settings, get_settings
from app.database.session import build_engine, build_sessionmaker
from app.domain.errors import DomainError
from app.integrations.storage import LocalDocumentStorage
from app.models.document import Document, DocumentStatus
from app.models.question import Question, VerificationStatus
from app.models.user import User
from app.schemas.document import PaperDateUpdate
from app.services import shared_bank
from app.services.document_service import DocumentService, read_documents

MANIFEST = "manifest.json"
LANGUAGES = ("en", "hi")


class ManifestError(ValueError):
    """The manifest or a listed file can't be used; the message says what to fix."""


@dataclass(frozen=True, slots=True)
class StarterPaper:
    file: Path
    exam: str
    language: str
    source: str
    rights: str
    exam_date: date | None = None
    shift: int | None = None

    @property
    def sha256(self) -> str:
        digest = hashlib.sha256()
        with self.file.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1 << 20), b""):
                digest.update(chunk)
        return digest.hexdigest()


@dataclass(frozen=True, slots=True)
class Manifest:
    operator: str
    papers: list[StarterPaper]


def _text(entry: dict[str, Any], key: str, where: str) -> str:
    value = entry.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ManifestError(f"{where}: '{key}' is required.")
    return value.strip()


def load_manifest(folder: Path) -> Manifest:
    path = folder / MANIFEST
    if not path.is_file():
        raise ManifestError(f"No {MANIFEST} in {folder}.")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ManifestError(f"{MANIFEST} is not valid JSON: {error}") from error
    if not isinstance(data, dict) or not isinstance(data.get("papers"), list):
        raise ManifestError(f"{MANIFEST} needs an 'operator' and a list of 'papers'.")
    operator = _text(data, "operator", MANIFEST)
    papers = []
    for index, entry in enumerate(data["papers"], start=1):
        where = f"paper {index}"
        if not isinstance(entry, dict):
            raise ManifestError(f"{where}: must be an object.")
        file = folder / _text(entry, "file", where)
        if not file.is_file():
            raise ManifestError(f"{where}: file {file.name} not found in {folder}.")
        language = entry.get("language", "en")
        if language not in LANGUAGES:
            raise ManifestError(f"{where}: language must be one of {', '.join(LANGUAGES)}.")
        held = entry.get("exam_date")
        shift = entry.get("shift")
        try:
            exam_date = date.fromisoformat(held) if held else None
        except (TypeError, ValueError) as error:
            raise ManifestError(f"{where}: exam_date must be YYYY-MM-DD.") from error
        if shift is not None and not isinstance(shift, int):
            raise ManifestError(f"{where}: shift must be a number.")
        papers.append(
            StarterPaper(
                file=file,
                exam=_text(entry, "exam", where),
                language=language,
                source=_text(entry, "source", where),
                rights=_text(entry, "rights", where),
                exam_date=exam_date,
                shift=shift,
            )
        )
    if not papers:
        raise ManifestError(f"{MANIFEST} lists no papers.")
    return Manifest(operator=operator, papers=papers)


def _operator(session: Session, email: str) -> User:
    user = session.scalars(select(User).where(func.lower(User.email) == email.lower())).first()
    if user is None:
        raise ManifestError(f"No account for {email}. Sign up in the app with it first.")
    return user


def _find(session: Session, owner: User, paper: StarterPaper) -> Document | None:
    return session.scalars(
        select(Document)
        .where(Document.owner_id == owner.id, Document.sha256 == paper.sha256)
        .order_by(Document.created_at)
    ).first()


def import_papers(
    session: Session, settings: Settings, manifest: Manifest, out: Callable[[str], None]
) -> int:
    """Uploads the papers not imported yet; returns how many were added."""
    owner = _operator(session, manifest.operator)
    service = DocumentService(
        session, LocalDocumentStorage(settings.upload_dir), settings, owner_id=owner.id
    )
    added = 0
    for paper in manifest.papers:
        if _find(session, owner, paper) is not None:
            out(f"skip    {paper.file.name}: already imported")
            continue
        with paper.file.open("rb") as stream:
            document = service.upload(
                stream=stream,
                filename=paper.file.name,
                exam_code=paper.exam,
                language=paper.language,
            )
        if paper.exam_date is not None:
            service.set_paper_date(
                document.id,
                PaperDateUpdate(
                    exam_year=paper.exam_date.year,
                    exam_date=paper.exam_date,
                    exam_shift=paper.shift,
                ),
            )
        added += 1
        out(f"import  {paper.file.name}: {document.page_count} pages, queued ({document.id})")
    return added


def process_all(factory: sessionmaker[Session], settings: Settings) -> int:
    """Reads every queued paper now (instead of waiting for the worker); returns how many."""
    from app.workers.document_worker import build_processor, run_once

    processor = build_processor(settings)
    done = 0
    while run_once(factory, processor):
        done += 1
    return done


def status(session: Session, manifest: Manifest, out: Callable[[str], None]) -> None:
    owner = _operator(session, manifest.operator)
    for paper in manifest.papers:
        document = _find(session, owner, paper)
        if document is None:
            out(f"{paper.file.name}: not imported")
            continue
        view = read_documents(session, [document])[0]
        verified = (
            session.scalar(
                select(func.count(Question.id)).where(
                    Question.document_id == document.id,
                    Question.verification_status == VerificationStatus.VERIFIED,
                )
            )
            or 0
        )
        if document.status != DocumentStatus.COMPLETED:
            state = f"{document.status} ({document.pages_processed}/{document.page_count} pages)"
        elif document.segmentation_status != "completed":
            state = f"questions: {document.segmentation_status}"
        else:
            state = (
                f"{view.questions_found} questions, {verified} verified, "
                f"{view.questions_to_check} need a look"
            )
        shared = "shared" if document.shared_at else "not shared"
        out(f"{paper.file.name}: {state}; {shared}")


def publish(session: Session, manifest: Manifest, out: Callable[[str], None]) -> int:
    """Publishes every imported paper with verified questions; returns how many were shared."""
    owner = _operator(session, manifest.operator)
    shared = 0
    for paper in manifest.papers:
        document = _find(session, owner, paper)
        if document is None:
            out(f"skip    {paper.file.name}: not imported")
            continue
        try:
            result = shared_bank.publish(
                session, document.id, rights_basis=paper.rights, source=paper.source
            )
        except DomainError as error:
            session.rollback()
            out(f"skip    {paper.file.name}: {error}")
            continue
        shared += 1
        out(f"shared  {paper.file.name}: {result.verified_questions} verified questions")
    return shared


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli.starter_papers")
    commands = parser.add_subparsers(dest="command", required=True)
    imp = commands.add_parser("import", help="import the folder's papers into the operator account")
    imp.add_argument("folder", type=Path)
    imp.add_argument("--process", action="store_true", help="read them now, not via the worker")
    commands.add_parser("status", help="where each paper is").add_argument("folder", type=Path)
    commands.add_parser("publish", help="share the reviewed papers").add_argument(
        "folder", type=Path
    )
    args = parser.parse_args(argv)

    settings = get_settings()
    engine = build_engine(settings)
    if engine is None:
        print("PREPLOOP_DATABASE_URL is not set.", file=sys.stderr)
        return 2
    factory = build_sessionmaker(engine)
    try:
        manifest = load_manifest(args.folder)
        with factory() as session:
            if args.command == "import":
                added = import_papers(session, settings, manifest, print)
                print(f"{added} papers imported.")
            elif args.command == "status":
                status(session, manifest, print)
            else:
                count = publish(session, manifest, print)
                print(f"{count} papers shared.")
        if args.command == "import" and args.process:
            print(f"{process_all(factory, settings)} papers read.")
        return 0
    except (ValueError, DomainError) as error:  # ManifestError, invalid dates
        print(f"Not done: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
