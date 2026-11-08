"""Scale: signed figure links a CDN can cache, attempt events, calibration that reads only what
changed, and the cached chapter list."""

import uuid
from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain import media
from app.models.events import AttemptEvent, JobCursor
from app.models.library import LibraryEntry
from app.models.question import QuestionFigure
from app.models.user import User
from app.services.attempt_events import backfill
from app.services.library_service import calibrate
from app.services.media import figure_url
from tests.conftest import auth_headers, make_user
from tests.test_practice import answer, make_question, start
from tests.test_shared_bank import make_document

KEY = b"k" * 32
SHA = "a" * 64


def test_links_last_one_to_two_windows_and_are_shared_within_one() -> None:
    hour = 3600
    first = media.window_expiry(10 * hour + 5, 24)
    assert first == media.window_expiry(23 * hour, 24)  # same link all day
    assert 24 * hour <= first - 10 * hour <= 48 * hour


def test_a_signature_holds_only_for_its_figure_and_time() -> None:
    sig = media.signature(SHA, 1000, KEY)
    assert media.valid(SHA, 1000, sig, KEY, now=999)
    assert not media.valid(SHA, 1000, sig, KEY, now=1001)  # expired
    assert not media.valid("b" * 64, 1000, sig, KEY, now=999)
    assert not media.valid(SHA, 2000, sig, KEY, now=999)
    assert not media.valid(SHA, 1000, sig, b"other" * 8, now=999)
    assert not media.valid("../etc", 1000, sig, KEY, now=999)


def test_a_cache_never_keeps_a_figure_past_its_link() -> None:
    assert media.cache_seconds(1100, 1000, 86400) == 100
    assert media.cache_seconds(10**9, 0, 86400) == 86400
    assert media.cache_seconds(900, 1000, 86400) == 0


def figure(db: Session, question_id: uuid.UUID, data: bytes = b"\x89PNG one") -> QuestionFigure:
    row = QuestionFigure(
        question_id=question_id,
        kind="stem",
        sort_order=1,
        page_number=1,
        box=[0, 0, 1, 1],
        width=10,
        height=10,
        data=data,
        source="pdf",
    )
    db.add(row)
    db.flush()
    return row


def shared_question(db: Session) -> Any:
    owner = make_user(db, "operator@example.com")
    document = make_document(db, owner)
    document.shared_at = document.created_at
    document.shared_source = "Official paper"
    document.shared_rights_basis = "Published for study."
    question = make_question(db, document)
    db.flush()
    return question


def test_shared_figures_get_a_link_anyone_can_fetch(
    db_client: TestClient, db_session: Session
) -> None:
    question = shared_question(db_session)
    row = figure(db_session, question.id)
    assert row.sha256 is not None and len(row.sha256) == 64

    read = db_client.get(f"/api/v1/questions/{question.id}").json()
    url = read["figures"][0]["url"]
    assert url.startswith(f"/api/v1/media/figures/{row.sha256}.png?e=")

    anonymous = TestClient(db_client.app)
    response = anonymous.get(url)
    assert response.status_code == 200
    assert response.content == b"\x89PNG one"
    assert response.headers["cache-control"].startswith("public, max-age=")
    assert "immutable" in response.headers["cache-control"]

    tampered = url.replace("&s=", "&s=0")
    assert anonymous.get(tampered).status_code == 404


