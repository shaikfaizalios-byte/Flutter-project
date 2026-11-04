"""Topic lists across papers and whole-paper summaries from the Study search: recognising the
request, the citation check, spreading over papers, and the whole loop with a fake AI."""

import uuid
from typing import Any

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.rag import RagSource
from app.domain.study_requests import (
    MAX_TOPICS,
    SUMMARY_BATCH_CHARS,
    SUMMARY_MAX_BATCHES,
    StudyRequest,
    matches_paper,
    page_batches,
    parse_study_request,
    spread_sources,
    validate_study,
)
from app.models.ai import AIGeneration
from app.models.document import Document, DocumentStatus
from app.models.user import User
from tests.conftest import make_user
from tests.fakes import FakeAIProvider
from tests.test_ai import AppFactory, ai, make_api
from tests.test_practice import document
from tests.test_rag import add_page, other_document

__all__ = ["ai", "document", "make_api"]  # fixtures re-used from other test modules

SEARCH = "/api/v1/ai/search-answer"

# --- recognising a request -------------------------------------------------------------------


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        (
            "provide 10 important topics in iOS across pdfs",
            StudyRequest(kind="topics", count=10, subject="iOS"),
        ),
        (
            "Give me top 5 topics of Percentage with answers",
            StudyRequest(kind="topics", count=5, subject="Percentage"),
        ),
        ("important topics in swift", StudyRequest(kind="topics", count=10, subject="swift")),
        ("key concepts of Polity", StudyRequest(kind="topics", count=10, subject="Polity")),
        ("10 important questions in ratio", StudyRequest(kind="topics", subject="ratio")),
        ("ten main topics from my papers", StudyRequest(kind="topics", count=10, subject="")),
        ("50 topics in history", StudyRequest(kind="topics", count=MAX_TOPICS, subject="history")),
        ("iOS के 10 महत्वपूर्ण टॉपिक बताओ", StudyRequest(kind="topics", subject="iOS")),
        ("summarize this pdf", StudyRequest(kind="summary")),
        ("Summarise the paper in simple points", StudyRequest(kind="summary")),
        ("give a quick summary of this document", StudyRequest(kind="summary")),
        ("summary of chsl-2024.pdf", StudyRequest(kind="summary", paper="chsl 2024")),
        ("summarize this pdf in 12 points", StudyRequest(kind="summary")),
        ("इस पेपर का सारांश", StudyRequest(kind="summary")),
    ],
)
def test_requests_are_recognised(text: str, expected: StudyRequest) -> None:
    assert parse_study_request(text) == expected


@pytest.mark.parametrize(
    "text",
    [
        "optional binding",
        "topics in history",  # a search: no count, nothing about importance
        "10 questions on ratio",  # asks for questions, not topics
        "what is the important days list",
    ],
)
def test_ordinary_searches_stay_searches(text: str) -> None:
    assert parse_study_request(text) is None


def test_a_paper_is_named_by_the_words_of_its_file_name() -> None:
    assert matches_paper("chsl 2024", "SSC-CHSL-2024-shift1.pdf")
    assert matches_paper("ios", "iOS Notes.pdf")
    assert not matches_paper("constitution", "SSC-CHSL-2024-shift1.pdf")
    assert not matches_paper("", "anything.pdf")


# --- the citation check ----------------------------------------------------------------------


def item(title: str = "Optionals", text: str = "A value or nil.", cited: Any = None) -> Any:
    return {"title": title, "text": text, "cited": ["S1"] if cited is None else cited}


def test_items_need_sources_that_were_sent() -> None:
    good = validate_study(
        {"found": True, "confident": True, "items": [item(), item("ARC", "Counts refs [S2].")]},
        ["S1", "S2"],
        limit=10,
    )
    assert good is not None and good.found
    assert [(i.title, i.text, i.cited) for i in good.items] == [
        ("Optionals", "A value or nil.", ("S1",)),
        ("ARC", "Counts refs.", ("S1", "S2")),  # markers leave the text, the list keeps them
    ]

    def result(*items: Any) -> Any:
        return validate_study({"found": True, "items": list(items)}, ["S1"], limit=10, titled=True)

    assert result(item(), item(cited=["S9"])) is None  # one invented source rejects everything
    assert result(item(text="Made up [S7].")) is None
    assert result(item(cited=[])) is None  # no source at all
    assert result(item(title="")) is None  # a topic needs its name
    assert result(item(text=" ")) is None
    assert result() is None  # found, but nothing there


def test_found_false_lists_nothing_and_extras_and_repeats_are_dropped() -> None:
    nothing = validate_study({"found": False, "items": []}, ["S1"], limit=10)
    assert nothing is not None and not nothing.found and nothing.items == ()

    many = [item(f"Topic {i}") for i in range(6)] + [item("topic 0")]
    capped = validate_study({"found": True, "items": many}, ["S1"], limit=3)
    assert capped is not None and [i.title for i in capped.items] == [
        "Topic 0",
        "Topic 1",
        "Topic 2",
    ]


