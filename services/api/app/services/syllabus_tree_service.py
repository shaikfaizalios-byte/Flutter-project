"""Syllabus versions and trees (rules in app/domain/syllabus_tree.py).

Trees sit over ``topics``: each leaf points to the topic questions use, an existing one when
the exam already has it, so a topic keeps its history when a new version repeats it.
"""

import uuid
from collections import defaultdict
from collections.abc import Iterable, Sequence
from datetime import UTC, datetime

from sqlalchemy import delete, or_, select
from sqlalchemy.orm import Session

from app.domain.errors import ConflictError, NotFoundError
from app.domain.syllabus_tree import SyllabusScope, VersionRef, in_force, scope_for
from app.models.question import Question, Topic, TopicStatus
from app.models.syllabus import SyllabusNode, SyllabusVersion
from app.repositories.exam_repository import ExamRepository
from app.schemas.syllabus import (
    SyllabusNodeInput,
    SyllabusNodeRead,
    SyllabusVersionCreate,
    SyllabusVersionRead,
)
from app.services.topic_service import visible_topics


def _lines(
    session: Session, owner_id: uuid.UUID | None, exam_code: str
) -> tuple[list[SyllabusVersion], list[list[VersionRef]]]:
    """The versions an account sees, and their refs split into the shared and the own line."""
    versions = session.scalars(
        select(SyllabusVersion)
        .where(
            SyllabusVersion.exam_code == exam_code,
            or_(SyllabusVersion.owner_id.is_(None), SyllabusVersion.owner_id == owner_id),
        )
        .order_by(SyllabusVersion.effective_year.nulls_first())
    ).all()
    topics: dict[uuid.UUID, set[uuid.UUID]] = defaultdict(set)
    if versions:
        for version_id, topic_id in session.execute(
            select(SyllabusNode.version_id, SyllabusNode.topic_id).where(
                SyllabusNode.version_id.in_([v.id for v in versions]),
                SyllabusNode.topic_id.is_not(None),
            )
        ):
            topics[version_id].add(topic_id)
    shared: list[VersionRef] = []
    own: list[VersionRef] = []
    for v in versions:
        ref = VersionRef(v.id, v.effective_year, frozenset(topics[v.id]))
        (shared if v.owner_id is None else own).append(ref)
    return list(versions), [shared, own]


def syllabus_scope(
    session: Session, owner_id: uuid.UUID | None, exam_code: str, years: Iterable[int]
) -> SyllabusScope:
    """Which topics count for papers of ``years`` (empty: this year's syllabus)."""
    _, lines = _lines(session, owner_id, exam_code)
    return scope_for(lines, years, datetime.now(UTC).year)


def active_topics(
    session: Session, owner_id: uuid.UUID | None, exam_code: str
) -> Sequence[Topic]:
    """The topics suggestions may use: the exam's, within the syllabus in force today."""
    out = syllabus_scope(session, owner_id, exam_code, ()).out_of_scope
    return [t for t in visible_topics(session, owner_id, exam_code) if t.id not in out]


def save_tree(
    session: Session,
    version: SyllabusVersion,
    tree: Sequence[SyllabusNodeInput],
    owner_id: uuid.UUID | None,
) -> None:
    """Adds the nodes. A leaf uses the exam's topic of that subject and name, or a new one."""
    known = {
        (t.subject.casefold(), t.name.casefold()): t
        for t in visible_topics(session, owner_id, version.exam_code)
    }

    def leaf_topic(subject: str, node: SyllabusNodeInput) -> Topic:
        key = (subject.casefold(), node.name.casefold())
        topic = known.get(key)
        if topic is None:
            topic = Topic(
                subject=subject,
                name=node.name,
                keywords=list(node.keywords),
                owner_id=owner_id,
                exam_codes=[version.exam_code],
            )
            session.add(topic)
            session.flush()
            known[key] = topic
        return topic

    def add(
        nodes: Sequence[SyllabusNodeInput], parent: uuid.UUID | None, subject: str | None
    ) -> None:
        for position, node in enumerate(nodes, start=1):
            root = subject or node.name
            row = SyllabusNode(
                id=uuid.uuid4(),
                version_id=version.id,
                parent_id=parent,
                position=position,
                name=node.name,
                level_label=node.level_label,
                keywords=list(node.keywords),
                aliases=list(node.aliases),
                topic_id=None if node.children else leaf_topic(root, node).id,
            )
            session.add(row)
            session.flush()
            add(node.children, row.id, root)

    add(tree, None, None)


