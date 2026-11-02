"""Sectional timers in mocks (SSC CGL 2026 Tier-I: four sections of 15 minutes, in order)."""

import uuid
from collections.abc import Iterator
from datetime import timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.api.v1.endpoints.practice import get_practice_service
from app.core.config import Settings
from app.domain.sections import PlannedSection, SectionClock, advance, finish_early, section_of
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.document import Document, DocumentStatus
from app.models.question import Question, QuestionOption, QuestionOrigin, VerificationStatus
from app.models.user import User
from app.services.practice_service import PracticeService
from tests.conftest import auth_headers
from tests.test_practice import T0, Clock

CGL_SUBJECTS = [
    "General Intelligence and Reasoning",
    "General Awareness",
    "Quantitative Aptitude",
    "English Comprehension",
]
PLAN = [PlannedSection(s, i * 25 + 1, i * 25 + 25, 15) for i, s in enumerate(CGL_SUBJECTS)]


# --- rules -------------------------------------------------------------------------------


def test_sections_close_in_order_as_their_time_runs_out() -> None:
    start = SectionClock(0, T0)

    assert advance(PLAN, start, T0 + timedelta(minutes=14)) == start
    assert advance(PLAN, start, T0 + timedelta(minutes=15)) == SectionClock(
        1, T0 + timedelta(minutes=15)
    )
    later = advance(PLAN, start, T0 + timedelta(minutes=47))
    assert later == SectionClock(3, T0 + timedelta(minutes=45))
    done = advance(PLAN, start, T0 + timedelta(hours=2))
    assert done.finished(PLAN) and done.started_at == T0 + timedelta(minutes=60)
    assert done.deadline(PLAN) is None


def test_finishing_early_opens_the_next_section_with_its_full_time() -> None:
    early = finish_early(PLAN, SectionClock(0, T0), T0 + timedelta(minutes=5))

    assert early == SectionClock(1, T0 + timedelta(minutes=5))
    assert early.deadline(PLAN) == T0 + timedelta(minutes=20)
    assert section_of(PLAN, 26) == 1 and section_of(PLAN, 101) is None


# --- API ---------------------------------------------------------------------------------


@pytest.fixture
def clock() -> Clock:
    return Clock()


@pytest.fixture
def api(
    settings: Settings,
    db_engine: Any,
    db_session: Session,
    storage: LocalDocumentStorage,
    clock: Clock,
    user: User,
) -> Iterator[TestClient]:
    from app.database.session import get_session

    app = create_app(settings, engine=db_engine, storage=storage)
    app.dependency_overrides[get_session] = lambda: db_session
    app.dependency_overrides[get_practice_service] = lambda: PracticeService(
        db_session, owner_id=user.id, now=clock
    )
    with TestClient(app, raise_server_exceptions=False, headers=auth_headers(user)) as client:
        yield client


@pytest.fixture
def cgl_mock(api: TestClient, db_session: Session, user: User) -> dict[str, Any]:
    doc = Document(
        owner_id=user.id,
        exam_code="SSC_CGL",
        language="en",
        original_filename="cgl.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
    )
    db_session.add(doc)
    db_session.flush()
    number = 0
    for subject in CGL_SUBJECTS:
        for _ in range(25):
            number += 1
            question = Question(
                owner_id=user.id,
                origin=QuestionOrigin.SOURCE,
                exam_code="SSC_CGL",
                section=subject,
                subject=subject,
                stem=f"{subject} question {number}?",
                language="en",
                document_id=doc.id,
                source_question_number=number,
                source_pages=[1],
                correct_option_position=1,
                verification_status=VerificationStatus.VERIFIED,
            )
            question.options = [
                QuestionOption(position=i, label=str(i), text=f"opt {i}") for i in range(1, 5)
            ]
            db_session.add(question)
    db_session.flush()
    response = api.post(
        "/api/v1/practice/mock-tests", json={"exam_format_code": "SSC_CGL_2026_TIER1"}
    )
    assert response.status_code == 201, response.text
    data: dict[str, Any] = response.json()
    return data


