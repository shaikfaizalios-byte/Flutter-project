"""Papers with official IDs: reading, keys by ID, language versions, import checks, the tool."""

import uuid
from datetime import date
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Environment, Settings
from app.domain.figures import Box, Graphic, LayoutLine, PageLayout
from app.domain.import_checks import CheckedQuestion, check_import
from app.domain.official_key import KeyTarget, plan_official_key, read_official_key
from app.domain.official_paper import is_official_paper, read_official_paper
from app.domain.question_formats import is_correct, spec_problems
from app.integrations.ai import AIProviderError
from app.integrations.storage import LocalDocumentStorage
from app.models.exam import Exam
from app.models.question import ExamFormat, FormatStatus, Question, QuestionFigure
from app.models.user import User
from app.services.processing_service import DocumentProcessor
from app.services.question_transcriber import transcribe_document
from tests.conftest import auth_headers, make_user
from tests.fakes import FakeAIProvider, FakeOcrEngine
from tests.pdf_factory import official_paper_pdf, text_pdf

DOCUMENTS = "/api/v1/documents"
QUESTIONS = "/api/v1/questions"


def line(text: str, top: float) -> LayoutLine:
    return LayoutLine(text, Box(40, top - 8, 500, top))


def image(top: float, height: float = 20) -> Graphic:
    return Graphic("image", Box(80, top - height, 300, top))


def header(number: int, kind: str = "MCQ") -> str:
    return f"Question Number : {number} Question Id : {900000 + number} Question Type : {kind} X"


def page(number: int, *lines: LayoutLine, images: tuple[Graphic, ...] = ()) -> PageLayout:
    return PageLayout(number, 595, 842, list(lines), list(images))


# --- reading ----------------------------------------------------------------------------------


def test_a_question_takes_its_id_section_stem_and_options() -> None:
    layout = page(
        1,
        line("Physics Section A", 800),
        line(header(1), 780),
        line("Options :", 700),
        line("111111. ", 680),
        line("111112. ", 650),
        images=(image(770), image(690), image(660)),
    )
    question = read_official_paper([layout])[0]
    assert (question.number, question.external_id, question.kind) == (1, "900001", "MCQ")
    assert question.section == "Physics Section A"
    assert len(question.crops) == 1
    assert [o.external_id for o in question.options] == ["111111", "111112"]
    assert [len(o.crops) for o in question.options] == [1, 1]


def test_an_option_image_goes_to_the_nearest_label_even_if_it_sits_above_it() -> None:
    layout = page(
        1,
        line(header(1), 780),
        line("Options :", 700),
        line("111111. ", 640),
        line("111112. ", 560),
        images=(image(665, 25), image(590, 25)),
    )
    options = read_official_paper([layout])[0].options
    assert options[0].crops[0].box.top > options[1].crops[0].box.top


def test_a_header_at_the_foot_of_a_page_keeps_its_stem_on_the_next() -> None:
    first = page(1, line(header(1), 60))
    second = page(
        2,
        line("Options :", 700),
        line("111111. ", 680),
        images=(image(790, 40), image(690)),
    )
    question = read_official_paper([first, second])[0]
    assert question.crops[0].page == 2
    assert len(question.options[0].crops) == 1


def test_options_running_onto_the_next_page_stay_with_their_question() -> None:
    first = page(
        1, line(header(1), 200), line("Options :", 120), line("111111. ", 100), images=(image(110),)
    )
    second = page(2, line("111112. ", 780), images=(image(790),))
    question = read_official_paper([first, second])[0]
    assert [o.external_id for o in question.options] == ["111111", "111112"]
    assert [len(o.crops) for o in question.options] == [1, 1]


def test_a_typed_question_has_no_options_and_ignores_its_entry_box() -> None:
    layout = page(
        1,
        line(header(1, "SA"), 780),
        line("Response Type : Numeric", 760),
        line("Possible Answers :", 740),
        line("1", 720),
        images=(image(700),),
    )
    question = read_official_paper([layout])[0]
    assert question.kind == "SA" and question.options == [] and question.text == ""
    assert len(question.crops) == 1


