"""The curated question library: learners see only approved questions with settled rights, nobody
checks their own work, a correction is a new version and marks attempts again, packs send only what
changed, and difficulty and "x% got this right" come from real attempts alone."""

import uuid
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Engine, select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.database.session import get_session
from app.domain import library
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.content import ContentReport
from app.models.library import LibraryEntry, LibraryVersion
from app.models.practice import SessionAnswer
from app.models.question import QuestionFigure, Topic
from app.models.syllabus import SyllabusNode, SyllabusVersion
from app.models.user import User
from app.services.library_service import calibrate
from tests.conftest import auth_headers, make_user
from tests.test_mock_marking import _format
from tests.test_practice import answer, make_question, start
from tests.test_shared_bank import make_document

BASE = "/api/v1/library"
NEW = {
    "source_type": "original_expert",
    "rights_status": "owned",
    "difficulty": "medium",
    "exam_code": "SSC_CHSL",
    "stem": "What is 2 + 2?",
    "options": [{"label": "A", "text": "3"}, {"label": "B", "text": "4"}],
    "correct_option_position": 2,
}


@pytest.fixture
def clients(
    settings: Settings,
    db_engine: Engine,
    db_session: Session,
    storage: LocalDocumentStorage,
    tmp_path: Path,
) -> Iterator[dict[str, TestClient]]:
    """An author and a second reviewer on the content team, and a learner."""
    author = make_user(db_session, "author@example.com")
    second = make_user(db_session, "second@example.com")
    learner = make_user(db_session, "learner2@example.com")
    author.content_role = "editor"
    second.content_role = "editor"
    db_session.flush()
    app = create_app(settings, engine=db_engine, storage=storage)
    app.dependency_overrides[get_session] = lambda: db_session
    with TestClient(app, raise_server_exceptions=False) as client:
        made = {}
        for name, account in (("author", author), ("second", second), ("learner", learner)):
            one = TestClient(app, raise_server_exceptions=False, headers=auth_headers(account))
            made[name] = one
        yield made
        del client


def add(api: TestClient, **changes: Any) -> str:
    response = api.post(f"{BASE}/entries", json={**NEW, **changes})
    assert response.status_code == 201, response.text
    question_id: str = response.json()["question_id"]
    return question_id


def approved(clients: dict[str, TestClient], **changes: Any) -> str:
    question_id = add(clients["author"], **changes)
    solved = clients["second"].post(
        f"{BASE}/entries/{question_id}/solve", json={"selected_position": 2}
    )
    assert solved.json()["agrees"] is True, solved.text
    done = clients["second"].post(f"{BASE}/entries/{question_id}/approve")
    assert done.status_code == 200, done.text
    return question_id


def found(api: TestClient, **query: Any) -> list[dict[str, Any]]:
    response = api.get(f"{BASE}/search", params={"exam": "SSC_CHSL", **query})
    assert response.status_code == 200, response.text
    items: list[dict[str, Any]] = response.json()["items"]
    return items


def test_learners_can_not_use_the_review_endpoints(clients: dict[str, TestClient]) -> None:
    assert clients["learner"].post(f"{BASE}/entries", json=NEW).status_code == 403
    assert clients["learner"].get(f"{BASE}/entries").status_code == 403
    assert clients["learner"].get(f"{BASE}/reports").status_code == 403


def test_a_draft_is_hidden_until_solved_by_someone_else_and_approved(
    clients: dict[str, TestClient],
) -> None:
    question_id = add(clients["author"])
    assert found(clients["learner"]) == []

    own = clients["author"].post(
        f"{BASE}/entries/{question_id}/solve", json={"selected_position": 2}
    )
    assert own.status_code == 409
    early = clients["second"].post(f"{BASE}/entries/{question_id}/approve")
    assert early.status_code == 409

    clients["second"].post(f"{BASE}/entries/{question_id}/solve", json={"selected_position": 2})
    assert found(clients["learner"]) == []
    assert clients["author"].post(f"{BASE}/entries/{question_id}/approve").status_code == 409
    assert clients["second"].post(f"{BASE}/entries/{question_id}/approve").status_code == 200

    assert [q["question_id"] for q in found(clients["learner"])] == [question_id]


def test_a_second_solve_that_differs_leaves_it_a_draft(clients: dict[str, TestClient]) -> None:
    question_id = add(clients["author"])
    result = clients["second"].post(
        f"{BASE}/entries/{question_id}/solve", json={"selected_position": 1}
    )
    assert result.json()["agrees"] is False
    assert result.json()["entry"]["status"] == "draft"
    assert result.json()["entry"]["solved_by_name"] is None


