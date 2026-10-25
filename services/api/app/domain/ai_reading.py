"""Reading a paper's questions with AI, when PrepLoop's own reader (segmentation rules) can't.

The model sees each page as an image plus its extracted text and returns the questions as
structured data. Because a model can paraphrase or "fix" text, every question is compared
with the page's own text; questions that don't match, or come from pages without a text
layer to compare with (scans), get a review issue. Nothing is corrected silently, and the
question records that it was read by AI.
"""

import re
import unicodedata
from collections.abc import Sequence
from dataclasses import dataclass, field
from typing import Any

from app.domain.ai_content import LANGUAGE_NAMES
from app.domain.segmentation import Issue, IssueCode

PAGES_PER_CALL = 3  # main pages per request; the next page is added as context
MAX_STEM = 4000
MAX_OPTION = 1000
MAX_OPTIONS = 6
MAX_WRITTEN_ANSWER = 20_000
# Share of the AI's words that must appear on the page for the text to count as copied.
MIN_TEXT_MATCH = 0.85

# Issue codes for AI-read questions (labels are localised in the app).
AI_TEXT_MISMATCH = "ai_text_mismatch"
AI_READ_UNCHECKED = "ai_read_unchecked"

READ_SYSTEM = (
    "You copy multiple-choice questions out of exam papers. Copy the text EXACTLY as printed: "
    "never correct spelling, grammar or numbers, never translate, summarise or reword, and "
    "never solve a question. Use the page image for layout (columns, tables, which option "
    "belongs to which question) and the extracted text for exact characters. Give an answer "
    "only when the paper itself shows it (an answer key, a marked option or an 'Ans' line). "
    "When a question needs a picture, diagram, chart or table that can't be written as text, "
    "set has_figure to true. Q&A notes and interview questions have no options: give their "
    "written answer, copied exactly, in written_answer (null for multiple-choice questions). "
    "Skip instructions, headers and anything that is not a question."
)

READ_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "questions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "number": {"type": "integer"},
                    "page": {"type": "integer"},
                    "section": {"anyOf": [{"type": "string"}, {"type": "null"}]},
                    "passage": {"anyOf": [{"type": "string"}, {"type": "null"}]},
                    "stem": {"type": "string"},
                    "options": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "label": {"type": "string"},
                                "text": {"type": "string"},
                            },
                            "required": ["label", "text"],
                            "additionalProperties": False,
                        },
                    },
                    "answer_label": {"anyOf": [{"type": "string"}, {"type": "null"}]},
                    "written_answer": {"anyOf": [{"type": "string"}, {"type": "null"}]},
                    "has_figure": {"type": "boolean"},
                },
                "required": [
                    "number", "page", "section", "passage", "stem", "options",
                    "answer_label", "written_answer", "has_figure",
                ],
                "additionalProperties": False,
            },
        }
    },
    "required": ["questions"],
    "additionalProperties": False,
}  # fmt: skip


@dataclass(frozen=True, slots=True)
class PageInput:
    number: int
    text: str  # the page's extracted text ("" for a scan without OCR text)
    main: bool  # questions starting here are wanted; False = context only


def read_prompt(pages: Sequence[PageInput], language: str) -> str:
    """The images come first (one per page, in this order); this text follows them."""
    main = [p.number for p in pages if p.main]
    parts = []
    for page in pages:
        role = "" if page.main else " (context only: do not return questions starting here)"
        text = page.text.strip() or "(no text layer: read the image)"
        parts.append(f"Page {page.number}{role}. Extracted text (may be out of order):\n{text}")
    return (
        "The images above are the pages listed below, in the same order.\n\n"
        + "\n\n".join(parts)
        + f"\n\nReturn every question that STARTS on page(s) {', '.join(map(str, main))}, "
        "with the number printed on the paper, the page it starts on, its section heading if "
        "one is printed, its reading passage if it has one, its options with their printed "
        f"labels, and the printed answer if any. The paper is in {LANGUAGE_NAMES[language]}; "
        "if it prints each question in two languages, copy only that language."
    )


@dataclass(slots=True)
class ReadOption:
    label: str
    text: str


@dataclass(slots=True)
class ReadQuestion:
    number: int
    page: int
    section: str | None
    passage: str | None
    stem: str
    options: list[ReadOption]
    answer_position: int | None
    has_figure: bool
    issues: list[Issue] = field(default_factory=list)
    # Q&A notes: the answer as written (then there are no options).
    written_answer: str | None = None


