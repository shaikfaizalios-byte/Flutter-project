"""Import every model here so Alembic autogenerate sees the full metadata."""

from app.models.ai import AIExplanation, AIGeneration
from app.models.concept import Concept
from app.models.content import AuditEvent, ContentReport, ContentRights
from app.models.descriptive import DescriptiveSession, DescriptiveStep
from app.models.document import Document, DocumentPage
from app.models.exam import Exam
from app.models.feedback import Suggestion
from app.models.ladder import (
    GeneratedReview,
    LadderBenchmarkRun,
    LadderGate,
    LadderSession,
    LadderStep,
)
from app.models.language import LanguageRow
from app.models.library import LibraryEntry, LibraryVersion
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
from app.models.repeat_analysis import ConceptHint, ModelProposal
from app.models.syllabus import SyllabusNode, SyllabusVersion
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
    "ConceptHint",
    "ContentReport",
    "ContentRights",
    "DescriptiveSession",
    "DescriptiveStep",
    "Document",
    "DocumentPage",
    "Exam",
    "ExamFormat",
    "GeneratedReview",
    "LadderBenchmarkRun",
    "LadderGate",
    "LadderSession",
    "LadderStep",
    "LanguageRow",
    "LibraryEntry",
    "LibraryVersion",
    "ModelProposal",
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
    "SyllabusNode",
    "SyllabusVersion",
    "SyncItem",
    "TaxonomyLabel",
    "TaxonomyNode",
    "Topic",
    "TopicCompletion",
    "TopicTaxonomyLink",
    "User",
]
