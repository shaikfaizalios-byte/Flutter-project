"""JEE Main, JEE Advanced and NEET UG syllabi: official lists, versioned, linked across exams."""

import json
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.cli.exam_formats import apply_template
from app.cli.syllabus import LinkFile, SyllabusFile, file_problems, import_file, link_file
from app.domain.exam_profile import DATA_DIR, TEMPLATES_DIR
from app.models.question import Topic
from app.models.syllabus import SyllabusNode, SyllabusVersion
from app.models.taxonomy import TaxonomyNode, TopicTaxonomyLink
from app.models.user import User

SYLLABI = DATA_DIR / "syllabi" / "official"
FILES = {
    "jee_main_2027": ("JEE_MAIN", 2027, {"Mathematics": 14, "Physics": 20, "Chemistry": 3}),
    "jee_advanced_2026": ("JEE_ADVANCED", 2026, {"Chemistry": 33, "Mathematics": 9, "Physics": 7}),
    "neet_ug_2026": ("NEET_UG", 2026, {"Physics": 20, "Chemistry": 3, "Biology": 10}),
}
OFFICIAL_HOSTS = ("https://cdnbbsr.s3waas.gov.in/", "https://jeeadv.ac.in/", "https://nta.ac.in/")
PAGE_FURNITURE = ("UGMEB", "eOffice", "CDN-20011", "Paper 2A", "File No", "Intentionally")


def load(name: str) -> dict[str, Any]:
    data: dict[str, Any] = json.loads((SYLLABI / f"{name}.json").read_text(encoding="utf-8"))
    return data


def leaves(nodes: list[dict[str, Any]]) -> Iterator[dict[str, Any]]:
    for node in nodes:
        if node.get("children"):
            yield from leaves(node["children"])
        else:
            yield node


@pytest.mark.parametrize("name", FILES)
def test_each_file_is_importable_with_an_official_source_and_year(name: str) -> None:
    spec = SyllabusFile.model_validate(load(name))
    assert file_problems(spec) == []
    code, year, _ = FILES[name]
    assert spec.exam_codes == [code] and spec.effective_year == year
    assert spec.source is not None and spec.source.url.startswith(OFFICIAL_HOSTS)


@pytest.mark.parametrize(("name", "expected"), [(k, v[2]) for k, v in FILES.items()])
def test_subjects_and_units_match_the_official_lists(name: str, expected: dict[str, int]) -> None:
    tree = load(name)["tree"]
    assert {s["name"]: len(s["children"]) for s in tree} == expected
    assert {s["level_label"] for s in tree} == {"Subject"}


def test_chemistry_keeps_its_three_official_sections_of_twenty_units() -> None:
    for name in ("jee_main_2027", "neet_ug_2026"):
        chemistry = next(s for s in load(name)["tree"] if s["name"] == "Chemistry")
        assert [s["name"] for s in chemistry["children"]] == [
            "Physical Chemistry",
            "Inorganic Chemistry",
            "Organic Chemistry",
        ]
        assert sum(len(s["children"]) for s in chemistry["children"]) == 20


@pytest.mark.parametrize("name", FILES)
def test_topics_are_clean_official_phrases(name: str) -> None:
    topics = list(leaves(load(name)["tree"]))
    assert len(topics) > 300
    for topic in topics:
        text = topic["name"]
        assert 3 <= len(text) <= 100, text
        assert not any(word in text for word in PAGE_FURNITURE), text
        assert text.count("(") == text.count(")"), text
        assert topic["level_label"] == "Topic"


@pytest.mark.parametrize("name", FILES)
def test_every_topic_keeps_its_own_keywords_within_the_limits(name: str) -> None:
    for topic in leaves(load(name)["tree"]):
        assert len(topic["keywords"]) <= 60
        assert all(len(k) <= 60 for k in topic["keywords"])


def test_no_textbook_text_is_stored() -> None:
    for name in FILES:
        assert "NCERT" not in json.dumps(load(name))


def apply_exams(db: Session) -> None:
    for name in ("jee_main", "jee_advanced", "neet_ug"):
        data = json.loads((TEMPLATES_DIR / f"{name}.json").read_text(encoding="utf-8"))
        apply_template(db, data, "A. Reviewer")
    db.flush()


def import_all(db: Session) -> None:
    apply_exams(db)
    for name in FILES:
        import_file(db, load(name), "A. Reviewer")
    db.flush()


