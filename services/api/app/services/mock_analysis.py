"""After a mock: marks and time per question, accuracy by chapter, the learner's own history, and a
percentile only where real attempts allow one."""

import uuid
from collections import defaultdict

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.domain.errors import ConflictError, NotFoundError
from app.domain.mock_analysis import percentile
from app.domain.scoring import score_session
from app.models.practice import PracticeSession, SessionMode, SessionStatus
from app.models.question import Topic
from app.schemas.practice import (
    ChapterAccuracy,
    MockAnalysis,
    MockHistoryRow,
    PercentileRead,
    QuestionAnalysis,
)
from app.services.chapter_map import unit_topics
from app.services.practice_service import given_answer, scored_item

MAX_HISTORY = 10


class MockAnalysisService:
    def __init__(self, session: Session, owner_id: uuid.UUID) -> None:
        self._session = session
        self._owner_id = owner_id

    def analysis(self, session_id: uuid.UUID) -> MockAnalysis:
        practice = self._session.scalar(
            select(PracticeSession)
            .where(PracticeSession.id == session_id)
            .options(selectinload(PracticeSession.items), selectinload(PracticeSession.answers))
        )
        if practice is None or practice.owner_id != self._owner_id:
            raise NotFoundError("Session not found.")
        if practice.mode != SessionMode.MOCK or practice.status != SessionStatus.SUBMITTED:
            raise ConflictError("not_a_finished_mock", "This is for finished mock tests.")
        answers = {a.position: a for a in practice.answers}
        topics = dict(
            self._session.execute(
                select(Topic.id, Topic.name).where(
                    Topic.id.in_({i.topic_id for i in practice.items if i.topic_id})
                )
            )
            .tuples()
            .all()
        )
        units = unit_topics(self._session, practice.exam_code or "", self._owner_id)
        questions = []
        chapters: dict[tuple[str, str], list[QuestionAnalysis]] = defaultdict(list)
        for item in practice.items:
            answer = answers.get(item.position)
            given = given_answer(answer) if answer is not None else None
            one = scored_item(item)
            marks = score_session([one], {item.position: given}).total.score
            status = (
                "dropped"
                if item.key_outcome == "dropped"
                else "unattempted"
                if given is None
                else "correct"
                if answer is not None and answer.is_correct
                else "wrong"
            )
            topic = topics.get(item.topic_id) if item.topic_id else None
            row = QuestionAnalysis(
                position=item.position,
                section=item.section,
                topic=topic,
                status=status,
                marks=float(marks),
                time_ms=answer.time_spent_ms if answer else None,
                marked=answer.marked_for_review if answer else False,
            )
            questions.append(row)
            chapter, subject = (
                units.get(item.topic_id, (topic or "", ""))
                if item.topic_id
                else (
                    "",
                    "",
                )
            )
            if chapter:
                chapters[(subject or item.subject or "", chapter)].append(row)
        return MockAnalysis(
            questions=questions,
            chapters=sorted(
                (_chapter(subject, name, rows) for (subject, name), rows in chapters.items()),
                key=lambda c: (c.subject, c.name),
            ),
            history=self._history(practice),
            percentile=self._percentile(practice),
        )

    def _peers(self, practice: PracticeSession) -> list[PracticeSession]:
        """Finished attempts at the same paper, whole or the same section."""
        rows = self._session.scalars(
            select(PracticeSession)
            .where(
                PracticeSession.exam_format_id == practice.exam_format_id,
                PracticeSession.mode == SessionMode.MOCK,
                PracticeSession.status == SessionStatus.SUBMITTED,
                PracticeSession.score.is_not(None),
            )
            .order_by(PracticeSession.submitted_at)
        ).all()
        wanted = (practice.selection or {}).get("section")
        return [r for r in rows if (r.selection or {}).get("section") == wanted]

    def _history(self, practice: PracticeSession) -> list[MockHistoryRow]:
        own = [p for p in self._peers(practice) if p.owner_id == self._owner_id]
        return [
            MockHistoryRow(
                session_id=p.id,
                submitted_at=p.submitted_at,
                score=float(p.score or 0),
                max_score=float(p.max_score or 0),
                current=p.id == practice.id,
            )
            for p in own[-MAX_HISTORY:]
        ]

    def _percentile(self, practice: PracticeSession) -> PercentileRead | None:
        if (practice.selection or {}).get("section") or practice.score is None:
            return None  # a single section has no paper's worth of comparison
        first: dict[uuid.UUID | None, float] = {}
        for attempt in self._peers(practice):
            first.setdefault(attempt.owner_id, float(attempt.score or 0))
        found = percentile(float(practice.score), list(first.values()))
        return PercentileRead(percent=found.percent, accounts=found.accounts) if found else None


def _chapter(subject: str, name: str, rows: list[QuestionAnalysis]) -> ChapterAccuracy:
    return ChapterAccuracy(
        subject=subject,
        name=name,
        correct=sum(r.status == "correct" for r in rows),
        wrong=sum(r.status == "wrong" for r in rows),
        unattempted=sum(r.status == "unattempted" for r in rows),
        time_ms=sum(r.time_ms or 0 for r in rows),
    )
