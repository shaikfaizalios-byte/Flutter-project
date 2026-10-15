"""question figures and topic taxonomy

Figures cropped from source PDFs (``question_figures``), the reason a topic was suggested,
and a larger SSC topic taxonomy. Keywords only drive *suggestions*: a phrase counts more the
more words it has, and more again when it appears in the question's first sentence (the
instruction), so "Select the correct passive form" beats a "percent" later in the sentence.

"Geometry and Mensuration" is split: the existing row is renamed "Geometry" (questions keep
their assignment) and "Mensuration" is added.

Revision ID: 0009
Revises: 0008
Create Date: 2026-10-14 22:11:27.400137

"""

import uuid
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0009"
down_revision: str | Sequence[str] | None = "0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TAXONOMY: dict[str, dict[str, list[str]]] = {
    "General Intelligence": {
        "Analogy": [
            "analogy",
            "is related to",
            "same way as",
            "related in the same way",
            "सादृश्य",
        ],
        "Classification (Odd One Out)": [
            "odd one out",
            "does not belong",
            "alike in a certain way",
            "one is different",
            "odd word",
            "odd number",
            "odd letters",
            "विषम",
        ],
        "Coding-Decoding": ["coded as", "code language", "is written as", "कूट", "कोड भाषा"],
        "Series": [
            "series",
            "next number",
            "missing number",
            "replace the question mark",
            "श्रृंखला",
        ],
        "Letter Series": ["sequentially placed", "letter series", "blanks of the given"],
        "Figure Series": ["figure series", "come next in the following figure"],
        "Blood Relations": [
            "brother",
            "sister",
            "father",
            "mother",
            "son of",
            "daughter",
            "married to",
            "husband",
            "wife",
            "grandfather",
            "blood relation",
        ],
        "Syllogism": [
            "statements",
            "conclusions",
            "syllogism",
            "follow from the statements",
            "कथन",
            "निष्कर्ष",
        ],
        "Mirror and Water Images": [
            "mirror image",
            "water image",
            "mirror is placed",
            "दर्पण",
        ],
        "Venn Diagrams": [
            "venn diagram",
            "relationship between the following classes",
            "वेन आरेख",
        ],
        "Embedded Figures": ["embedded", "is hidden", "निहित"],
        "Paper Folding and Cutting": [
            "paper is folded",
            "folded and cut",
            "is folded",
            "unfolded",
            "punched",
        ],
        "Counting Figures": [
            "how many triangles",
            "how many squares",
            "how many rectangles",
            "number of triangles",
            "कितने त्रिभुज",
        ],
        "Dice and Cubes": ["dice", "opposite to the face", "faces of a cube", "पासा"],
        "Word Arrangement": [
            "logical and meaningful order",
            "meaningful order",
            "dictionary order",
            "arrange the following words",
        ],
        "Mathematical Operations": [
            "interchanged",
            "mathematical signs",
            "balance the equation",
            "equation correct",
            "signs are interchanged",
        ],
        "Direction and Distance": [
            "north",
            "south",
            "east",
            "west",
            "turns left",
            "turns right",
            "दिशा",
        ],
        "Order and Ranking": ["rank", "from the top", "from the bottom", "position from"],
    },
    "Quantitative Aptitude": {
        "Number System": [
            "divisible",
            "remainder",
            "lcm",
            "hcf",
            "prime number",
            "unit digit",
            "unit's digit",
            "factors",
            "largest number",
            "smallest number",
        ],
        "Simplification": ["simplify", "simplified value", "simplification", "सरल"],
        "Algebra": [
            "x + 1/x",
            "a + b + c",
            "quadratic",
            "polynomial",
            "algebraic",
            "value of x",
        ],
        "Trigonometry": [
            "sin",
            "cos",
            "tan",
            "cot",
            "sec",
            "cosec",
            "θ",
            "trigonometric",
            "angle of elevation",
            "angle of depression",
        ],
        "Percentage": ["percent", "%", "प्रतिशत"],
        "Ratio and Proportion": ["ratio", "proportion", "divided among", "share", "अनुपात"],
        "Profit and Loss": [
            "profit",
            "loss",
            "gain",
            "gained",
            "sold",
            "cost price",
            "selling price",
            "लाभ",
            "हानि",
        ],
        "Discount": ["discount", "marked price", "list price", "बट्टा"],
        "Simple and Compound Interest": [
            "simple interest",
            "compound interest",
            "interest",
            "p.a.",
            "per annum",
            "ब्याज",
        ],
        "Time and Work": ["work", "days to complete", "pipes", "cistern", "working together"],
        "Time, Speed and Distance": [
            "speed",
            "km/h",
            "km/hr",
            "distance",
            "train",
            "boat",
            "stream",
            "चाल",
        ],
        "Average": ["average", "औसत"],
        "Mixture and Alligation": ["mixture", "alligation", "milk and water"],
        "Partnership": ["partnership", "partners", "invested"],
        "Geometry": [
            "triangle",
            "circle",
            "chord",
            "tangent",
            "angle",
            "quadrilateral",
            "parallel",
            "median",
            "bisector",
            "inscribed",
            "∆",
            "त्रिभुज",
        ],
        "Mensuration": [
            "area",
            "volume",
            "perimeter",
            "surface area",
            "cylinder",
            "cone",
            "sphere",
            "hemisphere",
            "cuboid",
            "radius",
            "क्षेत्रफल",
            "आयतन",
        ],
        "Data Interpretation": [
            "bar graph",
            "pie chart",
            "line graph",
            "the given table",
            "following table",
            "the given graph",
            "the given chart",
        ],
    },
    "English Language": {
        "Synonyms": ["synonym", "similar in meaning", "same meaning"],
        "Antonyms": ["antonym", "opposite in meaning"],
        "Idioms and Phrases": ["idiom", "phrase"],
        "One Word Substitution": [
            "group of words",
            "one word",
            "single word",
            "substitute for the given",
        ],
        "Error Spotting": [
            "error",
            "incorrect part",
            "grammatically",
            "grammatical error",
            "contains an error",
        ],
        "Sentence Improvement": [
            "underlined segment",
            "underlined part",
            "no improvement",
            "improve the",
        ],
        "Fill in the Blanks": ["fill in the blank", "blank"],
        "Cloze Test": ["for blank no", "blank no", "blank number", "cloze"],
        "Spelling": ["spelling", "correctly spelt", "wrongly spelt", "misspelt", "spelt"],
        "Para Jumbles": [
            "jumbled sentences",
            "jumbled",
            "correct order",
            "logical sequence",
            "rearrange",
        ],
        "Active and Passive Voice": ["passive", "active voice", "passive voice", "active form"],
        "Direct and Indirect Speech": [
            "indirect speech",
            "direct speech",
            "indirect form",
            "direct form",
            "narration",
            "reported speech",
        ],
        "Reading Comprehension": ["passage", "comprehension"],
    },
    "General Awareness": {
        "History": [
            "dynasty",
            "empire",
            "revolt",
            "independence",
            "freedom struggle",
            "mughal",
            "founded by",
            "samaj",
            "movement",
            "battle of",
            "इतिहास",
        ],
        "Geography": [
            "river",
            "mountain",
            "climate",
            "soil",
            "lake",
            "plateau",
            "ocean",
            "solar system",
            "planet",
            "himalaya",
            "भूगोल",
        ],
        "Polity": [
            "constitution",
            "article",
            "parliament",
            "president",
            "lok sabha",
            "rajya sabha",
            "union territor",
            "governor",
            "amendment",
            "fundamental rights",
            "संविधान",
        ],
        "Economy": [
            "gdp",
            "inflation",
            "bank",
            "budget",
            "rbi",
            "financial",
            "investment",
            "tax",
            "economy",
            "अर्थव्यवस्था",
        ],
        "General Science": [
            "physics",
            "chemistry",
            "biology",
            "vitamin",
            "si unit",
            "acid",
            "chemical",
            "element",
            "disease",
            "nutrition",
            "विज्ञान",
        ],
        "Computer Awareness": [
            "computer",
            "software",
            "excel",
            "pivot table",
            "communication technology",
            "internet",
            "keyboard",
        ],
        "Sports": [
            "medal",
            "world cup",
            "tournament",
            "olympic",
            "championship",
            "football",
            "cricket",
            "icc",
            "trophy",
        ],
        "Awards and Honours": ["award", "prize", "honoured", "bharat ratna", "padma"],
        "Books and Authors": ["author", "novel", "written by", "autobiography", "poet"],
        "Art and Culture": ["festival", "dance", "classical", "folk", "music"],
        "Important Days": ["celebrated on", "observed on", "day is celebrated", "world day"],
        "Current Affairs": [
            "appointed",
            "inaugurated",
            "recently",
            "launched",
            "announced",
            "elected to the board",
        ],
    },
}

