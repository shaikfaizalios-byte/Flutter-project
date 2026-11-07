"""Question formats through the API: who gets them, how they are answered and reviewed."""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models.document import Document, DocumentStatus
from app.models.question import (
    Question,
    QuestionOption,
    QuestionOrigin,
    VerificationStatus,
)
from app.models.user import User

MATCH = {"left": ["a", "b"], "right": ["x", "y"], "pairs": [[0, 1], [1, 0]]}
ORDER = {"items": ["p", "q", "r"], "order": [2, 0, 1]}
_numbers = iter(range(1, 100_000))


def _question(
    db: Session,
    owner: User,
    format_name: str,
    spec: dict[str, Any] | None = None,
    *,
    options: int = 4,
    answer_type: str = "choice",
    correct: int | None = None,
    typed: str | None = None,
) -> Question:
    document = Document(
        owner_id=owner.id,
        exam_code="SSC_CHSL",
        language="en",
        original_filename="paper.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
    )
    db.add(document)
    db.flush()
    question = Question(
        owner_id=owner.id,
        origin=QuestionOrigin.SOURCE,
        exam_code="SSC_CHSL",
        stem=f"A {format_name} question number {next(_numbers)}",
        language="en",
        document_id=document.id,
        source_question_number=next(_numbers),
        source_pages=[1],
        answer_type=answer_type,
        format=format_name,
        answer_spec=spec,
        correct_option_position=correct,
        typed_answer=typed,
        verification_status=VerificationStatus.VERIFIED,
    )
    question.options = [
        QuestionOption(position=i, label=str(i), text=f"o{i}") for i in range(1, options + 1)
    ]
    db.add(question)
    db.flush()
    return question


def _start(client: TestClient, **body: Any) -> dict[str, Any]:
    response = client.post(
        "/api/v1/practice/sessions", json={"count": 10, "exam_code": "SSC_CHSL", **body}
    )
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


def _answer(client: TestClient, session: dict[str, Any], position: int, **body: Any) -> Any:
    return client.put(
        f"/api/v1/practice/sessions/{session['id']}/answers/{position}",
        json={"client_seq": 1, **body},
    )


def _only(session: dict[str, Any]) -> dict[str, Any]:
    assert len(session["items"]) == 1
    item: dict[str, Any] = session["items"][0]
    return item


