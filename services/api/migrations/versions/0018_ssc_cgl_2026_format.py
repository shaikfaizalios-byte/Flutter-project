"""SSC CGL 2026 Tier-I format

The verified format of SSC CGL 2026 Tier-I, from the official notice (scheme in para 13.8,
negative marking in 13.8.2). The notice gives each subject a 15-minute sectional timer; the
mock keeps one overall timer and says so (see PracticeService._marking_note).

Revision ID: 0018
Revises: 0017
Create Date: 2026-10-19 23:00:00

"""

import uuid
from collections.abc import Sequence
from datetime import date

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0018"
down_revision: str | Sequence[str] | None = "0017"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Verified against the official notice on 2026-10-19 (text extracted from the PDF on
# ssc.gov.in). Re-verify for each new notice; never add a format that has not been checked
# against an official SSC document.
CGL_2026_TIER1 = {
    "id": uuid.UUID("7c2a4e10-9d3b-4f61-8a25-0c6d2026c91e"),
    "code": "SSC_CGL_2026_TIER1",
    "exam_code": "SSC_CGL",
    "tier": "Tier-I",
    "name": "SSC CGL 2026 Tier-I (Computer Based Examination)",
    "sections": [
        {
            "part": "A",
            "subject": "General Intelligence and Reasoning",
            "questions": 25,
            "max_marks": 50,
            "timer_minutes": 15,
        },
        {
            "part": "B",
            "subject": "General Awareness",
            "questions": 25,
            "max_marks": 50,
            "timer_minutes": 15,
        },
        {
            "part": "C",
            "subject": "Quantitative Aptitude",
            "questions": 25,
            "max_marks": 50,
            "timer_minutes": 15,
        },
        {
            "part": "D",
            "subject": "English Comprehension",
            "questions": 25,
            "max_marks": 50,
            "timer_minutes": 15,
        },
    ],
    # A sectional timer per subject implies the subjects are taken one after another.
    "sections_in_fixed_order": True,
    "total_questions": 100,
    "duration_minutes": 60,
    "negative_marks_per_wrong": 0.5,
    "source_title": "SSC Notice: Combined Graduate Level Examination, 2026",
    "source_url": "https://ssc.gov.in/api/attachment/uploads/masterData/NoticeBoards/Notice_of_adv_cgl_2025.pdf",
    "source_reference": "F. No. HQ-C11018/1/2026-C-1, para 13.8 (scheme of Tier-I) and 13.8.2 (negative marking)",  # noqa: E501
    "source_published_on": date(2026, 5, 21),
    "verified_on": date(2026, 10, 19),
}


def upgrade() -> None:
    """Upgrade schema."""
    exam_formats_table = sa.table(
        "exam_formats",
        sa.column("id", sa.Uuid()),
        sa.column("code", sa.String()),
        sa.column("exam_code", sa.String()),
        sa.column("tier", sa.String()),
        sa.column("name", sa.String()),
        sa.column("sections", postgresql.JSONB()),
        sa.column("sections_in_fixed_order", sa.Boolean()),
        sa.column("total_questions", sa.Integer()),
        sa.column("duration_minutes", sa.Integer()),
        sa.column("negative_marks_per_wrong", sa.Float()),
        sa.column("source_title", sa.String()),
        sa.column("source_url", sa.String()),
        sa.column("source_reference", sa.String()),
        sa.column("source_published_on", sa.Date()),
        sa.column("verified_on", sa.Date()),
    )
    op.bulk_insert(exam_formats_table, [CGL_2026_TIER1])


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DELETE FROM exam_formats WHERE code = 'SSC_CGL_2026_TIER1'")
