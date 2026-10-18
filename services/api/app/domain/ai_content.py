"""Prompts, output schemas and validation for AI assistance (pure; no provider calls).

Prompt versions are stored with every AI item so a change in wording is traceable.
Generated content is validated before storage; anything invalid is rejected and counted,
never "repaired" silently.
"""

import unicodedata
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any

PROMPT_VERSION = "p9.3"
OPTIONS_PER_QUESTION = 4  # SSC CGL/CHSL objective questions have four options
MAX_GENERATED = 5

LANGUAGE_NAMES = {"en": "English", "hi": "Hindi (Devanagari script)"}

SYSTEM = (
    "You help Indian students prepare for SSC CGL and SSC CHSL exams. You write original "
    "practice material only. Never claim or imply that anything you write is from an "
    "official or previous-year paper, and never invent exam patterns, cut-offs, marks or "
    "statistics. If you are not sure something is correct, say so in the explanation "
    "instead of guessing."
)

EXPLANATION_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "explanation": {"type": "string"},
        "confident": {"type": "boolean"},
    },
    "required": ["explanation", "confident"],
    "additionalProperties": False,
}

QUESTIONS_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "questions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "stem": {"type": "string"},
                    "options": {"type": "array", "items": {"type": "string"}},
                    "correct_option": {"type": "integer"},
                    "explanation": {"type": "string"},
                },
                "required": ["stem", "options", "correct_option", "explanation"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["questions"],
    "additionalProperties": False,
}

TOPIC_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {"topic": {"anyOf": [{"type": "string"}, {"type": "null"}]}},
    "required": ["topic"],
    "additionalProperties": False,
}


# One answer per question number; topic is "Subject > Topic" copied from the list, or null.
PAPER_TOPICS_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "answers": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "number": {"type": "integer"},
                    "topic": {"anyOf": [{"type": "string"}, {"type": "null"}]},
                },
                "required": ["number", "topic"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["answers"],
    "additionalProperties": False,
}
TOPIC_SEPARATOR = " > "
PAPER_TOPICS_BATCH = 20  # questions per AI call
MAX_TOPIC_STEM = 600
MAX_TOPIC_OPTION = 120


@dataclass(frozen=True, slots=True)
class TopicQuestion:
    number: int  # position in this batch (1-based), not the paper's question number
    stem: str
    options: Sequence[str]
    subject: str | None  # set when the paper's section heading names it


def _fmt_options(options: list[str]) -> str:
    return "\n".join(f"({i}) {text}" for i, text in enumerate(options, start=1))


def explanation_prompt(
    *, stem: str, options: list[str], correct: int, subject: str | None, language: str
) -> str:
    return (
        f"Subject: {subject or 'not given'}\n"
        f"Question:\n{stem}\n\nOptions:\n{_fmt_options(options)}\n\n"
        f"The correct answer is option ({correct}).\n\n"
        f"Write a short step-by-step explanation (at most 150 words) of why option "
        f"({correct}) is correct, in {LANGUAGE_NAMES[language]}. Set confident to false if "
        "you think the given answer may be wrong or the question is unclear."
    )


def questions_from_question_prompt(
    *,
    stem: str,
    options: list[str],
    correct: int,
    subject: str | None,
    topic: str | None,
    language: str,
    count: int,
) -> str:
    return (
        f"Subject: {subject or 'not given'}. Topic: {topic or 'not given'}.\n"
        f"Example question (do not copy it):\n{stem}\n{_fmt_options(options)}\n"
        f"Answer: ({correct})\n\n"
        f"Write {count} new, different multiple-choice practice questions on the same "
        f"topic and level, in {LANGUAGE_NAMES[language]}. Each has exactly "
        f"{OPTIONS_PER_QUESTION} distinct options, exactly one correct option "
        "(correct_option is 1-based) and a short explanation."
    )


def questions_from_notes_prompt(
    *, title: str, notes: str, subject: str, topic: str, language: str, count: int
) -> str:
    return (
        f"Subject: {subject}. Topic: {topic}.\n"
        f"The student's own notes on '{title}':\n{notes or '(no notes)'}\n\n"
        f"Write {count} multiple-choice practice questions that test this concept at SSC "
        f"CGL/CHSL level, in {LANGUAGE_NAMES[language]}. Each has exactly "
        f"{OPTIONS_PER_QUESTION} distinct options, exactly one correct option "
        "(correct_option is 1-based) and a short explanation. If the notes contain a "
        "mistake, do not repeat it."
    )