def test_the_page_header_logo_belongs_to_no_question() -> None:
    layout = page(1, line(header(1), 700), images=(image(800, 60), image(690)))
    assert len(read_official_paper([layout])[0].crops) == 1


def test_only_papers_with_these_headers_are_read_this_way() -> None:
    assert is_official_paper([header(n) for n in range(1, 6)])
    assert not is_official_paper(["Q.1 What is 2 + 2?", header(1)])


# --- keys -------------------------------------------------------------------------------------

KEY_TEXT = """JEE (Main) - 2026 : SESSION - 2 FINAL ANSWER KEY OF B.E. / B.Tech
Exam Date : 02.04.2026
6911211 6911213
69112121 4
695278261 Dropped
695278372 41 or 42
6911299 6911301 or 6911302
1 of 18
"""


def target(external_id: str, *, typed: bool = False, number: int = 1) -> KeyTarget:
    options = {} if typed else {"6911213": 3, "6911301": 1, "6911302": 2}
    return KeyTarget(external_id, number, typed, options)


def test_the_key_says_its_stage_and_lists_every_kind_of_entry() -> None:
    key = read_official_key([KEY_TEXT])
    assert key.stage == "final"
    assert key.entries["6911211"].values == ("6911213",)
    assert key.entries["695278261"].dropped is True
    assert key.entries["695278372"].values == ("41", "42")
    assert "1" not in key.entries


def test_a_provisional_file_says_so_and_an_unmarked_one_says_nothing() -> None:
    assert read_official_key(["PROVISIONAL ANSWER KEY\n123456 1"]).stage == "provisional"
    assert read_official_key(["123456 1"]).stage is None


def test_each_kind_of_entry_becomes_a_decision() -> None:
    key = read_official_key([KEY_TEXT])
    plan = plan_official_key(
        [
            target("6911211"),
            target("69112121", typed=True),
            target("695278261"),
            target("695278372", typed=True),
            target("6911299"),
        ],
        key,
    )
    assert plan.problems == [] and plan.missing == []
    one, typed, dropped, either, several = plan.decisions
    assert one.position == 3 and one.outcome == "one"
    assert typed.spec == {"value": "4"}
    assert dropped.outcome == "dropped"
    assert either.spec == {"value": "41", "also": ["42"]}
    assert several.outcome == "several" and several.accepted == (1, 2)


def test_a_key_for_other_shifts_is_ignored_and_a_gap_is_reported() -> None:
    plan = plan_official_key([target("999999", number=7)], read_official_key([KEY_TEXT]))
    assert plan.decisions == [] and plan.missing == [7]


def test_an_option_the_paper_doesnt_have_is_reported_not_guessed() -> None:
    key = read_official_key(["FINAL ANSWER KEY\n111111 222222"])
    plan = plan_official_key([target("111111", number=4)], key)
    assert plan.decisions == []
    assert "Question 4" in plan.problems[0]


def test_a_typed_answer_that_isnt_whole_is_reported() -> None:
    key = read_official_key(["FINAL ANSWER KEY\n111111 2.5"])
    assert plan_official_key([target("111111", typed=True)], key).problems


def test_either_of_two_accepted_numbers_is_right() -> None:
    spec = {"value": "41", "also": ["42"]}
    assert spec_problems("integer", spec, 0) == []
    assert is_correct("integer", spec, "42") and is_correct("integer", spec, "41")
    assert not is_correct("integer", spec, "43")


# --- import checks ----------------------------------------------------------------------------

SECTIONS: list[dict[str, Any]] = [
    {"part": "Section A", "subject": "Physics", "questions": 2, "formats": ["single_correct"]},
    {"part": "Section B", "subject": "Physics", "questions": 1, "formats": ["integer"]},
]


def checked(number: int, section: str, fmt: str, key: bool = True) -> CheckedQuestion:
    return CheckedQuestion(number, section, fmt, key)