# --- spreading and batching ------------------------------------------------------------------


def source(key: str, document_id: str | None, kind: Any = "page", text: str = "x") -> RagSource:
    return RagSource(
        key=key, kind=kind, label=key, text=text, verified=False, rank=1.0, document_id=document_id
    )


def test_one_long_paper_cannot_fill_the_whole_context() -> None:
    sources = [source(f"a{i}", "A") for i in range(10)]
    sources += [source("b0", "B"), source("q0", None, "question")]
    assert [s.key for s in spread_sources(sources, 5)] == ["a0", "b0", "q0", "a1", "a2"]


def test_pages_are_batched_whole_and_the_rest_is_reported() -> None:
    page = SUMMARY_BATCH_CHARS // 2
    pages = [source(f"S{i}", "A", text="x" * page) for i in range(1, 8)]
    batches, read = page_batches(pages)
    assert [len(b) for b in batches] == [2, 2, 2, 1] and read == 7

    pages = [source(f"S{i}", "A", text="x" * page) for i in range(1, 12)]
    batches, read = page_batches(pages)
    assert len(batches) == SUMMARY_MAX_BATCHES and read == 8  # pages 9-11 aren't read


# --- the whole loop through the API (fake AI provider: no network) ---------------------------


def second_paper(db: Session, user: User, name: str = "swift-notes.pdf") -> Document:
    paper = other_document(db, user)
    paper.original_filename = name
    db.flush()
    return paper


