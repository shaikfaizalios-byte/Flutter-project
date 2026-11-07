"""Computer-based mocks: the official rules on mark for review, saved answers, sections that
repeat a subject, sectional practice, and analysis with no invented ranks."""

import json
import uuid
from datetime import date
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.cli.exam_formats import FormatFile
from app.domain.exam_format import section_key
from app.domain.mock_analysis import percentile, sectional_minutes
from app.models.exam import Exam
from app.models.practice import PracticeSession, SessionAnswer
from app.models.question import ExamFormat, FormatStatus, Question, Topic
from app.models.syllabus import SyllabusNode, SyllabusVersion
from app.models.user import User
from tests.conftest import auth_headers, make_user
from tests.test_practice import make_question
from tests.test_shared_bank import make_document

EXAM = "CBT_EXAM"
RULES = {
    "marked_with_answer_counts": True,
    "marked_without_answer_counts": False,
    "answer_needs_saving": True,
    "free_navigation": True,
    "ends_at_zero": True,
    "language_switch": "paper",
    "reference": "Bulletin, p.1",
}
MOCKS = "/api/v1/practice/mock-tests"
SESSIONS = "/api/v1/practice/sessions"


def paper(db: Session, sections: list[dict[str, Any]], rules: Any = RULES, **fields: Any) -> None:
    db.add(Exam(code=EXAM, name="Computer exam"))
    db.flush()
    values: dict[str, Any] = {
        "negative_marks_per_wrong": 1,
        "question_types": ["choice", "integer"],
        "sections_in_fixed_order": False,
    }
    db.add(
        ExamFormat(
            code="CBT_2027",
            exam_code=EXAM,
            stage="Paper",
            name="Computer paper",
            sections=sections,
            total_questions=sum(s["questions"] for s in sections),
            duration_minutes=60,
            conduct={"cbt": rules} if rules else None,
            source_title="Notice",
            source_url="https://example.com/notice",
            source_reference="para 1",
            source_published_on=date(2026, 1, 1),
            verified_on=date(2026, 1, 2),
            reviewed_by="A. Reviewer",
            status=FormatStatus.VERIFIED,
            **(values | fields),
        )
    )
    db.flush()


ONE_SECTION = [{"part": "1", "subject": "Physics", "questions": 2, "max_marks": 8}]
TWO_PARTS = [
    {
        "part": "A",
        "subject": "Maths",
        "questions": 1,
        "max_marks": 4,
        "formats": ["single_correct"],
    },
    {"part": "B", "subject": "Maths", "questions": 1, "max_marks": 4, "formats": ["integer"]},
    {"part": "1", "subject": "Physics", "questions": 1, "max_marks": 4},
]


def questions(db: Session, owner: User, subject: str, count: int, **fields: Any) -> list[Question]:
    document = make_document(db, owner)
    document.exam_code = EXAM
    rows = []
    for _ in range(count):
        question = make_question(db, document, subject=subject)
        question.exam_code = EXAM
        for key, value in fields.items():
            setattr(question, key, value)
        rows.append(question)
    db.flush()
    return rows


def start(api: TestClient, **body: Any) -> dict[str, Any]:
    response = api.post(
        MOCKS, json={"exam_format_code": "CBT_2027", "include_new_formats": True, **body}
    )
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


def put(api: TestClient, session: str, position: int, seq: int, **body: Any) -> Any:
    return api.put(f"{SESSIONS}/{session}/answers/{position}", json={"client_seq": seq, **body})


def submit(api: TestClient, session: str) -> dict[str, Any]:
    response = api.post(f"{SESSIONS}/{session}/submit")
    assert response.status_code == 200, response.text
    data: dict[str, Any] = response.json()
    return data


def test_the_format_files_state_where_each_rule_came_from() -> None:
    folder = Path(__file__).parents[1] / "data" / "exam_formats"
    for name in ("jee_main_2027_paper1", "jee_advanced_2026_paper1", "neet_ug_2026_re"):
        data = json.loads((folder / f"{name}.json").read_text(encoding="utf-8"))
        rules = FormatFile.model_validate(data).conduct
        assert rules is not None and rules.cbt is not None
        assert rules.cbt.reference
        assert rules.cbt.marked_with_answer_counts is True
        assert rules.cbt.marked_without_answer_counts is False


def test_neet_says_its_rules_are_borrowed() -> None:
    folder = Path(__file__).parents[1] / "data" / "exam_formats"
    data = json.loads((folder / "neet_ug_2026_re.json").read_text(encoding="utf-8"))
    assert "no CBT instructions" in data["conduct"]["cbt"]["basis"]