def test_a_paper_that_fits_passes() -> None:
    result = check_import(
        SECTIONS,
        [
            checked(1, "Physics Section A", "single_correct"),
            checked(2, "Physics Section A", "single_correct"),
            checked(3, "Physics Section B", "integer"),
        ],
    )
    assert result.ok
    assert [(s.expected, s.found) for s in result.sections] == [(2, 2), (1, 1)]


def test_every_problem_is_listed() -> None:
    result = check_import(
        SECTIONS,
        [
            checked(1, "Physics Section A", "single_correct", key=False),
            checked(3, "Physics Section B", "single_correct"),
            checked(9, "Biology Section A", "single_correct"),
        ],
    )
    text = " | ".join(result.problems)
    assert "Physics Section A: 1 questions, the format has 2" in text
    assert "Question 3 is single_correct" in text
    assert "Question 9 isn't in a section" in text
    assert "1 questions have no key: 1" in text


# --- through the API --------------------------------------------------------------------------


def imported(
    client: TestClient,
    db: Session,
    storage: LocalDocumentStorage,
    settings: Settings,
    *,
    language: str = "en",
) -> uuid.UUID:
    response = client.post(
        DOCUMENTS,
        files={"file": ("paper.pdf", official_paper_pdf(language), "application/pdf")},
        data={"exam_code": "SSC_CHSL", "language": language},
    )
    assert response.status_code == 201, response.text
    processor = DocumentProcessor(storage=storage, ocr=FakeOcrEngine(), settings=settings)
    document = processor.claim_next(db)
    assert document is not None
    processor.process(db, document)
    return document


def rows(db: Session, document: uuid.UUID) -> list[Question]:
    db.expire_all()
    return list(
        db.scalars(
            select(Question)
            .where(Question.document_id == document)
            .order_by(Question.source_question_number)
        )
    )


@pytest.fixture
def paper(
    db_client: TestClient, db_session: Session, storage: LocalDocumentStorage, settings: Settings
) -> uuid.UUID:
    return imported(db_client, db_session, storage, settings)


def test_a_paper_imports_with_crops_ids_and_no_text_invented(
    db_session: Session, paper: uuid.UUID
) -> None:
    questions = rows(db_session, paper)
    assert len(questions) == 6
    first = questions[0]
    assert first.external_id == "7000001" and first.stem == ""
    assert first.section == "Physics Section A" and first.subject == "Physics"
    assert first.format == "single_correct" and first.image_dependent
    assert [o.external_id for o in first.options] == ["7100011", "7100012", "7100013", "7100014"]
    assert all(o.text == "" for o in first.options)
    kinds = db_session.scalars(
        select(QuestionFigure.kind).where(QuestionFigure.question_id == first.id)
    ).all()
    assert sorted(kinds) == ["option"] * 4 + ["stem"]
    typed = questions[5]
    assert typed.answer_type == "typed" and typed.format == "integer"
    assert typed.verification_status == "unverified"


def key_file(lines: list[str]) -> bytes:
    return text_pdf([lines])


def send_key(api: TestClient, paper: uuid.UUID, lines: list[str]) -> Any:
    return api.post(
        f"{DOCUMENTS}/{paper}/official-key",
        files={"file": ("key.pdf", key_file(lines), "application/pdf")},
    )


FINAL = [
    "SESSION 2 FINAL ANSWER KEY OF B.E. / B.Tech ON WHICH RESULT COMPILED",
    "7000001 7100012",
    "7000002 7100023",
    "7000003 Dropped",
    "7000004 7100041 or 7100042",
    "7000005 7100051",
    "7000006 41 or 42",
    "8888888 9999999",
]


