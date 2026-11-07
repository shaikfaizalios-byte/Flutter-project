"""Adds a shared syllabus version from a data file (data/syllabi).

    python -m app.cli.syllabus check FILE.json
    python -m app.cli.syllabus import FILE.json --reviewer "A. Reviewer"
    python -m app.cli.syllabus link FILE.json --reviewer "A. Reviewer"

A new version needs an official source and an effective year. Leaves become topics of the exam,
reusing the ones it has, so a topic keeps its history from one version to the next.

``link`` confirms which topics of different exams mean the same thing, so a learner preparing for
several can see them together. The file is a proposal: only a named reviewer's import counts.
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Annotated, Any

from pydantic import BaseModel, ConfigDict, StringConstraints, ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.database.session import build_engine, build_sessionmaker
from app.domain.taxonomy import slug
from app.models.exam import Exam
from app.models.syllabus import SyllabusNode, SyllabusVersion
from app.models.taxonomy import TaxonomyLabel, TaxonomyNode, TopicTaxonomyLink
from app.schemas.syllabus import EffectiveYear, SyllabusTreeInput
from app.services.content import audit
from app.services.syllabus_tree_service import save_tree


class _Source(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=300)]
    url: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=500)]
    reference: Annotated[str, StringConstraints(strip_whitespace=True, max_length=300)] = ""


class SyllabusFile(SyllabusTreeInput):
    exam_codes: list[str]
    effective_year: EffectiveYear | None = None
    name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
    note: str | None = None
    source: _Source | None = None


def file_problems(spec: SyllabusFile) -> list[str]:
    """What stops a file from being imported as a new version (empty: it can be)."""
    problems = []
    if spec.source is None:
        problems.append("it has no official source")
    if spec.effective_year is None:
        problems.append("it has no effective year")
    if not spec.exam_codes:
        problems.append("it names no exam")
    return problems


def import_file(session: Session, data: dict[str, Any], reviewer: str) -> list[SyllabusVersion]:
    spec = SyllabusFile.model_validate(data)
    if not reviewer.strip():
        raise ValueError("Name the reviewer who checked it against the official source.")
    problems = file_problems(spec)
    if problems:
        raise ValueError("Not importable:\n- " + "\n- ".join(problems))
    assert spec.source is not None  # noqa: S101 - checked above
    created = []
    for code in spec.exam_codes:
        exam = session.get(Exam, code)
        if exam is None or exam.owner_id is not None:
            raise ValueError(f"{code} is not a catalog exam.")
        taken = session.scalar(
            select(SyllabusVersion.id).where(
                SyllabusVersion.exam_code == code,
                SyllabusVersion.owner_id.is_(None),
                SyllabusVersion.effective_year == spec.effective_year,
            )
        )
        if taken is not None:
            raise ValueError(f"{code} already has a version for {spec.effective_year}.")
        version = SyllabusVersion(
            exam_code=code,
            effective_year=spec.effective_year,
            name=spec.name,
            source_kind="template",
            source_title=spec.source.title,
            source_url=spec.source.url,
        )
        session.add(version)
        session.flush()
        save_tree(session, version, spec.tree, None)
        audit(session, reviewer, "syllabus_imported", "exam", code, str(spec.effective_year))
        created.append(version)
    return created


class _Member(BaseModel):
    model_config = ConfigDict(extra="forbid")

    units: list[str] = []
    topics: list[str] = []


class _Canonical(BaseModel):
    model_config = ConfigDict(extra="forbid")

    subject: str
    name: str
    members: dict[str, _Member]


class LinkFile(BaseModel):
    model_config = ConfigDict(extra="forbid")

    note: str
    canonical: list[_Canonical]
    unlinked: list[str] = []  # left for a person to place


def _node(session: Session, key: str, label: str, parent: TaxonomyNode | None) -> TaxonomyNode:
    node = session.scalar(select(TaxonomyNode).where(TaxonomyNode.key == key))
    if node is None:
        node = TaxonomyNode(
            key=key, kind="topic" if parent else "subject", parent_id=parent.id if parent else None
        )
        session.add(node)
        session.flush()
        session.add(TaxonomyLabel(node_id=node.id, language="en", label=label))
        session.flush()
    return node


def _latest_nodes(session: Session, exam_code: str) -> list[SyllabusNode]:
    version = session.scalar(
        select(SyllabusVersion)
        .where(SyllabusVersion.exam_code == exam_code, SyllabusVersion.owner_id.is_(None))
        .order_by(SyllabusVersion.effective_year.desc().nulls_last())
        .limit(1)
    )
    if version is None:
        raise ValueError(f"{exam_code} has no shared syllabus; import it first.")
    return list(session.scalars(select(SyllabusNode).where(SyllabusNode.version_id == version.id)))


def _member_topics(
    nodes: list[SyllabusNode], subject_of: dict[object, str], subject: str, member: _Member
) -> set[object]:
    """The topics under the named units of a subject, and the topics it names."""
    children: dict[object, list[SyllabusNode]] = {}
    for node in nodes:
        children.setdefault(node.parent_id, []).append(node)

    def leaves(node: SyllabusNode) -> set[object]:
        if node.topic_id is not None:
            return {node.topic_id}
        return {t for child in children.get(node.id, []) for t in leaves(child)}

    found: set[object] = set()
    for node in nodes:
        if subject_of.get(node.id) != subject:
            continue
        if node.name in member.units and node.topic_id is None:
            found |= leaves(node)
        if node.name in member.topics and node.topic_id is not None:
            found.add(node.topic_id)
    return found


def _subjects(nodes: list[SyllabusNode]) -> dict[object, str]:
    """Each node's subject: the name of its root."""
    by_id = {node.id: node for node in nodes}

    def root(node: SyllabusNode) -> str:
        while node.parent_id is not None:
            node = by_id[node.parent_id]
        return node.name

    return {node.id: root(node) for node in nodes}