def test_the_second_reviewer_can_not_see_the_key_before_solving(
    clients: dict[str, TestClient],
) -> None:
    question_id = add(clients["author"], explanation="Because it is.")
    url = f"{BASE}/entries/{question_id}/question"
    hidden = clients["second"].get(url).json()
    assert hidden["stem"] == NEW["stem"]
    assert hidden["correct_position"] is None
    assert hidden["explanation"] is None
    assert clients["author"].get(url).json()["correct_position"] == 2

    clients["second"].post(f"{BASE}/entries/{question_id}/solve", json={"selected_position": 2})
    assert clients["second"].get(url).json()["correct_position"] == 2


def test_pending_rights_stay_hidden_even_when_approved(clients: dict[str, TestClient]) -> None:
    question_id = approved(clients, rights_status="pending")
    assert found(clients["learner"]) == []
    response = clients["learner"].get(f"/api/v1/questions/{question_id}")
    assert response.status_code == 404

    clients["author"].put(
        f"{BASE}/entries/{question_id}/rights",
        json={"rights_status": "licensed", "rights_note": "Licence signed by the publisher."},
    )
    assert len(found(clients["learner"])) == 1
    clients["author"].put(
        f"{BASE}/entries/{question_id}/rights",
        json={"rights_status": "pending", "rights_note": "Licence under review again."},
    )
    assert found(clients["learner"]) == []


def test_only_the_staff_members_own_questions_can_enter(
    clients: dict[str, TestClient], db_session: Session
) -> None:
    """A learner's import stays private: nobody on the team can pull it into the library."""
    owner = db_session.scalar(select(User).where(User.email == "learner2@example.com"))
    assert owner is not None
    private = make_question(db_session, make_document(db_session, owner))
    response = clients["author"].post(
        f"{BASE}/entries",
        json={
            "question_id": str(private.id),
            "source_type": "official_pyq",
            "difficulty": "easy",
        },
    )
    assert response.status_code == 404
    assert db_session.get(LibraryEntry, private.id) is None


def test_an_official_question_must_come_from_a_paper(clients: dict[str, TestClient]) -> None:
    response = clients["author"].post(
        f"{BASE}/entries", json={**NEW, "source_type": "official_pyq"}
    )
    assert response.status_code == 422


def test_a_learner_practises_a_library_question_with_its_label(
    clients: dict[str, TestClient],
) -> None:
    question_id = approved(clients)
    session = start(clients["learner"], exam_code="SSC_CHSL", count=1)
    item = session["items"][0]
    assert item["question_id"] == question_id
    assert item["library_source"] == "original_expert"


def test_corrections_make_a_version_and_mark_attempts_again(
    clients: dict[str, TestClient], db_session: Session
) -> None:
    question_id = approved(clients)
    session = start(clients["learner"], exam_code="SSC_CHSL", count=1)
    assert answer(clients["learner"], session["id"], 1, 1, 1).json()["feedback"]["is_correct"] is (
        False
    )
    clients["learner"].post(f"/api/v1/practice/sessions/{session['id']}/submit")
    report = clients["learner"].post(
        "/api/v1/content-reports",
        json={
            "question_id": question_id,
            "kind": "error",
            "text": "The first option is the right one here.",
        },
    )
    assert report.status_code == 201, report.text
    queue = clients["second"].get(f"{BASE}/reports").json()
    assert [r["id"] for r in queue] == [report.json()["id"]]

    fixed = clients["second"].post(
        f"{BASE}/entries/{question_id}/correct",
        json={
            "reason": "The key was wrong.",
            "correct_option_position": 1,
            "report_id": report.json()["id"],
        },
    )
    assert fixed.status_code == 200, fixed.text
    assert fixed.json()["entry"]["version"] == 2
    assert fixed.json()["sessions_remarked"] == 1

    row = db_session.scalar(
        select(SessionAnswer).where(SessionAnswer.session_id == uuid.UUID(session["id"]))
    )
    assert row is not None
    db_session.refresh(row)
    assert row.is_correct is True
    result = clients["learner"].get(f"/api/v1/practice/sessions/{session['id']}").json()
    assert result["result"]["remarked"] is True

    versions = clients["second"].get(f"{BASE}/entries/{question_id}/versions").json()
    assert [v["version"] for v in versions] == [1, 2]
    assert versions[1]["reason"] == "The key was wrong."
    first = db_session.get(LibraryVersion, (uuid.UUID(question_id), 1))
    assert first is not None
    assert first.snapshot["correct_option_position"] == 2

    assert clients["second"].get(f"{BASE}/reports").json() == []
    closed = db_session.get(ContentReport, uuid.UUID(report.json()["id"]))
    assert closed is not None
    assert closed.status != "open"


