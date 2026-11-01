"""Account data: every table is classified for the privacy export, the export holds every
row the account owns (and nobody else's), and account deletion removes all of it."""

import uuid
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient
from sqlalchemy import ForeignKey, func, select
from sqlalchemy.orm import Session

from app.database.base import Base
from app.models.ai import AIExplanation, AIGeneration
from app.models.concept import Concept
from app.models.document import Document, DocumentPage
from app.models.exam import Exam
from app.models.feedback import Suggestion
from app.models.plus import PlayPurchase, Subscription
from app.models.practice import Bookmark, PracticeSession, SessionAnswer, SessionItem
from app.models.progress import TopicCompletion
from app.models.question import (
    Passage,
    Question,
    QuestionFigure,
    QuestionIssue,
    QuestionOption,
    QuestionPattern,
    QuestionRevision,
    SyllabusImport,
    Topic,
)
from app.models.sync import SyncItem
from app.models.taxonomy import TaxonomyNode, TopicTaxonomyLink
from app.models.user import User
from app.services.account_data import CHILD_DATA, NOT_EXPORTED, OWNED_DATA
from tests.conftest import make_user

PASSWORD = "correct horse battery"  # make_user's password


def _foreign_key(table: str, column: str) -> ForeignKey:
    [fk] = Base.metadata.tables[table].c[column].foreign_keys
    return fk


def test_every_table_is_classified_once() -> None:
    owned = {m.__tablename__ for m in OWNED_DATA}
    children = {c.model.__tablename__ for c in CHILD_DATA}
    excluded = set(NOT_EXPORTED)
    assert not (owned & children or owned & excluded or children & excluded)
    unclassified = set(Base.metadata.tables) - owned - children - excluded
    assert not unclassified, f"Add to app/services/account_data.py: {sorted(unclassified)}"


def test_tables_with_an_account_column_are_exported_by_it_or_explained() -> None:
    owned = {m.__tablename__ for m in OWNED_DATA}
    for name, table in Base.metadata.tables.items():
        if "owner_id" in table.c:
            assert name in owned or name in NOT_EXPORTED, name
        if "user_id" in table.c:
            assert name in NOT_EXPORTED, name


def test_account_deletion_cascades_to_every_exported_table() -> None:
    for model in OWNED_DATA:
        fk = _foreign_key(model.__tablename__, "owner_id")
        assert fk.column.table.name == "users", model.__tablename__
        assert fk.ondelete == "CASCADE", model.__tablename__
    for child in CHILD_DATA:
        for column, parent in child.links:
            fk = _foreign_key(child.model.__tablename__, column)
            assert fk.column.table.name == parent, (child.model.__tablename__, column)
            assert fk.ondelete == "CASCADE", (child.model.__tablename__, column)
    for name in ("refresh_tokens", "account_codes"):
        assert _foreign_key(name, "user_id").ondelete == "CASCADE", name


