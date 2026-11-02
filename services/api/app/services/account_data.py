"""Which server data belongs to an account: the privacy export reads it, and account deletion
removes it (every link below is ON DELETE CASCADE from `users`).

Every table is listed here, either as exported or as left out with a reason;
`tests/test_account_data.py` fails when a table is added without being classified, so new
learner data can't be missed by the export or survive a deletion.
"""

from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any
from uuid import UUID

from sqlalchemy import LargeBinary, or_, select
from sqlalchemy.orm import Session

from app.models.ai import AIExplanation, AIGeneration
from app.models.concept import Concept
from app.models.content import ContentReport, ContentRights
from app.models.document import Document, DocumentPage
from app.models.exam import Exam
from app.models.feedback import Suggestion
from app.models.plus import PlayPurchase, Subscription
from app.models.practice import Bookmark, PracticeSession, SessionAnswer, SessionItem
from app.models.progress import TopicCompletion
from app.models.question import (
    Passage,
    QuestionFigure,
    QuestionIssue,
    QuestionOption,
    QuestionPattern,
    QuestionRevision,
    SyllabusImport,
    Topic,
)
from app.models.question import Question as QuestionModel
from app.models.sync import SyncItem
from app.models.taxonomy import TopicTaxonomyLink


@dataclass(frozen=True, slots=True)
class ChildData:
    """Rows that belong to the account through a parent it owns.

    ``links`` are (column, parent table) pairs; a row is exported when any of them points at
    one of the account's own parent rows (parents are exported first, by their ``id``).
    """

    model: type[Any]
    links: tuple[tuple[str, str], ...]


# Rows with the account's id in `owner_id`. Private exams and own topics only: catalog exams
# and shared topics have no owner and are reference data.
OWNED_DATA: tuple[type[Any], ...] = (
    Exam,
    Topic,
    SyllabusImport,
    TopicCompletion,
    Concept,
    Document,
    QuestionModel,
    PracticeSession,
    AIGeneration,
    Suggestion,
    ContentReport,
    Subscription,
    PlayPurchase,
    SyncItem,
)

# In order: a parent is always listed before its children.
CHILD_DATA: tuple[ChildData, ...] = (
    ChildData(QuestionPattern, (("topic_id", "topics"),)),
    ChildData(TopicTaxonomyLink, (("topic_id", "topics"),)),
    ChildData(DocumentPage, (("document_id", "documents"),)),
    ChildData(ContentRights, (("document_id", "documents"),)),
    ChildData(Passage, (("document_id", "documents"),)),
    ChildData(QuestionOption, (("question_id", "questions"),)),
    ChildData(QuestionIssue, (("question_id", "questions"), ("document_id", "documents"))),
    # Figure metadata only: the crops themselves are images of the account's own paper.
    ChildData(QuestionFigure, (("question_id", "questions"),)),
    ChildData(AIExplanation, (("question_id", "questions"),)),
    ChildData(QuestionRevision, (("question_id", "questions"),)),
    ChildData(Bookmark, (("question_id", "questions"),)),
    # By session only: a session may include shared-bank questions owned by the operator,
    # and the operator's export must never contain other learners' answers.
    ChildData(SessionItem, (("session_id", "practice_sessions"),)),
    ChildData(SessionAnswer, (("session_id", "practice_sessions"),)),
)

# Tables that are not exported, and why.
NOT_EXPORTED: dict[str, str] = {
    "users": "exported as `user` (without the password hash)",
    "refresh_tokens": "credential hashes; removed with the account",
    "account_codes": "one-time code hashes that expire in minutes; removed with the account",
    "rate_limit_counters": "keyed by a hash of the client, not linked to an account",
    "exam_formats": "official reference data, not the learner's",
    "taxonomy_nodes": "canonical topics: reference data, not the learner's",
    "taxonomy_labels": "names of canonical topics: reference data",
    "languages": "the supported content languages: reference data",
    "audit_events": "operator decisions about shared content (ids and reasons, no content)",
    "billing_events": "audit of store checks and notifications (token hashes, no content); kept "
    "after deletion with the account link cleared; the purchases are in play_purchases",
}


def _row_dict(row: Any) -> dict[str, Any]:
    return {
        attr.key: getattr(row, attr.key)
        for attr in row.__mapper__.column_attrs
        if not isinstance(attr.columns[0].type, LargeBinary)
    }


def account_data(session: Session, owner_id: UUID) -> dict[str, list[dict[str, Any]]]:
    """Every exported row of the account, by table name."""
    data: dict[str, list[dict[str, Any]]] = {}
    ids: dict[str, Sequence[Any]] = {}
    for model in OWNED_DATA:
        rows = session.scalars(select(model).where(model.owner_id == owner_id)).all()
        data[model.__tablename__] = [_row_dict(r) for r in rows]
        if "id" in model.__table__.c:
            ids[model.__tablename__] = [r.id for r in rows]
    for child in CHILD_DATA:
        conditions = [
            getattr(child.model, column).in_(ids[parent])
            for column, parent in child.links
            if ids.get(parent)
        ]
        rows = (
            session.scalars(select(child.model).where(or_(*conditions))).all() if conditions else []
        )
        data[child.model.__tablename__] = [_row_dict(r) for r in rows]
    return data
