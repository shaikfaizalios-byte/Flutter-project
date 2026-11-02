"""canonical topics

Canonical subjects and topics with labels per language, and links from exam-specific topics
(app/domain/taxonomy.py). Seeded from the shared topics that already exist (the same 4
subjects and their topics are shared by the SSC, banking and railway exams): one canonical
node each, with the existing English name as its label, and each shared topic linked to its
own node (an identity, recorded as confirmed by this migration). No Hindi labels are added:
none were ever reviewed. Learners' own topics get a *suggested* link only when their name
matches exactly one canonical topic; nothing is confirmed for them.

Revision ID: 0034
Revises: 0033
Create Date: 2026-11-01 20:00:00

"""

import re
import unicodedata
import uuid
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0034"
down_revision: str | Sequence[str] | None = "0033"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _slug(label: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", unicodedata.normalize("NFKD", label).casefold()).strip("-")


def _normalize(label: str) -> str:
    # Same rule as app/domain/taxonomy.normalize (copied: migrations don't import app code).
    text = unicodedata.normalize("NFC", label).casefold().replace("&", " and ")
    text = re.sub(r"[^\w\s]", " ", text)
    words = []
    for w in re.split(r"\s+", text.strip()):
        if not w:
            continue
        if w in ("series", "species", "mathematics", "physics", "economics"):
            pass
        elif len(w) > 4 and w.endswith("ies"):
            w = w[:-3] + "y"
        elif len(w) > 3 and w.endswith("s") and not w.endswith(("ss", "ies")):
            w = w[:-1]
        words.append(w)
    return " ".join(words)


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "taxonomy_nodes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("key", sa.String(length=160), nullable=False),
        sa.Column("kind", sa.String(length=8), nullable=False),
        sa.Column("parent_id", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "kind IN ('subject', 'topic')", name=op.f("ck_taxonomy_nodes_kind_valid")
        ),
        sa.CheckConstraint(
            "(kind = 'subject') = (parent_id IS NULL)",
            name=op.f("ck_taxonomy_nodes_topics_have_a_subject"),
        ),
        sa.ForeignKeyConstraint(
            ["parent_id"],
            ["taxonomy_nodes.id"],
            name=op.f("fk_taxonomy_nodes_parent_id_taxonomy_nodes"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_taxonomy_nodes")),
        sa.UniqueConstraint("key", name=op.f("uq_taxonomy_nodes_key")),
    )
    op.create_index(
        op.f("ix_taxonomy_nodes_parent_id"), "taxonomy_nodes", ["parent_id"], unique=False
    )
    op.create_table(
        "taxonomy_labels",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("node_id", sa.Uuid(), nullable=False),
        sa.Column("language", sa.String(length=2), nullable=False),
        sa.Column("label", sa.String(length=120), nullable=False),
        sa.Column("is_alias", sa.Boolean(), server_default="false", nullable=False),
        sa.CheckConstraint("language ~ '^[a-z]{2}$'", name=op.f("ck_taxonomy_labels_language_iso")),
        sa.ForeignKeyConstraint(
            ["node_id"],
            ["taxonomy_nodes.id"],
            name=op.f("fk_taxonomy_labels_node_id_taxonomy_nodes"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_taxonomy_labels")),
        sa.UniqueConstraint("node_id", "language", "label", name="uq_taxonomy_labels_node_label"),
    )
    op.create_index(
        op.f("ix_taxonomy_labels_node_id"), "taxonomy_labels", ["node_id"], unique=False
    )
    op.create_table(
        "topic_taxonomy_links",
        sa.Column("topic_id", sa.Uuid(), nullable=False),
        sa.Column("node_id", sa.Uuid(), nullable=False),
        sa.Column("status", sa.String(length=10), nullable=False),
        sa.Column("source", sa.String(length=10), nullable=False),
        sa.Column("reason", sa.String(length=200), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "status IN ('suggested', 'confirmed', 'rejected')",
            name=op.f("ck_topic_taxonomy_links_status_valid"),
        ),
        sa.CheckConstraint(
            "source IN ('migration', 'rules', 'learner', 'operator')",
            name=op.f("ck_topic_taxonomy_links_source_valid"),
        ),
        sa.ForeignKeyConstraint(
            ["node_id"],
            ["taxonomy_nodes.id"],
            name=op.f("fk_topic_taxonomy_links_node_id_taxonomy_nodes"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["topic_id"],
            ["topics.id"],
            name=op.f("fk_topic_taxonomy_links_topic_id_topics"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("topic_id", "node_id", name=op.f("pk_topic_taxonomy_links")),
    )
    op.create_index(
        op.f("ix_topic_taxonomy_links_node_id"), "topic_taxonomy_links", ["node_id"], unique=False
    )
    op.create_index(
        "uq_topic_taxonomy_links_one_confirmed",
        "topic_taxonomy_links",
        ["topic_id"],
        unique=True,
        postgresql_where=sa.text("status = 'confirmed'"),
    )

    # Seed from the shared topics.
    connection = op.get_bind()
    shared = connection.execute(
        sa.text(
            "SELECT id, subject, name FROM topics WHERE owner_id IS NULL ORDER BY subject, name"
        )
    ).all()
    nodes = sa.table(
        "taxonomy_nodes",
        sa.column("id", sa.Uuid()),
        sa.column("key", sa.String()),
        sa.column("kind", sa.String()),
        sa.column("parent_id", sa.Uuid()),
    )
    labels = sa.table(
        "taxonomy_labels",
        sa.column("id", sa.Uuid()),
        sa.column("node_id", sa.Uuid()),
        sa.column("language", sa.String()),
        sa.column("label", sa.String()),
    )
    links = sa.table(
        "topic_taxonomy_links",
        sa.column("topic_id", sa.Uuid()),
        sa.column("node_id", sa.Uuid()),
        sa.column("status", sa.String()),
        sa.column("source", sa.String()),
        sa.column("reason", sa.String()),
    )
    subjects: dict[str, uuid.UUID] = {}
    topic_nodes: dict[str, uuid.UUID] = {}  # normalized topic name -> node
    ambiguous: set[str] = set()
    for topic_id, subject, name in shared:
        if subject not in subjects:
            subjects[subject] = uuid.uuid4()
            connection.execute(
                nodes.insert().values(id=subjects[subject], key=_slug(subject), kind="subject")
            )
            connection.execute(
                labels.insert().values(
                    id=uuid.uuid4(), node_id=subjects[subject], language="en", label=subject
                )
            )
        node_id = uuid.uuid4()
        connection.execute(
            nodes.insert().values(
                id=node_id,
                key=f"{_slug(subject)}/{_slug(name)}",
                kind="topic",
                parent_id=subjects[subject],
            )
        )
        connection.execute(
            labels.insert().values(id=uuid.uuid4(), node_id=node_id, language="en", label=name)
        )
        connection.execute(
            links.insert().values(
                topic_id=topic_id,
                node_id=node_id,
                status="confirmed",
                source="migration",
                reason="Shared topic: its own canonical topic",
            )
        )
        key = _normalize(name)
        if key in topic_nodes:
            ambiguous.add(key)
        topic_nodes[key] = node_id

    own = connection.execute(
        sa.text("SELECT id, name FROM topics WHERE owner_id IS NOT NULL")
    ).all()
    for topic_id, name in own:
        key = _normalize(name)
        if key in topic_nodes and key not in ambiguous:
            connection.execute(
                links.insert().values(
                    topic_id=topic_id,
                    node_id=topic_nodes[key],
                    status="suggested",
                    source="rules",
                    reason=f'Same name as the shared topic "{name.strip()[:80]}"',
                )
            )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("uq_topic_taxonomy_links_one_confirmed", table_name="topic_taxonomy_links")
    op.drop_index(op.f("ix_topic_taxonomy_links_node_id"), table_name="topic_taxonomy_links")
    op.drop_table("topic_taxonomy_links")
    op.drop_index(op.f("ix_taxonomy_labels_node_id"), table_name="taxonomy_labels")
    op.drop_table("taxonomy_labels")
    op.drop_index(op.f("ix_taxonomy_nodes_parent_id"), table_name="taxonomy_nodes")
    op.drop_table("taxonomy_nodes")
