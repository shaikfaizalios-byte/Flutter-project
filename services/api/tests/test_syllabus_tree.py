"""Syllabus versions: pure scope rules, the backfill of today's topics, and the data files."""

import json
import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.cli.syllabus import SyllabusFile, file_problems, import_file
from app.domain.syllabus_tree import MAX_DEPTH, VersionRef, in_force, scope_for
from app.models.document import Document, DocumentStatus
from app.models.exam import Exam
from app.models.practice import PracticeSession, SessionAnswer, SessionItem
from app.models.question import Question, QuestionOption, QuestionOrigin, Topic, TopicStatus
from app.models.syllabus import SyllabusNode, SyllabusVersion
from app.models.taxonomy import TaxonomyNode, TopicTaxonomyLink
from app.models.user import User
from app.services.insights_service import InsightsService
from app.services.syllabus_tree_service import active_topics
from app.services.topic_service import visible_topics
from tests.conftest import auth_headers, make_user

SYLLABI = Path(__file__).resolve().parents[1] / "data" / "syllabi"
A, B, C = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()


def version(year: int | None, *topics: uuid.UUID) -> VersionRef:
    return VersionRef(uuid.uuid4(), year, frozenset(topics))


def test_in_force_is_the_newest_version_effective_by_the_year() -> None:
    old, new = version(None, A), version(2024, B)
    assert in_force([old, new], 2020) is old
    assert in_force([old, new], 2024) is new
    assert in_force([old, new], 2026) is new
    assert in_force([], 2026) is None


def test_a_paper_older_than_every_version_uses_the_earliest() -> None:
    first, second = version(2022, A), version(2024, B)
    assert in_force([first, second], 2019) is first


def test_one_version_changes_nothing() -> None:
    scope = scope_for([[version(None, A, B)]], [2019, 2024], 2026)
    assert scope.out_of_scope == frozenset() and scope.dropped == frozenset()
    assert scope_for([[version(2025, A)]], [2019], 2026).out_of_scope == frozenset()
    assert scope_for([], [2019], 2026).dropped == frozenset()


def test_old_papers_use_the_old_syllabus_and_its_topics_show_as_dropped() -> None:
    lines = [[version(None, A, B), version(2024, B, C)]]
    old_papers = scope_for(lines, [2020], 2026)
    assert old_papers.out_of_scope == {C}  # not on the syllabus when those papers were set
    assert old_papers.dropped == {A}
    new_papers = scope_for(lines, [2025], 2026)
    assert new_papers.out_of_scope == {A} and new_papers.dropped == frozenset()
    both = scope_for(lines, [2020, 2025], 2026)
    assert both.out_of_scope == frozenset() and both.dropped == {A}


def test_a_version_not_yet_effective_is_not_current() -> None:
    scope = scope_for([[version(None, A), version(2030, B)]], [2026], 2026)
    assert scope.out_of_scope == {B} and scope.dropped == frozenset()


def test_shared_and_own_lines_are_separate() -> None:
    scope = scope_for([[version(None, A)], [version(None, B)]], [2020], 2026)
    assert scope.out_of_scope == frozenset() and scope.dropped == frozenset()


def _tree(db: Session, version_id: uuid.UUID) -> dict[str, list[str]]:
    nodes = db.scalars(
        select(SyllabusNode)
        .where(SyllabusNode.version_id == version_id)
        .order_by(SyllabusNode.position)
    ).all()
    roots = [n for n in nodes if n.parent_id is None]
    return {r.name: [n.name for n in nodes if n.parent_id == r.id] for r in roots}


@pytest.mark.parametrize("exam", ["SSC_CGL", "SSC_CHSL", "RRB_NTPC"])
def test_todays_topics_became_one_version_per_exam(db_session: Session, exam: str) -> None:
    rows = db_session.scalars(
        select(SyllabusVersion).where(
            SyllabusVersion.exam_code == exam, SyllabusVersion.owner_id.is_(None)
        )
    ).all()
    assert len(rows) == 1
    assert rows[0].effective_year is None  # never recorded, so not invented
    linked = db_session.scalars(
        select(SyllabusNode.topic_id).where(
            SyllabusNode.version_id == rows[0].id, SyllabusNode.topic_id.is_not(None)
        )
    ).all()
    assert set(linked) == {t.id for t in visible_topics(db_session, None, exam)}


def test_catalog_exams_without_shared_topics_have_no_version(db_session: Session) -> None:
    assert not db_session.scalars(
        select(SyllabusVersion).where(SyllabusVersion.exam_code == "NEET_UG")
    ).all()


