"""versioned syllabus trees

Each exam's syllabus gets versions and a tree of any depth over the existing topics. Today's
shared topics become one version per catalog exam, with no effective year because none was ever
recorded: subject nodes with their topics under them. Learners' own topics stay as they are.
Topics and questions don't change.

Revision ID: 0044
Revises: 0043
"""

import uuid
from collections import defaultdict
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0044"
down_revision: str | None = "0043"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    versions = op.create_table(
        "syllabus_versions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("exam_code", sa.String(length=32), nullable=False),
        sa.Column("owner_id", sa.Uuid(), nullable=True),
        sa.Column("effective_year", sa.Integer(), nullable=True),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("source_kind", sa.String(length=8), nullable=False),
        sa.Column("source_title", sa.String(length=300), nullable=True),
        sa.Column("source_url", sa.String(length=500), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "source_kind IN ('template', 'pdf', 'manual')",
            name=op.f("ck_syllabus_versions_source_kind_valid"),
        ),
        sa.ForeignKeyConstraint(
            ["exam_code"],
            ["exams.code"],
            name=op.f("fk_syllabus_versions_exam_code_exams"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["owner_id"],
            ["users.id"],
            name=op.f("fk_syllabus_versions_owner_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_syllabus_versions")),
        sa.UniqueConstraint(
            "exam_code",
            "owner_id",
            "effective_year",
            name="uq_syllabus_versions_exam_owner_year",
            postgresql_nulls_not_distinct=True,
        ),
    )
    op.create_index(
        op.f("ix_syllabus_versions_exam_code"), "syllabus_versions", ["exam_code"], unique=False
    )
    op.create_index(
        op.f("ix_syllabus_versions_owner_id"), "syllabus_versions", ["owner_id"], unique=False
    )
    nodes = op.create_table(
        "syllabus_nodes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("version_id", sa.Uuid(), nullable=False),
        sa.Column("parent_id", sa.Uuid(), nullable=True),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("level_label", sa.String(length=30), nullable=True),
        sa.Column(
            "keywords", postgresql.ARRAY(sa.String(length=60)), server_default="{}", nullable=False
        ),
        sa.Column(
            "aliases", postgresql.ARRAY(sa.String(length=100)), server_default="{}", nullable=False
        ),
        sa.Column("topic_id", sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(
            ["parent_id"],
            ["syllabus_nodes.id"],
            name=op.f("fk_syllabus_nodes_parent_id_syllabus_nodes"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["topic_id"],
            ["topics.id"],
            name=op.f("fk_syllabus_nodes_topic_id_topics"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["version_id"],
            ["syllabus_versions.id"],
            name=op.f("fk_syllabus_nodes_version_id_syllabus_versions"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_syllabus_nodes")),
    )
    op.create_index(
        op.f("ix_syllabus_nodes_parent_id"), "syllabus_nodes", ["parent_id"], unique=False
    )
    op.create_index(
        op.f("ix_syllabus_nodes_topic_id"), "syllabus_nodes", ["topic_id"], unique=False
    )
    op.create_index(
        op.f("ix_syllabus_nodes_version_id"), "syllabus_nodes", ["version_id"], unique=False
    )

    bind = op.get_bind()
    exams = [
        row[0] for row in bind.execute(sa.text("SELECT code FROM exams WHERE owner_id IS NULL"))
    ]
    topics = bind.execute(
        sa.text(
            "SELECT id, subject, name, exam_codes FROM topics WHERE owner_id IS NULL "
            "ORDER BY subject, name"
        )
    ).all()
    version_rows: list[dict[str, object]] = []
    node_rows: list[dict[str, object]] = []
    for code in exams:
        by_subject: dict[str, list[tuple[uuid.UUID, str]]] = defaultdict(list)
        for topic_id, subject, name, exam_codes in topics:
            if exam_codes is None or code in exam_codes:
                by_subject[subject].append((topic_id, name))
        if not by_subject:
            continue
        version_id = uuid.uuid4()
        version_rows.append(
            {
                "id": version_id,
                "exam_code": code,
                "name": "Built-in syllabus",
                "source_kind": "template",
            }
        )
        for position, (subject, leaves) in enumerate(sorted(by_subject.items()), start=1):
            subject_id = uuid.uuid4()
            node_rows.append(
                {
                    "id": subject_id,
                    "version_id": version_id,
                    "parent_id": None,
                    "position": position,
                    "name": subject,
                    "level_label": "Subject",
                    "topic_id": None,
                }
            )
            for index, (topic_id, name) in enumerate(leaves, start=1):
                node_rows.append(
                    {
                        "id": uuid.uuid4(),
                        "version_id": version_id,
                        "parent_id": subject_id,
                        "position": index,
                        "name": name,
                        "level_label": "Topic",
                        "topic_id": topic_id,
                    }
                )
    if version_rows:
        op.bulk_insert(versions, version_rows)
        op.bulk_insert(nodes, node_rows)


def downgrade() -> None:
    op.drop_table("syllabus_nodes")
    op.drop_table("syllabus_versions")
