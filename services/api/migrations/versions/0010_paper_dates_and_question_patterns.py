"""paper dates and question patterns

When a paper was held (year, date, shift; suggested, then confirmed by the reviewer) and a
starter list of question *patterns* (named question types) under the existing topics.

Patterns are taxonomy data, like topics: a description of a kind of question, with keywords
that only drive suggestions. They say nothing about how often a pattern appears in an exam;
that is counted from the learner's own reviewed papers. Topics whose questions can't be told
apart by wording (e.g. Syllogism, Reading Comprehension) have no patterns; their repeated
questions are found by wording similarity instead.

Revision ID: 0010
Revises: 0009
Create Date: 2026-10-15 09:40:15.270321

"""

import uuid
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0010"
down_revision: str | Sequence[str] | None = "0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# subject -> topic -> [(pattern, keywords)]
PATTERNS: dict[str, dict[str, list[tuple[str, list[str]]]]] = {
    "General Intelligence": {
        "Analogy": [
            ("Word analogy", ["word pair", "word-pair", "words are related", "third word"]),
            ("Number analogy", ["number pair", "numbers are related", "third number"]),
            (
                "Letter-cluster analogy",
                ["letter-cluster", "letter cluster", "letter pair", "letter-pair"],
            ),
        ],
        "Classification (Odd One Out)": [
            ("Odd word", ["odd word", "words are alike"]),
            (
                "Odd number or number pair",
                ["odd number", "numbers are alike", "number pairs are alike", "number-pair"],
            ),
            (
                "Odd letter-cluster",
                ["letter-cluster", "letter cluster", "letter-clusters", "letters are alike"],
            ),
        ],
        "Coding-Decoding": [
            ("Word written as another word", ["is written as"]),
            ("Word coded as numbers", ["is coded as", "coded as"]),
            ("Sentence code language", ["means", "stands for"]),
        ],
        "Series": [
            (
                "Number series",
                ["number series", "next number", "missing number", "replace the question mark"],
            ),
            ("Alphanumeric series", ["alphanumeric", "letter-number", "letter number"]),
        ],
        "Mirror and Water Images": [
            ("Mirror image", ["mirror image", "mirror is placed"]),
            ("Water image", ["water image", "reflection in water"]),
        ],
        "Venn Diagrams": [
            (
                "Relationship between classes",
                [
                    "relationship between the following classes",
                    "best represents the relationship",
                    "best illustrates the relationship",
                ],
            ),
            (
                "Reading a given diagram",
                ["given diagram", "study the given", "in the given figure", "represented by"],
            ),
        ],
        "Counting Figures": [
            ("Triangles", ["triangles"]),
            ("Squares and rectangles", ["squares", "rectangles", "quadrilaterals"]),
        ],
        "Dice and Cubes": [
            ("Opposite faces of a dice", ["opposite", "dice", "die"]),
            ("Painted cube cut into pieces", ["painted", "smaller cubes", "cut into"]),
            ("Sheet folded into a cube", ["folded to form a cube", "sheet is folded"]),
        ],
        "Paper Folding and Cutting": [
            ("Fold, punch and unfold", ["unfolded", "folded and cut", "punched"]),
        ],
        "Word Arrangement": [
            ("Dictionary order", ["dictionary"]),
            ("Logical order", ["logical", "meaningful order"]),
        ],
        "Mathematical Operations": [
            ("Interchanging signs", ["interchanged", "interchange", "interchanging"]),
            ("Symbols standing for operations", ["means", "stands for"]),
            ("Signs to balance an equation", ["balance", "make the equation correct"]),
        ],
        "Order and Ranking": [
            ("Position in a row", ["from the left", "from the right", "in a row", "queue"]),
            ("Rank in a class", ["rank", "ranked", "from the top", "from the bottom"]),
        ],
        "Blood Relations": [
            ("Coded relations", ["a + b", "a - b", "a × b", "a # b", "a $ b", "means"]),  # noqa: RUF001
            (
                "Chain of statements",
                ["is married to", "is the son of", "is the daughter of", "is the father of"],
            ),
        ],
    },
    "Quantitative Aptitude": {
        "Number System": [
            ("Divisibility and remainders", ["divisible", "remainder", "divided by"]),
            ("Unit digit", ["unit digit", "unit's digit", "units digit"]),
            ("HCF and LCM", ["hcf", "lcm", "highest common factor", "least common multiple"]),
        ],
        "Algebra": [
            ("x + 1/x type", ["1/x", "1/a", "1/y"]),
            ("Cube and square identities", ["a³", "x³", "a^3", "x^3", "cube"]),
        ],
        "Trigonometry": [
            ("Heights and distances", ["angle of elevation", "angle of depression", "tower"]),
            ("Identities and values", ["sin²", "cos²", "sec", "cosec", "cot"]),
        ],
        "Percentage": [
            ("Income, expenditure and savings", ["income", "expenditure", "spends", "savings"]),
            ("Population and depreciation", ["population", "depreciat"]),
            ("Votes and marks", ["votes", "election", "candidate", "marks"]),
            ("Price change and consumption", ["consumption", "price of"]),
        ],
        "Ratio and Proportion": [
            ("Dividing an amount", ["divided among", "divided between", "share"]),
            ("Ages", ["age", "years ago", "years hence"]),
        ],
        "Profit and Loss": [
            ("Two articles at the same price", ["two articles", "sold two"]),
            ("False weights", ["false weight", "dishonest", "instead of"]),
            ("Cost and selling price", ["cost price", "selling price", "profit percent"]),
        ],
        "Discount": [
            ("Successive discounts", ["successive discounts", "two successive"]),
            ("Marked price above cost", ["marked", "above the cost price"]),
        ],
        "Simple and Compound Interest": [
            (
                "Difference between CI and SI",
                ["difference between the compound interest", "compound interest and simple"],
            ),
            ("Sum doubles or multiplies", ["doubles itself", "becomes double", "times itself"]),
            (
                "Compounded half-yearly or quarterly",
                ["half-yearly", "compounded half", "quarterly"],
            ),
        ],
        "Time and Work": [
            ("Working together and alone", ["together", "alone"]),
            ("Pipes and cisterns", ["pipe", "tank", "cistern"]),
            ("Wages", ["wages", "earn", "paid"]),
        ],
        "Time, Speed and Distance": [
            ("Trains", ["train", "platform", "pole"]),
            ("Boats and streams", ["stream", "upstream", "downstream", "boat"]),
            ("Average speed", ["average speed"]),
        ],
        "Average": [
            ("Member joins, leaves or is replaced", ["replaced", "joins", "leaves", "excluded"]),
            ("Consecutive numbers", ["consecutive", "natural numbers"]),
            ("Runs and innings", ["runs", "innings", "batsman"]),
        ],
        "Mixture and Alligation": [
            ("Replacement", ["replaced", "drawn off", "taken out"]),
            ("Mixing two kinds by price", ["per kg", "mixed"]),
        ],
        "Geometry": [
            ("Triangles", ["triangle", "centroid", "orthocentre", "incentre", "circumcentre"]),
            ("Circles", ["circle", "chord", "tangent"]),
            ("Polygons", ["polygon", "interior angle", "exterior angle"]),
        ],
        "Mensuration": [
            ("Area and perimeter", ["area of", "perimeter", "rectangle", "rhombus"]),
            (
                "Volume and surface area",
                ["volume", "cylinder", "cone", "sphere", "hemisphere", "cuboid", "surface area"],
            ),
        ],
        "Data Interpretation": [
            ("Bar chart", ["bar graph", "bar chart"]),
            ("Table", ["table"]),
            ("Pie chart", ["pie chart"]),
            ("Line graph", ["line graph"]),
        ],
    },
    "English Language": {
        "Synonyms": [
            ("Word in a sentence", ["underlined", "in the given sentence", "bold"]),
            ("Single word", ["synonym of the given word", "synonym of"]),
        ],
        "Antonyms": [
            ("Word in a sentence", ["underlined", "in the given sentence", "bold"]),
            ("Single word", ["antonym of the given word", "antonym of"]),
        ],
        "Idioms and Phrases": [
            ("Meaning of the idiom", ["meaning of the given idiom", "meaning of the idiom"]),
            ("Idiom in a sentence", ["in the given sentence", "substitute", "underlined"]),
        ],
        "Spelling": [
            ("Find the misspelt word", ["misspelt", "incorrectly spelt"]),
            ("Find the correct spelling", ["correctly spelt", "correct spelling"]),
        ],
        "Para Jumbles": [
            ("Parts of a sentence", ["parts of a sentence", "segments"]),
            ("Sentences of a paragraph", ["logical sequence", "coherent paragraph", "sentences"]),
        ],
        "Active and Passive Voice": [
            ("Active to passive", ["passive voice", "passive form"]),
            ("Passive to active", ["active voice", "active form"]),
        ],
        "Direct and Indirect Speech": [
            ("Direct to indirect", ["indirect speech", "indirect narration", "reported speech"]),
            ("Indirect to direct", ["direct speech", "direct narration"]),
        ],
    },
    "General Awareness": {
        "Polity": [
            ("Constitution articles and schedules", ["article", "schedule"]),
            ("Amendments", ["amendment"]),
            (
                "Parliament and offices",
                ["lok sabha", "rajya sabha", "president", "parliament", "governor"],
            ),
        ],
        "General Science": [
            ("Physics", ["force", "velocity", "current", "lens", "energy", "unit of"]),
            ("Chemistry", ["acid", "element", "compound", "chemical", "metal"]),
            ("Biology", ["cell", "vitamin", "disease", "plant", "blood", "organ"]),
        ],
    },
}

