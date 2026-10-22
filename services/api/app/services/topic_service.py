"""Exams and topics a learner can see and manage.

Visibility rules, used everywhere topics are listed or suggested:

- a topic is visible to a learner when it is shared (``owner_id`` NULL) or their own;
- it applies to an exam when ``exam_codes`` is NULL (every exam) or contains the exam.

Learners create their own exams (private, code ``MY_...``) and their own topics and question
types for any exam they can see. Shared taxonomy and catalog exams are read-only for them.
"""

import secrets
import uuid
from collections.abc import Sequence
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import exists, func, or_, select, update
from sqlalchemy.orm import Session

from app.domain.errors import ConflictError, InvalidReferenceError, NotFoundError
from app.models.concept import Concept
from app.models.document import Document
from app.models.exam import CUSTOM_EXAM_PREFIX, Exam
from app.models.progress import TopicCompletion
from app.models.question import Question, QuestionPattern, SyllabusImport, Topic, TopicStatus
from app.repositories.exam_repository import ExamRepository
from app.schemas.exam import (
    CustomExamCreate,
    CustomExamUpdate,
    ExamRead,
    OwnTopicRead,
    PatternCreate,
    SyllabusImportRead,
    SyllabusSource,
    TopicCreate,
    TopicUpdate,
)
from app.schemas.question import PatternRead

MAX_OWN_EXAMS = 30
MAX_OWN_TOPICS_PER_EXAM = 300


def topic_scope(owner_id: uuid.UUID | None, exam_code: str | None) -> list[Any]:
    """SQL conditions: topics visible to ``owner_id`` (and applying to ``exam_code``)."""
    conditions: list[Any] = [
        or_(Topic.owner_id.is_(None), Topic.owner_id == owner_id)
        if owner_id is not None
        else Topic.owner_id.is_(None)
    ]
    if exam_code is not None:
        conditions.append(or_(Topic.exam_codes.is_(None), Topic.exam_codes.contains([exam_code])))
    return conditions


def visible_topics(
    session: Session, owner_id: uuid.UUID | None, exam_code: str | None
) -> Sequence[Topic]:
    return session.scalars(
        select(Topic).where(*topic_scope(owner_id, exam_code)).order_by(Topic.subject, Topic.name)
    ).all()


def exam_read(exam: Exam) -> ExamRead:
    return ExamRead(
        code=exam.code,
        name=exam.name,
        short_name=exam.short_name or exam.name,
        category=exam.category,
        featured=exam.featured,
        custom=exam.owner_id is not None,
    )


def _own_topic_read(topic: Topic, completed: bool = False) -> OwnTopicRead:
    return OwnTopicRead(
        id=topic.id,
        subject=topic.subject,
        name=topic.name,
        keywords=list(topic.keywords),
        own=topic.owner_id is not None,
        exam_codes=topic.exam_codes,
        completed=completed,
        syllabus_import_id=topic.syllabus_import_id,
    )