def _fill_account(db: Session, user: User) -> None:
    """One row in every exported table, all on a private exam of the account."""
    now = datetime.now(UTC)
    code = f"MY_{uuid.uuid4().hex[:8].upper()}"
    db.add(Exam(code=code, name="My own exam", owner_id=user.id))
    db.flush()
    imported = SyllabusImport(owner_id=user.id, exam_code=code, name="Typed syllabus", kind="typed")
    db.add(imported)
    db.flush()
    topic = Topic(
        subject="Maths",
        name="Ratios",
        keywords=[],
        owner_id=user.id,
        exam_codes=[code],
        syllabus_import_id=imported.id,
    )
    db.add(topic)
    db.flush()
    db.add_all(
        [
            QuestionPattern(topic_id=topic.id, name="Mixtures", keywords=[]),
            TopicTaxonomyLink(
                topic_id=topic.id,
                node_id=db.scalars(
                    select(TaxonomyNode.id).where(TaxonomyNode.kind == "topic").limit(1)
                ).one(),
                status="suggested",
                source="rules",
            ),
            TopicCompletion(owner_id=user.id, topic_id=topic.id),
            Concept(
                owner_id=user.id,
                exam_code=code,
                title="Ratio rules",
                subject="Maths",
                topic="Ratios",
                language="en",
            ),
            Suggestion(owner_id=user.id, kind="add", text="Please add a ratio drill."),
            Subscription(owner_id=user.id, source="test", active_until=now + timedelta(days=1)),
            PlayPurchase(
                owner_id=user.id,
                purchase_token=f"token-{uuid.uuid4().hex}",
                product_id="plus_monthly",
                state="SUBSCRIPTION_STATE_ACTIVE",
                acknowledged=True,
                test_purchase=True,
            ),
            SyncItem(owner_id=user.id, entity="setting", item_id="theme", data={"value": "dark"}),
        ]
    )
    document = Document(
        owner_id=user.id,
        exam_code=code,
        language="en",
        original_filename="mine.pdf",
        size_bytes=1,
        sha256="0" * 64,
        storage_key=f"documents/{uuid.uuid4().hex}.pdf",
        page_count=1,
    )
    db.add(document)
    db.flush()
    passage = Passage(document_id=document.id, text="Read this.", source_pages=[1])
    db.add_all([DocumentPage(document_id=document.id, page_number=1, method="text"), passage])
    db.flush()
    question = Question(
        owner_id=user.id,
        exam_code=code,
        topic_id=topic.id,
        stem="2 : 3 = ?",
        language="en",
        document_id=document.id,
        source_question_number=1,
        source_pages=[1],
        passage_id=passage.id,
        correct_option_position=1,
    )
    question.options = [QuestionOption(position=1, label="a", text="4 : 6")]
    db.add(question)
    db.flush()
    session = PracticeSession(
        owner_id=user.id, mode="practice", exam_code=code, selection={}, started_at=now
    )
    session.items = [
        SessionItem(
            position=1,
            question_id=question.id,
            correct_position=1,
            option_count=1,
            marks_correct=1,
            marks_wrong=0,
            question_verified=False,
        )
    ]
    db.add(session)
    db.flush()
    db.add_all(
        [
            QuestionIssue(document_id=document.id, question_id=question.id, code="test"),
            QuestionFigure(
                question_id=question.id,
                kind="stem",
                sort_order=1,
                page_number=1,
                box=[0.0, 0.0, 1.0, 1.0],
                width=1,
                height=1,
                data=b"\x89PNG",
            ),
            AIExplanation(
                question_id=question.id,
                text="Both sides double.",
                language="en",
                provider="fake",
                model="fake",
                prompt_version="1",
            ),
            Bookmark(question_id=question.id),
            QuestionRevision(
                question_id=question.id,
                action="extracted",
                actor="rules",
                changed=["stem"],
                snapshot={"stem": "2 : 3 = ?"},
            ),
            SessionAnswer(
                session_id=session.id,
                position=1,
                question_id=question.id,
                selected_position=1,
                is_correct=True,
                client_seq=1,
                answered_at=now,
            ),
            AIGeneration(
                owner_id=user.id,
                task="explanation",
                provider="fake",
                model="fake",
                prompt_version="1",
                outcome="ok",
            ),
        ]
    )
    db.flush()


def test_export_holds_every_owned_row_and_deletion_removes_them(
    db_client: TestClient, db_session: Session, user: User
) -> None:
    other = make_user(db_session, email="other@example.com")
    _fill_account(db_session, user)
    _fill_account(db_session, other)

    export = db_client.get("/api/v1/auth/me/export")

    assert export.status_code == 200, export.text
    data = export.json()["data"]
    for model in OWNED_DATA:
        assert data[model.__tablename__], f"{model.__tablename__} missing from the export"
        assert {str(r["owner_id"]) for r in data[model.__tablename__]} == {str(user.id)}
    for child in CHILD_DATA:
        assert len(data[child.model.__tablename__]) == 1, child.model.__tablename__
    assert "data" not in data["question_figures"][0]  # image bytes are left out
    assert "password_hash" not in export.text

    def child_counts() -> dict[str, int | None]:
        return {
            c.model.__tablename__: db_session.scalar(select(func.count()).select_from(c.model))
            for c in CHILD_DATA
        }

    before = child_counts()
    deleted = db_client.post("/api/v1/auth/me/delete", json={"password": PASSWORD})

    assert deleted.status_code == 204, deleted.text
    for model in OWNED_DATA:
        mine = select(func.count()).select_from(model).where(model.owner_id == user.id)
        theirs = select(func.count()).select_from(model).where(model.owner_id == other.id)
        assert db_session.scalar(mine) == 0, model.__tablename__
        assert db_session.scalar(theirs) == 1, model.__tablename__
    after = child_counts()
    for name, count in before.items():
        assert count is not None and after[name] == count - 1, name  # only the account's row
