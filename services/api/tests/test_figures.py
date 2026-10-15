"""Figures: finding them in a page layout (pure), and end to end from a generated PDF through
the worker to the API (crops, issues, image endpoint, practice)."""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain.figures import (
    Box,
    FigureKind,
    Graphic,
    LayoutLine,
    PageLayout,
    analyse_page,
    decorations,
    locate_figures,
)
from app.domain.segmentation import IssueCode, PageText, content_issues, image_hint, segment
from app.integrations.storage import LocalDocumentStorage
from app.services.processing_service import DocumentProcessor
from tests.conftest import auth_headers, make_user
from tests.fakes import FakeOcrEngine
from tests.pdf_factory import figure_paper_pdf

WIDTH, HEIGHT = 612.0, 792.0


def line(text: str, top: float, left: float = 36.0, right: float = 400.0) -> LayoutLine:
    return LayoutLine(text, Box(left, top - 9, right, top))


def path(left: float, bottom: float, right: float, top: float) -> Graphic:
    return Graphic("path", Box(left, bottom, right, top))


def page(number: int, lines: list[LayoutLine], graphics: list[Graphic]) -> PageLayout:
    return PageLayout(number, WIDTH, HEIGHT, lines, graphics)


def run(
    layouts: list[PageLayout], unreadable: bool = False
) -> tuple[list[Any], list[Any], list[Any]]:
    keys = decorations(layouts)
    analyses = [analyse_page(layout, keys) for layout in layouts]
    result = segment([PageText(a.layout.number, a.text()) for a in analyses])
    located = locate_figures(
        result.questions,
        analyses,
        strong_numbering=result.strong_numbering,
        unreadable=[unreadable] * len(result.questions),
    )
    return result.questions, located, analyses


# --- pure rules ----------------------------------------------------------------------------


def test_option_figures_belong_to_the_option_above_them() -> None:
    layout = page(
        1,
        [
            line("Q.1 Select the Venn diagram.", 720),
            line("(a)", 700, right=50),
            line("(b)", 630, right=50),
            line("Q.2 What is 2 + 2?", 560),
            line("(a) 4 (b) 5", 540),
        ],
        [path(80, 650, 140, 690), path(80, 580, 140, 620)],
    )
    questions, located, _ = run([layout])

    assert [(c.kind, c.option_index) for c in located[0].crops] == [
        (FigureKind.OPTION, 0),
        (FigureKind.OPTION, 1),
    ]
    assert located[1].crops == []
    assert located[0].has_figure and not located[0].text_incomplete
    assert questions[0].options[0].text == ""  # the option *is* the figure


def test_a_figure_before_the_options_is_the_stems() -> None:
    layout = page(
        1,
        [line("Q.1 How many triangles are there?", 720), line("(a) 4 (b) 6 (c) 8 (d) 9", 600)],
        [path(80, 620, 200, 700)],
    )
    _, located, _ = run([layout])

    [crop] = located[0].crops
    assert crop.kind == FigureKind.STEM
    assert not located[0].ambiguous_options


def test_figures_after_a_line_of_several_options_cannot_be_matched_to_one() -> None:
    layout = page(
        1,
        [line("Q.1 Which figure fits?", 720), line("(a) (b) (c) (d)", 700)],
        [path(80, 620, 200, 690)],
    )
    _, located, _ = run([layout])

    assert located[0].ambiguous_options
    # No guessing which option is which: the whole question is kept as printed.
    assert [c.kind for c in located[0].crops] == [FigureKind.ORIGINAL]


def test_labels_inside_a_chart_belong_to_the_figure_not_the_text() -> None:
    layout = page(
        1,
        [
            line("Q.1 The bar graph shows sales.", 740),
            line("100", 700, left=95, right=110),
            line("70", 660, left=178, right=190),
            line("(a) 170", 560),
            line("(b) 150", 545),
        ],
        [path(60, 600, 260, 720), path(90, 610, 120, 690), path(170, 610, 200, 660)],
    )
    questions, located, analyses = run([layout])

    assert "100" not in analyses[0].text()
    assert [o.text for o in questions[0].options] == ["170", "150"]
    assert [c.kind for c in located[0].crops] == [FigureKind.STEM]