class TopicService:
    def __init__(self, session: Session, owner_id: uuid.UUID) -> None:
        self._session = session
        self._owner_id = owner_id
        self._exams = ExamRepository(session)

    # --- exams -------------------------------------------------------------------------

    def exams(self) -> list[ExamRead]:
        return [exam_read(e) for e in self._exams.list_visible(self._owner_id)]

    def create_exam(self, data: CustomExamCreate) -> ExamRead:
        own = self._session.scalar(
            select(func.count()).select_from(Exam).where(Exam.owner_id == self._owner_id)
        )
        if (own or 0) >= MAX_OWN_EXAMS:
            raise ConflictError("too_many_exams", f"At most {MAX_OWN_EXAMS} own exams.")
        exam = Exam(
            code=f"{CUSTOM_EXAM_PREFIX}{secrets.token_hex(8).upper()}",
            name=data.name,
            owner_id=self._owner_id,
        )
        self._session.add(exam)
        self._session.commit()
        return exam_read(exam)

    def rename_exam(self, code: str, data: CustomExamUpdate) -> ExamRead:
        exam = self._own_exam(code)
        exam.name = data.name
        self._session.commit()
        return exam_read(exam)

    def delete_exam(self, code: str) -> None:
        """Only an unused own exam can be deleted (papers and notes keep their exam)."""
        exam = self._own_exam(code)
        in_use = self._session.scalar(
            select(
                exists().where(Document.exam_code == code)
                | exists().where(Question.exam_code == code)
                | exists().where(Concept.exam_code == code)
            )
        )
        if in_use:
            raise ConflictError(
                "exam_in_use", "Papers, questions or notes still use this exam; delete them first."
            )
        for topic in self._session.scalars(
            select(Topic).where(Topic.owner_id == self._owner_id, Topic.exam_codes.contains([code]))
        ):
            self._session.delete(topic)
        self._session.delete(exam)
        self._session.commit()

    def _own_exam(self, code: str) -> Exam:
        exam = self._session.get(Exam, code)
        if exam is None or exam.owner_id != self._owner_id:
            raise NotFoundError("Exam not found.")
        return exam

    def _visible_exam(self, code: str) -> Exam:
        exam = self._exams.get_visible(code, self._owner_id)
        if exam is None:
            raise InvalidReferenceError(f"Unknown exam '{code}'.")
        return exam

    # --- topics ------------------------------------------------------------------------

    def topics(self, exam_code: str) -> list[OwnTopicRead]:
        self._visible_exam(exam_code)
        done = set(
            self._session.scalars(
                select(TopicCompletion.topic_id).where(TopicCompletion.owner_id == self._owner_id)
            )
        )
        return [
            _own_topic_read(t, completed=t.id in done)
            for t in visible_topics(self._session, self._owner_id, exam_code)
        ]

    def set_completed(self, topic_id: uuid.UUID, completed: bool) -> OwnTopicRead:
        """Marks a visible topic (shared or own) as revised, or not, for this learner."""
        topic = self._session.scalars(
            select(Topic).where(Topic.id == topic_id, *topic_scope(self._owner_id, None))
        ).first()
        if topic is None:
            raise NotFoundError("Topic not found.")
        existing = self._session.get(TopicCompletion, (self._owner_id, topic_id))
        if completed and existing is None:
            self._session.add(TopicCompletion(owner_id=self._owner_id, topic_id=topic_id))
        elif not completed and existing is not None:
            self._session.delete(existing)
        self._session.commit()
        return _own_topic_read(topic, completed=completed)

    def create_topic(self, data: TopicCreate) -> OwnTopicRead:
        topic = self._new_topic(data)
        self._session.commit()
        return _own_topic_read(topic)

    def create_topics(
        self,
        exam_code: str,
        items: Sequence[TopicCreate],
        source: SyllabusSource | None = None,
    ) -> list[OwnTopicRead]:
        """Saves several topics at once (an accepted draft); duplicates are skipped. With a
        ``source`` (a syllabus), the new topics are grouped under one syllabus import."""
        created = []
        seen: set[tuple[str, str]] = set()
        for item in items:
            if item.exam_code != exam_code:
                raise InvalidReferenceError("All topics must belong to the same exam.")
            key = (item.subject.casefold(), item.name.casefold())
            if key in seen or self._duplicate(exam_code, item.subject, item.name):
                continue
            seen.add(key)
            created.append(self._new_topic(item))
        if source is not None and created:
            record = SyllabusImport(
                owner_id=self._owner_id,
                exam_code=exam_code,
                name=source.name,
                kind=source.kind,
                # The moment of this import (now() is fixed for a whole transaction).
                created_at=datetime.now(UTC),
            )
            self._session.add(record)
            self._session.flush()
            for topic in created:
                topic.syllabus_import_id = record.id
        self._session.commit()
        return [_own_topic_read(t) for t in created]

    def syllabus_imports(self, exam_code: str) -> list[SyllabusImportRead]:
        self._visible_exam(exam_code)
        rows = self._session.execute(
            select(SyllabusImport, func.count(Topic.id))
            .outerjoin(Topic, Topic.syllabus_import_id == SyllabusImport.id)
            .where(
                SyllabusImport.owner_id == self._owner_id,
                SyllabusImport.exam_code == exam_code,
            )
            .group_by(SyllabusImport.id)
            .order_by(SyllabusImport.created_at.desc())
        ).all()
        return [
            SyllabusImportRead(
                id=r.id, name=r.name, kind=r.kind, created_at=r.created_at, topic_count=count
            )
            for r, count in rows
        ]

    def delete_syllabus_import(self, import_id: uuid.UUID) -> int:
        """Removes a syllabus import and all its topics (questions go back to no topic).
        Returns how many topics were removed."""
        record = self._session.get(SyllabusImport, import_id)
        if record is None or record.owner_id != self._owner_id:
            raise NotFoundError("Syllabus import not found.")
        topics = list(
            self._session.scalars(
                select(Topic).where(
                    Topic.syllabus_import_id == import_id, Topic.owner_id == self._owner_id
                )
            )
        )
        if topics:
            self._delete(topics, commit=False)
        self._session.delete(record)
        self._session.commit()
        self._session.expire_all()
        return len(topics)

    def update_topic(self, topic_id: uuid.UUID, data: TopicUpdate) -> OwnTopicRead:
        topic = self._own_topic(topic_id)
        changes = data.model_dump(exclude_unset=True, exclude_none=True)
        subject = changes.get("subject", topic.subject)
        name = changes.get("name", topic.name)
        exam_code = (topic.exam_codes or [""])[0]
        if (subject, name) != (topic.subject, topic.name) and self._duplicate(
            exam_code, subject, name, exclude=topic.id
        ):
            raise ConflictError("topic_exists", "This exam already has that topic.")
        for field_name, value in changes.items():
            setattr(topic, field_name, value)
        if "subject" in changes:  # questions follow their topic's subject
            self._session.execute(
                update(Question)
                .where(Question.topic_id == topic.id, Question.owner_id == self._owner_id)
                .values(subject=topic.subject)
            )
        self._session.commit()
        self._session.expire_all()
        return _own_topic_read(topic)

    def delete_topic(self, topic_id: uuid.UUID) -> None:
        """Questions of the topic go back to "no topic" (their patterns too)."""
        self._delete([self._own_topic(topic_id)])

    def delete_topics(self, topic_ids: Sequence[uuid.UUID]) -> int:
        """Removes the learner's own topics among ``topic_ids`` (e.g. a syllabus import they
        don't want); shared topics and other learners' topics are left alone."""
        topics = self._session.scalars(
            select(Topic).where(Topic.id.in_(topic_ids), Topic.owner_id == self._owner_id)
        ).all()
        if topics:
            self._delete(list(topics))
        return len(topics)

    def _delete(self, topics: list[Topic], *, commit: bool = True) -> None:
        ids = [t.id for t in topics]
        self._session.execute(
            update(Question)
            .where(Question.topic_id.in_(ids))
            .values(
                topic_id=None,
                topic_status=TopicStatus.UNASSIGNED,
                topic_suggested_by=None,
                topic_suggestion_reason=None,
                pattern_id=None,
                pattern_status=TopicStatus.UNASSIGNED,
                pattern_suggestion_reason=None,
            )
        )
        for topic in topics:
            self._session.delete(topic)
        if commit:
            self._session.commit()
            self._session.expire_all()  # questions changed in bulk above

    def _new_topic(self, data: TopicCreate) -> Topic:
        self._visible_exam(data.exam_code)
        if self._duplicate(data.exam_code, data.subject, data.name):
            raise ConflictError("topic_exists", "This exam already has that topic.")
        count = self._session.scalar(
            select(func.count())
            .select_from(Topic)
            .where(Topic.owner_id == self._owner_id, Topic.exam_codes.contains([data.exam_code]))
        )
        if (count or 0) >= MAX_OWN_TOPICS_PER_EXAM:
            raise ConflictError("too_many_topics", "This exam has too many topics.")
        topic = Topic(
            subject=data.subject,
            name=data.name,
            keywords=_clean_keywords(data.keywords, data.name),
            owner_id=self._owner_id,
            exam_codes=[data.exam_code],
        )
        self._session.add(topic)
        self._session.flush()
        return topic

    def _duplicate(
        self, exam_code: str, subject: str, name: str, exclude: uuid.UUID | None = None
    ) -> bool:
        stmt = select(Topic.id).where(
            *topic_scope(self._owner_id, exam_code),
            func.lower(Topic.subject) == subject.casefold(),
            func.lower(Topic.name) == name.casefold(),
        )
        if exclude is not None:
            stmt = stmt.where(Topic.id != exclude)
        return self._session.scalar(stmt.limit(1)) is not None

    def _own_topic(self, topic_id: uuid.UUID) -> Topic:
        topic = self._session.get(Topic, topic_id)
        if topic is None or topic.owner_id != self._owner_id:
            raise NotFoundError("Topic not found.")
        return topic

    # --- patterns (question types) under own topics ------------------------------------

    def create_pattern(self, data: PatternCreate) -> PatternRead:
        topic = self._own_topic(data.topic_id)
        clash = self._session.scalar(
            select(QuestionPattern.id).where(
                QuestionPattern.topic_id == topic.id,
                func.lower(QuestionPattern.name) == data.name.casefold(),
            )
        )
        if clash is not None:
            raise ConflictError("pattern_exists", "This topic already has that question type.")
        pattern = QuestionPattern(
            topic_id=topic.id,
            name=data.name,
            keywords=_clean_keywords(data.keywords, data.name),
        )
        self._session.add(pattern)
        self._session.commit()
        return PatternRead.model_validate(pattern)

    def delete_pattern(self, pattern_id: uuid.UUID) -> None:
        pattern = self._session.get(QuestionPattern, pattern_id)
        if pattern is None:
            raise NotFoundError("Question type not found.")
        self._own_topic(pattern.topic_id)  # only under the learner's own topics
        self._session.execute(
            update(Question)
            .where(Question.pattern_id == pattern.id)
            .values(
                pattern_id=None,
                pattern_status=TopicStatus.UNASSIGNED,
                pattern_suggestion_reason=None,
            )
        )
        self._session.delete(pattern)
        self._session.commit()
        self._session.expire_all()


def _clean_keywords(keywords: Sequence[str], name: str) -> list[str]:
    """Distinct keywords; without any, the name itself (so suggestions can work at all)."""
    seen: dict[str, str] = {}
    for keyword in [*keywords] or [name]:
        folded = keyword.strip().casefold()
        if folded and folded not in seen:
            seen[folded] = keyword.strip()[:60]
    return list(seen.values())
