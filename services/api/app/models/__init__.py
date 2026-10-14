"""Import every model here so Alembic autogenerate sees the full metadata."""

from app.models.ai import AIExplanation, AIGeneration
from app.models.concept import Concept
from app.models.document import Document, DocumentPage
from app.models.exam import Exam
from app.models.ops import RateLimitCounter
from app.models.practice import Bookmark, PracticeSession, SessionAnswer, SessionItem
from app.models.question import (
    ExamFormat,
    Passage,
    Question,
    QuestionIssue,
    QuestionOption,
    Topic,
)
from app.models.sync import SyncItem
from app.models.user import AccountCode, RefreshToken, User

__all__ = [
    "AIExplanation",
    "AIGeneration",
    "AccountCode",
    "Bookmark",
    "Concept",
    "Document",
    "DocumentPage",
    "Exam",
    "ExamFormat",
    "Passage",
    "PracticeSession",
    "Question",
    "QuestionIssue",
    "QuestionOption",
    "RateLimitCounter",
    "RefreshToken",
    "SessionAnswer",
    "SessionItem",
    "SyncItem",
    "Topic",
    "User",
]