def test_a_box_around_a_question_is_layout_not_a_figure() -> None:
    layout = page(
        1,
        [line("Q.1 Choose the synonym of RAPID.", 370), line("(a) Slow", 350)],
        [path(30, 290, 430, 390)],
    )
    questions, located, analyses = run([layout])

    assert analyses[0].figures == []
    assert located[0].crops == []
    assert questions[0].options[0].text == "Slow"


def test_graphics_on_a_text_line_mean_the_text_is_incomplete() -> None:
    layout = page(
        1,
        [line("Q.1 Find the value of", 480, right=140), line("(a) 1", 460)],
        [path(150, 470, 176, 484)],
    )
    _, located, _ = run([layout])

    assert located[0].text_incomplete
    assert [c.kind for c in located[0].crops] == [FigureKind.STEM, FigureKind.ORIGINAL]


def test_unreadable_text_gets_an_image_of_the_question_as_printed() -> None:
    layout = page(1, [line("Q.1 Select the odd one.", 700), line("(a) 1", 680)], [])
    _, located, _ = run([layout], unreadable=True)

    [crop] = located[0].crops
    assert crop.kind == FigureKind.ORIGINAL
    assert crop.box.top >= 700 and crop.box.bottom <= 671


def test_graphics_repeated_on_most_pages_are_decoration() -> None:
    logo, footer = path(545, 745, 575, 775), path(36, 29, 576, 31)
    layouts = [
        page(n, [line(f"Q.{n} Question {n}?", 700), line("(a) yes", 680)], [logo, footer])
        for n in (1, 2, 3)
    ]
    _, located, analyses = run(layouts)

    assert all(a.figures == [] for a in analyses)
    assert all(f.crops == [] for f in located)


def test_two_column_pages_are_not_analysed() -> None:
    layout = page(
        1,
        [
            line("Q.1 Left column?", 700, right=250),
            line("(a) 1", 680, right=250),
            line("Q.2 Right column?", 700, left=320, right=560),
            line("(a) 2", 680, left=320, right=560),
        ],
        [path(80, 600, 200, 660)],
    )
    _, located, _ = run([layout])

    assert all(f.crops == [] for f in located)


def test_rotated_pages_are_skipped() -> None:
    layout = PageLayout(1, WIDTH, HEIGHT, [line("Q.1 A?", 700)], [], rotated=True)
    analysis = analyse_page(layout, set())
    assert not analysis.supported and analysis.reason == "rotated_page"


def test_image_hints_survive_a_lost_ligature() -> None:
    assert image_hint("Select the \x1fgure that will come next.") == "figure"
    assert image_hint("Select the correct mirror image.") == "mirror image"
    assert image_hint("What is 2 + 2?") is None


def test_an_option_that_is_a_figure_is_not_empty() -> None:
    issues = content_issues(
        option_texts=["", "", "", ""],
        answer_position=1,
        expected_options=4,
        option_figures={1, 2, 3, 4},
    )
    assert issues == []
    issues = content_issues(option_texts=["", "x", "y", "z"], answer_position=1, expected_options=4)
    assert [i.code for i in issues] == [IssueCode.EMPTY_OPTION]


# --- end to end ----------------------------------------------------------------------------