def _tree(session: Session, version_id: uuid.UUID) -> list[SyllabusNodeRead]:
    rows = session.execute(
        select(SyllabusNode, Topic.keywords)
        .outerjoin(Topic, Topic.id == SyllabusNode.topic_id)
        .where(SyllabusNode.version_id == version_id)
        .order_by(SyllabusNode.position)
    ).all()
    by_parent: dict[uuid.UUID | None, list[tuple[SyllabusNode, list[str] | None]]] = (
        defaultdict(list)
    )
    for node, keywords in rows:
        by_parent[node.parent_id].append((node, keywords))

    def build(parent: uuid.UUID | None) -> list[SyllabusNodeRead]:
        return [
            SyllabusNodeRead(
                id=node.id,
                name=node.name,
                level_label=node.level_label,
                keywords=list(node.keywords) or list(keywords or []),
                aliases=list(node.aliases),
                topic_id=node.topic_id,
                children=build(node.id),
            )
            for node, keywords in by_parent[parent]
        ]

    return build(None)


class SyllabusTreeService:
    def __init__(self, session: Session, owner_id: uuid.UUID) -> None:
        self._session = session
        self._owner_id = owner_id
        self._exams = ExamRepository(session)

    def _visible_exam(self, code: str) -> None:
        if self._exams.get_visible(code, self._owner_id) is None:
            raise NotFoundError(f"Exam '{code}' not found.")

    def _read(self, version: SyllabusVersion, current: set[uuid.UUID]) -> SyllabusVersionRead:
        return SyllabusVersionRead(
            id=version.id,
            exam_code=version.exam_code,
            effective_year=version.effective_year,
            name=version.name,
            source_kind=version.source_kind,
            source_title=version.source_title,
            source_url=version.source_url,
            own=version.owner_id is not None,
            in_force=version.id in current,
            tree=_tree(self._session, version.id),
        )

    def versions(self, exam_code: str) -> list[SyllabusVersionRead]:
        self._visible_exam(exam_code)
        versions, lines = _lines(self._session, self._owner_id, exam_code)
        year = datetime.now(UTC).year
        current = {found.id for line in lines if (found := in_force(line, year)) is not None}
        return [self._read(v, current) for v in versions]

    def create(self, exam_code: str, data: SyllabusVersionCreate) -> SyllabusVersionRead:
        self._visible_exam(exam_code)
        taken = self._session.scalar(
            select(SyllabusVersion.id).where(
                SyllabusVersion.exam_code == exam_code,
                SyllabusVersion.owner_id == self._owner_id,
                SyllabusVersion.effective_year.is_not_distinct_from(data.effective_year),
            )
        )
        if taken is not None:
            raise ConflictError(
                "syllabus_version_exists", "You already have a syllabus for this year."
            )
        version = SyllabusVersion(
            exam_code=exam_code,
            owner_id=self._owner_id,
            effective_year=data.effective_year,
            name=data.name,
            source_kind=data.source_kind,
        )
        self._session.add(version)
        self._session.flush()
        save_tree(self._session, version, data.tree, self._owner_id)
        self._session.commit()
        found = [v for v in self.versions(exam_code) if v.id == version.id]
        return found[0]

    def delete(self, version_id: uuid.UUID) -> None:
        """Removes an own version and the own topics nothing else uses."""
        version = self._session.get(SyllabusVersion, version_id)
        if version is None or version.owner_id != self._owner_id:
            raise NotFoundError("Syllabus not found.")
        topic_ids = set(
            self._session.scalars(
                select(SyllabusNode.topic_id).where(
                    SyllabusNode.version_id == version_id, SyllabusNode.topic_id.is_not(None)
                )
            ).all()
        )
        self._session.delete(version)
        self._session.flush()
        still_used = set(
            self._session.scalars(
                select(SyllabusNode.topic_id).where(SyllabusNode.topic_id.in_(topic_ids))
            ).all()
        )
        removable = [
            t
            for t in self._session.scalars(
                select(Topic).where(Topic.id.in_(topic_ids - still_used))
            ).all()
            if t.owner_id == self._owner_id and t.syllabus_import_id is None
        ]
        ids = [t.id for t in removable]
        for question in self._session.scalars(select(Question).where(Question.topic_id.in_(ids))):
            question.topic_id = None
            question.topic_status = TopicStatus.UNASSIGNED
        self._session.flush()
        self._session.execute(delete(Topic).where(Topic.id.in_(ids)))
        self._session.commit()
