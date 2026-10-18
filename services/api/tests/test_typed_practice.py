"""Typed-in (TITA) questions through review, practice and scoring."""

from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models.document import Document
from app.models.question import Question, VerificationStatus
from tests.test_practice import api, clock, document, make_question  # noqa: F401 - fixtures


def _typed(db: Session, doc: Document, answer: str | None = "2.5", **extra: Any) -> Question:
    q = make_question(db, doc, answer=None, **extra)
    q.options = []
    q.answer_type = "typed"
    q.typed_answer = answer
    db.flush()
    return q


def _start(client: TestClient, **body: Any) -> dict[str, Any]:
    response = client.post("/api/v1/practice/sessions", json=body)
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


def test_practice_a_typed_question(
    api: TestClient,  # noqa: F811
    db_session: Session,
    document: Document,  # noqa: F811
) -> None:
    _typed(db_session, document)
    session = _start(api, count=5)
    item = session["items"][0]
    assert item["answer_type"] == "typed" and item["options"] == []
    assert item["typed_answer_numeric"] is True
    assert item["feedback"] is None  # the answer isn't revealed before answering

    url = f"/api/v1/practice/sessions/{session['id']}/answers/1"
    assert api.put(url, json={"selected_position": 1, "client_seq": 1}).status_code == 422

    response = api.put(url, json={"typed_answer": " 2.50 ", "client_seq": 2})
    assert response.status_code == 200, response.text
    ack = response.json()
    assert ack["typed_answer"] == "2.50"
    assert ack["feedback"]["is_correct"] is True
    assert ack["feedback"]["correct_typed_answer"] == "2.5"
    assert ack["feedback"]["correct_position"] is None

    # Practice answers are final.
    again = api.put(url, json={"typed_answer": "3", "client_seq": 3}).json()
    assert again["applied"] is False

    result = api.post(f"/api/v1/practice/sessions/{session['id']}/submit").json()["result"]
    assert result["correct"] == 1 and result["wrong"] == 0


def test_a_wrong_typed_answer_and_choice_answers_refuse_text(
    api: TestClient,  # noqa: F811
    db_session: Session,
    document: Document,  # noqa: F811
) -> None:
    _typed(db_session, document, answer="3421")
    session = _start(api, count=5)
    url = f"/api/v1/practice/sessions/{session['id']}/answers/1"
    ack = api.put(url, json={"typed_answer": "3412", "client_seq": 1}).json()
    assert ack["feedback"]["is_correct"] is False
    assert ack["feedback"]["correct_typed_answer"] == "3421"


def test_choice_questions_refuse_a_typed_answer(
    api: TestClient,  # noqa: F811
    db_session: Session,
    document: Document,  # noqa: F811
) -> None:
    make_question(db_session, document)
    session = _start(api, count=5)
    url = f"/api/v1/practice/sessions/{session['id']}/answers/1"
    assert api.put(url, json={"typed_answer": "1", "client_seq": 1}).status_code == 422


def test_typed_questions_without_an_answer_are_not_practised(
    api: TestClient,  # noqa: F811
    db_session: Session,
    document: Document,  # noqa: F811
) -> None:
    _typed(db_session, document, answer=None)
    response = api.post("/api/v1/practice/sessions", json={"count": 5})
    assert response.status_code == 422


def test_review_switches_a_question_to_typed_and_verifies_it(
    api: TestClient,  # noqa: F811
    db_session: Session,
    document: Document,  # noqa: F811
) -> None:
    q = make_question(db_session, document, status=VerificationStatus.UNVERIFIED)
    url = f"/api/v1/questions/{q.id}"

    body = api.patch(url, json={"answer_type": "typed"}).json()
    assert body["answer_type"] == "typed" and body["correct_option_position"] is None
    assert "missing_answer" in [i["code"] for i in body["issues"] if not i["resolved"]]
    assert api.patch(url, json={"verification_status": "verified"}).status_code == 422
    # A typed question takes no option answer.
    assert api.patch(url, json={"correct_option_position": 2}).status_code == 422

    body = api.patch(
        url,
        json={
            "typed_answer": "12",
            "options": [{"label": "1", "text": "x"}, {"label": "2", "text": "y"}],
        },
    ).json()
    assert body["typed_answer"] == "12" and body["typed_answer_numeric"] is True
    assert body["answer_source"] == "manual"
    assert api.patch(url, json={"verification_status": "verified"}).status_code == 200

    # Back to choice: the typed answer goes, an option answer is needed again.
    body = api.patch(url, json={"answer_type": "choice"}).json()
    assert body["typed_answer"] is None and body["verification_status"] == "unverified"
