"""Test data for a load test, and its removal. Never on production.

    python -m app.cli.load_seed create --learners 300 --tokens PATH [--minutes 60]
    python -m app.cli.load_seed clean

Creates an exam made for the load test (``LOAD_TEST``, labelled as such), a verified format with two
sections, a shared paper of generated questions, and learner accounts named ``load-N@example.test``.
Their access tokens, signed with the server's secret, go to PATH for scripts/load_test.py. Keep PATH
out of the repository. ``clean`` removes all of it.
"""

import argparse
import json
import sys
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.config import Environment, get_settings
from app.core.security import TokenSigner, hash_password
from app.database.session import build_engine, build_sessionmaker
from app.models.document import Document, DocumentStatus
from app.models.exam import Exam
from app.models.question import (
    ExamFormat,
    FormatStatus,
    Question,
    QuestionOption,
    QuestionOrigin,
    VerificationStatus,
)
from app.models.user import User

EXAM = "LOAD_TEST"
FORMAT = "LOAD_TEST_PAPER"
EMAIL = "load-{}@example.test"
OPERATOR = "load-operator@example.test"
SUBJECTS = ("Physics", "Chemistry")
PER_SECTION = 10
POOL = 60  # questions per subject, so mocks differ


def _refuse(settings_environment: Environment, url: str) -> str | None:
    if settings_environment in (Environment.PRODUCTION, Environment.STAGING):
        return "Refused: load-test data never goes into staging or production."
    if "test" not in url.rsplit("/", 1)[-1]:
        return "Refused: use a database whose name contains 'test'."
    return None


def create(session: Session, learners: int, tokens: Path, minutes: int, secret: str) -> None:
    session.add(Exam(code=EXAM, name="Load test exam (generated, not a real exam)"))
    operator = User(email=OPERATOR, password_hash=hash_password("not-used-load-test"))
    session.add(operator)
    session.flush()
    session.add(
        ExamFormat(
            code=FORMAT,
            exam_code=EXAM,
            stage="Paper",
            name="Load test paper (generated)",
            sections=[
                {
                    "part": str(i),
                    "subject": s,
                    "questions": PER_SECTION,
                    "max_marks": 4 * PER_SECTION,
                }
                for i, s in enumerate(SUBJECTS, start=1)
            ],
            sections_in_fixed_order=False,
            total_questions=PER_SECTION * len(SUBJECTS),
            duration_minutes=30,
            negative_marks_per_wrong=1,
            question_types=["choice"],
            conduct={
                "cbt": {
                    "marked_with_answer_counts": True,
                    "marked_without_answer_counts": False,
                    "answer_needs_saving": True,
                    "free_navigation": True,
                    "ends_at_zero": True,
                    "language_switch": "paper",
                    "reference": "Load test only: not an exam's rules",
                }
            },
            source_title="Load test (generated)",
            source_url="https://example.test/load",
            source_reference="none",
            source_published_on=date(2026, 1, 1),
            verified_on=date(2026, 1, 1),
            reviewed_by="Load test",
            status=FormatStatus.VERIFIED,
        )
    )
    document = Document(
        owner_id=operator.id,
        exam_code=EXAM,
        language="en",
        original_filename="load-test.pdf",
        size_bytes=1,
        sha256="1" * 64,
        storage_key="documents/load-test.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
        segmentation_status="completed",
        shared_at=datetime.now(UTC),
        shared_source="Load test (generated questions)",
        shared_rights_basis="Generated for a load test.",
    )
    session.add(document)
    session.flush()
    number = 0
    for subject in SUBJECTS:
        for i in range(POOL):
            number += 1
            question = Question(
                owner_id=operator.id,
                origin=QuestionOrigin.SOURCE,
                exam_code=EXAM,
                section=subject,
                subject=subject,
                stem=f"Load test question {number}: which option is {i % 4 + 1}?",
                language="en",
                document_id=document.id,
                source_question_number=number,
                source_pages=[1],
                correct_option_position=i % 4 + 1,
                verification_status=VerificationStatus.VERIFIED,
            )
            question.options = [
                QuestionOption(position=p, label=str(p), text=f"option {p}") for p in range(1, 5)
            ]
            session.add(question)
    signer = TokenSigner(secret, minutes)
    issued = []
    for n in range(learners):
        user = User(email=EMAIL.format(n), password_hash=operator.password_hash)
        session.add(user)
        session.flush()
        issued.append(signer.access_token(user.id))
    session.commit()
    tokens.write_text(
        json.dumps({"exam": EXAM, "format": FORMAT, "tokens": issued}), encoding="utf-8"
    )


def clean(session: Session) -> int:
    """Accounts first: their sessions point at the format, and go with them."""
    accounts = session.scalars(select(User.id).where(User.email.like("load-%@example.test"))).all()
    session.execute(delete(User).where(User.id.in_(accounts)))
    session.execute(delete(ExamFormat).where(ExamFormat.code == FORMAT))
    session.execute(delete(Exam).where(Exam.code == EXAM))
    session.commit()
    return len(accounts)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli.load_seed")
    commands = parser.add_subparsers(dest="command", required=True)
    making = commands.add_parser("create")
    making.add_argument("--learners", type=int, default=50)
    making.add_argument("--tokens", type=Path, required=True)
    making.add_argument("--minutes", type=int, default=60)
    commands.add_parser("clean")
    args = parser.parse_args(argv)
    settings = get_settings()
    engine = build_engine(settings)
    if engine is None or settings.database_url is None:
        print("PREPLOOP_DATABASE_URL is not set.", file=sys.stderr)
        return 2
    problem = _refuse(settings.environment, settings.database_url.get_secret_value())
    if problem:
        print(problem, file=sys.stderr)
        return 2
    with build_sessionmaker(engine)() as session:
        if args.command == "clean":
            print(f"Removed {clean(session)} load-test account(s).")
            return 0
        if settings.auth_secret is None:
            print("Set PREPLOOP_AUTH_SECRET to the server's, so its tokens are accepted.")
            return 2
        create(
            session,
            args.learners,
            args.tokens,
            args.minutes,
            settings.auth_secret.get_secret_value(),
        )
    expires = datetime.now(UTC) + timedelta(minutes=args.minutes)
    print(f"{args.learners} learners; tokens valid until {expires:%H:%M} UTC.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