def test_an_approved_question_changes_only_through_a_correction(
    clients: dict[str, TestClient],
) -> None:
    question_id = approved(clients)
    response = clients["author"].patch(
        f"/api/v1/questions/{question_id}", json={"correct_option_position": 1}
    )
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "library_question"


def test_a_report_on_a_hidden_question_is_refused(clients: dict[str, TestClient]) -> None:
    question_id = add(clients["author"])
    response = clients["learner"].post(
        "/api/v1/content-reports",
        json={"question_id": question_id, "kind": "error", "text": "Something looks wrong here."},
    )
    assert response.status_code == 404


def test_withdrawn_questions_leave_search(clients: dict[str, TestClient]) -> None:
    question_id = approved(clients)
    clients["author"].post(
        f"{BASE}/entries/{question_id}/withdraw", json={"reason": "Out of the syllabus."}
    )
    assert found(clients["learner"]) == []


def test_approval_needs_shared_labels(clients: dict[str, TestClient], db_session: Session) -> None:
    author = db_session.scalar(select(User).where(User.email == "author@example.com"))
    assert author is not None
    topic = Topic(owner_id=author.id, subject="Maths", name="Private topic", keywords=[])
    db_session.add(topic)
    db_session.flush()
    question_id = add(clients["author"], topic_id=str(topic.id))
    clients["second"].post(f"{BASE}/entries/{question_id}/solve", json={"selected_position": 2})
    response = clients["second"].post(f"{BASE}/entries/{question_id}/approve")
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "library_private_label"


def _unit(db: Session, exam: str, subject: str, unit: str, topic: Topic) -> None:
    version = SyllabusVersion(
        exam_code=exam, name="Test list", effective_year=2026, source_kind="manual"
    )
    db.add(version)
    db.flush()
    root = SyllabusNode(version_id=version.id, position=1, name=subject, level_label="Subject")
    db.add(root)
    db.flush()
    middle = SyllabusNode(
        version_id=version.id, parent_id=root.id, position=1, name=unit, level_label="Unit"
    )
    db.add(middle)
    db.flush()
    db.add(
        SyllabusNode(
            version_id=version.id,
            parent_id=middle.id,
            position=1,
            name=topic.name,
            level_label="Topic",
            topic_id=topic.id,
        )
    )
    db.flush()


def test_search_filters(clients: dict[str, TestClient], db_session: Session) -> None:
    topic = Topic(subject="Maths", name="Library sums", keywords=[])
    db_session.add(topic)
    db_session.flush()
    _unit(db_session, "SSC_CHSL", "Maths", "Arithmetic", topic)
    wanted = approved(clients, topic_id=str(topic.id), exam_year=2024, difficulty="hard")
    approved(clients, stem="What is the capital of France?", difficulty="easy", exam_year=2020)

    learner = clients["learner"]
    assert [q["question_id"] for q in found(learner, topic_id=str(topic.id))] == [wanted]
    assert [q["question_id"] for q in found(learner, unit="Arithmetic")] == [wanted]
    assert [q["question_id"] for q in found(learner, year=2024)] == [wanted]
    assert [q["question_id"] for q in found(learner, difficulty="hard")] == [wanted]
    assert [q["question_id"] for q in found(learner, q="2 + 2")] == [wanted]
    assert found(learner, format="match") == []
    assert "correct_option_position" not in found(learner, year=2024)[0]


def test_packs_send_only_what_changed(clients: dict[str, TestClient], db_session: Session) -> None:
    topic = Topic(subject="Maths", name="Pack sums", keywords=[])
    db_session.add(topic)
    db_session.flush()
    _unit(db_session, "SSC_CHSL", "Maths", "Arithmetic", topic)
    first = approved(clients, topic_id=str(topic.id))
    db_session.add(
        QuestionFigure(
            question_id=uuid.UUID(first),
            kind="stem",
            page_number=1,
            width=1,
            height=1,
            data=b"png",
            content_type="image/png",
            source="reviewer",
            sort_order=1,
            box=[0, 0, 1, 1],
        )
    )
    db_session.flush()
    second = approved(clients, topic_id=str(topic.id), stem="What is 3 + 3?")
    learner = clients["learner"]

    packs = learner.get(f"{BASE}/packs", params={"exam": "SSC_CHSL"}).json()
    assert [(p["name"], p["subject"], p["questions"]) for p in packs] == [
        ("Arithmetic", "Maths", 2)
    ]
    url = f"{BASE}/packs/{packs[0]['key']}"
    full = learner.get(url, params={"exam": "SSC_CHSL"}).json()
    assert {q["id"] for q in full["questions"]} == {first, second}
    assert all(q["correct_position"] == 2 for q in full["questions"])
    assert len(full["figures"]) == 1

    same = learner.get(url, params={"exam": "SSC_CHSL", "since": full["seq"]}).json()
    assert same["questions"] == []
    assert same["removed"] == []

    clients["second"].post(
        f"{BASE}/entries/{first}/correct",
        json={"reason": "Clearer wording.", "stem": "Work out 2 + 2."},
    )
    clients["second"].post(
        f"{BASE}/entries/{second}/withdraw", json={"reason": "Out of the syllabus."}
    )
    delta = learner.get(url, params={"exam": "SSC_CHSL", "since": full["seq"]}).json()
    assert [q["stem"] for q in delta["questions"]] == ["Work out 2 + 2."]
    assert delta["removed"] == [second]
    assert delta["seq"] > full["seq"]
    assert (
        learner.get(f"{BASE}/packs", params={"exam": "SSC_CHSL"}).json()[0]["seq"] > packs[0]["seq"]
    )