# Keywords before this migration, restored on downgrade.
_OLD_KEYWORDS: dict[tuple[str, str], list[str]] = {
    ("Quantitative Aptitude", "Percentage"): ["percent", "%", "प्रतिशत"],
    ("Quantitative Aptitude", "Ratio and Proportion"): ["ratio", "proportion", "अनुपात"],
    ("Quantitative Aptitude", "Profit and Loss"): [
        "profit",
        "loss",
        "cost price",
        "selling price",
        "लाभ",
        "हानि",
    ],
    ("Quantitative Aptitude", "Simple and Compound Interest"): [
        "simple interest",
        "compound interest",
        "ब्याज",
    ],
    ("Quantitative Aptitude", "Time and Work"): ["work", "days to complete", "pipes", "cistern"],
    ("Quantitative Aptitude", "Time, Speed and Distance"): [
        "speed",
        "km/h",
        "distance",
        "train",
        "चाल",
    ],
    ("Quantitative Aptitude", "Average"): ["average", "औसत"],
    ("Quantitative Aptitude", "Geometry and Mensuration"): [
        "triangle",
        "circle",
        "area",
        "volume",
        "perimeter",
    ],
    ("General Intelligence", "Analogy"): ["analogy", "is related to", "same way as", "सादृश्य"],
    ("General Intelligence", "Coding-Decoding"): ["coded as", "code language", "कूट"],
    ("General Intelligence", "Series"): ["series", "next number", "missing number", "श्रृंखला"],
    ("General Intelligence", "Blood Relations"): [
        "brother",
        "sister",
        "father",
        "mother",
        "related to",
    ],
    ("General Intelligence", "Syllogism"): ["statements", "conclusions", "syllogism"],
    ("General Intelligence", "Mirror and Water Images"): ["mirror image", "water image", "दर्पण"],
    ("English Language", "Synonyms"): ["synonym", "similar in meaning", "same meaning"],
    ("English Language", "Antonyms"): ["antonym", "opposite in meaning"],
    ("English Language", "Idioms and Phrases"): ["idiom", "phrase"],
    ("English Language", "Error Spotting"): ["error", "incorrect part", "grammatically"],
    ("English Language", "Fill in the Blanks"): ["fill in the blank", "blank"],
    ("English Language", "Spelling"): ["spelling", "correctly spelt", "misspelt"],
    ("English Language", "Reading Comprehension"): ["passage", "comprehension"],
    ("General Awareness", "History"): ["dynasty", "empire", "revolt", "independence", "इतिहास"],
    ("General Awareness", "Geography"): ["river", "mountain", "climate", "soil", "भूगोल"],
    ("General Awareness", "Polity"): [
        "constitution",
        "article",
        "parliament",
        "president",
        "संविधान",
    ],
    ("General Awareness", "Economy"): ["gdp", "inflation", "bank", "budget", "अर्थव्यवस्था"],
    ("General Awareness", "General Science"): [
        "physics",
        "chemistry",
        "biology",
        "vitamin",
        "विज्ञान",
    ],
}

