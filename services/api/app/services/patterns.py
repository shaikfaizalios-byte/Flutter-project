"""Keeping a question's pattern (question type) suggestion in step with its topic.

Shared by segmentation, review edits and the AI topic step. A confirmed pattern of the
question's current topic is never touched; anything else is re-suggested from the rules
(or cleared when nothing matches).
"""

import uuid

from sqlalchemy import ColumnElement, or_, select
from sqlalchemy.orm import Session

from app.domain.topics import PatternCandidate, suggest_pattern
from app.models.question import Question, QuestionPattern, TopicStatus


def visible_pattern(owner_id: uuid.UUID | None) -> ColumnElement[bool]:
    """The ONE rule for models: the shared list, plus the account's own."""
    return or_(QuestionPattern.owner_id.is_(None), QuestionPattern.owner_id == owner_id)


def pattern_candidates(session: Session, owner_id: uuid.UUID | None) -> list[PatternCandidate]:
    return [
        PatternCandidate(p.id, p.topic_id, p.name, p.keywords)
        for p in session.scalars(select(QuestionPattern).where(visible_pattern(owner_id))).all()
    ]


def refresh_pattern(question: Question, candidates: list[PatternCandidate]) -> None:
    by_id = {c.id: c for c in candidates}
    current = by_id.get(question.pattern_id) if question.pattern_id else None
    if (
        question.pattern_status == TopicStatus.CONFIRMED
        and current is not None
        and current.topic_id == question.topic_id
    ):
        return
    suggestion = suggest_pattern(question.stem, topic_id=question.topic_id, patterns=candidates)
    if suggestion is None:
        clear_pattern(question)
        return
    question.pattern_id = suggestion.pattern_id
    question.pattern_status = TopicStatus.SUGGESTED
    question.pattern_suggestion_reason = suggestion.reason[:200]


def clear_pattern(question: Question) -> None:
    question.pattern_id = None
    question.pattern_status = TopicStatus.UNASSIGNED
    question.pattern_suggestion_reason = None
