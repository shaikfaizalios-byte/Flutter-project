"""Which chapter each topic belongs to, from the exam's syllabus."""

import uuid

from sqlalchemy import ColumnElement, or_, select
from sqlalchemy.orm import Session

from app.models.syllabus import SyllabusNode, SyllabusVersion


def unit_topics(
    session: Session, exam_code: str, owner_id: uuid.UUID | None = None
) -> dict[uuid.UUID, tuple[str, str]]:
    """Topic -> (chapter, subject). Older syllabus versions fill in topics since removed; the
    newest wins. A chapter is the syllabus Unit: the official lists have no Chapter level."""
    owners: ColumnElement[bool] = SyllabusVersion.owner_id.is_(None)
    if owner_id is not None:
        owners = or_(owners, SyllabusVersion.owner_id == owner_id)
    versions = session.scalars(
        select(SyllabusVersion.id)
        .where(SyllabusVersion.exam_code == exam_code, owners)
        .order_by(SyllabusVersion.effective_year.asc().nulls_first())
    ).all()
    found: dict[uuid.UUID, tuple[str, str]] = {}
    for version in versions:
        nodes = session.scalars(
            select(SyllabusNode).where(SyllabusNode.version_id == version)
        ).all()
        by_id = {n.id: n for n in nodes}
        for node in nodes:
            if node.topic_id is None:
                continue
            parent = by_id.get(node.parent_id) if node.parent_id else None
            root = parent
            while root is not None and root.parent_id is not None:
                root = by_id.get(root.parent_id)
            found[node.topic_id] = (
                parent.name if parent else node.name,
                root.name if root else "",
            )
    return found
