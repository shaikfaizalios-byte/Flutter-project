"""Import every model here so Alembic autogenerate sees the full metadata."""

from app.models.ai import AIExplanation, AIGeneration
from app.models.concept import Concept
from app.models.content import AuditEvent, ContentReport, ContentRights
from app.models.document import Document, DocumentPage
from app.models.exam import Exam
from app.models.feedback import Suggestion
from app.models.ops import RateLimitCounter
from app.models.plus import BillingEvent, PlayPurchase, Subscription
from app.models.practice import Bookmark, PracticeSession, SessionAnswer, SessionItem
from app.models.progress import TopicCompletion
from app.models.question import (
    ExamFormat,
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
from app.models.taxonomy import TaxonomyLabel, TaxonomyNode, TopicTaxonomyLink
from app.models.user import AccountCode, RefreshToken, User

__all__ = [
    "AIExplanation",
    "AIGeneration",
    "AccountCode",
    "AuditEvent",
    "BillingEvent",
    "Bookmark",
    "Concept",
    "ContentReport",
    "ContentRights",
    "Document",
    "DocumentPage",
    "Exam",
    "ExamFormat",
    "Passage",
    "PlayPurchase",
    "PracticeSession",
    "Question",
    "QuestionFigure",
    "QuestionIssue",
    "QuestionOption",
    "QuestionPattern",
    "QuestionRevision",
    "RateLimitCounter",
    "RefreshToken",
    "SessionAnswer",
    "SessionItem",
    "Subscription",
    "Suggestion",
    "SyllabusImport",
    "SyncItem",
    "TaxonomyLabel",
    "TaxonomyNode",
    "Topic",
    "TopicCompletion",
    "TopicTaxonomyLink",
    "User",
]