def test_a_key_matches_by_id_with_every_state(
    db_client: TestClient, db_session: Session, paper: uuid.UUID
) -> None:
    response = send_key(db_client, paper, FINAL)
    assert response.status_code == 200, response.text
    result = response.json()
    assert result["stage"] == "final" and result["applied"] == 6
    assert (result["dropped"], result["several"]) == (1, 1)
    assert result["missing"] == [] and result["problems"] == []
    questions = rows(db_session, paper)
    assert questions[0].correct_option_position == 2
    assert questions[0].key_stage == "final"
    assert questions[2].key_outcome == "dropped"
    assert questions[3].accepted_positions == [1, 2]
    assert questions[5].answer_spec == {"value": "41", "also": ["42"]}


def test_a_final_key_replaces_a_provisional_one_and_flags_the_change(
    db_client: TestClient, db_session: Session, paper: uuid.UUID
) -> None:
    provisional = ["PROVISIONAL ANSWER KEY OF B.E. / B.Tech FOR THE PAPER", "7000001 7100011"]
    result = send_key(db_client, paper, provisional).json()
    assert result["stage"] == "provisional" and len(result["missing"]) == 5
    send_key(db_client, paper, FINAL)
    question = rows(db_session, paper)[0]
    assert question.correct_option_position == 2 and question.key_changed is True


def test_a_file_without_ids_or_a_stage_is_refused(db_client: TestClient, paper: uuid.UUID) -> None:
    assert send_key(db_client, paper, ["Some page of ordinary text with no key"]).status_code == 422
    unmarked = ["A list of question ids and options here", "7000001 7100012"]
    assert send_key(db_client, paper, unmarked).status_code == 422


def test_someone_elses_paper_stays_out_of_reach(
    db_client: TestClient, db_session: Session, paper: uuid.UUID
) -> None:
    other = make_user(db_session, "reader@example.com")
    response = db_client.post(
        f"{DOCUMENTS}/{paper}/official-key",
        files={"file": ("key.pdf", key_file(FINAL), "application/pdf")},
        headers=auth_headers(other),
    )
    assert response.status_code == 404


def test_the_same_id_in_another_language_counts_once(
    db_client: TestClient,
    db_session: Session,
    storage: LocalDocumentStorage,
    settings: Settings,
    paper: uuid.UUID,
) -> None:
    hindi = imported(db_client, db_session, storage, settings, language="hi")
    english_rows, hindi_rows = rows(db_session, paper), rows(db_session, hindi)
    assert [q.translation_of_id for q in hindi_rows] == [q.id for q in english_rows]
    assert all(q.translation_of_id is None for q in english_rows)


def add_format(db: Session) -> None:
    db.add(
        ExamFormat(
            code="OFFICIAL_CHECK",
            exam_code="SSC_CHSL",
            stage="Paper",
            name="Check",
            sections=[
                {
                    "part": "Section A",
                    "subject": "Physics",
                    "questions": 5,
                    "max_marks": 20,
                    "formats": ["single_correct"],
                },
                {
                    "part": "Section B",
                    "subject": "Physics",
                    "questions": 2,
                    "max_marks": 8,
                    "formats": ["integer"],
                },
            ],
            sections_in_fixed_order=False,
            total_questions=7,
            duration_minutes=60,
            negative_marks_per_wrong=1,
            source_title="Notice",
            source_url="https://example.com/n",
            source_reference="para 1",
            source_published_on=date(2026, 1, 1),
            verified_on=date(2026, 1, 2),
            status=FormatStatus.DRAFT,
        )
    )
    db.flush()


def test_the_import_check_reports_counts_and_missing_keys(
    db_client: TestClient, db_session: Session, paper: uuid.UUID
) -> None:
    add_format(db_session)
    url = f"{DOCUMENTS}/{paper}/import-check"
    before = db_client.get(url, params={"format_code": "OFFICIAL_CHECK"}).json()
    assert before["ok"] is False
    assert [(s["expected"], s["found"]) for s in before["sections"]] == [(5, 5), (2, 1)]
    assert any("have no key" in p for p in before["problems"])
    send_key(db_client, paper, FINAL)
    after = db_client.get(url, params={"format_code": "OFFICIAL_CHECK"}).json()
    assert not any("have no key" in p for p in after["problems"])