def link_file(session: Session, data: dict[str, Any], reviewer: str) -> tuple[int, int]:
    """Confirms the file's links. Returns how many were added, and how many were left alone
    because the topic already has a confirmed link elsewhere."""
    spec = LinkFile.model_validate(data)
    if not reviewer.strip():
        raise ValueError("Name the reviewer who checked these links.")
    nodes_of: dict[str, list[SyllabusNode]] = {}
    added = kept = 0
    for entry in spec.canonical:
        subject = _node(session, slug(entry.subject), entry.subject, None)
        node = _node(session, f"{subject.key}/{slug(entry.name)}", entry.name, subject)
        for exam_code, member in entry.members.items():
            if exam_code not in nodes_of:
                nodes_of[exam_code] = _latest_nodes(session, exam_code)
            nodes = nodes_of[exam_code]
            for topic_id in _member_topics(nodes, _subjects(nodes), entry.subject, member):
                confirmed = session.scalar(
                    select(TopicTaxonomyLink).where(
                        TopicTaxonomyLink.topic_id == topic_id,
                        TopicTaxonomyLink.status == "confirmed",
                    )
                )
                if confirmed is not None:
                    kept += 1
                    continue
                session.add(
                    TopicTaxonomyLink(
                        topic_id=topic_id, node_id=node.id, status="confirmed", source="operator"
                    )
                )
                added += 1
        session.flush()
    audit(session, reviewer, "canonical_links_imported", "exam", "several", str(added))
    return added, kept


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli.syllabus")
    parser.add_argument("action", choices=["check", "import", "link"])
    parser.add_argument("file")
    parser.add_argument("--reviewer", default="")
    args = parser.parse_args(argv)
    try:
        data = json.loads(Path(args.file).read_text(encoding="utf-8"))
        if args.action == "check":
            problems = file_problems(SyllabusFile.model_validate(data))
            print("Can be imported." if not problems else "- " + "\n- ".join(problems))
            return 0 if not problems else 1
    except (ValueError, ValidationError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    engine = build_engine(get_settings())
    if engine is None:
        print("PREPLOOP_DATABASE_URL is not set.", file=sys.stderr)
        return 2
    with build_sessionmaker(engine)() as session:
        try:
            if args.action == "link":
                added, kept = link_file(session, data, args.reviewer)
                session.commit()
                print(f"Linked {added} topic(s); {kept} already had a link.")
                return 0
            versions = import_file(session, data, args.reviewer)
            session.commit()
        except (ValueError, ValidationError) as exc:
            session.rollback()
            print(str(exc), file=sys.stderr)
            return 1
    print(f"Added {len(versions)} version(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
