"""PrepLoop's made-up sample papers: added through the normal import, read correctly, labelled,
added once, and never pooled into Repeat Radar or published to the shared bank."""

import json
import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain.errors import ConflictError
from app.integrations.storage import LocalDocumentStorage
from app.models.document import Document
from app.models.question import Question, QuestionOption
from app.services import shared_bank
from app.services.document_service import SAMPLE_FOLDER, sample_papers
from tests.test_document_processing import run_worker

URL = "/api/v1/documents/samples"
EXAM = "SSC_CGL"


def listing() -> dict[str, object]:
    data: dict[str, object] = json.loads(
        (SAMPLE_FOLDER / "sample_papers.json").read_text(encoding="utf-8")
    )
    return data


def test_the_listing_and_its_pdfs_agree() -> None:
    papers = listing()["papers"]
    assert isinstance(papers, list) and len(papers) == len(sample_papers()) == 2
    for paper in papers:
        questions = [q for s in paper["sections"] for q in s["questions"]]
        assert len(questions) == 20
        assert all(len(q[1]) == 4 and 1 <= q[2] <= 4 for q in questions)
    assert all("(sample)" in p.filename for p in sample_papers())


def test_samples_are_added_once_and_labelled(db_client: TestClient, db_session: Session) -> None:
    first = db_client.post(URL, json={"exam_code": EXAM})
    assert first.status_code == 201, first.text
    added = first.json()
    assert len(added) == 2
    assert all(d["is_sample"] and d["exam_code"] == EXAM for d in added)
    assert all("sample" in d["original_filename"].lower() for d in added)
    again = db_client.post(URL, json={"exam_code": EXAM}).json()
    assert [d["id"] for d in again] == [d["id"] for d in added]
    assert len(db_session.scalars(select(Document)).all()) == 2
    listed = db_client.get("/api/v1/documents").json()["items"]
    assert {d["is_sample"] for d in listed} == {True}
    assert db_client.post(URL, json={"exam_code": "NO_SUCH_EXAM"}).status_code == 422


def test_the_import_reads_every_question_and_answer(
    db_client: TestClient,
    db_session: Session,
    storage: LocalDocumentStorage,
    settings: Settings,
) -> None:
    added = db_client.post(URL, json={"exam_code": EXAM}).json()
    while run_worker(db_session, storage, settings) is not None:
        pass
    for paper, read in zip(listing()["papers"], added, strict=True):  # type: ignore[call-overload]
        want = [q for s in paper["sections"] for q in s["questions"]]
        questions = db_session.scalars(
            select(Question)
            .where(Question.document_id == uuid.UUID(read["id"]))
            .order_by(Question.source_question_number)
        ).all()
        assert len(questions) == len(want) == 20
        for question, (stem, options, answer) in zip(questions, want, strict=True):
            assert question.stem == stem
            rows = db_session.scalars(
                select(QuestionOption)
                .where(QuestionOption.question_id == question.id)
                .order_by(QuestionOption.position)
            ).all()
            assert [o.text for o in rows] == options
            assert question.correct_option_position == answer
        document = db_client.get(f"/api/v1/documents/{read['id']}").json()
        assert document["questions_found"] == 20 and document["questions_to_check"] == 0


def test_samples_are_never_shared(db_client: TestClient, db_session: Session) -> None:
    added = db_client.post(URL, json={"exam_code": EXAM}).json()
    with pytest.raises(ConflictError, match="never shared"):
        shared_bank.publish(
            db_session, uuid.UUID(added[0]["id"]), rights_basis="own", source="PrepLoop"
        )
