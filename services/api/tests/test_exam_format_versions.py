"""Exam formats as versions: review before use, effective dates, retiring, and catalog exams
added by configuration (global Phase 5)."""

from datetime import date, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.cli.exam_formats import import_format, publish, retire, set_exam
from app.domain.exam_format import config_problems, in_effect
from app.models.exam import Exam
from app.models.question import ExamFormat

TODAY = date.today()


def config(**changes: Any) -> list[str]:
    fields: dict[str, Any] = {
        "sections": [{"subject": "A", "timer_minutes": 15}, {"subject": "B", "timer_minutes": 15}],
        "duration_minutes": 30,
        "sections_in_fixed_order": True,
        "sectional_timing": True,
        "question_types": ["choice"],
        "effective_from": None,
        "effective_to": None,
        "source_title": "Notice",
        "source_url": "https://example.gov/notice.pdf",
        "source_reference": "para 1",
    }
    fields.update(changes)
    return config_problems(**fields)


def test_publishing_needs_consistent_timers_types_dates_and_a_source() -> None:
    assert config() == []
    assert "The section timers do not add up to the duration." in config(duration_minutes=40)
    assert "Sectional timing needs a timer for every section." in config(
        sections=[{"subject": "A", "timer_minutes": 15}, {"subject": "B"}]
    )
    assert "Sectionally timed sections must be taken in a fixed order." in config(
        sections_in_fixed_order=False
    )
    assert "Question types must be among: choice, typed." in config(question_types=["multi"])
    assert "The format ends before it starts." in config(
        effective_from=date(2027, 1, 2), effective_to=date(2027, 1, 1)
    )
    assert "The official source URL must be https." in config(source_url="http://x")
    assert "The official source has no reference." in config(source_reference=" ")


def test_in_effect_needs_verified_and_the_dates() -> None:
    def check(status: str = "verified", start: int | None = None, end: int | None = None) -> bool:
        return in_effect(
            status=status,
            effective_from=TODAY + timedelta(days=start) if start is not None else None,
            effective_to=TODAY + timedelta(days=end) if end is not None else None,
            today=TODAY,
        )

    assert check() and check(start=0, end=0)
    assert not check(status="draft") and not check(status="retired")
    assert not check(start=1) and not check(end=-1)


def test_recorded_formats_became_verified_versions(db_session: Session) -> None:
    formats = {f.code: f for f in db_session.scalars(select(ExamFormat)).all()}
    cgl, chsl = formats["SSC_CGL_2026_TIER1"], formats["SSC_CHSL_2026_TIER1"]
    assert (cgl.status, chsl.status) == ("verified", "verified")
    assert cgl.reviewed_by and chsl.reviewed_by
    assert (cgl.sectional_timing, chsl.sectional_timing) == (True, False)
    assert cgl.question_types == ["choice"]
    cgl_exam = db_session.get(Exam, "SSC_CGL")
    assert cgl_exam is not None
    assert (cgl_exam.country_code, cgl_exam.authority) == ("IN", None)  # authority not guessed


def draft_data(**changes: Any) -> dict[str, Any]:
    data: dict[str, Any] = {
        "code": "SSC_CHSL_2027_TIER1",
        "exam_code": "SSC_CHSL",
        "tier": "Tier-I",
        "name": "SSC CHSL 2027 Tier-I",
        "sections": [{"part": "I", "subject": "General Awareness", "questions": 1, "max_marks": 2}],
        "sections_in_fixed_order": False,
        "total_questions": 1,
        "duration_minutes": 60,
        "negative_marks_per_wrong": None,
        "supersedes": "SSC_CHSL_2026_TIER1",
        "effective_from": (TODAY + timedelta(days=10)).isoformat(),
        "source": {
            "title": "Test notice",
            "url": "https://example.gov/notice.pdf",
            "reference": "para 1",
            "published_on": "2026-10-01",
        },
    }
    data.update(changes)
    return data


