"""language reference list

Content languages become a reference table (`languages`, the same list as
app/domain/languages.py) instead of `language IN ('en', 'hi')` CHECK constraints on four
tables: documents, questions, concepts and ai_explanations now reference `languages.code`.
Adding a language later is a new row here plus an entry in the domain list, not a schema
change. Exams get `languages` (the languages their paper is offered in, from the official
notice): empty for every existing exam, because none has been recorded yet.

Revision ID: 0037
Revises: 0036
Create Date: 2026-11-02 10:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0037"
down_revision: str | Sequence[str] | None = "0036"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

CONTENT_TABLES = ("documents", "questions", "concepts", "ai_explanations")

# A copy, not an import: a migration must not change when the app's list changes later.
LANGUAGES = (
    {"code": "en", "english_name": "English", "native_name": "English", "script": "Latn"},
    {"code": "hi", "english_name": "Hindi", "native_name": "हिन्दी", "script": "Deva"},
)


def upgrade() -> None:
    """Upgrade schema."""
    languages = op.create_table(
        "languages",
        sa.Column("code", sa.String(length=8), nullable=False),
        sa.Column("english_name", sa.String(length=60), nullable=False),
        sa.Column("native_name", sa.String(length=60), nullable=False),
        sa.Column("script", sa.String(length=4), nullable=False),
        sa.Column("direction", sa.String(length=3), nullable=False),
        sa.CheckConstraint("code ~ '^[a-z]{2,3}$'", name=op.f("ck_languages_code_iso")),
        sa.CheckConstraint("script ~ '^[A-Z][a-z]{3}$'", name=op.f("ck_languages_script_iso")),
        sa.CheckConstraint(
            "direction IN ('ltr', 'rtl')", name=op.f("ck_languages_direction_known")
        ),
        sa.PrimaryKeyConstraint("code", name=op.f("pk_languages")),
    )
    op.bulk_insert(languages, [{**row, "direction": "ltr"} for row in LANGUAGES])

    for table in CONTENT_TABLES:
        op.drop_constraint(op.f(f"ck_{table}_language_supported"), table, type_="check")
        op.create_foreign_key(
            op.f(f"fk_{table}_language_languages"), table, "languages", ["language"], ["code"]
        )

    op.add_column(
        "exams",
        sa.Column(
            "languages",
            postgresql.ARRAY(sa.String(length=8)),
            server_default="{}",
            nullable=False,
        ),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("exams", "languages")
    for table in CONTENT_TABLES:
        op.drop_constraint(op.f(f"fk_{table}_language_languages"), table, type_="foreignkey")
        op.create_check_constraint(
            op.f(f"ck_{table}_language_supported"), table, "language IN ('en', 'hi')"
        )
    op.drop_table("languages")