def test_topics_come_from_every_paper_with_their_sources(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, document: Document
) -> None:
    add_page(db_session, document, 1, "iOS optionals hold a value or nil.")
    add_page(db_session, second_paper(db_session, user), 3, "iOS uses ARC to manage memory.")
    stranger = make_user(db_session, "stranger@example.com")
    add_page(db_session, other_document(db_session, stranger), 1, "SECRET iOS notes")
    ai.responses = [
        {
            "found": True,
            "confident": True,
            "items": [
                {"title": "Optionals", "text": "A value or nil.", "cited": ["S1"]},
                {"title": "ARC", "text": "Manages memory.", "cited": ["S2"]},
            ],
        }
    ]

    response = make_api(ai).post(
        SEARCH,
        json={"text": "provide 10 important topics in iOS across pdfs", "exam_code": "SSC_CHSL"},
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert (body["kind"], body["found"], body["requested"]) == ("topics", True, 10)
    assert [i["title"] for i in body["items"]] == ["Optionals", "ARC"]  # fewer: never padded
    assert len(body["sources"]) == 2 and all(s["cited"] for s in body["sources"])
    prompt = ai.calls[0].prompt
    assert "hold a value" in prompt and "manage memory" in prompt  # both papers
    assert "SECRET" not in prompt  # never other accounts
    assert "up to 10" in prompt
    assert "Never say a topic will appear" in ai.calls[0].system
    log = db_session.scalars(select(AIGeneration).where(AIGeneration.task == "study_topics")).one()
    assert (log.outcome, log.items_created) == ("ok", 2)


def test_topics_with_no_matching_material_cost_nothing(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    add_page(db_session, document, 1, "Percentages and ratios.")
    response = make_api(ai).post(
        SEARCH, json={"text": "10 important topics in kotlin", "exam_code": "SSC_CHSL"}
    )
    body = response.json()
    assert (body["kind"], body["found"], body["items"]) == ("topics", False, [])
    assert ai.calls == []


def test_topics_without_a_subject_sample_every_paper(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, document: Document
) -> None:
    add_page(db_session, document, 1, "Percentages and ratios.")
    add_page(db_session, second_paper(db_session, user), 1, "Time and work.")
    ai.responses = [{"found": False, "confident": True, "items": []}]

    body = (
        make_api(ai)
        .post(SEARCH, json={"text": "10 important topics across my pdfs", "exam_code": "SSC_CHSL"})
        .json()
    )
    assert (body["kind"], body["found"]) == ("topics", False)
    assert "Percentages" in ai.calls[0].prompt and "Time and work" in ai.calls[0].prompt


def test_invented_sources_reject_a_topic_list_and_are_logged(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    add_page(db_session, document, 1, "iOS optionals.")
    ai.responses = [{"found": True, "confident": True, "items": [item(cited=["S9"])]}]

    response = make_api(ai).post(
        SEARCH, json={"text": "5 important topics in ios", "exam_code": "SSC_CHSL"}
    )
    assert response.status_code == 502
    log = db_session.scalars(select(AIGeneration).where(AIGeneration.task == "study_topics")).one()
    assert log.outcome == "invalid"


def points(*cited: str) -> dict[str, Any]:
    return {
        "found": True,
        "confident": True,
        "items": [{"title": "", "text": f"Point from {c}.", "cited": [c]} for c in cited],
    }


def test_this_pdf_with_one_paper_summarises_it_all(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    add_page(db_session, document, 1, "Chapter one is about optionals.")
    add_page(db_session, document, 2, "")  # a page with no text isn't sent
    add_page(db_session, document, 3, "Chapter three is about memory.")
    ai.responses = [points("S1", "S3")]

    response = make_api(ai).post(
        SEARCH, json={"text": "summarize this pdf", "exam_code": "SSC_CHSL"}
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert (body["kind"], body["found"]) == ("summary", True)
    assert body["document_name"] == "sample.pdf"
    assert (body["pages_read"], body["pages_total"]) == (2, 2)
    assert [i["cited"] for i in body["items"]] == [["S1"], ["S3"]]
    assert [s["page_number"] for s in body["sources"]] == [1, 3]
    assert len(ai.calls) == 1  # one batch needs no merge
    assert "Chapter one" in ai.calls[0].prompt and "Chapter three" in ai.calls[0].prompt
    assert "10 to 15 short points" in ai.calls[0].prompt
    log = db_session.scalars(select(AIGeneration).where(AIGeneration.task == "paper_summary")).one()
    assert log.outcome == "ok"


def test_several_papers_ask_which_one_without_an_ai_call(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, document: Document
) -> None:
    second = second_paper(db_session, user)
    failed = second_paper(db_session, user, "broken.pdf")
    failed.status = DocumentStatus.FAILED
    db_session.flush()

    body = (
        make_api(ai)
        .post(SEARCH, json={"text": "summarize this pdf", "exam_code": "SSC_CHSL"})
        .json()
    )
    assert body["kind"] == "choose_paper"
    assert {p["name"] for p in body["papers"]} == {document.original_filename, "swift-notes.pdf"}
    assert ai.calls == []
    assert second.id


def test_a_paper_can_be_named_or_chosen(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, user: User, document: Document
) -> None:
    named = second_paper(db_session, user)
    add_page(db_session, named, 1, "Swift notes.")
    add_page(db_session, document, 1, "Other paper.")
    api = make_api(ai)

    ai.responses = [points("S1")]
    by_name = api.post(SEARCH, json={"text": "summary of swift notes", "exam_code": "SSC_CHSL"})
    assert by_name.json()["document_name"] == "swift-notes.pdf"

    ai.responses = [points("S1")]
    chosen = api.post(
        SEARCH,
        json={
            "text": "summary",
            "exam_code": "SSC_CHSL",
            "document_id": str(document.id),
            "language": "hi",
        },
    )
    assert chosen.json()["document_name"] == document.original_filename
    assert "Hindi" in ai.calls[-1].prompt


def test_words_that_name_no_paper_stay_an_ordinary_search(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    add_page(db_session, document, 1, "The constitution of India.")
    ai.responses = [
        {"found": True, "answer": "It is law [S1].", "cited": ["S1"], "confident": True}
    ]

    body = (
        make_api(ai)
        .post(SEARCH, json={"text": "summary of the constitution", "exam_code": "SSC_CHSL"})
        .json()
    )
    assert (body["kind"], body["found"]) == ("answer", True)


def test_no_paper_yet_says_so(make_api: AppFactory, ai: FakeAIProvider, user: User) -> None:
    body = (
        make_api(ai)
        .post(SEARCH, json={"text": "summarize this pdf", "exam_code": "SSC_CHSL"})
        .json()
    )
    assert (body["kind"], body["papers"]) == ("choose_paper", [])
    assert ai.calls == []


def test_a_long_paper_is_read_in_batches_then_merged(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    half = "word " * (SUMMARY_BATCH_CHARS // 10)  # two pages fill one batch
    for number in range(1, 4):
        add_page(db_session, document, number, f"Page {number} " + half + half)
    ai.responses = [points("S1"), points("S2"), points("S3"), points("S1", "S3")]

    response = make_api(ai).post(
        SEARCH, json={"text": "summarize this pdf", "exam_code": "SSC_CHSL"}
    )

    body = response.json()
    assert [i["cited"] for i in body["items"]] == [["S1"], ["S3"]]
    assert len(ai.calls) == 4
    assert "(part 2 of 3)" in ai.calls[1].prompt
    merge = ai.calls[3].prompt
    assert "Point from S2." in merge and "Merge them" in merge
    logs = db_session.scalars(
        select(AIGeneration).where(AIGeneration.task == "paper_summary")
    ).all()
    assert len(logs) == 4


def test_a_paper_of_another_account_cannot_be_summarised(
    make_api: AppFactory, ai: FakeAIProvider, db_session: Session, document: Document
) -> None:
    stranger = make_user(db_session, "stranger@example.com")
    theirs = other_document(db_session, stranger)
    add_page(db_session, theirs, 1, "SECRET")

    for target in (theirs.id, uuid.uuid4()):
        response = make_api(ai).post(
            SEARCH, json={"text": "summary", "exam_code": "SSC_CHSL", "document_id": str(target)}
        )
        assert response.status_code == 404
    assert ai.calls == []
