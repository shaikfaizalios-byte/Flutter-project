"""Repeat Radar: opt-in sharing, agreement between accounts, nothing identifying in the output."""

import uuid
from datetime import date
from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.radar import Contribution, ShiftKey, agreed, pool
from app.models.document import Document, DocumentStatus
from app.models.question import (
    Question,
    QuestionOption,
    QuestionOrigin,
    QuestionPattern,
    Topic,
    TopicStatus,
    VerificationStatus,
)
from app.models.user import User
from tests.conftest import make_user

S1 = ShiftKey("SSC_CHSL", date(2019, 7, 2), 3)
S2 = ShiftKey("SSC_CHSL", date(2021, 4, 12), 1)


# --- pure pooling ------------------------------------------------------------------------


def test_agreement_needs_two_matching_reports_and_no_tie() -> None:
    assert agreed([3, 3]) == 3
    assert agreed([3, 3, 4]) == 3
    assert agreed([3, 4]) is None  # each value reported once
    assert agreed([3, 3, 4, 4]) is None  # tie
    assert agreed([]) is None


def test_shifts_need_two_accounts_and_counts_need_agreement() -> None:
    pooled = pool(
        [
            Contribution("a", S1, {"venn": 2, "series": 3}, {"classes": 2}),
            Contribution("b", S1, {"venn": 2, "series": 4}, {"classes": 2}),
            Contribution("a", S2, {"venn": 1}, {}),  # only one account: not published
        ]
    )
    assert len(pooled) == 1
    shift = pooled[0]
    assert shift.shift == S1 and shift.accounts == 2
    assert shift.topics == {"venn": 2}  # series withheld: 3 vs 4
    assert shift.patterns == {"classes": 2}
    assert shift.withheld == 1


def test_one_account_counts_once_per_shift() -> None:
    pooled = pool(
        [
            Contribution("a", S1, {"venn": 2}, {}),
            Contribution("a", S1, {"venn": 2, "series": 1}, {}),  # same shift again: larger kept
            Contribution("b", S1, {"venn": 2, "series": 1}, {}),
        ]
    )
    assert pooled[0].accounts == 2
    assert pooled[0].topics == {"venn": 2, "series": 1}


def test_a_topic_one_account_lacks_counts_as_zero() -> None:
    pooled = pool([Contribution("a", S1, {"venn": 2}, {}), Contribution("b", S1, {}, {})])
    assert pooled[0].topics == {} and pooled[0].withheld == 1


# --- API ---------------------------------------------------------------------------------

VENN = "Select the Venn diagram that best illustrates the relationship between the classes."


def _shift_paper(
    db: Session, owner: User, *, day: date | None = date(2019, 7, 2), shift: int | None = 3
) -> Document:
    doc = Document(
        owner_id=owner.id,
        exam_code="SSC_CHSL",
        language="en",
        original_filename=f"chsl-{uuid.uuid4().hex[:6]}.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
        status=DocumentStatus.COMPLETED,
        segmentation_status="completed",
        exam_year=day.year if day else None,
        exam_date=day,
        exam_shift=shift,
        paper_date_status="confirmed",
    )
    db.add(doc)
    db.flush()
    return doc


_numbers = iter(range(1, 100_000))


def _classified(
    db: Session, doc: Document, topic: Topic, pattern: QuestionPattern | None, n: int = 1
) -> None:
    for _ in range(n):
        q = Question(
            owner_id=doc.owner_id,
            origin=QuestionOrigin.SOURCE,
            exam_code="SSC_CHSL",
            subject=topic.subject,
            topic_id=topic.id,
            topic_status=TopicStatus.CONFIRMED,
            pattern_id=pattern.id if pattern else None,
            pattern_status=TopicStatus.CONFIRMED if pattern else TopicStatus.UNASSIGNED,
            stem=VENN,
            language="en",
            document_id=doc.id,
            source_question_number=next(_numbers),
            source_pages=[1],
            verification_status=VerificationStatus.UNVERIFIED,
        )
        q.options = [QuestionOption(position=1, label="1", text="a")]
        db.add(q)
    db.flush()


def _venn(db: Session) -> tuple[Topic, QuestionPattern]:
    topic = db.scalars(select(Topic).where(Topic.name == "Venn Diagrams")).one()
    pattern = db.scalars(
        select(QuestionPattern).where(
            QuestionPattern.topic_id == topic.id,
            QuestionPattern.name == "Relationship between classes",
        )
    ).one()
    return topic, pattern


def _radar(client: TestClient) -> dict[str, Any]:
    response = client.get("/api/v1/radar", params={"exam": "SSC_CHSL"})
    assert response.status_code == 200, response.text
    data: dict[str, Any] = response.json()
    return data


def test_sharing_is_off_by_default_and_counts_eligible_papers(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic, pattern = _venn(db_session)
    _classified(db_session, _shift_paper(db_session, user), topic, pattern)
    _classified(db_session, _shift_paper(db_session, user, shift=None), topic, pattern)  # no shift

    settings = db_client.get("/api/v1/radar/settings").json()
    assert settings == {"share": False, "eligible_papers": 1, "min_accounts": 2}

    on = db_client.put("/api/v1/radar/settings", json={"share": True}).json()
    assert on["share"] is True
    db_session.refresh(user)
    assert user.radar_opt_in_at is not None
    off = db_client.put("/api/v1/radar/settings", json={"share": False}).json()
    assert off["share"] is False


def test_radar_publishes_only_shifts_two_opted_in_accounts_agree_on(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic, pattern = _venn(db_session)
    user.radar_opt_in = True
    other = make_user(db_session, "other@example.com")
    other.radar_opt_in = True
    third = make_user(db_session, "third@example.com")  # did not opt in: never counted

    for owner in (user, other, third):
        _classified(db_session, _shift_paper(db_session, owner), topic, pattern, n=2)
    # A 2021 shift only one account reviewed: not published.
    _classified(
        db_session, _shift_paper(db_session, user, day=date(2021, 4, 12), shift=1), topic, None
    )
    db_session.flush()

    report = _radar(db_client)
    assert report["basis"] == {"shifts": 1, "years": [2019], "min_accounts": 2, "withheld": 0}
    venn = report["topics"][0]
    assert venn["name"] == "Venn Diagrams"
    assert venn["counts"] == {"shifts": 1, "questions": 2, "years": [{"year": 2019, "shifts": 1}]}
    assert venn["patterns"][0]["name"] == "Relationship between classes"
    # Nothing identifying: no account, paper or question ids, no filenames, no text.
    flat = str(report)
    for secret in (str(user.id), str(other.id), "chsl-", VENN, "example.com"):
        assert secret not in flat

    # Turning sharing off removes that account's counts at once.
    db_client.put("/api/v1/radar/settings", json={"share": False})
    assert _radar(db_client)["basis"]["shifts"] == 0


def test_disagreeing_counts_are_withheld(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    topic, pattern = _venn(db_session)
    user.radar_opt_in = True
    other = make_user(db_session, "other@example.com")
    other.radar_opt_in = True
    _classified(db_session, _shift_paper(db_session, user), topic, pattern, n=2)
    _classified(db_session, _shift_paper(db_session, other), topic, pattern, n=3)

    report = _radar(db_client)
    assert report["basis"]["shifts"] == 1
    assert report["basis"]["withheld"] == 2  # topic and pattern: 2 vs 3
    assert report["topics"] == []
