"""Progress analytics over recorded answers (real PostgreSQL, timezone-aware days)."""

import uuid
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.api.v1.endpoints.analytics import get_analytics_service
from app.core.config import Settings
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.document import Document
from app.models.question import Topic
from app.schemas.practice import AnswerUpdate, MockCreate, PracticeCreate
from app.services.analytics_service import AnalyticsService
from app.services.practice_service import PracticeService
from tests.test_practice import Clock, document, make_formats_ready, make_question

__all__ = ["document"]  # fixture re-used from test_practice

# 12 Oct 2026, 19:00 UTC = 13 Oct 00:30 in India (IST, +05:30).
LATE_EVENING_UTC = datetime(2026, 10, 12, 19, 0, tzinfo=UTC)


@pytest.fixture
def clock() -> Clock:
    c = Clock()
    c.now = LATE_EVENING_UTC
    return c


@pytest.fixture
def api(
    settings: Settings,
    db_engine: Any,
    db_session: Session,
    storage: LocalDocumentStorage,
    clock: Clock,
) -> Iterator[TestClient]:
    from app.database.session import get_session

    app = create_app(settings, engine=db_engine, storage=storage)
    app.dependency_overrides[get_session] = lambda: db_session
    app.dependency_overrides[get_analytics_service] = lambda: AnalyticsService(
        db_session, now=clock
    )
    with TestClient(app, raise_server_exceptions=False) as client:
        yield client


def overview(api: TestClient, tz: str = "Asia/Kolkata", **params: Any) -> dict[str, Any]:
    response = api.get("/api/v1/analytics/overview", params={"timezone": tz, **params})
    assert response.status_code == 200, response.text
    data: dict[str, Any] = response.json()
    return data


def topic(db: Session, subject: str, name: str) -> Topic:
    row = Topic(subject=subject, name=name, keywords=[])
    db.add(row)
    db.flush()
    return row


def practise(
    db: Session,
    clock: Clock,
    topic_row: Topic,
    selections: list[int | None],
) -> uuid.UUID:
    """Starts a practice session on [topic_row] and answers in order (option 1 is right)."""
    service = PracticeService(db, now=clock)
    session = service.start_practice(PracticeCreate(topic_id=topic_row.id, count=len(selections)))
    for position, selected in enumerate(selections, start=1):
        service.answer(
            session.id, position, AnswerUpdate(selected_position=selected, client_seq=position)
        )
    return session.id


def test_no_data_is_reported_as_zero_not_invented(api: TestClient) -> None:
    data = overview(api)

    assert data["today"] == "2026-10-13"  # local date in India
    assert (data["answered"], data["correct"], data["sessions"]) == (0, 0, 0)
    assert data["subjects"] == data["topics"] == data["daily"] == data["mocks"] == []


def test_counts_per_subject_and_topic(
    api: TestClient, db_session: Session, document: Document, clock: Clock
) -> None:
    pct = topic(db_session, "Quantitative Aptitude", "Analytics Percentage")
    syn = topic(db_session, "English Language", "Analytics Synonyms")
    for _ in range(4):
        make_question(db_session, document, topic=pct)
    for _ in range(2):
        make_question(db_session, document, subject="English Language", topic=syn)

    practise(db_session, clock, pct, [1, 1, 2, None])  # 2 right, 1 wrong, 1 unanswered
    practise(db_session, clock, syn, [3, 1])

    data = overview(api)
    assert (data["answered"], data["correct"], data["sessions"]) == (5, 3, 2)
    subjects = {s["name"]: s for s in data["subjects"]}
    assert (
        subjects["Quantitative Aptitude"]["answered"],
        subjects["Quantitative Aptitude"]["correct"],
    ) == (3, 2)
    assert (subjects["English Language"]["answered"], subjects["English Language"]["correct"]) == (
        2,
        1,
    )
    topics = {t["name"]: t for t in data["topics"]}
    assert topics["Analytics Percentage"]["subject"] == "Quantitative Aptitude"
    assert topics["Analytics Percentage"]["topic_id"] == str(pct.id)
    assert (topics["Analytics Synonyms"]["answered"], topics["Analytics Synonyms"]["correct"]) == (
        2,
        1,
    )


def test_days_follow_the_learners_timezone(
    api: TestClient, db_session: Session, document: Document, clock: Clock
) -> None:
    pct = topic(db_session, "Quantitative Aptitude", "Analytics Boundary")
    make_question(db_session, document, topic=pct)
    practise(db_session, clock, pct, [1])  # 19:00 UTC on 12 Oct

    india = overview(api, "Asia/Kolkata")
    utc = overview(api, "UTC")

    assert india["daily"] == [{"date": "2026-10-13", "answered": 1, "correct": 1}]
    assert utc["daily"] == [{"date": "2026-10-12", "answered": 1, "correct": 1}]
    assert (india["today"], utc["today"]) == ("2026-10-13", "2026-10-12")


def test_recent_window_and_daily_range(
    api: TestClient, db_session: Session, document: Document, clock: Clock
) -> None:
    pct = topic(db_session, "Quantitative Aptitude", "Analytics Trend")
    for _ in range(3):
        make_question(db_session, document, topic=pct)

    clock.now = LATE_EVENING_UTC - timedelta(days=20)
    practise(db_session, clock, pct, [2, 2])  # old, wrong
    clock.now = LATE_EVENING_UTC
    practise(db_session, clock, pct, [1])  # recent, right

    data = overview(api, recent_days=14, days=7)
    row = data["topics"][0]
    assert (row["answered"], row["correct"]) == (3, 1)
    assert (row["recent_answered"], row["recent_correct"]) == (1, 1)
    assert [d["date"] for d in data["daily"]] == ["2026-10-13"]  # the old day is outside 7 days


def test_mock_answers_count_only_after_submission(
    api: TestClient, db_session: Session, document: Document, clock: Clock
) -> None:
    make_formats_ready(db_session, document)
    service = PracticeService(db_session, now=clock)
    mock = service.start_mock(MockCreate(exam_format_code="SSC_CHSL_2026_TIER1"))
    service.answer(mock.id, 1, AnswerUpdate(selected_position=1, client_seq=1))
    service.answer(mock.id, 2, AnswerUpdate(selected_position=2, client_seq=2))

    before = overview(api)
    assert before["answered"] == 0
    assert before["mocks"] == []

    clock.now = LATE_EVENING_UTC + timedelta(minutes=5)
    service.submit(mock.id)
    after = overview(api)

    assert (after["answered"], after["correct"]) == (2, 1)
    result = after["mocks"][0]
    assert result["exam_format_code"] == "SSC_CHSL_2026_TIER1"
    assert (result["score"], result["max_score"]) == (1.5, 200.0)
    assert result["local_date"] == "2026-10-13"
    assert "13.8" in result["marking_note"]  # cites the official source


def test_timezone_is_required_and_validated(api: TestClient) -> None:
    missing = api.get("/api/v1/analytics/overview")
    assert missing.status_code == 422

    bad = api.get("/api/v1/analytics/overview", params={"timezone": "Mars/Olympus"})
    assert bad.status_code == 422
    assert bad.json()["error"]["code"] == "invalid_timezone"

    too_many = api.get("/api/v1/analytics/overview", params={"timezone": "UTC", "days": 400})
    assert too_many.status_code == 422