def test_apps_that_dont_ask_never_get_the_new_formats(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    single = _question(db_session, user, "single_correct", correct=1)
    _question(db_session, user, "multiple_correct", {"correct_positions": [1, 2]})
    _question(db_session, user, "numeric", {"value": "2"}, answer_type="typed", options=0)
    _question(db_session, user, "match", MATCH, options=0)
    assert _only(_start(db_client))["question_id"] == str(single.id)


def test_a_new_format_with_a_plain_answer_too_still_needs_asking(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    single = _question(db_session, user, "single_correct", correct=1)
    _question(
        db_session, user, "numeric", {"value": "2"}, answer_type="typed", options=0, typed="2"
    )
    assert _only(_start(db_client))["question_id"] == str(single.id)


def test_formats_shown_differently_reach_every_app(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _question(db_session, user, "assertion_reason", correct=2)
    item = _only(_start(db_client))
    assert item["format"] == "assertion_reason"
    assert len(item["options"]) == 4


def test_multiple_correct_is_marked_on_the_whole_set(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _question(db_session, user, "multiple_correct", {"correct_positions": [1, 3]})
    session = _start(db_client, include_new_formats=True)
    item = _only(session)
    assert item["format"] == "multiple_correct"
    assert item["feedback"] is None  # the answer stays on the server until answered
    answered = _answer(db_client, session, 1, response={"positions": [3, 1]}).json()
    assert answered["feedback"]["is_correct"] is True
    assert answered["feedback"]["correct_spec"] == {"correct_positions": [1, 3]}
    assert answered["response"] == {"positions": [3, 1]}


def test_a_partly_right_set_is_wrong_and_the_first_answer_stays(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _question(db_session, user, "multiple_correct", {"correct_positions": [1, 3]})
    session = _start(db_client, include_new_formats=True)
    first = _answer(db_client, session, 1, response={"positions": [1]}).json()
    assert first["feedback"]["is_correct"] is False
    again = db_client.put(
        f"/api/v1/practice/sessions/{session['id']}/answers/1",
        json={"client_seq": 2, "response": {"positions": [1, 3]}},
    ).json()
    assert again["applied"] is False


def test_numeric_uses_its_tolerance(db_client: TestClient, db_session: Session, user: User) -> None:
    _question(
        db_session,
        user,
        "numeric",
        {"value": "2.5", "tolerance": "0.01"},
        answer_type="typed",
        options=0,
    )
    session = _start(db_client, include_new_formats=True)
    item = _only(session)
    assert item["answer_type"] == "typed" and item["typed_answer_numeric"] is True
    answered = _answer(db_client, session, 1, typed_answer="2.51").json()
    assert answered["feedback"]["is_correct"] is True


def test_fill_in_the_blank(db_client: TestClient, db_session: Session, user: User) -> None:
    _question(
        db_session, user, "fill_blank", {"accepted": ["Nucleus"]}, answer_type="typed", options=0
    )
    session = _start(db_client, include_new_formats=True)
    answered = _answer(db_client, session, 1, typed_answer=" nucleus ").json()
    assert answered["feedback"]["is_correct"] is True


def test_match_shows_the_lists_but_not_the_pairs(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _question(db_session, user, "match", MATCH, options=0)
    session = _start(db_client, include_new_formats=True)
    item = _only(session)
    assert item["format_data"] == {"left": ["a", "b"], "right": ["x", "y"]}
    assert "pairs" not in str(item)
    answered = _answer(db_client, session, 1, response={"pairs": [[1, 0], [0, 1]]}).json()
    assert answered["feedback"]["is_correct"] is True


def test_ordering(db_client: TestClient, db_session: Session, user: User) -> None:
    _question(db_session, user, "ordering", ORDER, options=0)
    session = _start(db_client, include_new_formats=True)
    assert _only(session)["format_data"] == {"items": ["p", "q", "r"]}
    answered = _answer(db_client, session, 1, response={"order": [0, 1, 2]}).json()
    assert answered["feedback"]["is_correct"] is False


@pytest.mark.parametrize(
    "body",
    [
        {"response": {"positions": [9]}},
        {"response": {"pairs": [[0, 0]]}},
        {"selected_position": 1},
        {"typed_answer": "1"},
    ],
)
def test_answers_that_dont_fit_are_refused(
    db_client: TestClient, db_session: Session, user: User, body: dict[str, Any]
) -> None:
    _question(db_session, user, "multiple_correct", {"correct_positions": [1, 3]})
    session = _start(db_client, include_new_formats=True)
    assert _answer(db_client, session, 1, **body).status_code == 422


def test_a_response_is_refused_on_a_plain_question(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _question(db_session, user, "single_correct", correct=1)
    session = _start(db_client)
    assert _answer(db_client, session, 1, response={"positions": [1]}).status_code == 422


def test_a_session_scores_and_counts_these_answers(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    _question(db_session, user, "multiple_correct", {"correct_positions": [1, 3]})
    session = _start(db_client, include_new_formats=True)
    _answer(db_client, session, 1, response={"positions": [1, 3]})
    done = db_client.post(f"/api/v1/practice/sessions/{session['id']}/submit").json()
    assert done["result"]["correct"] == 1
    overview = db_client.get(
        "/api/v1/analytics/overview", params={"timezone": "Asia/Kolkata"}
    ).json()
    assert overview["answered"] == 1


def test_the_offline_pack_leaves_them_out(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    single = _question(db_session, user, "single_correct", correct=1)
    _question(db_session, user, "multiple_correct", {"correct_positions": [1, 3]})
    pack = db_client.get("/api/v1/practice/offline-pack", params={"exam": "SSC_CHSL"}).json()
    assert [q["id"] for q in pack["questions"]] == [str(single.id)]


def test_a_reviewer_sets_the_format_and_its_answer(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    question = _question(db_session, user, "single_correct", correct=1)
    url = f"/api/v1/questions/{question.id}"
    changed = db_client.patch(
        url, json={"format": "multiple_correct", "answer_spec": {"correct_positions": [1, 2]}}
    )
    assert changed.status_code == 200, changed.text
    data = changed.json()
    assert data["format"] == "multiple_correct"
    assert data["answer_spec"] == {"correct_positions": [1, 2]}
    assert data["answer_type"] == "choice"
    history = db_client.get(f"{url}/revisions").json()
    assert "answer_spec" in history[-1]["changed"]
    assert history[-1]["snapshot"]["answer_spec"] == {"correct_positions": [1, 2]}
    assert history[-1]["snapshot"]["format"] == "multiple_correct"


def test_a_reviewer_can_turn_a_question_into_a_numeric_one(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    question = _question(db_session, user, "single_correct", correct=1)
    changed = db_client.patch(
        f"/api/v1/questions/{question.id}",
        json={"format": "numeric", "answer_spec": {"min": "1", "max": "2"}},
    ).json()
    assert (changed["format"], changed["answer_type"]) == ("numeric", "typed")
    assert changed["correct_option_position"] is None


@pytest.mark.parametrize(
    "body",
    [
        {"format": "oral"},
        {"format": "multiple_correct", "answer_spec": {"correct_positions": [9]}},
        {"format": "numeric", "answer_spec": {"min": "3", "max": "1"}},
    ],
)
def test_impossible_reviews_are_refused(
    db_client: TestClient, db_session: Session, user: User, body: dict[str, Any]
) -> None:
    question = _question(db_session, user, "single_correct", correct=1)
    response = db_client.patch(f"/api/v1/questions/{question.id}", json=body)
    assert response.status_code == 422


def test_plain_formats_follow_the_answer_type(db_session: Session, user: User) -> None:
    question = _question(db_session, user, "single_correct", correct=1)
    question.answer_type = "typed"
    assert question.format == "typed_in"
    question.answer_type = "written"
    assert question.format == "descriptive"
    question.answer_type = "choice"
    assert question.format == "single_correct"


def test_a_chosen_format_is_not_overwritten(db_session: Session, user: User) -> None:
    question = _question(db_session, user, "multiple_correct", {"correct_positions": [1]})
    question.answer_type = "choice"
    assert question.format == "multiple_correct"