def test_a_reviewer_must_be_named_to_import(db_session: Session) -> None:
    apply_exams(db_session)
    with pytest.raises(ValueError, match="reviewer"):
        import_file(db_session, load("neet_ug_2026"), " ")


def test_importing_makes_versioned_trees_whose_topics_stay_with_their_exam(
    db_session: Session,
) -> None:
    import_all(db_session)
    versions = db_session.scalars(
        select(SyllabusVersion).where(SyllabusVersion.exam_code == "NEET_UG")
    ).all()
    assert [v.effective_year for v in versions] == [2026]
    assert versions[0].source_url is not None
    topic = db_session.scalar(
        select(Topic).where(Topic.exam_codes == ["NEET_UG"], Topic.subject == "Biology")
    )
    assert topic is not None and topic.owner_id is None


def test_a_second_year_can_be_added_and_reuses_topics(db_session: Session) -> None:
    import_all(db_session)
    before = db_session.scalar(select(func.count()).select_from(Topic))
    later = load("neet_ug_2026") | {"effective_year": 2027}
    import_file(db_session, later, "A. Reviewer")
    assert db_session.scalar(select(func.count()).select_from(Topic)) == before


def links() -> dict[str, Any]:
    data: dict[str, Any] = load("canonical_jee_neet")
    return data


def test_the_link_file_names_only_units_and_topics_that_exist() -> None:
    spec = LinkFile.model_validate(links())
    assert len(spec.canonical) == 40
    trees = {FILES[name][0]: load(name)["tree"] for name in FILES}

    def names(nodes: list[dict[str, Any]]) -> Iterator[str]:
        for node in nodes:
            yield node["name"]
            yield from names(node.get("children", []))

    known = {code: set(names(tree)) for code, tree in trees.items()}
    for entry in spec.canonical:
        for code, member in entry.members.items():
            assert set(member.units + member.topics) <= known[code]


def test_what_couldnt_be_placed_is_written_down_for_a_person() -> None:
    unlinked = links()["unlinked"]
    assert "Chemistry / Solid State" in unlinked


def test_nothing_links_until_a_named_reviewer_imports_the_file(db_session: Session) -> None:
    import_all(db_session)
    assert not db_session.scalar(
        select(func.count()).select_from(TaxonomyNode).where(TaxonomyNode.key == "physics/optics")
    )
    with pytest.raises(ValueError, match="reviewer"):
        link_file(db_session, links(), "  ")


def test_linking_joins_the_same_unit_across_exams(db_session: Session) -> None:
    import_all(db_session)
    added, kept = link_file(db_session, links(), "A. Reviewer")
    assert added > 700
    assert kept <= 5  # a phrase listed under two units keeps its first link
    node = db_session.scalars(
        select(TaxonomyNode).where(TaxonomyNode.key == "physics/kinematics")
    ).one()
    exams = db_session.scalars(
        select(Topic.exam_codes)
        .join(TopicTaxonomyLink, TopicTaxonomyLink.topic_id == Topic.id)
        .where(TopicTaxonomyLink.node_id == node.id, TopicTaxonomyLink.status == "confirmed")
    ).all()
    assert {code for codes in exams for code in codes or []} == {
        "JEE_MAIN",
        "JEE_ADVANCED",
        "NEET_UG",
    }


def test_linking_twice_changes_nothing(db_session: Session) -> None:
    import_all(db_session)
    added, _ = link_file(db_session, links(), "A. Reviewer")
    again, kept = link_file(db_session, links(), "A. Reviewer")
    assert again == 0 and kept >= added


def test_maths_and_biology_stay_unlinked(db_session: Session) -> None:
    import_all(db_session)
    link_file(db_session, links(), "A. Reviewer")
    linked = db_session.scalars(
        select(Topic.subject)
        .join(TopicTaxonomyLink, TopicTaxonomyLink.topic_id == Topic.id)
        .where(Topic.exam_codes.overlap(["JEE_MAIN", "JEE_ADVANCED", "NEET_UG"]))
    ).all()
    assert set(linked) == {"Physics", "Chemistry"}


def test_the_app_can_read_the_tree_by_exam(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    import_all(db_session)
    body = db_client.get("/api/v1/exams/JEE_MAIN/syllabus-versions").json()
    assert body[0]["effective_year"] == 2027
    assert (db_session.scalar(select(func.count()).select_from(SyllabusNode)) or 0) > 1000


def test_no_build_script_or_source_text_is_committed() -> None:
    assert not list(Path(SYLLABI).glob("*.txt"))
