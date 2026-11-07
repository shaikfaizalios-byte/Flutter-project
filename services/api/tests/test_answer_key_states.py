"""Answer-key states: several answers, dropped questions, and scoring with the final key."""

import uuid
from datetime import date
from decimal import Decimal
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain import question_formats
from app.domain.answer_keys import answer_changed, key_problems
from app.domain.scoring import ScoredItem, score_session, tally_json
from app.models.document import Document, DocumentStatus
from app.models.exam import Exam
from app.models.practice import PracticeSession, SessionAnswer
from app.models.question import (
    ExamFormat,
    FormatStatus,
    Question,
    QuestionOption,
    QuestionOrigin,
    VerificationStatus,
)
from app.models.user import User
from tests.conftest import auth_headers, make_user

QUESTIONS = "/api/v1/questions"
SESSIONS = "/api/v1/practice/sessions"
_numbers = iter(range(1, 100_000))


def item(**fields: Any) -> ScoredItem:
    values: dict[str, Any] = {
        "position": 1,
        "section": None,
        "topic_id": None,
        "correct_position": 2,
        "marks_correct": Decimal(4),
        "marks_wrong": Decimal(1),
    }
    return ScoredItem(**(values | fields))


# --- whole numbers and decimal rules ----------------------------------------------------------


@pytest.mark.parametrize(
    ("given", "right"),
    [("7", True), ("7.0", True), ("07", True), ("8", False), ("7.5", False), ("seven", False)],
)
def test_a_whole_number_is_compared_by_value(given: str, right: bool) -> None:
    assert question_formats.is_correct("integer", {"value": "7"}, given) is right


def test_an_integer_key_must_be_whole() -> None:
    assert question_formats.spec_problems("integer", {"value": "7"}, 0) == []
    assert question_formats.spec_problems("integer", {"value": "7.5"}, 0)
    assert question_formats.answer_type_of("integer") == "typed"


@pytest.mark.parametrize(
    ("given", "right"),
    [
        ("2.67", True),  # as typed
        ("2.666", True),  # rounds to the key
        ("2.674", True),  # truncates to the key
        ("2.68", False),
        ("2.66", False),
    ],
)
def test_a_decimal_rule_accepts_truncating_or_rounding(given: str, right: bool) -> None:
    spec = {"value": "2.67", "decimals": 2}
    assert question_formats.is_correct("numeric", spec, given) is right


def test_a_range_with_a_decimal_rule_still_works() -> None:
    spec = {"min": "1.40", "max": "1.50", "decimals": 2}
    assert question_formats.is_correct("numeric", spec, "1.456")
    assert not question_formats.is_correct("numeric", spec, "1.51")


def test_without_a_rule_nothing_is_rounded() -> None:
    assert not question_formats.is_correct("numeric", {"value": "2.67"}, "2.666")


def test_decimal_places_must_make_sense() -> None:
    assert question_formats.spec_problems("numeric", {"value": "1", "decimals": 20}, 0)
    assert question_formats.spec_problems("numeric", {"value": "1", "decimals": True}, 0)


# --- rules ------------------------------------------------------------------------------------


def test_several_answers_apply_only_to_one_option_questions() -> None:
    def problems(name: str, accepted: list[int]) -> list[str]:
        return key_problems(format_name=name, outcome="several", accepted=accepted, option_count=4)

    assert problems("single_correct", [1, 3]) == []
    assert problems("numeric", [1, 3])
    assert problems("single_correct", [1])
    assert problems("single_correct", [1, 1])
    assert problems("single_correct", [1, 9])


def test_only_several_lists_accepted_options() -> None:
    assert key_problems(format_name="single_correct", outcome="one", accepted=[1], option_count=4)
    assert not key_problems(format_name="numeric", outcome="dropped", accepted=None, option_count=0)


def test_a_change_counts_only_once_the_key_is_final() -> None:
    assert answer_changed([1], [2], "final")
    assert not answer_changed([1], [1], "final")
    assert not answer_changed([1], [2], "provisional")


# --- scoring ----------------------------------------------------------------------------------


def test_any_accepted_answer_earns_the_marks() -> None:
    several = item(key_outcome="several", accepted_positions=[2, 3])
    assert score_session([several], {1: 3}).total.score == 4
    assert score_session([several], {1: 2}).total.score == 4
    assert score_session([several], {1: 1}).total.score == -1
    assert score_session([several], {}).total.score == 0