def topic_prompt(*, stem: str, subject: str, topics: list[str]) -> str:
    listed = "\n".join(f"- {t}" for t in topics)
    return (
        f"Subject: {subject}\nQuestion:\n{stem}\n\n"
        f"Choose the single best topic for this question from this list, copying the name "
        f"exactly:\n{listed}\n\nUse null if none fits."
    )


def paper_topics_prompt(
    questions: Sequence[TopicQuestion], topics: Sequence[str], exam_name: str = "a competitive"
) -> str:
    """``topics`` are "Subject > Topic" labels."""
    listed = "\n".join(f"- {t}" for t in topics)
    blocks = []
    for q in questions:
        options = " | ".join(o[:MAX_TOPIC_OPTION] for o in q.options)
        subject = f" (subject: {q.subject})" if q.subject else ""
        blocks.append(f"[{q.number}]{subject} {q.stem[:MAX_TOPIC_STEM]}\nOptions: {options}")
    return (
        f"These are questions from a {exam_name} exam paper. Some text may be incomplete "
        "where the "
        "paper had a figure or formula. For each question, choose the single best topic from "
        'this list, copying the label exactly ("Subject > Topic"). If a question names its '
        "subject, choose a topic of that subject. Use null when you are not sure or nothing "
        f"fits; a wrong topic is worse than none.\n\nTopics:\n{listed}\n\nQuestions:\n"
        + "\n\n".join(blocks)
        + "\n\nAnswer once for every question number."
    )


# A draft topic list for an exam, from samples of the learner's own imported questions.
TAXONOMY_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "subjects": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "topics": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "keywords": {"type": "array", "items": {"type": "string"}},
                            },
                            "required": ["name", "keywords"],
                            "additionalProperties": False,
                        },
                    },
                },
                "required": ["name", "topics"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["subjects"],
    "additionalProperties": False,
}
TAXONOMY_SAMPLE = 60  # questions sent
TAXONOMY_STEM = 300  # characters per question
MAX_DRAFT_SUBJECTS = 10
MAX_DRAFT_TOPICS_PER_SUBJECT = 15
MAX_DRAFT_TOPICS = 60
MAX_DRAFT_KEYWORDS = 8


def taxonomy_prompt(exam_name: str, stems: Sequence[str], existing: Sequence[str]) -> str:
    """``existing`` are "Subject > Topic" labels the exam already has (not to repeat)."""
    listed = "\n".join(f"- {s[:TAXONOMY_STEM]}" for s in stems)
    have = "\n".join(f"- {t}" for t in existing) or "(none)"
    return (
        f"These are sample questions from {exam_name} papers a learner imported. Propose the "
        "subjects and topics a learner would use to organise questions like these, as a "
        'syllabus-style list. Use short, standard names (e.g. "Biology" > "Cell Biology"). '
        "For each topic give up to 8 keywords or short phrases that appear in such questions' "
        "wording, so questions can be matched to it. Only propose topics these questions "
        "actually cover; do not invent exam patterns, question counts or marking. "
        f"Do not repeat topics the exam already has.\n\nAlready has:\n{have}\n\n"
        f"Questions:\n{listed}"
    )


@dataclass(frozen=True, slots=True)
class DraftTopic:
    subject: str
    name: str
    keywords: tuple[str, ...]


def _clean_name(value: object, longest: int) -> str | None:
    if not isinstance(value, str):
        return None
    text = " ".join(unicodedata.normalize("NFC", value).split())
    return text if 2 <= len(text) <= longest else None


def validate_taxonomy(data: dict[str, Any], existing: Sequence[str]) -> list[DraftTopic]:
    """Bounded, de-duplicated draft. Topics the exam already has are dropped, as is anything
    malformed; the learner edits the rest before anything is saved."""
    subjects = data.get("subjects")
    if not isinstance(subjects, list):
        return []
    have = {_norm(t) for t in existing}
    seen: set[str] = set()
    result: list[DraftTopic] = []
    for subject in subjects[:MAX_DRAFT_SUBJECTS]:
        if not isinstance(subject, dict):
            continue
        subject_name = _clean_name(subject.get("name"), 80)
        topics = subject.get("topics")
        if subject_name is None or not isinstance(topics, list):
            continue
        for topic in topics[:MAX_DRAFT_TOPICS_PER_SUBJECT]:
            if not isinstance(topic, dict):
                continue
            name = _clean_name(topic.get("name"), 80)
            if name is None:
                continue
            label = _norm(f"{subject_name}{TOPIC_SEPARATOR}{name}")
            if label in have or label in seen:
                continue
            seen.add(label)
            keywords: list[str] = []
            raw = topic.get("keywords")
            for keyword in raw if isinstance(raw, list) else []:
                clean = _clean_name(keyword, 40)
                if clean and _norm(clean) not in {_norm(k) for k in keywords}:
                    keywords.append(clean)
                if len(keywords) == MAX_DRAFT_KEYWORDS:
                    break
            result.append(DraftTopic(subject_name, name, tuple(keywords)))
            if len(result) == MAX_DRAFT_TOPICS:
                return result
    return result


