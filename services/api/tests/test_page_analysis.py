"""Page scripts, two-column pages and reviewer-marked figures (global Phase 8)."""

import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain.figures import Box, LayoutLine, figure_box_problem, page_box
from app.domain.page_analysis import detect_script, two_columns
from app.domain.text_quality import ReviewReason
from app.integrations.storage import LocalDocumentStorage
from tests.conftest import auth_headers, make_user
from tests.fakes import FakeOcrEngine
from tests.pdf_factory import SAMPLE_QUESTION, image_pdf, text_image, text_pdf, two_column_pdf
from tests.test_document_processing import pages, run_worker, upload

# --- rules -------------------------------------------------------------------------------


def test_scripts_are_told_apart_only_with_enough_text() -> None:
    assert detect_script("What is twenty percent of one hundred and fifty?") == "latin"
    assert detect_script("एक सौ पचास का बीस प्रतिशत कितना होता है बताइए") == "devanagari"
    assert detect_script("Percentage प्रतिशत of a number संख्या का भाग") == "mixed"
    assert detect_script("Q.1 (a) 20") == "none"


def line(left: float, right: float, y: float = 0) -> LayoutLine:
    return LayoutLine("Q.1 some question text", Box(left, y, right, y + 10))


def test_two_columns_need_both_halves_and_few_lines_across() -> None:
    columns = [line(50, 280, y) for y in range(6)] + [line(330, 560, y) for y in range(6)]
    assert two_columns(columns, 612)
    assert not two_columns([line(50, 560, y) for y in range(12)], 612)  # full-width lines
    assert not two_columns([line(50, 280, y) for y in range(12)], 612)  # one column only
    across = columns + [line(50, 560, y) for y in range(6)]
    assert not two_columns(across, 612)  # many lines run across the middle


def test_reviewer_regions_must_be_on_the_page_and_not_tiny() -> None:
    assert figure_box_problem([0.1, 0.2, 0.5, 0.4]) is None
    assert figure_box_problem([0.1, 0.2, 1.2, 0.4]) == "The region must lie on the page."
    assert figure_box_problem([0.1, 0.2, 0.11, 0.4]) == "The region is too small."
    box = page_box([0.25, 0.1, 0.75, 0.5], 600, 800)  # top-left fractions -> PDF points
    assert (box.left, box.right, box.top, box.bottom) == (150, 450, 720, 400)


def reasons(page: dict[str, object]) -> list[str]:
    found = page["review_reasons"]
    assert isinstance(found, list)
    return [str(r) for r in found]


# --- processing --------------------------------------------------------------------------


def test_a_two_column_page_is_flagged_and_its_text_kept_as_found(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    document_id = upload(db_client, two_column_pdf())
    run_worker(db_session, storage, settings)

    [page] = pages(db_client, document_id)

    assert ReviewReason.TWO_COLUMNS in reasons(page)
    assert page["needs_review"] is True
    assert page["script"] == "latin"
    assert "Left column question 1?" in str(page["text"])


def test_a_one_column_page_is_not_flagged(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    document_id = upload(db_client, text_pdf([SAMPLE_QUESTION * 4]))
    run_worker(db_session, storage, settings)

    [page] = pages(db_client, document_id)

    assert page["review_reasons"] == []
    assert page["script"] == "latin"


def test_a_devanagari_page_in_an_english_paper_is_flagged(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> None:
    ocr = FakeOcrEngine(text="एक सौ पचास का बीस प्रतिशत कितना होता है बताइए और समझाइए")
    document_id = upload(db_client, image_pdf([text_image(["scan"])]), language="en")
    run_worker(db_session, storage, settings, ocr)

    [page] = pages(db_client, document_id)

    assert page["script"] == "devanagari"
    assert ReviewReason.DEVANAGARI_IN_ENGLISH in reasons(page)


# --- reviewer figures ---------------------------------------------------------------------


@pytest.fixture
def scanned_question(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> dict[str, object]:
    from tests.test_question_bank import PAPER_PAGE_1, PAPER_PAGE_2, QUESTIONS

    document_id = upload(db_client, text_pdf([PAPER_PAGE_1, PAPER_PAGE_2]))
    run_worker(db_session, storage, settings)
    items = db_client.get(QUESTIONS, params={"document_id": str(document_id)}).json()["items"]
    question: dict[str, object] = items[0]
    return question


def test_a_reviewer_marks_a_figure_on_the_page(
    db_client: TestClient, scanned_question: dict[str, object]
) -> None:
    qid = scanned_question["id"]

    added = db_client.post(
        f"/api/v1/questions/{qid}/figures",
        json={"page_number": 1, "box": [0.1, 0.1, 0.6, 0.3], "kind": "stem"},
    )

    assert added.status_code == 201, added.text
    figure = added.json()
    assert (figure["source"], figure["kind"], figure["page_number"]) == ("reviewer", "stem", 1)
    image = db_client.get(f"/api/v1/questions/{qid}/figures/{figure['id']}")
    assert image.status_code == 200 and image.content.startswith(b"\x89PNG")
    question = db_client.get(f"/api/v1/questions/{qid}").json()
    assert question["image_dependent"] is True
    assert [f["source"] for f in question["figures"]] == ["reviewer"]

    removed = db_client.delete(f"/api/v1/questions/{qid}/figures/{figure['id']}")
    assert removed.status_code == 204
    assert db_client.get(f"/api/v1/questions/{qid}").json()["figures"] == []


def test_marked_regions_are_checked(
    db_client: TestClient, db_session: Session, scanned_question: dict[str, object]
) -> None:
    qid = scanned_question["id"]

    def add(**body: object) -> int:
        payload = {"page_number": 1, "box": [0.1, 0.1, 0.6, 0.3], **body}
        return db_client.post(f"/api/v1/questions/{qid}/figures", json=payload).status_code

    assert add(page_number=9) == 422  # not a page of the paper
    assert add(box=[0.1, 0.1, 0.105, 0.3]) == 422
    assert add(kind="option") == 422  # needs its option
    other = make_user(db_session, email="other@example.com")
    response = db_client.post(
        f"/api/v1/questions/{qid}/figures",
        json={"page_number": 1, "box": [0.1, 0.1, 0.6, 0.3]},
        headers=auth_headers(other),
    )
    assert response.status_code == 404
    assert uuid.UUID(str(qid))