@pytest.mark.parametrize("answer", [None, 1, 2])
def test_a_dropped_question_gives_everyone_the_marks(answer: int | None) -> None:
    result = score_session([item(key_outcome="dropped")], {1: answer})
    assert result.total.score == 4 and result.total.max_score == 4
    assert result.total.dropped == 1
    assert result.outcomes[1] is None
    assert result.total.attempted == 0  # it can't help or hurt accuracy


def test_the_result_explains_a_dropped_question() -> None:
    total = score_session([item(key_outcome="dropped")], {}).total
    data = tally_json(total)
    assert data["dropped"] == 1
    assert "Dropped by the key 1" in str(data["explanation"])


def test_results_without_a_dropped_question_look_as_they_did() -> None:
    assert "dropped" not in tally_json(score_session([item()], {1: 2}).total)


# --- through the API --------------------------------------------------------------------------


def paper(db: Session, owner: User) -> Document:
    document = Document(
        owner_id=owner.id,
        exam_code="SSC_CHSL",
        language="en",
        original_filename="p.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
    )
    db.add(document)
    db.flush()
    return document


def question(db: Session, owner: User, correct: int = 2, **fields: Any) -> Question:
    number = next(_numbers)
    row = Question(
        owner_id=owner.id,
        origin=QuestionOrigin.SOURCE,
        exam_code="SSC_CHSL",
        stem=f"Question number {number}?",
        language="en",
        document_id=paper(db, owner).id,
        source_question_number=number,
        source_pages=[1],
        correct_option_position=correct,
        verification_status=VerificationStatus.VERIFIED,
        **fields,
    )
    row.options = [
        QuestionOption(position=i, label=str(i), text=f"Option {i}") for i in range(1, 5)
    ]
    db.add(row)
    db.flush()
    return row


def set_key(api: TestClient, row: Question, **body: Any) -> dict[str, Any]:
    response = api.put(f"{QUESTIONS}/{row.id}/answer-key", json=body)
    assert response.status_code == 200, response.text
    data: dict[str, Any] = response.json()
    return data


def answered_session(api: TestClient, position: int = 2) -> dict[str, Any]:
    started = api.post(SESSIONS, json={"count": 1, "exam_code": "SSC_CHSL"}).json()
    url = f"{SESSIONS}/{started['id']}"
    api.put(f"{url}/answers/1", json={"client_seq": 1, "selected_position": position})
    data: dict[str, Any] = api.post(f"{url}/submit").json()
    return data