def test_an_unknown_format_is_refused(db_client: TestClient, paper: uuid.UUID) -> None:
    url = f"{DOCUMENTS}/{paper}/import-check"
    assert db_client.get(url, params={"format_code": "NOPE"}).status_code == 422


def test_bulk_assign_sets_a_state_on_many_and_reports_refusals(
    db_client: TestClient, db_session: Session, paper: uuid.UUID
) -> None:
    send_key(db_client, paper, FINAL)
    ids = [str(q.id) for q in rows(db_session, paper)[:2]]
    missing = str(uuid.uuid4())
    response = db_client.post(
        f"{QUESTIONS}/bulk-assign",
        json={"question_ids": [*ids, missing], "verification_status": "verified"},
    )
    assert response.status_code == 200, response.text
    assert response.json() == {"updated": 2, "failed": [missing]}
    assert rows(db_session, paper)[0].verification_status == "verified"


def test_verified_picture_questions_can_be_practised(
    db_client: TestClient, db_session: Session, paper: uuid.UUID
) -> None:
    send_key(db_client, paper, FINAL)
    question = rows(db_session, paper)[0]
    db_client.post(
        f"{QUESTIONS}/bulk-assign",
        json={"question_ids": [str(question.id)], "verification_status": "verified"},
    )
    session = db_client.post(
        "/api/v1/practice/sessions", json={"count": 1, "exam_code": "SSC_CHSL"}
    ).json()
    assert session["items"][0]["question_id"] == str(question.id)
    assert session["items"][0]["figures"]


# --- hidden search text -----------------------------------------------------------------------


def test_transcripts_stay_hidden_and_make_a_question_findable(
    db_client: TestClient, db_session: Session, paper: uuid.UUID
) -> None:
    provider = FakeAIProvider(responses=[{"text": "Find $\\sqrt{2}$ quantum"}])
    read, failed = transcribe_document(db_session, provider, paper, 1)
    assert (read, failed) == (1, 0)
    assert provider.calls[0].images == 5
    question = rows(db_session, paper)[0]
    assert question.stem == ""  # learners still see the picture
    found = db_client.get(QUESTIONS, params={"q": "quantum"}).json()["items"]
    assert [q["id"] for q in found] == [str(question.id)]
    assert "transcript" not in found[0]


def test_a_failed_transcription_is_counted_and_goes_on(
    db_session: Session, paper: uuid.UUID
) -> None:
    provider = FakeAIProvider(responses=[AIProviderError("down"), {"text": "Second"}])
    assert transcribe_document(db_session, provider, paper, 2) == (1, 1)


# --- the review tool --------------------------------------------------------------------------


def test_the_tool_is_served_and_holds_no_data(db_client: TestClient) -> None:
    response = db_client.get("/review-tool")
    assert response.status_code == 200
    assert "Content review" in response.text
    assert response.headers["content-type"].startswith("text/html")


def test_the_tool_is_off_in_production_unless_turned_on() -> None:
    assert Settings(_env_file=None, environment=Environment.TEST).review_tool_enabled is True
    production = Settings.model_construct(
        environment=Environment.PRODUCTION, expose_review_tool=False
    )
    assert production.review_tool_enabled is False
    production.expose_review_tool = True
    assert production.review_tool_enabled is True


def test_the_tool_lives_outside_the_app_and_loads_nothing_else() -> None:
    html = (Path(__file__).parents[1] / "app" / "tools" / "review_tool.html").read_text("utf-8")
    assert "https://" not in html and "http://" not in html
    assert 'id="login"' in html


def test_exam_rows_are_untouched_by_reading_a_paper(db_session: Session, paper: uuid.UUID) -> None:
    assert db_session.get(Exam, "SSC_CHSL") is not None


def test_a_reviewer_still_owns_the_paper(db_session: Session, paper: uuid.UUID, user: User) -> None:
    assert all(q.owner_id == user.id for q in rows(db_session, paper))
