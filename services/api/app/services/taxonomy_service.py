"""Canonical topics: suggesting, deciding and reading links (rules in app/domain/taxonomy.py).

Only confirmed links are used anywhere (mock sections, analytics). A suggestion stays a
suggestion until the topic's owner confirms it; a rejected pair is never suggested again.
"""

import uuid
from collections import defaultdict
from collections.abc import Iterable
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain import taxonomy
from app.domain.errors import InvalidReferenceError, NotFoundError
from app.models.question import Topic
from app.models.taxonomy import TaxonomyLabel, TaxonomyNode, TopicTaxonomyLink
from app.schemas.exam import CanonicalTopicRead, TaxonomySubjectRead, TaxonomyTopicRead


def _topic_labels(session: Session) -> dict[str, list[str]]:
    rows = session.execute(
        select(TaxonomyLabel.node_id, TaxonomyLabel.label)
        .join(TaxonomyNode, TaxonomyNode.id == TaxonomyLabel.node_id)
        .where(TaxonomyNode.kind == "topic")
    ).all()
    labels: dict[str, list[str]] = defaultdict(list)
    for node_id, label in rows:
        labels[str(node_id)].append(label)
    return labels


def suggest_link(session: Session, topic: Topic) -> None:
    """Adds a suggested link for a learner's own topic when its name matches exactly one
    canonical topic (and that pair wasn't rejected before)."""
    if topic.owner_id is None:
        return
    found = taxonomy.suggest(topic.name, _topic_labels(session))
    if found is None:
        return
    node_id = uuid.UUID(found.node_id)
    existing = session.get(TopicTaxonomyLink, (topic.id, node_id))
    if existing is not None:
        return  # suggested, confirmed or rejected already
    session.add(
        TopicTaxonomyLink(
            topic_id=topic.id,
            node_id=node_id,
            status="suggested",
            source="rules",
            reason=found.reason[:200],
        )
    )


def forget_suggestions(session: Session, topic: Topic) -> None:
    """A renamed topic: its old suggestions no longer apply (decisions stay)."""
    for link in session.scalars(
        select(TopicTaxonomyLink).where(
            TopicTaxonomyLink.topic_id == topic.id, TopicTaxonomyLink.status == "suggested"
        )
    ):
        session.delete(link)
    session.flush()


def canonical_for(
    session: Session, topic_ids: Iterable[uuid.UUID]
) -> dict[uuid.UUID, CanonicalTopicRead]:
    """The link to show for each topic: the confirmed one, else a suggestion (rejected
    links are not shown)."""
    ids = list(topic_ids)
    if not ids:
        return {}
    subject = TaxonomyNode.__table__.alias("subject_node")
    subject_label = TaxonomyLabel.__table__.alias("subject_label")
    rows = session.execute(
        select(
            TopicTaxonomyLink.topic_id,
            TopicTaxonomyLink.status,
            TopicTaxonomyLink.reason,
            TaxonomyNode.id,
            TaxonomyNode.key,
            TaxonomyLabel.label,
            subject_label.c.label,
        )
        .join(TaxonomyNode, TaxonomyNode.id == TopicTaxonomyLink.node_id)
        .join(
            TaxonomyLabel,
            (TaxonomyLabel.node_id == TaxonomyNode.id)
            & (TaxonomyLabel.language == "en")
            & TaxonomyLabel.is_alias.is_(False),
        )
        .join(subject, subject.c.id == TaxonomyNode.parent_id)
        .join(
            subject_label,
            (subject_label.c.node_id == subject.c.id)
            & (subject_label.c.language == "en")
            & subject_label.c.is_alias.is_(False),
        )
        .where(TopicTaxonomyLink.topic_id.in_(ids), TopicTaxonomyLink.status != "rejected")
    ).all()
    found: dict[uuid.UUID, CanonicalTopicRead] = {}
    for topic_id, status, reason, node_id, key, label, subject_name in rows:
        if topic_id in found and found[topic_id].status == "confirmed":
            continue
        found[topic_id] = CanonicalTopicRead(
            node_id=node_id,
            key=key,
            label=label,
            subject_label=subject_name,
            status=status,
            reason=reason if status == "suggested" else None,
        )
    return found


def decide(
    session: Session, owner_id: uuid.UUID, topic_id: uuid.UUID, node_id: uuid.UUID, confirm: bool
) -> None:
    """The owner of a topic confirms (or rejects) that it means this canonical topic. A
    confirmation replaces any earlier confirmed link of the topic."""
    topic = session.scalar(select(Topic).where(Topic.id == topic_id, Topic.owner_id == owner_id))
    if topic is None:
        raise NotFoundError("Topic not found.")
    node = session.get(TaxonomyNode, node_id)
    if node is None or node.kind != "topic":
        raise InvalidReferenceError("Unknown canonical topic.")
    now = datetime.now(UTC)
    if confirm:
        for other in session.scalars(
            select(TopicTaxonomyLink).where(
                TopicTaxonomyLink.topic_id == topic_id,
                TopicTaxonomyLink.status == "confirmed",
                TopicTaxonomyLink.node_id != node_id,
            )
        ):
            session.delete(other)
        session.flush()
    link = session.get(TopicTaxonomyLink, (topic_id, node_id))
    if link is None:
        link = TopicTaxonomyLink(topic_id=topic_id, node_id=node_id, source="learner")
        session.add(link)
    link.status = "confirmed" if confirm else "rejected"
    link.decided_at = now
    if link.source == "rules":
        link.source = "learner"


def subject_labels_by_topic(
    session: Session, topic_ids: Iterable[uuid.UUID]
) -> dict[uuid.UUID, list[str]]:
    """For topics with a confirmed link: the labels of their canonical subject."""
    ids = list(topic_ids)
    if not ids:
        return {}
    rows = session.execute(
        select(TopicTaxonomyLink.topic_id, TaxonomyLabel.label)
        .join(TaxonomyNode, TaxonomyNode.id == TopicTaxonomyLink.node_id)
        .join(TaxonomyLabel, TaxonomyLabel.node_id == TaxonomyNode.parent_id)
        .where(TopicTaxonomyLink.topic_id.in_(ids), TopicTaxonomyLink.status == "confirmed")
    ).all()
    labels: dict[uuid.UUID, list[str]] = defaultdict(list)
    for topic_id, label in rows:
        labels[topic_id].append(label)
    return labels


def canonical_tree(session: Session) -> list[TaxonomySubjectRead]:
    """Every canonical subject with its topics (English labels), for choosing a link."""
    nodes = session.scalars(select(TaxonomyNode).order_by(TaxonomyNode.key)).all()
    names = {
        node_id: label
        for node_id, label in session.execute(
            select(TaxonomyLabel.node_id, TaxonomyLabel.label).where(
                TaxonomyLabel.language == "en", TaxonomyLabel.is_alias.is_(False)
            )
        )
    }
    subjects = {
        n.id: TaxonomySubjectRead(node_id=n.id, key=n.key, label=names.get(n.id, n.key), topics=[])
        for n in nodes
        if n.kind == "subject"
    }
    for n in nodes:
        if n.kind == "topic" and n.parent_id in subjects:
            subjects[n.parent_id].topics.append(
                TaxonomyTopicRead(node_id=n.id, key=n.key, label=names.get(n.id, n.key))
            )
    return sorted(subjects.values(), key=lambda s: s.label)
