from datetime import UTC, datetime

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.concept import Concept
from app.models.user import User
from app.repositories.concept_repository import ConceptFilter, ConceptRepository
from app.repositories.exam_repository import ExamRepository


def _concept(**overrides: object) -> Concept:
    values: dict[str, object] = {
        "exam_code": "SSC_CGL",
        "title": "Title",
        "subject": "Reasoning",
        "topic": "Coding-Decoding",
        "language": "en",
        "tags": [],
    }
    values.update(overrides)
    return Concept(**values)


def test_add_assigns_id_and_server_timestamps(db_session: Session, user: User) -> None:
    repo = ConceptRepository(db_session, user.id)

    concept = repo.add(_concept())
    db_session.refresh(concept)

    assert concept.id is not None
    assert concept.created_at is not None
    assert concept.updated_at is not None
    assert concept.notes == ""


def test_search_excludes_archived_unless_requested(db_session: Session, user: User) -> None:
    repo = ConceptRepository(db_session, user.id)
    repo.add(_concept(title="Active"))
    repo.add(_concept(title="Old", archived_at=datetime.now(UTC)))

    active, active_total = repo.search(ConceptFilter(), limit=10, offset=0)
    everything, all_total = repo.search(ConceptFilter(include_archived=True), limit=10, offset=0)

    assert [c.title for c in active] == ["Active"]
    assert active_total == 1
    assert all_total == 2
    assert len(everything) == 2


def test_tag_filter_uses_array_membership(db_session: Session, user: User) -> None:
    repo = ConceptRepository(db_session, user.id)
    repo.add(_concept(title="Tagged", tags=["formula", "pyq"]))
    repo.add(_concept(title="Untagged"))

    items, total = repo.search(ConceptFilter(tag="pyq"), limit=10, offset=0)

    assert total == 1
    assert items[0].title == "Tagged"


def test_database_rejects_unsupported_language(db_session: Session, user: User) -> None:
    repo = ConceptRepository(db_session, user.id)

    with pytest.raises(IntegrityError):
        repo.add(_concept(language="fr"))


def test_database_rejects_unknown_exam(db_session: Session, user: User) -> None:
    repo = ConceptRepository(db_session, user.id)

    with pytest.raises(IntegrityError):
        repo.add(_concept(exam_code="NOPE"))


def test_exam_repository_lists_active_exams(db_session: Session, user: User) -> None:
    assert [e.code for e in ExamRepository(db_session).list_active()] == ["SSC_CGL", "SSC_CHSL"]
