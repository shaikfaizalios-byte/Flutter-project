"""Starter papers: the operator imports official papers from a folder with a manifest, follows
them, and publishes the reviewed ones; learners see per-exam starter counts."""

import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.cli.starter_papers import ManifestError, import_papers, load_manifest, publish, status
from app.core.config import Settings
from app.integrations.storage import LocalDocumentStorage
from app.models.document import Document
from app.models.question import Question, VerificationStatus
from app.models.user import User
from tests.conftest import make_user
from tests.pdf_factory import SAMPLE_QUESTION, text_pdf
from tests.test_document_processing import run_worker

RIGHTS = "Published by the exam body for candidates on its website."


def write_folder(folder: Path, operator: str, papers: list[dict[str, object]]) -> Path:
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "manifest.json").write_text(
        json.dumps({"operator": operator, "papers": papers}), encoding="utf-8"
    )
    return folder


def paper(file: str, **extra: object) -> dict[str, object]:
    return {
        "file": file,
        "exam": "SSC_CHSL",
        "language": "en",
        "source": f"SSC CHSL 2024 Tier-I, official paper ({file})",
        "rights": RIGHTS,
        **extra,
    }


def test_import_status_and_publish_only_reviewed_papers(
    tmp_path: Path,
    db_session: Session,
    settings: Settings,
    storage: LocalDocumentStorage,
    db_client: TestClient,
) -> None:
    operator = make_user(db_session, "papers@example.com")
    folder = tmp_path / "starter"
    folder.mkdir()
    (folder / "chsl-1.pdf").write_bytes(text_pdf([SAMPLE_QUESTION]))
    (folder / "chsl-2.pdf").write_bytes(text_pdf([SAMPLE_QUESTION, ["Q.3 Extra page text here."]]))
    write_folder(
        folder,
        operator.email,
        [paper("chsl-1.pdf", exam_date="2024-07-01", shift=1), paper("chsl-2.pdf")],
    )
    manifest = load_manifest(folder)
    out: list[str] = []

    assert import_papers(db_session, settings, manifest, out.append) == 2
    assert import_papers(db_session, settings, manifest, out.append) == 0  # safe to re-run
    assert sum("already imported" in line for line in out) == 2
    docs = db_session.scalars(select(Document).where(Document.owner_id == operator.id)).all()
    dated = next(d for d in docs if d.original_filename == "chsl-1.pdf")
    assert (dated.exam_year, dated.exam_shift, dated.paper_date_status) == (2024, 1, "confirmed")

    while run_worker(db_session, storage, settings) is not None:
        pass
    out.clear()
    status(db_session, manifest, out.append)
    assert out[0].startswith("chsl-1.pdf: 2 questions, 0 verified")
    assert out[0].endswith("not shared")

    # Nothing is published before its questions are reviewed.
    out.clear()
    assert publish(db_session, manifest, out.append) == 0
    assert all("Verify the paper's questions" in line for line in out)

    for q in db_session.scalars(select(Question).where(Question.document_id == dated.id)):
        q.verification_status = VerificationStatus.VERIFIED
    db_session.flush()
    out.clear()
    assert publish(db_session, manifest, out.append) == 1
    assert out[0] == "shared  chsl-1.pdf: 2 verified questions"
    db_session.refresh(dated)
    assert dated.shared_source == "SSC CHSL 2024 Tier-I, official paper (chsl-1.pdf)"
    assert dated.shared_rights_basis == RIGHTS

    # Learners see the starter count for the exam (verified questions only).
    summary = db_client.get("/api/v1/insights/shared-bank").json()
    assert summary == [{"exam_code": "SSC_CHSL", "papers": 1, "questions": 2}]


def test_manifest_problems_are_explained(tmp_path: Path, db_session: Session, user: User) -> None:
    with pytest.raises(ManifestError, match=r"No manifest.json"):
        load_manifest(tmp_path)
    write_folder(tmp_path, user.email, [paper("missing.pdf")])
    with pytest.raises(ManifestError, match=r"missing.pdf not found"):
        load_manifest(tmp_path)
    (tmp_path / "a.pdf").write_bytes(text_pdf())
    write_folder(tmp_path, user.email, [{"file": "a.pdf", "exam": "SSC_CHSL"}])
    with pytest.raises(ManifestError, match="'source' is required"):
        load_manifest(tmp_path)
    write_folder(tmp_path, user.email, [paper("a.pdf", exam_date="1 July 2024")])
    with pytest.raises(ManifestError, match="YYYY-MM-DD"):
        load_manifest(tmp_path)
    write_folder(tmp_path, "nobody@example.com", [paper("a.pdf")])
    with pytest.raises(ManifestError, match="Sign up in the app"):
        status(db_session, load_manifest(tmp_path), print)


def test_shared_bank_summary_is_empty_without_shared_papers(db_client: TestClient) -> None:
    assert db_client.get("/api/v1/insights/shared-bank").json() == []
