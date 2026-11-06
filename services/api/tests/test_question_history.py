"""Question history: the paper's own answer stays known after review, and every edit is kept."""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain import question_history
from app.integrations.storage import LocalDocumentStorage
from app.services.processing_service import DocumentProcessor
from tests.conftest import auth_headers, make_user
from tests.fakes import FakeOcrEngine
from tests.test_question_bank import QUESTIONS, by_number, upload_paper

SNAP = question_history.snapshot(
    stem="What is 20 percent of 150?",
    options=[("a", "20"), ("b", "30"), ("c", "40"), ("d", "50")],
    answer_type="choice",
    correct_option_position=2,
    typed_answer=None,
    model_answer=None,
    answer_source="answer_key",
    explanation=None,
    format_name="single_correct",
    answer_spec=None,
)


# --- rules -------------------------------------------------------------------------------


def test_changed_fields_lists_only_what_differs() -> None:
    assert question_history.changed_fields(None, SNAP) == list(question_history.TRACKED_FIELDS)
    edited = {**SNAP, "correct_option_position": 3, "answer_source": "manual"}
    assert question_history.changed_fields(SNAP, edited) == [
        "correct_option_position",
        "answer_source",
    ]
    assert question_history.changed_fields(SNAP, dict(SNAP)) == []


def test_answer_origin_never_calls_a_reviewers_answer_the_papers() -> None:
    def origin(source: str | None, answered: bool = True, kind: str = "source") -> str:
        return question_history.answer_origin(origin=kind, answer_source=source, answered=answered)

    assert origin("answer_key") == "paper"
    assert origin("inline") == "paper"
    assert origin("manual") == "reviewer"
    assert origin(None) == "reviewer"  # an answer without a recorded source is not the paper's
    assert origin(None, answered=False) == "none"
    assert origin("ai", kind="ai") == "ai"


def test_paper_answer_comes_from_the_extracted_snapshot_only() -> None:
    found = question_history.paper_answer(SNAP)
    assert found is not None
    assert (found.source, found.option_position, found.option_label, found.option_text) == (
        "answer_key",
        2,
        "b",
        "30",
    )
    none = question_history.paper_answer({**SNAP, "answer_source": None})
    assert none is not None and none.source is None and none.option_position is None
    assert question_history.paper_answer(None) is None  # no record: unknown, not "no answer"


# --- API ---------------------------------------------------------------------------------


@pytest.fixture
def paper_id(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> uuid.UUID:
    """The synthetic paper of test_question_bank, read by the worker (key: 1-2, 2-1, 3-b)."""
    document_id = upload_paper(db_client)
    processor = DocumentProcessor(storage=storage, ocr=FakeOcrEngine(), settings=settings)
    assert processor.claim_next(db_session) == document_id
    processor.process(db_session, document_id)
    return document_id


def revisions(client: TestClient, question_id: str) -> list[dict[str, Any]]:
    response = client.get(f"{QUESTIONS}/{question_id}/revisions")
    assert response.status_code == 200, response.text
    found: list[dict[str, Any]] = response.json()
    return found


def test_a_read_question_starts_its_history_as_found_in_the_paper(
    db_client: TestClient, paper_id: uuid.UUID
) -> None:
    question = by_number(db_client, paper_id, 3)

    [first] = revisions(db_client, question["id"])

    assert (first["action"], first["actor"]) == ("extracted", "rules")
    assert first["snapshot"]["stem"] == question["stem"]
    assert first["snapshot"]["correct_option_position"] == 2  # key: 3-(b)
    assert first["snapshot"]["answer_source"] == "answer_key"
    assert question["answer_origin"] == "paper"
    assert question["paper_answer"] is None  # only shown once a reviewer changes the answer


def test_changing_the_answer_keeps_what_the_paper_said(
    db_client: TestClient, paper_id: uuid.UUID
) -> None:
    question = by_number(db_client, paper_id, 3)

    edited = db_client.patch(f"{QUESTIONS}/{question['id']}", json={"correct_option_position": 3})

    assert edited.status_code == 200, edited.text
    body = edited.json()
    assert (body["correct_option_position"], body["answer_origin"]) == (3, "reviewer")
    assert body["paper_answer"] == {
        "source": "answer_key",
        "option_position": 2,
        "option_label": "b",
        "option_text": "30",
        "typed_answer": None,
        "written_answer": None,
    }
    history = revisions(db_client, question["id"])
    assert [r["action"] for r in history] == ["extracted", "edited"]
    assert history[1]["actor"] == "reviewer"
    assert history[1]["changed"] == ["correct_option_position", "answer_source"]
    assert history[0]["snapshot"]["correct_option_position"] == 2  # never rewritten


def test_a_paper_without_an_answer_says_so(db_client: TestClient, paper_id: uuid.UUID) -> None:
    question = by_number(db_client, paper_id, 4)  # not in the answer key
    assert question["answer_origin"] == "none"

    body = db_client.patch(
        f"{QUESTIONS}/{question['id']}", json={"correct_option_position": 2}
    ).json()

    assert body["answer_origin"] == "reviewer"
    assert body["paper_answer"]["source"] is None
    assert body["paper_answer"]["option_position"] is None


def test_wording_edits_are_kept_and_status_only_changes_add_no_revision(
    db_client: TestClient, paper_id: uuid.UUID
) -> None:
    question = by_number(db_client, paper_id, 2)

    db_client.patch(f"{QUESTIONS}/{question['id']}", json={"stem": "How is DOG coded?"})
    db_client.patch(f"{QUESTIONS}/{question['id']}", json={"verification_status": "rejected"})
    db_client.patch(f"{QUESTIONS}/{question['id']}", json={"stem": "How is DOG coded?"})

    history = revisions(db_client, question["id"])
    assert [(r["action"], r["changed"]) for r in history[1:]] == [("edited", ["stem"])]
    assert history[0]["snapshot"]["stem"] == question["stem"]
    assert history[1]["snapshot"]["stem"] == "How is DOG coded?"


def test_another_accounts_history_is_not_found(
    db_client: TestClient, db_session: Session, paper_id: uuid.UUID
) -> None:
    question = by_number(db_client, paper_id, 1)
    other = make_user(db_session, email="other@example.com")

    response = db_client.get(f"{QUESTIONS}/{question['id']}/revisions", headers=auth_headers(other))

    assert response.status_code == 404
