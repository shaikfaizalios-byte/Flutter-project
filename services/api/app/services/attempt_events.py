"""Attempt events: written when an answer becomes final, and when a key change re-marks it.

Calibration reads them from where it last stopped, so it no longer scans every session. Sessions
from before events existed are written once by ``backfill``.
"""

import uuid
from collections.abc import Iterable

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.events import AttemptEvent, JobCursor
from app.models.practice import (
    PracticeSession,
    SessionAnswer,
    SessionItem,
    SessionMode,
    SessionStatus,
)


def final_events(
    session: Session, practice: PracticeSession, answers: Iterable[SessionAnswer]
) -> None:
    if practice.owner_id is None:
        return  # from before accounts
    items = {i.position: i for i in practice.items}
    for answer in answers:
        if answer.is_correct is None:
            continue  # not answered, or not marked: nothing to count
        item = items.get(answer.position)
        session.add(
            AttemptEvent(
                owner_id=practice.owner_id,
                session_id=practice.id,
                position=answer.position,
                question_id=item.question_id if item else answer.question_id,
                exam_code=practice.exam_code,
                topic_id=item.topic_id if item else None,
                kind="final",
                correct=answer.is_correct,
                time_ms=answer.time_spent_ms,
            )
        )


def remarked_event(
    session: Session,
    practice: PracticeSession,
    item: SessionItem,
    answer: SessionAnswer,
    was: bool | None,
) -> None:
    """Only for answers that had counted, and only when the mark changed."""
    counted = practice.mode == SessionMode.PRACTICE or practice.status == SessionStatus.SUBMITTED
    if practice.owner_id is None or not counted or was == answer.is_correct:
        return
    session.add(
        AttemptEvent(
            owner_id=practice.owner_id,
            session_id=practice.id,
            position=answer.position,
            question_id=item.question_id,
            exam_code=practice.exam_code,
            topic_id=item.topic_id,
            kind="remarked",
            correct=answer.is_correct,
            was_correct=was,
            time_ms=answer.time_spent_ms,
        )
    )


def backfill(session: Session) -> int:
    """Writes final events for answers from before events existed. Runs once: an account with any
    event already has them all."""
    started = select(AttemptEvent.owner_id).distinct()
    rows = session.scalars(
        select(PracticeSession).where(
            PracticeSession.owner_id.is_not(None),
            PracticeSession.owner_id.not_in(started),
            (PracticeSession.status == SessionStatus.SUBMITTED)
            | (PracticeSession.mode == SessionMode.PRACTICE),
        )
    ).all()
    written = 0
    for practice in rows:
        answered = [a for a in practice.answers if a.is_correct is not None]
        final_events(session, practice, answered)
        written += len(answered)
    session.commit()
    return written


def read_since(
    session: Session, job: str, question_ids: set[uuid.UUID] | None = None
) -> tuple[set[uuid.UUID], int]:
    """Questions with events after the job's cursor, and the newest event id."""
    cursor = session.get(JobCursor, job)
    last = cursor.last_id if cursor else 0
    stmt = select(AttemptEvent.question_id).where(
        AttemptEvent.id > last, AttemptEvent.question_id.is_not(None)
    )
    if question_ids is not None:
        stmt = stmt.where(AttemptEvent.question_id.in_(question_ids))
    touched = {q for q in session.scalars(stmt.distinct()) if q is not None}
    newest = session.scalar(select(func.max(AttemptEvent.id))) or last
    return touched, newest


def move_cursor(session: Session, job: str, to: int) -> None:
    cursor = session.get(JobCursor, job)
    if cursor is None:
        session.add(JobCursor(name=job, last_id=to))
    else:
        cursor.last_id = to


def attempts_of(session: Session, question_id: uuid.UUID) -> list[tuple[bool, int | None]]:
    """Each attempt's current mark and time: the final event, as any re-marking left it."""
    latest: dict[tuple[uuid.UUID, int], tuple[bool, int | None]] = {}
    rows = session.execute(
        select(
            AttemptEvent.session_id,
            AttemptEvent.position,
            AttemptEvent.correct,
            AttemptEvent.time_ms,
        )
        .where(AttemptEvent.question_id == question_id)
        .order_by(AttemptEvent.id)
    ).all()
    for session_id, position, correct, time_ms in rows:
        key = (session_id, position)
        if correct is None:
            latest.pop(key, None)  # a re-marking that left no mark: the attempt no longer counts
        else:
            kept = latest.get(key, (False, None))[1]
            latest[key] = (bool(correct), time_ms if time_ms is not None else kept)
    return list(latest.values())