# --- validation -----------------------------------------------------------------------

MAX_STEM = 2000
MAX_OPTION = 500
MAX_EXPLANATION = 3000
MIN_STEM = 10


def _norm(text: str) -> str:
    return " ".join(unicodedata.normalize("NFC", text).split()).casefold()


@dataclass(frozen=True, slots=True)
class GeneratedQuestion:
    stem: str
    options: list[str]
    correct_option: int
    explanation: str


def validate_generated(
    item: Any, *, avoid_stems: Sequence[str] = ()
) -> tuple[GeneratedQuestion | None, list[str]]:
    """Checks one generated question. Returns the cleaned question, or None with the
    reasons it was rejected (codes, safe to store and show)."""
    problems: list[str] = []
    if not isinstance(item, dict):
        return None, ["not_an_object"]
    stem = item.get("stem")
    options = item.get("options")
    correct = item.get("correct_option")
    explanation = item.get("explanation")

    if not isinstance(stem, str) or not (MIN_STEM <= len(stem.strip()) <= MAX_STEM):
        problems.append("bad_stem")
    if not isinstance(options, list) or len(options) != OPTIONS_PER_QUESTION:
        problems.append("wrong_option_count")
    elif not all(isinstance(o, str) and 0 < len(o.strip()) <= MAX_OPTION for o in options):
        problems.append("bad_option")
    elif len({_norm(o) for o in options}) != len(options):
        problems.append("duplicate_options")
    if (
        isinstance(correct, bool)
        or not isinstance(correct, int)
        or not 1 <= correct <= OPTIONS_PER_QUESTION
    ):
        problems.append("bad_answer")
    if not isinstance(explanation, str) or not (0 < len(explanation.strip()) <= MAX_EXPLANATION):
        problems.append("bad_explanation")
    if isinstance(stem, str) and _norm(stem) in {_norm(s) for s in avoid_stems}:
        problems.append("copied_source")
    if problems:
        return None, problems
    assert isinstance(stem, str) and isinstance(options, list)  # noqa: S101 - checked above
    assert isinstance(correct, int) and isinstance(explanation, str)  # noqa: S101
    clean = [unicodedata.normalize("NFC", o.strip()) for o in options]
    return (
        GeneratedQuestion(
            stem=unicodedata.normalize("NFC", stem.strip()),
            options=clean,
            correct_option=correct,
            explanation=unicodedata.normalize("NFC", explanation.strip()),
        ),
        [],
    )


def validate_explanation(data: dict[str, Any]) -> tuple[str | None, bool]:
    """Returns (explanation or None if unusable, whether the model was confident)."""
    text = data.get("explanation")
    confident = data.get("confident") is True
    if not isinstance(text, str) or not (0 < len(text.strip()) <= MAX_EXPLANATION):
        return None, confident
    return unicodedata.normalize("NFC", text.strip()), confident


def pick_paper_topics(
    data: dict[str, Any], numbers: Sequence[int], topics: Sequence[str]
) -> dict[int, str]:
    """number -> exact topic label, only for numbers asked about, answered exactly once, with
    a label from the list. Everything else is dropped (and counted by the caller)."""
    answers = data.get("answers")
    if not isinstance(answers, list):
        return {}
    by_key = {_norm(t): t for t in topics}
    wanted = set(numbers)
    seen: dict[int, int] = {}
    chosen: dict[int, str] = {}
    for answer in answers:
        if not isinstance(answer, dict):
            continue
        number, topic = answer.get("number"), answer.get("topic")
        if not isinstance(number, int) or isinstance(number, bool) or number not in wanted:
            continue
        seen[number] = seen.get(number, 0) + 1
        if isinstance(topic, str) and _norm(topic) in by_key:
            chosen[number] = by_key[_norm(topic)]
    return {n: t for n, t in chosen.items() if seen[n] == 1}


def pick_topic(data: dict[str, Any], topics: list[str]) -> str | None:
    """The chosen topic if it is exactly one of [topics] (case-insensitive), else None."""
    choice = data.get("topic")
    if not isinstance(choice, str):
        return None
    by_key = {_norm(t): t for t in topics}
    return by_key.get(_norm(choice))
