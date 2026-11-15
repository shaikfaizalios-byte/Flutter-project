"""Compensatory time for candidates with disabilities: only as a verified format states it, added
to the whole paper and to each timed section when the learner declares it applies to them."""

from datetime import datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.compensatory import compensatory_problems, compensatory_rule
from app.models.question import ExamFormat
from app.models.user import User
from tests.test_practice import Clock  # noqa: F401
from tests.test_sectional_mock import api, cgl_mock, clock  # noqa: F401  (fixtures)

RULE = {"minutes_per_hour": 20, "reference": "Sample notice, para 1"}


def test_the_rule_comes_whole_from_the_format_or_not_at_all() -> None:
    rule = compensatory_rule({"compensatory_time": RULE})
    assert rule is not None and rule.extra_minutes(60) == 20 and rule.extra_minutes(15) == 5
    assert rule.extra_minutes(25) == 9  # 8.33 rounded up
    assert compensatory_rule(None) is None and compensatory_rule({}) is None
    for broken in (
        {"minutes_per_hour": 20},
        {"minutes_per_hour": 0, "reference": "x"},
        {"minutes_per_hour": "20", "reference": "x"},
        {"minutes_per_hour": 61, "reference": "x"},
    ):
        assert compensatory_rule({"compensatory_time": broken}) is None
        assert compensatory_problems({"compensatory_time": broken})
    assert compensatory_problems({"compensatory_time": RULE}) == []
    assert compensatory_problems({}) == []


def _cgl(db: Session) -> ExamFormat:
    row = db.scalars(select(ExamFormat).where(ExamFormat.code == "SSC_CGL_2026_TIER1")).one()
    return row


def test_a_format_without_a_rule_offers_none(
    api: TestClient,  # noqa: F811
    cgl_mock: dict[str, Any],  # noqa: F811
) -> None:
    listed = api.get("/api/v1/practice/mock-tests").json()
    cgl = next(m for m in listed if m["exam_format_code"] == "SSC_CGL_2026_TIER1")
    assert cgl["compensatory_minutes_per_hour"] is None
    refused = api.post(
        "/api/v1/practice/mock-tests",
        json={"exam_format_code": "SSC_CGL_2026_TIER1", "compensatory_time": True},
    )
    assert refused.status_code == 409
    assert refused.json()["error"]["code"] == "no_compensatory_rule"
    assert cgl_mock["compensatory_minutes"] is None


def test_declared_compensatory_time_extends_the_paper_and_each_section(
    api: TestClient,  # noqa: F811
    cgl_mock: dict[str, Any],  # noqa: F811
    db_session: Session,
    user: User,
) -> None:
    fmt = _cgl(db_session)
    fmt.conduct = {**(fmt.conduct or {}), "compensatory_time": RULE}
    db_session.flush()
    listed = api.get("/api/v1/practice/mock-tests").json()
    cgl = next(m for m in listed if m["exam_format_code"] == "SSC_CGL_2026_TIER1")
    assert cgl["compensatory_minutes_per_hour"] == 20
    assert cgl["compensatory_reference"] == "Sample notice, para 1"

    plain = cgl_mock
    extended = api.post(
        "/api/v1/practice/mock-tests",
        json={"exam_format_code": "SSC_CGL_2026_TIER1", "compensatory_time": True},
    )
    assert extended.status_code == 201, extended.text
    body = extended.json()
    assert body["compensatory_minutes"] == 20  # 60 minutes x 20 per hour

    def minutes(session: dict[str, Any]) -> float:
        start = datetime.fromisoformat(session["started_at"])
        return (datetime.fromisoformat(session["deadline_at"]) - start).total_seconds() / 60

    assert minutes(body) == minutes(plain) + 20
    assert [s["minutes"] for s in body["sections"]] == [20, 20, 20, 20]  # 15 + 5 each
    assert [s["minutes"] for s in plain["sections"]] == [15, 15, 15, 15]


@pytest.mark.parametrize("value", [{"minutes_per_hour": 20}, {"reference": "x"}])
def test_publishing_refuses_an_incomplete_rule(value: dict[str, Any], db_session: Session) -> None:
    from app.services.exam_formats import publish_problems

    fmt = _cgl(db_session)
    fmt.conduct = {**(fmt.conduct or {}), "compensatory_time": value}
    assert any("Compensatory time" in p for p in publish_problems(fmt))