def test_a_session_carries_its_rules_and_keeps_them(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper(db_session, ONE_SECTION)
    questions(db_session, user, "Physics", 2)
    mock = start(db_client)
    assert mock["cbt"]["language_switch"] == "paper"
    row = db_session.scalar(select(ExamFormat).where(ExamFormat.code == "CBT_2027"))
    assert row is not None
    row.conduct = None
    db_session.flush()
    again = db_client.get(f"{SESSIONS}/{mock['id']}").json()
    assert again["cbt"]["language_switch"] == "paper"


def test_answered_and_marked_counts_and_marked_alone_does_not(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper(db_session, ONE_SECTION)
    questions(db_session, user, "Physics", 2)
    mock = start(db_client)
    put(db_client, mock["id"], 1, 1, selected_position=1, marked_for_review=True)
    put(db_client, mock["id"], 2, 2, selected_position=None, marked_for_review=True)
    read = db_client.get(f"{SESSIONS}/{mock['id']}").json()
    assert [i["marked_for_review"] for i in read["items"]] == [True, True]
    assert read["answered_count"] == 1

    result = submit(db_client, mock["id"])["result"]
    assert (result["correct"], result["unattempted"]) == (1, 1)
    assert float(result["score"]) == 4


def test_rules_that_dont_count_marked_answers_are_followed(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper(db_session, ONE_SECTION, RULES | {"marked_with_answer_counts": False})
    questions(db_session, user, "Physics", 2)
    mock = start(db_client)
    put(db_client, mock["id"], 1, 1, selected_position=1, marked_for_review=True)
    put(db_client, mock["id"], 2, 2, selected_position=1)
    assert float(submit(db_client, mock["id"])["result"]["score"]) == 4


def test_a_visit_keeps_the_saved_answer_and_adds_the_time(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper(db_session, ONE_SECTION)
    questions(db_session, user, "Physics", 2)
    mock = start(db_client)
    put(db_client, mock["id"], 1, 1, selected_position=2, time_spent_ms=1000)
    response = put(db_client, mock["id"], 1, 2, visit=True, time_spent_ms=500)
    assert response.status_code == 200, response.text
    put(db_client, mock["id"], 2, 3, visit=True, time_spent_ms=700)
    read = db_client.get(f"{SESSIONS}/{mock['id']}").json()
    assert read["items"][0]["selected_position"] == 2
    assert [i["visited"] for i in read["items"]] == [True, True]
    assert read["answered_count"] == 1
    row = db_session.scalar(
        select(SessionAnswer).where(
            SessionAnswer.session_id == uuid.UUID(mock["id"]), SessionAnswer.position == 1
        )
    )
    assert row is not None
    assert row.time_spent_ms == 1500


def test_a_replayed_update_adds_no_time(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper(db_session, ONE_SECTION)
    questions(db_session, user, "Physics", 2)
    mock = start(db_client)
    put(db_client, mock["id"], 1, 5, visit=True, time_spent_ms=500)
    put(db_client, mock["id"], 1, 5, visit=True, time_spent_ms=500)
    row = db_session.scalar(
        select(SessionAnswer).where(SessionAnswer.session_id == uuid.UUID(mock["id"]))
    )
    assert row is not None
    assert row.time_spent_ms == 500


def test_a_visit_cant_carry_an_answer(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper(db_session, ONE_SECTION)
    questions(db_session, user, "Physics", 2)
    mock = start(db_client)
    response = put(db_client, mock["id"], 1, 1, visit=True, selected_position=1)
    assert response.status_code >= 400


def test_other_mocks_have_no_review_marks(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper(db_session, ONE_SECTION, None)
    questions(db_session, user, "Physics", 2)
    mock = start(db_client)
    assert mock["cbt"] is None
    response = put(db_client, mock["id"], 1, 1, selected_position=1, marked_for_review=True)
    assert response.status_code >= 400
    put(db_client, mock["id"], 1, 2, selected_position=1, time_spent_ms=900)
    put(db_client, mock["id"], 1, 3, selected_position=2, time_spent_ms=300)
    row = db_session.scalar(
        select(SessionAnswer).where(SessionAnswer.session_id == uuid.UUID(mock["id"]))
    )
    assert row is not None
    assert row.time_spent_ms == 300  # as it always was


def test_section_names_stay_plain_unless_a_subject_repeats() -> None:
    assert section_key(TWO_PARTS[0], TWO_PARTS) == "Maths A"
    assert section_key(TWO_PARTS[2], TWO_PARTS) == "Physics"


def test_sections_of_one_subject_mark_apart(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    sections = [
        TWO_PARTS[0] | {"marks_wrong": 1},
        TWO_PARTS[1] | {"marks_wrong": 0},
        TWO_PARTS[2],
    ]
    paper(db_session, sections)
    questions(db_session, user, "Maths", 1)
    questions(
        db_session,
        user,
        "Maths",
        1,
        answer_type="typed",
        format="integer",
        answer_spec={"value": "7"},
        correct_option_position=None,
    )
    questions(db_session, user, "Physics", 1)
    mock = start(db_client)
    assert [i["section"] for i in mock["items"]] == ["Maths A", "Maths B", "Physics"]
    put(db_client, mock["id"], 1, 1, selected_position=2)  # wrong: -1
    put(db_client, mock["id"], 2, 2, typed_answer="9")  # wrong: 0 in this section
    result = submit(db_client, mock["id"])["result"]
    scores = {s["name"]: float(s["score"]) for s in result["sections"]}
    assert scores == {"Maths A": -1, "Maths B": 0, "Physics": 0}


def test_a_question_is_used_once_when_sections_share_a_subject(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    sections = [
        {"part": "A", "subject": "Maths", "questions": 1, "max_marks": 4},
        {"part": "B", "subject": "Maths", "questions": 1, "max_marks": 4},
    ]
    paper(db_session, sections, question_types=["choice"])
    questions(db_session, user, "Maths", 2)
    mock = start(db_client)
    assert len({i["question_id"] for i in mock["items"]}) == 2


def test_one_section_can_be_practised_on_its_share_of_the_time(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    sections = [
        {"part": "1", "subject": "Physics", "questions": 1, "max_marks": 4},
        {"part": "2", "subject": "Biology", "questions": 3, "max_marks": 12},
    ]
    paper(db_session, sections)
    questions(db_session, user, "Physics", 1)  # enough for this section, not for the whole paper
    mock = start(db_client, section="Physics")
    assert mock["sectional"] == "Physics"
    assert [i["section"] for i in mock["items"]] == ["Physics"]
    assert mock["remaining_seconds"] <= 15 * 60
    assert sectional_minutes(180, 45, 180) == 45
    bad = db_client.post(MOCKS, json={"exam_format_code": "CBT_2027", "section": "Art"})
    assert bad.status_code == 422


# --- analysis ---------------------------------------------------------------------------------


def test_analysis_gives_marks_time_and_chapters(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper(db_session, ONE_SECTION)
    topic = Topic(subject="Physics", name="Motion", keywords=[], exam_codes=[EXAM])
    db_session.add(topic)
    db_session.flush()
    version = SyllabusVersion(
        exam_code=EXAM, name="List", effective_year=2027, source_kind="manual"
    )
    db_session.add(version)
    db_session.flush()
    root = SyllabusNode(version_id=version.id, position=1, name="Physics")
    db_session.add(root)
    db_session.flush()
    unit = SyllabusNode(version_id=version.id, parent_id=root.id, position=1, name="Kinematics")
    db_session.add(unit)
    db_session.flush()
    db_session.add(
        SyllabusNode(
            version_id=version.id, parent_id=unit.id, position=1, name="Motion", topic_id=topic.id
        )
    )
    db_session.flush()
    questions(db_session, user, "Physics", 2, topic_id=topic.id)
    mock = start(db_client)
    put(db_client, mock["id"], 1, 1, selected_position=1, time_spent_ms=30000)
    put(db_client, mock["id"], 2, 2, selected_position=2, time_spent_ms=60000)
    url = f"{SESSIONS}/{mock['id']}/analysis"
    assert db_client.get(url).status_code == 409  # not finished
    submit(db_client, mock["id"])

    data = db_client.get(url).json()
    assert [(q["status"], q["marks"], q["time_ms"]) for q in data["questions"]] == [
        ("correct", 4, 30000),
        ("wrong", -1, 60000),
    ]
    chapter = data["chapters"][0]
    assert (chapter["subject"], chapter["name"]) == ("Physics", "Kinematics")
    assert (chapter["correct"], chapter["wrong"], chapter["time_ms"]) == (1, 1, 90000)
    assert [h["current"] for h in data["history"]] == [True]
    assert data["percentile"] is None


def test_the_history_is_the_learners_own_and_of_this_paper(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper(db_session, ONE_SECTION)
    questions(db_session, user, "Physics", 2)
    first = start(db_client)
    submit(db_client, first["id"])
    second = start(db_client)
    submit(db_client, second["id"])
    data = db_client.get(f"{SESSIONS}/{second['id']}/analysis").json()
    assert [h["session_id"] for h in data["history"]] == [first["id"], second["id"]]
    assert [h["current"] for h in data["history"]] == [False, True]


def test_another_learners_analysis_is_hidden(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    paper(db_session, ONE_SECTION)
    questions(db_session, user, "Physics", 2)
    mock = start(db_client)
    submit(db_client, mock["id"])
    db_client.headers.update(auth_headers(make_user(db_session, "other@example.com")))
    assert db_client.get(f"{SESSIONS}/{mock['id']}/analysis").status_code == 404


def test_no_percentile_without_enough_real_attempts() -> None:
    assert percentile(100, [50.0] * 99) is None
    found = percentile(100, [50.0] * 75 + [150.0] * 25)
    assert found is not None
    assert (found.percent, found.accounts) == (75, 100)


def test_the_percentile_counts_each_accounts_first_attempt_once(
    db_client: TestClient, db_session: Session, user: User, monkeypatch: pytest.MonkeyPatch
) -> None:
    paper(db_session, ONE_SECTION)
    questions(db_session, user, "Physics", 2)
    mock = start(db_client)
    put(db_client, mock["id"], 1, 1, selected_position=1)
    submit(db_client, mock["id"])
    row = db_session.get(PracticeSession, uuid.UUID(mock["id"]))
    assert row is not None
    monkeypatch.setattr(
        "app.domain.mock_analysis.mock_analysis_settings",
        lambda: {"percentile_min_accounts": 1},
    )
    data = db_client.get(f"{SESSIONS}/{mock['id']}/analysis").json()
    assert data["percentile"] == {"percent": 0, "accounts": 1}