_topics = sa.table(
    "topics",
    sa.column("id", sa.Uuid()),
    sa.column("subject", sa.String()),
    sa.column("name", sa.String()),
)
_patterns = sa.table(
    "question_patterns",
    sa.column("id", sa.Uuid()),
    sa.column("topic_id", sa.Uuid()),
    sa.column("name", sa.String()),
    sa.column("keywords", postgresql.ARRAY(sa.String())),
    sa.column("sort_order", sa.Integer()),
)


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "question_patterns",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("topic_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column(
            "keywords", postgresql.ARRAY(sa.String(length=60)), server_default="{}", nullable=False
        ),
        sa.Column("sort_order", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["topic_id"],
            ["topics.id"],
            name=op.f("fk_question_patterns_topic_id_topics"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_question_patterns")),
        sa.UniqueConstraint("topic_id", "name", name="uq_question_patterns_topic_name"),
    )
    op.create_index(
        op.f("ix_question_patterns_topic_id"), "question_patterns", ["topic_id"], unique=False
    )

    op.add_column("documents", sa.Column("exam_year", sa.Integer(), nullable=True))
    op.add_column("documents", sa.Column("exam_date", sa.Date(), nullable=True))
    op.add_column("documents", sa.Column("exam_shift", sa.Integer(), nullable=True))
    op.add_column(
        "documents",
        sa.Column(
            "paper_date_status", sa.String(length=12), server_default="unknown", nullable=False
        ),
    )
    op.add_column("documents", sa.Column("paper_date_reason", sa.String(length=200), nullable=True))
    op.create_check_constraint(
        op.f("ck_documents_paper_date_status_valid"),
        "documents",
        "paper_date_status IN ('unknown', 'suggested', 'confirmed')",
    )
    op.create_check_constraint(
        op.f("ck_documents_exam_shift_range"),
        "documents",
        "exam_shift IS NULL OR exam_shift BETWEEN 1 AND 9",
    )
    op.create_check_constraint(
        op.f("ck_documents_exam_date_matches_year"),
        "documents",
        "exam_date IS NULL OR (exam_year IS NOT NULL AND exam_year = EXTRACT(YEAR FROM exam_date))",
    )

    op.add_column("questions", sa.Column("pattern_id", sa.Uuid(), nullable=True))
    op.add_column(
        "questions",
        sa.Column(
            "pattern_status", sa.String(length=12), server_default="unassigned", nullable=False
        ),
    )
    op.add_column(
        "questions", sa.Column("pattern_suggestion_reason", sa.String(length=200), nullable=True)
    )
    op.create_index(op.f("ix_questions_pattern_id"), "questions", ["pattern_id"], unique=False)
    op.create_foreign_key(
        op.f("fk_questions_pattern_id_question_patterns"),
        "questions",
        "question_patterns",
        ["pattern_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_check_constraint(
        op.f("ck_questions_pattern_status_valid"),
        "questions",
        "pattern_status IN ('unassigned', 'suggested', 'confirmed')",
    )

    connection = op.get_bind()
    topic_ids = {
        (row.subject, row.name): row.id
        for row in connection.execute(sa.select(_topics.c.id, _topics.c.subject, _topics.c.name))
    }
    rows = []
    for subject, topics in PATTERNS.items():
        for topic, patterns in topics.items():
            topic_id = topic_ids.get((subject, topic))
            if topic_id is None:  # topic removed or renamed locally: skip its patterns
                continue
            for order, (name, keywords) in enumerate(patterns):
                rows.append(
                    {
                        "id": uuid.uuid4(),
                        "topic_id": topic_id,
                        "name": name,
                        "keywords": keywords,
                        "sort_order": order,
                    }
                )
    if rows:
        op.bulk_insert(_patterns, rows)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(op.f("ck_questions_pattern_status_valid"), "questions", type_="check")
    op.drop_constraint(
        op.f("fk_questions_pattern_id_question_patterns"), "questions", type_="foreignkey"
    )
    op.drop_index(op.f("ix_questions_pattern_id"), table_name="questions")
    op.drop_column("questions", "pattern_suggestion_reason")
    op.drop_column("questions", "pattern_status")
    op.drop_column("questions", "pattern_id")
    op.drop_constraint(op.f("ck_documents_exam_date_matches_year"), "documents", type_="check")
    op.drop_constraint(op.f("ck_documents_exam_shift_range"), "documents", type_="check")
    op.drop_constraint(op.f("ck_documents_paper_date_status_valid"), "documents", type_="check")
    op.drop_column("documents", "paper_date_reason")
    op.drop_column("documents", "paper_date_status")
    op.drop_column("documents", "exam_shift")
    op.drop_column("documents", "exam_date")
    op.drop_column("documents", "exam_year")
    op.drop_index(op.f("ix_question_patterns_topic_id"), table_name="question_patterns")
    op.drop_table("question_patterns")