_topics = sa.table(
    "topics",
    sa.column("id", sa.Uuid()),
    sa.column("subject", sa.String()),
    sa.column("name", sa.String()),
    sa.column("keywords", postgresql.ARRAY(sa.String())),
)


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "question_figures",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("question_id", sa.Uuid(), nullable=False),
        sa.Column("kind", sa.String(length=8), nullable=False),
        sa.Column("option_position", sa.Integer(), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("page_number", sa.Integer(), nullable=False),
        sa.Column("box", postgresql.ARRAY(sa.Float()), nullable=False),
        sa.Column("width", sa.Integer(), nullable=False),
        sa.Column("height", sa.Integer(), nullable=False),
        sa.Column("content_type", sa.String(length=32), nullable=False),
        sa.Column("data", sa.LargeBinary(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "(kind = 'option') = (option_position IS NOT NULL)",
            name=op.f("ck_question_figures_option_position_iff_option"),
        ),
        sa.CheckConstraint(
            "kind IN ('stem', 'option', 'original')", name=op.f("ck_question_figures_kind_valid")
        ),
        sa.CheckConstraint("page_number >= 1", name=op.f("ck_question_figures_page_positive")),
        sa.ForeignKeyConstraint(
            ["question_id"],
            ["questions.id"],
            name=op.f("fk_question_figures_question_id_questions"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_question_figures")),
    )
    op.create_index(
        op.f("ix_question_figures_question_id"), "question_figures", ["question_id"], unique=False
    )
    op.add_column(
        "questions", sa.Column("topic_suggestion_reason", sa.String(length=200), nullable=True)
    )

    connection = op.get_bind()
    connection.execute(
        _topics.update()
        .where(
            _topics.c.subject == "Quantitative Aptitude",
            _topics.c.name == "Geometry and Mensuration",
        )
        .values(name="Geometry")
    )
    existing = {
        (row.subject, row.name)
        for row in connection.execute(sa.select(_topics.c.subject, _topics.c.name))
    }
    new_rows = []
    for subject, topics in TAXONOMY.items():
        for name, keywords in topics.items():
            if (subject, name) in existing:
                connection.execute(
                    _topics.update()
                    .where(_topics.c.subject == subject, _topics.c.name == name)
                    .values(keywords=keywords)
                )
            else:
                new_rows.append(
                    {"id": uuid.uuid4(), "subject": subject, "name": name, "keywords": keywords}
                )
    if new_rows:
        op.bulk_insert(_topics, new_rows)


def downgrade() -> None:
    """Downgrade schema."""
    connection = op.get_bind()
    added = [
        (subject, name)
        for subject, topics in TAXONOMY.items()
        for name in topics
        if (subject, name) not in _OLD_KEYWORDS and name != "Geometry"
    ]
    for subject, name in added:
        # Questions assigned to a removed topic lose the assignment (FK is SET NULL).
        connection.execute(
            _topics.delete().where(_topics.c.subject == subject, _topics.c.name == name)
        )
    connection.execute(
        sa.text(
            "UPDATE questions SET topic_status = 'unassigned', topic_suggested_by = NULL"
            " WHERE topic_id IS NULL AND topic_status <> 'unassigned'"
        )
    )
    connection.execute(
        _topics.update()
        .where(_topics.c.subject == "Quantitative Aptitude", _topics.c.name == "Geometry")
        .values(name="Geometry and Mensuration")
    )
    for (subject, name), keywords in _OLD_KEYWORDS.items():
        connection.execute(
            _topics.update()
            .where(_topics.c.subject == subject, _topics.c.name == name)
            .values(keywords=keywords)
        )

    op.drop_column("questions", "topic_suggestion_reason")
    op.drop_index(op.f("ix_question_figures_question_id"), table_name="question_figures")
    op.drop_table("question_figures")