def test_a_learners_own_figures_get_no_public_link(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    question = make_question(db_session, make_document(db_session, user))
    figure(db_session, question.id, b"\x89PNG private")
    read = db_client.get(f"/api/v1/questions/{question.id}").json()
    assert read["figures"][0]["url"] is None


def test_an_expired_link_is_refused(db_client: TestClient, db_session: Session) -> None:
    question = shared_question(db_session)
    row = figure(db_session, question.id)
    assert row.sha256 is not None
    old = figure_url(row.sha256, now=0)
    assert TestClient(db_client.app).get(old).status_code == 404


# --- attempt events -------------------------------------------------------------------------


def events(db: Session, **where: Any) -> list[AttemptEvent]:
    stmt = select(AttemptEvent).order_by(AttemptEvent.id)
    for key, value in where.items():
        stmt = stmt.where(getattr(AttemptEvent, key) == value)
    return list(db.scalars(stmt))


def test_a_practice_answer_is_an_event_at_once(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    make_question(db_session, make_document(db_session, user))
    session = start(db_client, exam_code="SSC_CHSL", count=1)
    answer(db_client, session["id"], 1, 1, 1)
    found = events(db_session, session_id=uuid.UUID(session["id"]))
    assert [(e.kind, e.correct, e.owner_id) for e in found] == [("final", True, user.id)]


def test_a_tests_answers_become_events_when_it_is_submitted(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    from tests import test_cbt_mocks as cbt

    cbt.paper(db_session, cbt.ONE_SECTION)
    cbt.questions(db_session, user, "Physics", 2)
    mock = cbt.start(db_client)
    cbt.put(db_client, mock["id"], 1, 1, selected_position=2)
    cbt.put(db_client, mock["id"], 1, 2, selected_position=1)  # changed: not an event yet
    assert events(db_session, session_id=uuid.UUID(mock["id"])) == []
    cbt.submit(db_client, mock["id"])
    found = events(db_session, session_id=uuid.UUID(mock["id"]))
    assert [(e.kind, e.correct, e.exam_code) for e in found] == [("final", True, cbt.EXAM)]


def test_a_key_change_writes_what_it_was_and_what_it_is(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    question = make_question(db_session, make_document(db_session, user))
    session = start(db_client, exam_code="SSC_CHSL", count=1)
    answer(db_client, session["id"], 1, 2, 1)
    response = db_client.put(
        f"/api/v1/questions/{question.id}/answer-key",
        json={"stage": "final", "outcome": "one", "correct_option_position": 2},
    )
    assert response.status_code == 200, response.text
    found = events(db_session, question_id=question.id)
    assert [(e.kind, e.was_correct, e.correct) for e in found] == [
        ("final", None, False),
        ("remarked", False, True),
    ]


def test_answers_from_before_events_are_written_once(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    make_question(db_session, make_document(db_session, user))
    session = start(db_client, exam_code="SSC_CHSL", count=1)
    answer(db_client, session["id"], 1, 1, 1)
    for row in events(db_session):
        db_session.delete(row)  # as if answered before events existed
    db_session.flush()
    assert backfill(db_session) == 1
    assert backfill(db_session) == 0


def test_calibration_reads_only_what_changed(
    db_client: TestClient, db_session: Session, user: User, monkeypatch: Any
) -> None:
    from tests.test_library import approved

    editor = make_user(db_session, "author@example.com")
    second = make_user(db_session, "second@example.com")
    editor.content_role = second.content_role = "editor"
    db_session.flush()
    clients = {
        "author": TestClient(db_client.app, headers=auth_headers(editor)),
        "second": TestClient(db_client.app, headers=auth_headers(second)),
    }
    question_id = uuid.UUID(approved(clients))
    session = start(db_client, exam_code="SSC_CHSL", count=1)
    answer(db_client, session["id"], 1, 2, 1)

    calibrate(db_session)
    entry = db_session.get(LibraryEntry, question_id)
    assert entry is not None
    assert (entry.attempts, entry.correct_count) == (1, 1)
    cursor = db_session.get(JobCursor, "calibration")
    assert cursor is not None and cursor.last_id > 0

    looked: list[uuid.UUID] = []

    def spy(session: Session, question: uuid.UUID) -> list[tuple[bool, int | None]]:
        looked.append(question)
        return []

    monkeypatch.setattr("app.services.library_service.attempts_of", spy)
    calibrate(db_session)
    assert looked == []  # nothing new since the last run


def test_the_chapter_list_follows_library_changes(
    db_client: TestClient, db_session: Session
) -> None:
    from tests.test_library import approved

    editor = make_user(db_session, "author@example.com")
    second = make_user(db_session, "second@example.com")
    editor.content_role = second.content_role = "editor"
    db_session.flush()
    clients = {
        "author": TestClient(db_client.app, headers=auth_headers(editor)),
        "second": TestClient(db_client.app, headers=auth_headers(second)),
    }
    url = "/api/v1/library/packs"
    assert db_client.get(url, params={"exam": "SSC_CHSL"}).json() == []
    approved(clients)
    listed = db_client.get(url, params={"exam": "SSC_CHSL"}).json()
    assert [p["questions"] for p in listed] == [1]


def test_load_test_data_never_goes_near_production() -> None:
    from app.cli.load_seed import _refuse
    from app.core.config import Environment

    assert _refuse(Environment.PRODUCTION, "postgresql://h/preploop_test") is not None
    assert _refuse(Environment.STAGING, "postgresql://h/preploop_test") is not None
    assert _refuse(Environment.DEVELOPMENT, "postgresql://h/preploop") is not None
    assert _refuse(Environment.DEVELOPMENT, "postgresql://h/preploop_test") is None
