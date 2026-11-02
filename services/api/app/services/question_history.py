"""Writing and reading question history (rules in app/domain/question_history.py)."""

import uuid
from collections.abc import Iterable
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain import question_history
from app.domain.question_history import Action, Actor
from app.models.question import Question, QuestionRevision


def current_snapshot(question: Question) -> dict[str, Any]:
    return question_history.snapshot(
        stem=question.stem,
        options=[(o.label, o.text) for o in question.options],
        answer_type=question.answer_type or "choice",
        correct_option_position=question.correct_option_position,
        typed_answer=question.typed_answer,
        model_answer=question.model_answer,
        answer_source=question.answer_source,
        explanation=question.explanation,
    )


def add_first_revision(question: Question, action: Action, actor: Actor) -> None:
    """For a question being created: its state as read (or generated) goes into history."""
    question.revisions.append(
        QuestionRevision(
            action=action,
            actor=actor,
            changed=list(question_history.TRACKED_FIELDS),
            snapshot=current_snapshot(question),
        )
    )


def record_edit(session: Session, question: Question, before: dict[str, Any]) -> None:
    """Adds an "edited" revision when a reviewer's change touched a tracked field."""
    after = current_snapshot(question)
    changed = question_history.changed_fields(before, after)
    if changed:
        session.add(
            QuestionRevision(
                question_id=question.id,
                action="edited",
                actor="reviewer",
                changed=changed,
                snapshot=after,
            )
        )


def extracted_snapshots(
    session: Session, question_ids: Iterable[uuid.UUID]
) -> dict[uuid.UUID, dict[str, Any]]:
    """Each question's "extracted" snapshot (the question as read from its paper)."""
    ids = list(question_ids)
    if not ids:
        return {}
    rows = session.execute(
        select(QuestionRevision.question_id, QuestionRevision.snapshot)
        .where(QuestionRevision.question_id.in_(ids), QuestionRevision.action == "extracted")
        .order_by(QuestionRevision.created_at.desc())
    ).all()
    return {question_id: snap for question_id, snap in rows}  # earliest wins


def revisions(session: Session, question_id: uuid.UUID) -> list[QuestionRevision]:
    return list(
        session.scalars(
            select(QuestionRevision)
            .where(QuestionRevision.question_id == question_id)
            .order_by(QuestionRevision.created_at, QuestionRevision.id)
        ).all()
    )
