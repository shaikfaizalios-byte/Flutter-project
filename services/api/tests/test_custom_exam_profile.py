"""Learners describe their own exams; operators apply templates only when they're sourced."""

import json
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.cli.exam_formats import FormatFile, TemplateFile, apply_template, template_problems
from app.domain.exam_profile import DEFAULTS_FILE, FORMATS_DIR, TEMPLATES_DIR
from app.models.exam import Exam
from app.models.user import User
from tests.conftest import auth_headers, make_user

STAGE = {
    "name": "Written test",
    "duration_minutes": 120,
    "sections": [
        {"name": "Part A", "question_count": 50, "duration_minutes": 60, "cutoff": 20},
        {"name": "Part B", "question_count": 50},
    ],
    "marking_scheme": {"marks_correct": 2, "marks_wrong": 0.5},
}


def _create(client: TestClient, **body: Any) -> dict[str, Any]:
    response = client.post("/api/v1/me/exams", json={"name": "My board exam", **body})
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


def test_a_name_alone_still_makes_an_exam_with_the_defaults(db_client: TestClient) -> None:
    exam = _create(db_client)
    assert exam["custom"] is True
    assert exam["profile"]["options_per_question"] == 4
    assert exam["profile"]["min_papers"] == 3
    assert db_client.get(f"/api/v1/me/exams/{exam['code']}/stages").json() == []


def test_a_learner_describes_their_exam(db_client: TestClient) -> None:
    exam = _create(
        db_client,
        conducting_body="State Board",
        kind="mixed",
        options_per_question=5,
        languages=["en", "ta"],
        exam_dates=["2027-03-14"],
        stages=[STAGE],
        counting_unit="session",
    )
    assert exam["authority"] == "State Board"
    assert exam["languages"] == ["en", "ta"]
    profile = exam["profile"]
    assert (profile["kind"], profile["options_per_question"]) == ("mixed", 5)
    assert profile["counting_unit"] == "session"
    assert profile["exam_dates"] == ["2027-03-14"]
    stages = db_client.get(f"/api/v1/me/exams/{exam['code']}/stages").json()
    assert stages[0]["name"] == "Written test"
    assert stages[0]["sections"][0]["cutoff"] == 20
    assert stages[0]["marking_scheme"]["marks_wrong"] == 0.5
    assert stages[0]["verified"] is False  # a learner's entry is never shown as verified


def test_options_can_differ_from_paper_to_paper(db_client: TestClient) -> None:
    exam = _create(db_client, options_per_question=None)
    assert exam["profile"]["options_per_question"] is None


def test_renaming_leaves_the_rest_alone(db_client: TestClient) -> None:
    exam = _create(db_client, options_per_question=5, stages=[STAGE])
    code = exam["code"]
    renamed = db_client.patch(f"/api/v1/me/exams/{code}", json={"name": "New name"}).json()
    assert renamed["name"] == "New name"
    assert renamed["profile"]["options_per_question"] == 5
    assert len(db_client.get(f"/api/v1/me/exams/{code}/stages").json()) == 1


@pytest.mark.parametrize(
    "change",
    [
        {"options_per_question": 9},
        {"kind": "oral"},
        {"languages": ["English"]},
        {"repeat_share": 1.5},
        {"stages": [{**STAGE, "duration_minutes": 30}]},  # its sections need longer
        {"stages": [{**STAGE, "sections": []}]},
    ],
)
def test_impossible_values_are_refused(db_client: TestClient, change: dict[str, Any]) -> None:
    response = db_client.post("/api/v1/me/exams", json={"name": "Exam", **change})
    assert response.status_code == 422


def test_another_learners_stages_look_missing(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    code = _create(db_client, stages=[STAGE])["code"]
    other = make_user(db_session, "other@example.com")
    response = db_client.get(f"/api/v1/me/exams/{code}/stages", headers=auth_headers(other))
    assert response.status_code == 404


def test_catalog_stages_come_from_reviewed_formats(db_client: TestClient) -> None:
    stages = db_client.get("/api/v1/me/exams/SSC_CGL/stages").json()
    assert len(stages) == 1
    stage = stages[0]
    assert stage["verified"] is True and stage["source"]
    assert stage["duration_minutes"] == 60
    assert [s["duration_minutes"] for s in stage["sections"]] == [15, 15, 15, 15]
    assert stage["marking_scheme"] == {
        "marks_correct": 2.0,
        "marks_wrong": 0.5,
        "marks_unanswered": None,  # the format doesn't state it
    }


def _templates() -> dict[str, dict[str, Any]]:
    return {
        p.name: json.loads(p.read_text(encoding="utf-8"))
        for p in TEMPLATES_DIR.glob("*.json")
        if p.name != DEFAULTS_FILE
    }


def test_every_template_and_format_file_is_well_formed() -> None:
    templates = _templates()
    assert {"ssc_cgl.json", "ssc_chsl.json", "ibps_po.json", "neet_ug.json"} <= set(templates)
    for data in templates.values():
        TemplateFile.model_validate(data)
    for path in FORMATS_DIR.glob("*.json"):
        FormatFile.model_validate(json.loads(path.read_text(encoding="utf-8")))


def test_every_stated_fact_in_a_template_has_a_source() -> None:
    for name, data in _templates().items():
        if data["status"] == "example":
            continue  # claims no facts
        problems = template_problems(TemplateFile.model_validate(data))
        assert not [p for p in problems if p.endswith("has no source")], name


def test_templates_without_official_facts_claim_none() -> None:
    templates = _templates()
    for name in ("upsc_cse_prelims.json", "jee_main.json"):
        data = templates[name]
        assert data["status"] == "draft"
        assert data["kind"] is None and data["options_per_question"] is None
        assert data["formats"] == [] and data["sources"] == {}
    assert templates["ibps_po.json"]["options_per_question"] is None  # the notice doesn't say
    assert templates["example_descriptive_university.json"]["status"] == "example"


def test_only_a_sourced_template_with_a_reviewer_is_applied(db_session: Session) -> None:
    templates = _templates()
    with pytest.raises(ValueError, match="reviewer"):
        apply_template(db_session, templates["ssc_cgl.json"], " ")
    with pytest.raises(ValueError, match="Not applicable"):
        apply_template(db_session, templates["ibps_po.json"], "A. Reviewer")
    with pytest.raises(ValueError, match="Not applicable"):
        apply_template(db_session, templates["neet_ug.json"], "A. Reviewer")  # flagged uncertain
    with pytest.raises(ValueError, match="example"):
        apply_template(db_session, templates["example_descriptive_university.json"], "A. Reviewer")


def test_applying_a_template_writes_the_profile(db_session: Session) -> None:
    data = {
        "code": "NEW_EXAM",
        "status": "verified",
        "name": "New exam",
        "short_name": "New",
        "kind": "mcq",
        "options_per_question": 5,
        "languages": ["en"],
        "sources": {
            "kind": {"source": "Notice"},
            "options_per_question": {"source": "Notice"},
            "languages": {"source": "Notice"},
        },
    }
    apply_template(db_session, data, "A. Reviewer")
    exam = db_session.get(Exam, "NEW_EXAM")
    assert exam is not None
    assert (exam.options_per_question, exam.languages) == (5, ["en"])