def _names(nodes: list[dict[str, Any]]) -> dict[str, list[str]]:
    return {n["name"]: [c["name"] for c in n.get("children", [])] for n in nodes}


def test_the_built_in_syllabus_files_equal_the_database(db_session: Session) -> None:
    for path in SYLLABI.glob("*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        for exam in data["exam_codes"]:
            row = db_session.scalars(
                select(SyllabusVersion).where(
                    SyllabusVersion.exam_code == exam, SyllabusVersion.owner_id.is_(None)
                )
            ).one()
            assert _tree(db_session, row.id) == _names(data["tree"]), (path.name, exam)
            topics = {(t.subject, t.name): t for t in visible_topics(db_session, None, exam)}
            for subject in data["tree"]:
                for leaf in subject["children"]:
                    topic = topics[(subject["name"], leaf["name"])]
                    assert list(topic.keywords) == leaf["keywords"], leaf["name"]


# --- a learner's own syllabus ------------------------------------------------------------------

TREE = [
    {
        "name": "Physics",
        "level_label": "Subject",
        "children": [
            {
                "name": "Mechanics",
                "level_label": "Unit",
                "children": [
                    {
                        "name": "Kinematics",
                        "level_label": "Chapter",
                        "children": [
                            {"name": "Projectiles", "level_label": "Topic", "keywords": ["range"]}
                        ],
                    }
                ],
            }
        ],
    },
    {"name": "Essay"},
]


def _own_exam(client: TestClient) -> str:
    code: str = client.post("/api/v1/me/exams", json={"name": "Board"}).json()["code"]
    return code


def _post(client: TestClient, code: str, **body: Any) -> Any:
    return client.post(
        f"/api/v1/exams/{code}/syllabus-versions", json={"name": "Mine", "tree": TREE, **body}
    )


def test_a_tree_of_any_depth_is_saved_and_its_leaves_become_topics(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    code = _own_exam(db_client)
    response = _post(db_client, code, effective_year=2026)
    assert response.status_code == 201, response.text
    version = response.json()
    assert version["own"] is True and version["in_force"] is True
    physics = version["tree"][0]
    leaf = physics["children"][0]["children"][0]["children"][0]
    assert (leaf["name"], leaf["level_label"], leaf["keywords"]) == (
        "Projectiles",
        "Topic",
        ["range"],
    )
    assert physics["topic_id"] is None and leaf["topic_id"] is not None
    topics = {(t.subject, t.name) for t in visible_topics(db_session, user.id, code)}
    assert topics == {("Physics", "Projectiles"), ("Essay", "Essay")}


def test_a_new_version_reuses_the_topic_so_its_history_stays(db_client: TestClient) -> None:
    code = _own_exam(db_client)
    first = _post(db_client, code, effective_year=2020).json()
    second = _post(db_client, code, effective_year=2024).json()
    assert first["tree"][1]["topic_id"] == second["tree"][1]["topic_id"]
    listed = db_client.get(f"/api/v1/exams/{code}/syllabus-versions").json()
    assert [(v["effective_year"], v["in_force"]) for v in listed] == [(2020, False), (2024, True)]


def test_catalog_syllabus_is_listed_with_keywords_from_its_topics(db_client: TestClient) -> None:
    versions = db_client.get("/api/v1/exams/SSC_CGL/syllabus-versions").json()
    assert len(versions) == 1
    assert versions[0]["own"] is False and versions[0]["effective_year"] is None
    leaves = [leaf for subject in versions[0]["tree"] for leaf in subject["children"]]
    assert len(leaves) == 60
    percentage = next(leaf for leaf in leaves if leaf["name"] == "Percentage")
    assert "percent" in percentage["keywords"]


@pytest.mark.parametrize(
    "change",
    [{"effective_year": 1500}, {"tree": []}, {"source_kind": "template"}, {"name": " "}],
)
def test_bad_versions_are_refused(db_client: TestClient, change: dict[str, Any]) -> None:
    assert _post(db_client, _own_exam(db_client), **change).status_code == 422


def test_too_deep_a_tree_is_refused(db_client: TestClient) -> None:
    node: dict[str, Any] = {"name": "Leaf"}
    for level in range(MAX_DEPTH):
        node = {"name": f"Level {level}", "children": [node]}
    assert _post(db_client, _own_exam(db_client), tree=[node]).status_code == 422


def test_one_syllabus_per_year(db_client: TestClient) -> None:
    code = _own_exam(db_client)
    assert _post(db_client, code).status_code == 201
    assert _post(db_client, code).status_code == 409


def test_another_learners_syllabus_is_private(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    code = _own_exam(db_client)
    version = _post(db_client, code).json()
    other = auth_headers(make_user(db_session, "other@example.com"))
    assert (
        db_client.get(f"/api/v1/exams/{code}/syllabus-versions", headers=other).status_code == 404
    )
    url = f"/api/v1/syllabus-versions/{version['id']}"
    assert db_client.delete(url, headers=other).status_code == 404
    shared = db_session.scalars(
        select(SyllabusVersion).where(SyllabusVersion.exam_code == "SSC_CGL")
    ).first()
    assert shared is not None
    assert db_client.delete(f"/api/v1/syllabus-versions/{shared.id}").status_code == 404


def test_deleting_keeps_topics_another_version_uses(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    code = _own_exam(db_client)
    first = _post(db_client, code, effective_year=2020).json()
    second = _post(db_client, code, effective_year=2024).json()
    assert db_client.delete(f"/api/v1/syllabus-versions/{first['id']}").status_code == 204
    assert len(visible_topics(db_session, user.id, code)) == 2
    assert db_client.delete(f"/api/v1/syllabus-versions/{second['id']}").status_code == 204
    assert visible_topics(db_session, user.id, code) == []


# --- versions and papers ------------------------------------------------------------------------


def _shared_exam(db: Session) -> tuple[str, Topic, Topic, Topic]:
    """An exam whose 2024 syllabus dropped Old and added New; Kept is in both."""
    db.add(Exam(code="VERSIONED", name="Versioned"))
    db.flush()
    data = {
        "exam_codes": ["VERSIONED"],
        "name": "2010 syllabus",
        "effective_year": 2010,
        "source": {"title": "Notice", "url": "https://example.com/notice"},
        "tree": [{"name": "Maths", "children": [{"name": "Old"}, {"name": "Kept"}]}],
    }
    import_file(db, data, "A. Reviewer")
    data["effective_year"] = 2024
    data["tree"] = [{"name": "Maths", "children": [{"name": "Kept"}, {"name": "New"}]}]
    import_file(db, data, "A. Reviewer")
    topics = {t.name: t for t in visible_topics(db, None, "VERSIONED")}
    return "VERSIONED", topics["Old"], topics["Kept"], topics["New"]


def _paper(db: Session, owner: User, exam: str, year: int, topic: Topic) -> None:
    document = Document(
        owner_id=owner.id,
        exam_code=exam,
        language="en",
        original_filename=f"{year}.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
        exam_year=year,
        paper_date_status="confirmed",
    )
    db.add(document)
    db.flush()
    question = Question(
        owner_id=owner.id,
        origin=QuestionOrigin.SOURCE,
        exam_code=exam,
        subject=topic.subject,
        topic_id=topic.id,
        topic_status=TopicStatus.CONFIRMED,
        stem=f"A question from the paper of {year} about something?",
        language="en",
        document_id=document.id,
        source_question_number=1,
        source_pages=[1],
        correct_option_position=1,
    )
    question.options = [QuestionOption(position=1, label="1", text="a")]
    db.add(question)
    db.flush()


def test_not_repeated_uses_the_syllabus_of_the_counted_papers(
    db_session: Session, user: User
) -> None:
    exam, _, kept, _ = _shared_exam(db_session)
    _paper(db_session, user, exam, 2015, kept)
    gaps = InsightsService(db_session, user.id).repeats(exam).not_repeated
    assert [(t.name, t.dropped) for t in gaps.not_seen] == [("Old", True)]  # New wasn't asked yet


def test_a_newer_paper_brings_in_the_new_syllabus(db_session: Session, user: User) -> None:
    exam, _, kept, _ = _shared_exam(db_session)
    _paper(db_session, user, exam, 2025, kept)
    gaps = InsightsService(db_session, user.id).repeats(exam).not_repeated
    assert [(t.name, t.dropped) for t in gaps.not_seen] == [("New", False)]


def test_papers_from_both_periods_show_both_and_mark_the_dropped_one(
    db_session: Session, user: User
) -> None:
    exam, _, kept, _ = _shared_exam(db_session)
    _paper(db_session, user, exam, 2015, kept)
    _paper(db_session, user, exam, 2025, kept)
    gaps = InsightsService(db_session, user.id).repeats(exam).not_repeated
    assert sorted((t.name, t.dropped) for t in gaps.not_seen) == [("New", False), ("Old", True)]


def test_suggestions_use_only_the_syllabus_in_force(db_session: Session, user: User) -> None:
    exam, *_ = _shared_exam(db_session)
    assert {t.name for t in active_topics(db_session, user.id, exam)} == {"Kept", "New"}


def test_an_exam_with_one_version_suggests_every_topic(db_session: Session, user: User) -> None:
    names = {t.id for t in active_topics(db_session, user.id, "SSC_CGL")}
    assert names == {t.id for t in visible_topics(db_session, user.id, "SSC_CGL")}


def test_a_new_shared_version_needs_a_source_a_year_and_a_reviewer(db_session: Session) -> None:
    data: dict[str, Any] = {"exam_codes": ["SSC_CGL"], "name": "Next", "tree": TREE}
    problems = file_problems(SyllabusFile.model_validate(data))
    assert problems == ["it has no official source", "it has no effective year"]
    with pytest.raises(ValueError, match="Not importable"):
        import_file(db_session, data, "A. Reviewer")
    with pytest.raises(ValueError, match="reviewer"):
        import_file(db_session, data, " ")


def test_the_built_in_files_are_refused_as_new_versions() -> None:
    for path in SYLLABI.glob("*.json"):
        spec = SyllabusFile.model_validate(json.loads(path.read_text(encoding="utf-8")))
        assert "it has no official source" in file_problems(spec)


# --- answers on the same topic across exams -----------------------------------------------------


def _answer(db: Session, owner: User, exam: str, topic: Topic, *, correct: bool) -> None:
    question = Question(
        owner_id=owner.id,
        origin=QuestionOrigin.AI,
        exam_code=exam,
        topic_id=topic.id,
        stem=f"Question {uuid.uuid4()}",
        language="en",
        source_pages=[],
        correct_option_position=1,
        ai_provider="fake",
        ai_model="fake",
        ai_prompt_version="v1",
    )
    question.options = [QuestionOption(position=1, label="1", text="a")]
    db.add(question)
    db.flush()
    now = datetime.now(UTC)
    session = PracticeSession(
        owner_id=owner.id, mode="practice", exam_code=exam, selection={}, started_at=now
    )
    session.items = [
        SessionItem(
            position=1,
            question_id=question.id,
            topic_id=topic.id,
            correct_position=1,
            option_count=1,
            marks_correct=1,
            marks_wrong=0,
            question_verified=False,
        )
    ]
    db.add(session)
    db.flush()
    db.add(
        SessionAnswer(
            session_id=session.id,
            position=1,
            question_id=question.id,
            selected_position=1,
            is_correct=correct,
            client_seq=1,
            answered_at=now,
        )
    )
    db.flush()


def test_stats_per_exam_and_combined_count_only_confirmed_links(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    node = db_session.scalars(select(TaxonomyNode).where(TaxonomyNode.kind == "topic")).first()
    assert node is not None
    shared = db_session.scalars(
        select(Topic).join(TopicTaxonomyLink).where(TopicTaxonomyLink.node_id == node.id)
    ).first()
    assert shared is not None
    own = Topic(subject="S", name="Same thing", owner_id=user.id, exam_codes=None, keywords=[])
    guess = Topic(subject="S", name="Maybe", owner_id=user.id, exam_codes=None, keywords=[])
    db_session.add_all([own, guess])
    db_session.flush()
    db_session.add_all(
        [
            TopicTaxonomyLink(
                topic_id=own.id, node_id=node.id, status="confirmed", source="learner"
            ),
            TopicTaxonomyLink(
                topic_id=guess.id, node_id=node.id, status="suggested", source="rules"
            ),
        ]
    )
    db_session.flush()
    _answer(db_session, user, "SSC_CGL", shared, correct=True)
    _answer(db_session, user, "NEET_UG", own, correct=False)
    _answer(db_session, user, "NEET_UG", guess, correct=True)  # only suggested: not counted

    response = db_client.get("/api/v1/analytics/canonical", params={"exam": ["SSC_CGL", "NEET_UG"]})
    assert response.status_code == 200, response.text
    rows = response.json()
    assert len(rows) == 1
    assert (rows[0]["answered"], rows[0]["correct"]) == (2, 1)
    assert {e["exam_code"]: (e["answered"], e["correct"]) for e in rows[0]["exams"]} == {
        "NEET_UG": (1, 0),
        "SSC_CGL": (1, 1),
    }