def test_a_provisional_key_marks_new_attempts_only(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    row = question(db_session, user)
    done = answered_session(db_client, 2)
    assert done["result"]["correct"] == 1
    result = set_key(db_client, row, stage="provisional", correct_option_position=3)
    assert result["sessions_remarked"] == 0
    assert db_client.get(f"{SESSIONS}/{done['id']}").json()["result"]["correct"] == 1


def test_a_final_key_that_changes_the_answer_re_marks_past_attempts(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    row = question(db_session, user)
    set_key(db_client, row, stage="provisional", correct_option_position=2)
    done = answered_session(db_client, 2)
    assert done["result"]["correct"] == 1

    result = set_key(db_client, row, stage="final", correct_option_position=3)
    assert result["sessions_remarked"] == 1
    assert result["question"]["key_changed"] is True
    after = db_client.get(f"{SESSIONS}/{done['id']}").json()
    assert (after["result"]["correct"], after["result"]["wrong"]) == (0, 1)
    assert after["result"]["remarked"] is True
    assert after["items"][0]["feedback"]["is_correct"] is False
    assert after["items"][0]["feedback"]["correct_position"] == 3
    assert after["items"][0]["feedback"]["key_note"] == "changed"
    answer = db_session.scalars(select(SessionAnswer)).one()
    db_session.refresh(answer)
    assert answer.is_correct is False


def test_a_final_key_that_agrees_changes_nothing_but_the_stage(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    row = question(db_session, user)
    set_key(db_client, row, stage="provisional", correct_option_position=2)
    answered_session(db_client, 2)
    result = set_key(db_client, row, stage="final", correct_option_position=2)
    assert result["question"]["key_changed"] is False
    assert result["question"]["key_stage"] == "final"


def test_a_first_final_key_isnt_a_change(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    row = question(db_session, user)
    result = set_key(db_client, row, stage="final", correct_option_position=4)
    assert result["question"]["key_changed"] is False


def test_several_accepted_answers_re_mark_and_are_shown(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    row = question(db_session, user)
    done = answered_session(db_client, 3)
    assert done["result"]["wrong"] == 1
    set_key(db_client, row, stage="final", outcome="several", accepted_positions=[2, 3])
    after = db_client.get(f"{SESSIONS}/{done['id']}").json()
    assert after["result"]["correct"] == 1
    feedback = after["items"][0]["feedback"]
    assert feedback["accepted_positions"] == [2, 3] and feedback["key_note"] == "several"


def test_a_dropped_question_re_marks_as_marks_to_everyone(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    row = question(db_session, user)
    done = answered_session(db_client, 1)
    set_key(db_client, row, stage="final", outcome="dropped")
    after = db_client.get(f"{SESSIONS}/{done['id']}").json()
    assert after["result"]["dropped"] == 1 and after["result"]["wrong"] == 0
    assert after["items"][0]["feedback"]["key_note"] == "dropped"
    assert after["items"][0]["feedback"]["is_correct"] is None


def test_a_dropped_question_is_no_longer_practised(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    row = question(db_session, user)
    set_key(db_client, row, stage="final", outcome="dropped")
    response = db_client.post(SESSIONS, json={"count": 1, "exam_code": "SSC_CHSL"})
    assert response.status_code != 201 or row.stem not in response.text


def test_offline_packs_leave_out_keys_that_arent_a_single_answer(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    plain = question(db_session, user)
    several = question(db_session, user)
    set_key(db_client, several, stage="final", outcome="several", accepted_positions=[1, 2])
    pack = db_client.get("/api/v1/practice/offline-pack", params={"exam": "SSC_CHSL"}).json()
    assert [q["id"] for q in pack["questions"]] == [str(plain.id)]


def mock_format(db: Session) -> ExamFormat:
    db.add(Exam(code="KEYED", name="Keyed"))
    db.flush()
    row = ExamFormat(
        code="KEYED_2026",
        exam_code="KEYED",
        stage="Paper",
        name="Keyed paper",
        sections=[{"subject": "Reasoning", "questions": 1, "max_marks": 4}],
        sections_in_fixed_order=False,
        total_questions=1,
        duration_minutes=60,
        negative_marks_per_wrong=1,
        source_title="Notice",
        source_url="https://example.com/n",
        source_reference="para 1",
        source_published_on=date(2026, 1, 1),
        verified_on=date(2026, 1, 2),
        reviewed_by="A. Reviewer",
        status=FormatStatus.VERIFIED,
    )
    db.add(row)
    db.flush()
    return row


def test_a_final_key_reaches_another_accounts_mock_with_its_own_marks(
    db_session: Session, user: User, db_client: TestClient
) -> None:
    from app.services.practice_service import PracticeService
    from app.services.question_service import QuestionService  # noqa: F401

    row = question(db_session, user)
    done = answered_session(db_client, 2)
    practice = db_session.get(PracticeSession, uuid.UUID(done["id"]))
    assert practice is not None
    other = make_user(db_session, "other-learner@example.com")
    practice.owner_id = other.id
    item_ = practice.items[0]
    item_.marks_correct, item_.marks_wrong = 4.0, 1.0
    PracticeService(db_session, owner_id=other.id).remark(practice)
    assert practice.score == 4
    set_key(db_client, row, stage="final", correct_option_position=3)
    db_session.refresh(practice)
    assert practice.score == -1
    assert auth_headers(other)  # the learner's own account, not the reviewer's


def test_time_taken_survives_re_marking(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    row = question(db_session, user)
    done = answered_session(db_client, 2)
    seconds = done["result"]["time_taken_seconds"]
    set_key(db_client, row, stage="final", correct_option_position=3)
    after = db_client.get(f"{SESSIONS}/{done['id']}").json()
    assert after["result"]["time_taken_seconds"] == seconds


def test_someone_elses_question_stays_out_of_reach(
    db_client: TestClient, db_session: Session
) -> None:
    other = make_user(db_session, "someone@example.com")
    row = question(db_session, other)
    response = db_client.put(
        f"{QUESTIONS}/{row.id}/answer-key", json={"stage": "final", "outcome": "dropped"}
    )
    assert response.status_code == 404


def test_a_key_that_cant_stand_is_refused(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    row = question(db_session, user)
    response = db_client.put(
        f"{QUESTIONS}/{row.id}/answer-key",
        json={"stage": "final", "outcome": "several", "accepted_positions": [1]},
    )
    assert response.status_code == 422


def test_the_change_is_in_the_questions_history(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    row = question(db_session, user)
    set_key(db_client, row, stage="final", correct_option_position=3)
    revisions = db_client.get(f"{QUESTIONS}/{row.id}/revisions").json()
    assert any("correct_option_position" in r["changed"] for r in revisions)
