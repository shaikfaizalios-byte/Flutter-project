"""regional content languages

Ten Indic languages join the reference list, so papers and questions can be stored in them. Urdu
isn't added: it runs right to left, which the app doesn't lay out yet. OCR needs each language's
Tesseract data on the server (the Docker image installs it).

Revision ID: 0049
Revises: 0048
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0049"
down_revision: str | None = "0048"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

ROWS = [
    ("as", "Assamese", "অসমীয়া", "Beng"),
    ("bn", "Bengali", "বাংলা", "Beng"),
    ("gu", "Gujarati", "ગુજરાતી", "Gujr"),
    ("kn", "Kannada", "ಕನ್ನಡ", "Knda"),
    ("ml", "Malayalam", "മലയാളം", "Mlym"),
    ("mr", "Marathi", "मराठी", "Deva"),
    ("or", "Odia", "ଓଡ଼ିଆ", "Orya"),
    ("pa", "Punjabi", "ਪੰਜਾਬੀ", "Guru"),
    ("ta", "Tamil", "தமிழ்", "Taml"),
    ("te", "Telugu", "తెలుగు", "Telu"),
]


def upgrade() -> None:
    table = sa.table(
        "languages",
        sa.column("code", sa.String),
        sa.column("english_name", sa.String),
        sa.column("native_name", sa.String),
        sa.column("script", sa.String),
        sa.column("direction", sa.String),
    )
    op.bulk_insert(
        table,
        [
            {
                "code": code,
                "english_name": english,
                "native_name": native,
                "script": script,
                "direction": "ltr",
            }
            for code, english, native, script in ROWS
        ],
    )


def downgrade() -> None:
    # Content in these languages has no place in the older list, so it blocks the downgrade
    # through its foreign keys rather than being deleted here.
    codes = ", ".join(f"'{row[0]}'" for row in ROWS)
    op.execute(f"DELETE FROM languages WHERE code IN ({codes})")  # noqa: S608
