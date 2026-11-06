"""Syllabus versions: pure scope rules, the backfill of today's topics, and the data files."""

import json
import uuid
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.syllabus_tree import VersionRef, in_force, scope_for
from app.models.syllabus import SyllabusNode, SyllabusVersion
from app.services.topic_service import visible_topics

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