def _clean(value: object, longest: int) -> str | None:
    if not isinstance(value, str):
        return None
    text = unicodedata.normalize("NFC", re.sub(r"[ \t]+", " ", value).strip())
    return text if 0 < len(text) <= longest else None


def _label_key(label: str) -> str:
    return re.sub(r"[\s().\[\]]", "", label).casefold()


def validate_read(
    data: dict[str, Any], main_pages: Sequence[int]
) -> tuple[list[ReadQuestion], list[str]]:
    """Usable questions starting on [main_pages], and a reason for each one dropped. A dropped
    question is never repaired; the reviewer still has the source page."""
    raw = data.get("questions")
    if not isinstance(raw, list):
        return [], ["no_question_list"]
    wanted = set(main_pages)
    kept: list[ReadQuestion] = []
    dropped: list[str] = []
    seen: set[tuple[str | None, int]] = set()
    for item in raw:
        if not isinstance(item, dict):
            dropped.append("not_an_object")
            continue
        number, page = item.get("number"), item.get("page")
        if not isinstance(number, int) or number < 1 or not isinstance(page, int):
            dropped.append("bad_number")
            continue
        if page not in wanted:
            continue  # starts on a context page: the next request reads it
        stem = _clean(item.get("stem"), MAX_STEM)
        if stem is None:
            dropped.append("bad_stem")
            continue
        options: list[ReadOption] = []
        raw_options = item.get("options")
        for option in raw_options if isinstance(raw_options, list) else []:
            if not isinstance(option, dict):
                continue
            label = _clean(option.get("label"), 8)
            text = _clean(option.get("text"), MAX_OPTION)
            if label and text:
                options.append(ReadOption(label, text))
        if len(options) == 1 or len(options) > MAX_OPTIONS:
            dropped.append("bad_options")
            continue
        if len({_label_key(o.label) for o in options}) != len(options):
            dropped.append("repeated_labels")
            continue
        section = _clean(item.get("section"), 200)
        key = (section, number)
        if key in seen:
            dropped.append("duplicate_number")
            continue
        seen.add(key)
        question = ReadQuestion(
            number=number,
            page=page,
            section=section,
            passage=_clean(item.get("passage"), MAX_STEM),
            stem=stem,
            options=options,
            answer_position=None,
            has_figure=item.get("has_figure") is True,
        )
        written = None if options else _clean(item.get("written_answer"), MAX_WRITTEN_ANSWER)
        question.written_answer = written
        answer = _clean(item.get("answer_label"), 20)
        if written is not None:
            pass  # a written question needs no option answer
        elif answer is not None:
            by_label = {_label_key(o.label): i + 1 for i, o in enumerate(options)}
            position = by_label.get(_label_key(answer))
            if position is None:
                question.issues.append(
                    Issue(IssueCode.UNRECOGNISED_ANSWER, f"Answer as read by AI: {answer}")
                )
            else:
                question.answer_position = position
        elif options:
            question.issues.append(Issue(IssueCode.MISSING_ANSWER, "No answer printed."))
        if question.has_figure:
            question.issues.append(
                Issue(IssueCode.IMAGE_DEPENDENT, f"Figure on page {page}: see the source page.")
            )
        kept.append(question)
    return kept, dropped


_WORDS = re.compile(r"[\wऀ-ॿ]+")


def text_match(question: ReadQuestion, page_text: str) -> float:
    """Share of the question's words (stem + options) that appear in the page's own text."""
    parts = [question.stem, *(o.text for o in question.options), question.written_answer or ""]
    words = [w.casefold() for w in _WORDS.findall(" ".join(parts))]
    if not words:
        return 0.0
    on_page = {w.casefold() for w in _WORDS.findall(page_text)}
    return sum(1 for w in words if w in on_page) / len(words)


def check_against_page(question: ReadQuestion, page_text: str, next_page_text: str = "") -> None:
    """Adds a review issue when the AI's wording can't be confirmed by the text of the page the
    question starts on (plus the next page, where it may continue). A page without text (a
    scan) can't confirm anything, whatever the next page holds."""
    if not page_text.strip():
        question.issues.append(
            Issue(AI_READ_UNCHECKED, "Read by AI from a page image; compare with the source page.")
        )
        return
    share = text_match(question, f"{page_text}\n{next_page_text}")
    if share < MIN_TEXT_MATCH:
        question.issues.append(
            Issue(
                AI_TEXT_MISMATCH,
                f"Only {round(share * 100)}% of the words read by AI are on the page; "
                "compare with the source page.",
            )
        )
