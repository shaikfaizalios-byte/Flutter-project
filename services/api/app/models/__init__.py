"""Import every model here so Alembic autogenerate sees the full metadata."""

from app.models.concept import Concept
from app.models.document import Document, DocumentPage
from app.models.exam import Exam
from app.models.question import (
    ExamFormat,
    Passage,
    Question,
    QuestionIssue,
    QuestionOption,
    Topic,
)

__all__ = [
    "Concept",
    "Document",
    "DocumentPage",
    "Exam",
    "ExamFormat",
    "Passage",
    "Question",
    "QuestionIssue",
    "QuestionOption",
    "Topic",
]
