"""RRB NTPC from CEN 06/2026 and CEN 07/2026

Railways become the second exam family taken end to end (global Phase 10), from the official
Centralised Employment Notices CEN No. 06/2026 (NTPC Graduate) and CEN No. 07/2026 (NTPC Under
Graduate), Railway Recruitment Boards, Ministry of Railways (indicative notice in Employment News
26.09.2026). Only what the notices state:

- `exam_formats.section_counts_indicative`: both notices say "the section wise distribution given
  in the above table is only indicative and there may be some variations in the actual question
  papers" (para 13.1 and 13.2.1). Mocks built from such a format say so. False for every
  existing format.
- RRB NTPC: authority "Railway Recruitment Boards (Ministry of Railways)"; languages: "Questions
  for CBTs will be available in English, Hindi and 13 regional Indian languages (viz., Assamese,
  Bengali, Gujarati, Kannada, Konkani, Malayalam, Manipuri, Marathi, Odia, Punjabi, Tamil, Telugu
  and Urdu)" (para 14.3 d of both notices).
- The notices call the subject "Mathematics"; it is added as an alias of the canonical subject
  "Quantitative Aptitude" so mock sections named "Mathematics" find its questions. ("General
  Intelligence and Reasoning" already matches "General Intelligence" by name.)
- Syllabus topics the notices list (para 13.1 a-c) that no shared topic covers yet are added as
  shared topics for RRB_NTPC only, each with its own canonical topic (as in migration 0034).
  Topics already shared (Percentage, Syllogism, General Science, ...) are not duplicated.

The CBT formats themselves are NOT inserted here: they are draft files in
services/api/data/exam_formats/ that the operator imports, checks against the notice and
publishes under a named reviewer (python -m app.cli.exam_formats).

Revision ID: 0038
Revises: 0037
Create Date: 2026-11-02 20:00:00

"""

import re
import unicodedata
import uuid
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0038"
down_revision: str | Sequence[str] | None = "0037"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

EXAM = "RRB_NTPC"
AUTHORITY = "Railway Recruitment Boards (Ministry of Railways)"
# ISO 639 codes of the 15 languages named in para 14.3 (d), in the notice's order.
LANGUAGES = [
    "en", "hi", "as", "bn", "gu", "kn", "kok", "ml", "mni", "mr", "or", "pa", "ta", "te", "ur",
]  # fmt: skip
MATHEMATICS_ALIAS = "Mathematics"
QUANT_SUBJECT_KEY = "quantitative-aptitude"
SOURCE = "CEN 06/2026 and 07/2026 para 13.1"

# Syllabus items of para 13.1 not covered by an existing shared topic, under the shared subject
# they belong to. Names keep the notice's wording.
NEW_TOPICS: dict[str, list[str]] = {
    "Quantitative Aptitude": ["Decimals and Fractions", "LCM and HCF", "Elementary Statistics"],
    "General Intelligence": [
        "Similarities and Differences",
        "Relationships",
        "Analytical Reasoning",
        "Jumbling",
        "Puzzle",
        "Data Sufficiency",
        "Statement and Conclusion",
        "Statement and Courses of Action",
        "Decision Making",
        "Maps",
        "Interpretation of Graphs",
    ],
    "General Awareness": [
        "Indian Literature",
        "Monuments and Places of India",
        "Scientific and Technological Developments",
        "UN and Other Important World Organizations",
        "Environmental Issues",
        "Common Abbreviations",
        "Transport Systems in India",
        "Famous Personalities of India and World",
        "Flagship Government Programs",
        "Flora and Fauna of India",
        "Important Government and Public Sector Organizations",
    ],
}


def _slug(label: str) -> str:
    # Same as migration 0034.
    return re.sub(r"[^a-z0-9]+", "-", unicodedata.normalize("NFKD", label).casefold()).strip("-")


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "exam_formats",
        sa.Column(
            "section_counts_indicative", sa.Boolean(), server_default="false", nullable=False
        ),
    )
    connection = op.get_bind()
    connection.execute(
        sa.text(
            "UPDATE exams SET authority = :authority, languages = :languages WHERE code = :code"
        ),
        {"authority": AUTHORITY, "languages": LANGUAGES, "code": EXAM},
    )

    subjects = dict(
        connection.execute(
            sa.text(
                "SELECT l.label, n.id FROM taxonomy_nodes n JOIN taxonomy_labels l "
                "ON l.node_id = n.id WHERE n.kind = 'subject' AND l.language = 'en' "
                "AND NOT l.is_alias"
            )
        ).all()
    )
    quant = connection.execute(
        sa.text("SELECT id FROM taxonomy_nodes WHERE key = :key"), {"key": QUANT_SUBJECT_KEY}
    ).scalar()
    if quant is not None:
        connection.execute(
            sa.text(
                "INSERT INTO taxonomy_labels (id, node_id, language, label, is_alias) "
                "VALUES (:id, :node, 'en', :label, true)"
            ),
            {"id": uuid.uuid4(), "node": quant, "label": MATHEMATICS_ALIAS},
        )

    for subject, names in NEW_TOPICS.items():
        for name in names:
            topic_id = uuid.uuid4()
            connection.execute(
                sa.text(
                    "INSERT INTO topics (id, subject, name, keywords, exam_codes) "
                    "VALUES (:id, :subject, :name, '{}', :exams)"
                ),
                {"id": topic_id, "subject": subject, "name": name, "exams": [EXAM]},
            )
            parent = subjects.get(subject)
            if parent is None:  # no canonical subject (a database without migration 0034 seeds)
                continue
            node_id = uuid.uuid4()
            connection.execute(
                sa.text(
                    "INSERT INTO taxonomy_nodes (id, key, kind, parent_id) "
                    "VALUES (:id, :key, 'topic', :parent)"
                ),
                {"id": node_id, "key": f"{_slug(subject)}/{_slug(name)}", "parent": parent},
            )
            connection.execute(
                sa.text(
                    "INSERT INTO taxonomy_labels (id, node_id, language, label) "
                    "VALUES (:id, :node, 'en', :label)"
                ),
                {"id": uuid.uuid4(), "node": node_id, "label": name},
            )
            connection.execute(
                sa.text(
                    "INSERT INTO topic_taxonomy_links (topic_id, node_id, status, source, reason) "
                    "VALUES (:topic, :node, 'confirmed', 'migration', :reason)"
                ),
                {"topic": topic_id, "node": node_id, "reason": f"Shared topic from {SOURCE}"},
            )


def downgrade() -> None:
    """Downgrade schema."""
    connection = op.get_bind()
    for subject, names in NEW_TOPICS.items():
        keys = [f"{_slug(subject)}/{_slug(name)}" for name in names]
        connection.execute(
            sa.text("DELETE FROM taxonomy_nodes WHERE key = ANY(:keys)"), {"keys": keys}
        )
        connection.execute(
            sa.text(
                "DELETE FROM topics WHERE owner_id IS NULL AND subject = :subject "
                "AND name = ANY(:names) AND exam_codes = :exams"
            ),
            {"subject": subject, "names": names, "exams": [EXAM]},
        )
    connection.execute(
        sa.text("DELETE FROM taxonomy_labels WHERE label = :label AND is_alias"),
        {"label": MATHEMATICS_ALIAS},
    )
    connection.execute(
        sa.text("UPDATE exams SET authority = NULL, languages = '{}' WHERE code = :code"),
        {"code": EXAM},
    )
    op.drop_column("exam_formats", "section_counts_indicative")
