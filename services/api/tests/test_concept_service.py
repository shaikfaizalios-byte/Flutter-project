import uuid

import pytest
from sqlalchemy.orm import Session

from app.domain.errors import InvalidReferenceError, NotFoundError
from app.models.exam import Exam
from app.schemas.concept import ConceptCreate, ConceptUpdate
from app.services.concept_service import ConceptService


def _create_input(**overrides: object) -> ConceptCreate:
    data: dict[str, object] = {
        "exam_code": "SSC_CHSL",
        "title": "Antonyms",
        "subject": "English",
        "topic": "Vocabulary",
        "language": "en",
    }
    data.update(overrides)
    return ConceptCreate.model_validate(data)


def test_archive_is_idempotent_and_keeps_first_timestamp(db_session: Session) -> None:
    service = ConceptService(db_session)
    created = service.create(_create_input())

    first = service.set_archived(created.id, archived=True)
    second = service.set_archived(created.id, archived=True)

    assert first.archived_at is not None
    assert second.archived_at == first.archived_at


def test_update_rejects_switching_to_unknown_exam(db_session: Session) -> None:
    service = ConceptService(db_session)
    created = service.create(_create_input())

    with pytest.raises(InvalidReferenceError):
        service.update(created.id, ConceptUpdate(exam_code="UNKNOWN"))


def test_inactive_exam_cannot_receive_new_concepts(db_session: Session) -> None:
    exam = db_session.get(Exam, "SSC_CHSL")
    assert exam is not None
    exam.is_active = False
    db_session.flush()

    with pytest.raises(InvalidReferenceError):
        ConceptService(db_session).create(_create_input())


def test_update_bumps_updated_at(db_session: Session) -> None:
    service = ConceptService(db_session)
    created = service.create(_create_input())

    updated = service.update(created.id, ConceptUpdate(notes="new notes"))

    assert updated.notes == "new notes"
    assert updated.updated_at >= created.updated_at


@pytest.mark.parametrize("operation", ["get", "delete", "archive"])
def test_missing_concept_raises_not_found(db_session: Session, operation: str) -> None:
    service = ConceptService(db_session)
    missing = uuid.uuid4()

    with pytest.raises(NotFoundError):
        if operation == "get":
            service.get(missing)
        elif operation == "delete":
            service.delete(missing)
        else:
            service.set_archived(missing, archived=True)