@pytest.fixture
def figure_paper(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> uuid.UUID:
    response = db_client.post(
        "/api/v1/documents",
        files={"file": ("figures.pdf", figure_paper_pdf(), "application/pdf")},
        data={"exam_code": "SSC_CHSL", "language": "en"},
    )
    assert response.status_code == 201, response.text
    document_id = uuid.UUID(response.json()["id"])
    processor = DocumentProcessor(storage=storage, ocr=FakeOcrEngine(), settings=settings)
    assert processor.claim_next(db_session) == document_id
    processor.process(db_session, document_id)
    return document_id


def paper_questions(client: TestClient, document_id: uuid.UUID) -> dict[int, dict[str, Any]]:
    response = client.get(
        "/api/v1/questions", params={"document_id": str(document_id), "limit": 100}
    )
    assert response.status_code == 200, response.text
    return {q["source_question_number"]: q for q in response.json()["items"]}


def codes(question: dict[str, Any]) -> set[str]:
    return {i["code"] for i in question["issues"] if not i["resolved"]}


def test_figures_are_cropped_from_the_paper(db_client: TestClient, figure_paper: uuid.UUID) -> None:
    questions = paper_questions(db_client, figure_paper)

    venn = questions[1]
    assert [(f["kind"], f["option_position"]) for f in venn["figures"]] == [
        ("option", 1),
        ("option", 2),
        ("option", 3),
        ("option", 4),
    ]
    assert venn["image_dependent"] is True
    assert IssueCode.EMPTY_OPTION not in codes(venn)  # its options are figures
    assert IssueCode.IMAGE_DEPENDENT in codes(venn)

    assert questions[2]["figures"] == [] and questions[2]["image_dependent"] is False
    assert [f["kind"] for f in questions[3]["figures"]] == ["stem"]

    chart = questions[4]
    assert [f["kind"] for f in chart["figures"]] == ["stem"]
    assert "100" not in chart["stem"]  # chart labels stay in the chart
    assert [o["text"] for o in chart["options"]] == ["170", "150", "130", "30"]

    formula = questions[5]
    assert [f["kind"] for f in formula["figures"]] == ["stem", "original"]
    assert IssueCode.UNREADABLE_TEXT in codes(formula)

    assert questions[6]["figures"] == []  # a bordered question is not a figure


def test_figure_image_is_served_to_its_owner_only(
    db_client: TestClient, db_session: Session, figure_paper: uuid.UUID
) -> None:
    question = paper_questions(db_client, figure_paper)[1]
    figure = question["figures"][0]
    url = f"/api/v1/questions/{question['id']}/figures/{figure['id']}"

    response = db_client.get(url)
    assert response.status_code == 200
    assert response.headers["content-type"] == "image/png"
    assert response.headers["cache-control"].startswith("private")
    assert response.content.startswith(b"\x89PNG")
    assert figure["width"] > 0 and figure["height"] > 0

    other = make_user(db_session, "other@example.com")
    assert db_client.get(url, headers=auth_headers(other)).status_code == 404
    wrong_question = f"/api/v1/questions/{uuid.uuid4()}/figures/{figure['id']}"
    assert db_client.get(wrong_question).status_code == 404


def test_figure_questions_can_be_practised(db_client: TestClient, figure_paper: uuid.UUID) -> None:
    venn = paper_questions(db_client, figure_paper)[1]
    verified = db_client.patch(
        f"/api/v1/questions/{venn['id']}", json={"verification_status": "verified"}
    )
    assert verified.status_code == 200, verified.text

    response = db_client.post("/api/v1/practice/sessions", json={"count": 10})
    assert response.status_code == 201, response.text
    [item] = response.json()["items"]
    assert item["question_id"] == venn["id"]
    assert [f["kind"] for f in item["figures"]] == ["option"] * 4


def test_topics_are_suggested_with_a_reason_and_accepted_in_one_go(
    db_client: TestClient, figure_paper: uuid.UUID
) -> None:
    questions = paper_questions(db_client, figure_paper)
    venn = questions[1]
    assert venn["topic_status"] == "suggested"
    assert venn["topic"]["name"] == "Venn Diagrams"
    assert venn["subject"] == "General Intelligence"
    assert venn["topic_suggestion_reason"].startswith("Matched ")

    summary = db_client.get(f"/api/v1/documents/{figure_paper}/parse-summary")
    assert summary.status_code == 200, summary.text
    suggested = summary.json()["topics_suggested"]
    assert suggested >= 4
    assert summary.json()["with_figures"] == 4

    accepted = db_client.post(f"/api/v1/documents/{figure_paper}/topics/accept")
    assert accepted.status_code == 200, accepted.text
    assert accepted.json() == {"accepted": suggested}
    venn = paper_questions(db_client, figure_paper)[1]
    assert venn["topic_status"] == "confirmed"
    assert venn["topic_suggestion_reason"] is None
    assert db_client.post(f"/api/v1/documents/{figure_paper}/topics/accept").json() == {
        "accepted": 0
    }


def test_accepting_topics_needs_the_owners_document(
    db_client: TestClient, db_session: Session, figure_paper: uuid.UUID
) -> None:
    other = make_user(db_session, "other@example.com")
    response = db_client.post(
        f"/api/v1/documents/{figure_paper}/topics/accept", headers=auth_headers(other)
    )
    assert response.status_code == 404