def test_a_chapter_left_empty_stays_listed_so_devices_update(
    clients: dict[str, TestClient],
) -> None:
    only = approved(clients)
    learner = clients["learner"]
    before = learner.get(f"{BASE}/packs", params={"exam": "SSC_CHSL"}).json()
    clients["second"].post(
        f"{BASE}/entries/{only}/withdraw", json={"reason": "Out of the syllabus."}
    )
    after = learner.get(f"{BASE}/packs", params={"exam": "SSC_CHSL"}).json()
    assert after[0]["questions"] == 0
    assert after[0]["seq"] > before[0]["seq"]
    delta = learner.get(
        f"{BASE}/packs/{after[0]['key']}", params={"exam": "SSC_CHSL", "since": before[0]["seq"]}
    ).json()
    assert delta["removed"] == [only]


def test_levels_move_only_on_enough_real_attempts() -> None:
    assert library.calibrated(199, 199, None, None) is None
    assert library.calibrated(200, 180, None, None) == "easy"
    assert library.calibrated(200, 100, None, None) == "medium"
    assert library.calibrated(200, 20, None, None) == "hard"
    # Right often, but far slower than the paper allows: one level harder.
    assert library.calibrated(200, 180, 120_000, 40) == "medium"
    assert library.calibrated(200, 20, 120_000, 40) == "hard"
    assert library.shown_level("hard", None) == "hard"
    assert library.shown_level("hard", "easy") == "easy"


def test_percent_right_needs_real_attempts() -> None:
    assert library.percent_right(0, 0) is None
    assert library.percent_right(29, 29) is None
    assert library.percent_right(30, 15) == 50


def test_median() -> None:
    assert library.median([]) is None
    assert library.median([5, 1, 3]) == 3
    assert library.median([1, 3]) == 2


def test_calibration_counts_real_answers(
    clients: dict[str, TestClient], db_session: Session
) -> None:
    question_id = approved(clients)
    session = start(clients["learner"], exam_code="SSC_CHSL", count=1)
    answer(clients["learner"], session["id"], 1, 2, 1)

    assert calibrate(db_session) == 0  # counted, but too few to move the level
    entry = db_session.get(LibraryEntry, uuid.UUID(question_id))
    assert entry is not None
    assert (entry.attempts, entry.correct_count) == (1, 1)
    assert entry.observed_difficulty is None

    hit = found(clients["learner"])[0]
    assert hit["percent_right"] is None
    assert hit["difficulty"] == "medium"

    entry.attempts, entry.correct_count, entry.observed_difficulty = 300, 270, "easy"
    db_session.flush()
    hit = found(clients["learner"])[0]
    assert hit["percent_right"] == 90
    assert hit["difficulty"] == "easy"


def test_ai_checked_questions_never_reach_a_mock(
    clients: dict[str, TestClient], db_session: Session
) -> None:
    _format(
        db_session,
        [{"part": "1", "subject": "Maths", "questions": 1, "max_marks": 4}],
        question_types=["choice"],
        negative_marks_per_wrong=0,
    )
    topic = Topic(subject="Maths", name="Mock sums", keywords=[])
    db_session.add(topic)
    db_session.flush()
    where = {"exam_code": "MARKED", "topic_id": str(topic.id)}
    checked = approved(clients, source_type="original_ai_verified", **where)
    learner = clients["learner"]
    practice = start(learner, exam_code="MARKED", count=1)
    assert practice["items"][0]["question_id"] == checked
    assert practice["items"][0]["library_source"] == "original_ai_verified"

    mock = {"exam_format_code": "MARKED_2026"}
    assert learner.post("/api/v1/practice/mock-tests", json=mock).status_code == 422

    written = approved(clients, stem="What is 5 + 5?", **where)
    started = learner.post("/api/v1/practice/mock-tests", json=mock)
    assert started.status_code == 201, started.text
    assert [i["question_id"] for i in started.json()["items"]] == [written]