def test_a_draft_is_hidden_until_a_reviewer_publishes_it(
    db_client: TestClient, db_session: Session
) -> None:
    draft, problems = import_format(db_session, draft_data())

    assert draft.status == "draft"
    assert problems == ["The format does not state its negative marking (0 if there is none)."]
    listed = db_client.get("/api/v1/exam-formats", params={"exam": "SSC_CHSL"}).json()
    assert [f["code"] for f in listed] == ["SSC_CHSL_2026_TIER1"]
    mocks = db_client.get("/api/v1/practice/mock-tests", params={"exam": "SSC_CHSL"}).json()
    assert [m["exam_format_code"] for m in mocks] == ["SSC_CHSL_2026_TIER1"]
    started = db_client.post(
        "/api/v1/practice/mock-tests", json={"exam_format_code": "SSC_CHSL_2027_TIER1"}
    )
    assert started.status_code == 422
    with pytest.raises(ValueError, match="negative marking"):
        publish(db_session, draft.code, "Reviewer", TODAY)
    with pytest.raises(ValueError, match="already exists"):
        import_format(db_session, draft_data())


def test_publishing_a_new_version_ends_the_old_one_when_the_new_one_starts(
    db_client: TestClient, db_session: Session
) -> None:
    import_format(db_session, draft_data(negative_marks_per_wrong=0.5))
    with pytest.raises(ValueError, match="reviewer"):
        publish(db_session, "SSC_CHSL_2027_TIER1", " ", TODAY)

    new = publish(db_session, "SSC_CHSL_2027_TIER1", "A. Reviewer", TODAY)
    db_session.flush()

    old = db_session.scalar(select(ExamFormat).where(ExamFormat.code == "SSC_CHSL_2026_TIER1"))
    assert old is not None
    assert (new.status, new.reviewed_by, new.verified_on) == ("verified", "A. Reviewer", TODAY)
    assert old.effective_to == TODAY + timedelta(days=9)
    listed = {
        f["code"]: f
        for f in db_client.get("/api/v1/exam-formats", params={"exam": "SSC_CHSL"}).json()
    }
    assert listed["SSC_CHSL_2027_TIER1"]["effective_from"] == str(TODAY + timedelta(days=10))
    # Only the version in effect today is offered for a new mock.
    mocks = db_client.get("/api/v1/practice/mock-tests", params={"exam": "SSC_CHSL"}).json()
    assert [m["exam_format_code"] for m in mocks] == ["SSC_CHSL_2026_TIER1"]
    with pytest.raises(ValueError, match="only drafts"):
        publish(db_session, "SSC_CHSL_2027_TIER1", "Again", TODAY)


def test_retiring_stops_new_mocks_but_keeps_the_format_readable(
    db_client: TestClient, db_session: Session
) -> None:
    retire(db_session, "SSC_CHSL_2026_TIER1", TODAY - timedelta(days=1))
    db_session.flush()

    mocks = db_client.get("/api/v1/practice/mock-tests", params={"exam": "SSC_CHSL"}).json()
    listed = db_client.get("/api/v1/exam-formats", params={"exam": "SSC_CHSL"}).json()
    assert mocks == []
    assert [(f["code"], f["status"]) for f in listed] == [("SSC_CHSL_2026_TIER1", "retired")]


def _set(session: Session, code: str, **values: Any) -> Exam:
    fields: dict[str, Any] = dict.fromkeys(
        ("name", "short_name", "category", "country", "authority", "aliases")
    )
    fields.update(values)
    return set_exam(session, code, **fields)


def test_catalog_exams_are_added_and_described_by_configuration(
    db_client: TestClient, db_session: Session
) -> None:
    _set(
        db_session,
        "TEST_EXAM",
        name="Test Board Exam",
        short_name="TBE",
        category="Test",
        country="GB",
        authority="Test Board",
        aliases=["TBE exam"],
    )
    _set(db_session, "SSC_CGL", authority="Recorded authority")
    db_session.flush()

    exams = {e["code"]: e for e in db_client.get("/api/v1/exams").json()}
    assert (exams["TEST_EXAM"]["country_code"], exams["TEST_EXAM"]["aliases"]) == (
        "GB",
        ["TBE exam"],
    )
    assert (exams["SSC_CGL"]["authority"], exams["SSC_CGL"]["country_code"]) == (
        "Recorded authority",
        "IN",
    )
    with pytest.raises(ValueError, match="ISO 3166"):
        _set(db_session, "TEST_EXAM", country="India")
    with pytest.raises(ValueError, match="needs --name"):
        _set(db_session, "ANOTHER")
    with pytest.raises(ValueError, match="MY_"):
        _set(db_session, "MY_EXAM", name="Mine")