def get(api: TestClient, sid: str) -> dict[str, Any]:
    data: dict[str, Any] = api.get(f"/api/v1/practice/sessions/{sid}").json()
    return data


def answer(api: TestClient, sid: str, position: int, seq: int = 1) -> Any:
    return api.put(
        f"/api/v1/practice/sessions/{sid}/answers/{position}",
        json={"selected_position": 1, "client_seq": seq},
    )


def test_a_cgl_mock_opens_its_first_section_only(cgl_mock: dict[str, Any]) -> None:
    assert [s["name"] for s in cgl_mock["sections"]] == CGL_SUBJECTS
    assert [(s["first_position"], s["last_position"], s["minutes"]) for s in cgl_mock["sections"]][
        :2
    ] == [(1, 25, 15), (26, 50, 15)]
    assert cgl_mock["current_section"] == 0
    assert cgl_mock["section_deadline_at"] is not None
    items = cgl_mock["items"]
    assert items[0]["stem"] is not None
    assert items[25]["stem"] is None and items[25]["options"] == []  # not open yet


def test_answers_are_taken_only_in_the_open_section(
    api: TestClient, cgl_mock: dict[str, Any]
) -> None:
    sid = cgl_mock["id"]

    assert answer(api, sid, 1).status_code == 200
    refused = answer(api, sid, 26)

    assert refused.status_code == 409
    assert refused.json()["error"]["code"] == "section_closed"


def test_when_a_section_s_time_is_up_the_next_opens_and_the_last_ends_the_mock(
    api: TestClient, cgl_mock: dict[str, Any], clock: Clock
) -> None:
    sid = cgl_mock["id"]
    answer(api, sid, 1)
    clock.now = T0 + timedelta(minutes=16)

    second = get(api, sid)
    assert second["current_section"] == 1
    assert second["items"][25]["stem"] is not None
    assert answer(api, sid, 2, seq=2).status_code == 409  # section 1 is closed now
    assert answer(api, sid, 26).status_code == 200

    clock.now = T0 + timedelta(minutes=61)
    done = get(api, sid)
    assert (done["status"], done["submit_reason"]) == ("submitted", "time_up")
    assert done["result"]["correct"] == 2
    assert "Each section had its own timer (15 min each" in done["result"]["marking_note"]


def test_finishing_sections_early_and_the_last_one_submits(
    api: TestClient, cgl_mock: dict[str, Any], clock: Clock
) -> None:
    sid = cgl_mock["id"]
    clock.now = T0 + timedelta(minutes=3)

    moved = api.post(f"/api/v1/practice/sessions/{sid}/next-section", json={"from_section": 0})
    again = api.post(f"/api/v1/practice/sessions/{sid}/next-section", json={"from_section": 0})

    assert moved.json()["current_section"] == 1
    assert again.json()["current_section"] == 1  # a retried request doesn't skip a section
    deadline = moved.json()["section_deadline_at"].replace("Z", "+00:00")
    assert deadline.startswith((T0 + timedelta(minutes=18)).isoformat()[:19])
    for section in (1, 2, 3):
        last = api.post(
            f"/api/v1/practice/sessions/{sid}/next-section", json={"from_section": section}
        )
    assert (last.json()["status"], last.json()["submit_reason"]) == ("submitted", "user")


def test_chsl_mocks_keep_one_overall_timer(api: TestClient, db_session: Session) -> None:
    from tests.test_practice import make_formats_ready

    doc = Document(
        owner_id=None,
        exam_code="SSC_CHSL",
        language="en",
        original_filename="chsl.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
    )
    db_session.add(doc)
    db_session.flush()
    user_id = api.get("/api/v1/auth/me").json()["id"]
    doc.owner_id = uuid.UUID(user_id)
    db_session.flush()
    make_formats_ready(db_session, doc)

    mock = api.post("/api/v1/practice/mock-tests", json={"exam_format_code": "SSC_CHSL_2026_TIER1"})

    assert mock.status_code == 201, mock.text
    assert (mock.json()["sections"], mock.json()["current_section"]) == ([], None)
    assert answer(api, mock.json()["id"], 100).status_code == 200
