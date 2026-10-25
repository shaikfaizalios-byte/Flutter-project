"""Deterministic question-paper segmentation.

Input: extracted page texts. Output: questions (stem, options, answer, explanation, shared
passage, source pages), passages and issues. The segmenter never guesses silently: anything
uncertain (gaps, duplicates, unmatched answers, image-dependent questions, ...) becomes an
``Issue`` for a human reviewer.

Paper layouts vary, so the rules are conservative:

* Questions start at ``Q.12`` / ``Question 12`` / ``प्रश्न 12`` (strong markers). Plain ``12.``
  lines start a question only when a paper uses no strong markers *and* the number is the
  expected next one; while option N is expected, an ``N.`` line is an option.
* Options are parsed separately from question boundaries: ``(1)..(4)``, ``(a)..(d)``,
  ``A.``/``a)`` at line start, several per line allowed.
* Directions/passages that name a question range ("questions 21 to 25") are linked to every
  question in that range.
* Answer keys and explanations are separate sections joined **by question number**, never by
  position; numbers that do not exist are reported, not attached elsewhere.
"""

import difflib
import itertools
import re
from collections import Counter, defaultdict
from collections.abc import Collection, Iterable, Sequence
from dataclasses import dataclass, field

from app.domain import typed_answers
from app.domain.text_quality import UNREADABLE_CHARS

EXPECTED_OPTIONS = 4  # SSC objective papers; formats with other counts can pass their own.
_DASHES = "-" + chr(0x2013) + chr(0x2014)  # hyphen, en dash, em dash
_DASH = f"[{_DASHES}]"


class IssueCode:
    # Question level
    MISSING_ANSWER = "missing_answer"
    INCOMPLETE_OPTIONS = "incomplete_options"
    EMPTY_OPTION = "empty_option"
    DUPLICATE_NUMBER = "duplicate_number"
    AMBIGUOUS_BOUNDARY = "ambiguous_boundary"
    IMAGE_DEPENDENT = "image_dependent"
    REPEATED_OPTION_LABELS = "repeated_option_labels"
    ANSWER_NOT_IN_OPTIONS = "answer_not_in_options"
    CONFLICTING_ANSWERS = "conflicting_answers"
    SOURCE_PAGE_NEEDS_REVIEW = "source_page_needs_review"
    # Some characters (ligatures, formulas, symbols) could not be read from the PDF text;
    # the question also carries an image of it as printed.
    UNREADABLE_TEXT = "unreadable_text"
    # An answer line that names no option ("Correct Answer: Sentence 5", a typed-in number):
    # kept as found for the reviewer, never mapped to an option.
    UNRECOGNISED_ANSWER = "unrecognised_answer"
    # "Option 7:" where option 1 was due (an OCR misreading): used in order, flagged.
    OPTION_LABEL_UNCLEAR = "option_label_unclear"
    # Document level
    NO_QUESTIONS_FOUND = "no_questions_found"
    NUMBERING_GAPS = "numbering_gaps"
    ANSWER_KEY_UNMATCHED = "answer_key_unmatched"
    ANSWER_KEY_AMBIGUOUS = "answer_key_ambiguous_numbering"
    COUNT_MISMATCH = "count_mismatch"
    SECTION_COUNT_MISMATCH = "section_count_mismatch"
    FIGURES_NOT_EXTRACTED = "figures_not_extracted"


@dataclass(frozen=True, slots=True)
class PageText:
    number: int
    text: str
    needs_review: bool = False


@dataclass(frozen=True, slots=True)
class Issue:
    code: str
    detail: str = ""


@dataclass(slots=True)
class ParsedOption:
    label: str
    text: str


@dataclass(slots=True)
class ParsedQuestion:
    number: int
    section: str | None
    stem: str
    options: list[ParsedOption]
    pages: list[int]
    passage_index: int | None = None
    answer_position: int | None = None
    answer_source: str | None = None  # "inline" | "answer_key"
    explanation: str | None = None
    image_dependent: bool = False
    issues: list[Issue] = field(default_factory=list)
    answer_type: str = "choice"  # "choice" | "typed"
    typed_answer: str | None = None


@dataclass(slots=True)
class ParsedPassage:
    text: str
    first_question: int | None
    last_question: int | None
    pages: list[int]


@dataclass(slots=True)
class SegmentationResult:
    questions: list[ParsedQuestion]
    passages: list[ParsedPassage]
    document_issues: list[Issue]
    sections: list[str]
    # True when the paper marks questions with "Q.12"-style markers (plain "12." otherwise).
    strong_numbering: bool = True


# --- patterns --------------------------------------------------------------------------

STRONG_QUESTION = re.compile(
    r"^(?:Q(?:ues(?:tion)?)?\s*\.?\s*(?:no\.?\s*)?|प्रश्न\s*(?:सं(?:ख्या)?\.?\s*)?)"
    rf"(\d{{1,3}})\s*(?:[.):]|{_DASH})?\s*(.*)$",
    re.IGNORECASE,
)
# A row of labels such as "Q1 Q2 Q3 Q4" (quarters in a chart or table) is not a question.
_LABEL_ROW = re.compile(r"^\s*(?:Q\s*\d{1,3}[\s,|/-]*){2,}$", re.IGNORECASE)
# Fewer different strong numbers than this only count when the paper isn't plainly numbered.
MIN_STRONG_NUMBERS = 3


def strong_start(text: str) -> re.Match[str] | None:
    """A strong question marker ("Q.12", "Question 12", "प्रश्न 12"), except label rows."""
    if _LABEL_ROW.match(text):
        return None
    return STRONG_QUESTION.match(text)


def uses_strong_numbering(texts: Sequence[str]) -> bool:
    """Strong markers decide the numbering unless they are only a stray line or two in a paper
    plainly numbered "1.", "2.", "3."... (e.g. "Q1 sales" in a passage)."""
    strong = {int(m.group(1)) for t in texts if (m := strong_start(t))}
    if not strong:
        return False
    if len(strong) >= MIN_STRONG_NUMBERS:
        return True
    plain = {int(m.group(1)) for t in texts if (m := WEAK_QUESTION.match(t))}
    return len(plain) < MIN_STRONG_NUMBERS


WEAK_QUESTION = re.compile(r"^(\d{1,3})\s*[.):]\s+(.*)$")
# A question number alone on its line ("4."), its text on the next lines.
BARE_NUMBER = re.compile(r"^(\d{1,3})\s*[.)]$")
SECTION_PREFIX = re.compile(
    rf"^(?:section|part|खंड|भाग)\s*(?:{_DASH}|:)?\s*([A-D]|[IVX]{{1,4}}|\d{{1,2}})?\b\s*"
    rf"(?:{_DASH}|:|\.)?\s*(.*)$",
    re.IGNORECASE,
)
KNOWN_SECTION_HEADINGS = {
    "general intelligence and reasoning",
    "general intelligence",
    "reasoning",
    "quantitative aptitude",
    "quantitative aptitude (basic arithmetic skill)",
    "english language",
    "english language and comprehension",
    "english comprehension",
    "english language (basic knowledge)",
    "general awareness",
    "general knowledge",
    "सामान्य बुद्धि और तर्क",
    "सामान्य बुद्धिमत्ता",
    "सामान्य जागरूकता",
    "सामान्य ज्ञान",
    "मात्रात्मक योग्यता",
    "अंग्रेजी भाषा",
}
ANSWER_KEY_HEADING = re.compile(r"^(?:answer\s*key|answers|उत्तर\s*कुंजी)\b", re.IGNORECASE)
# A heading-only line ("Solutions", "Explanations:"); "Sol: x = 5" is an inline explanation.
EXPLANATION_HEADING = re.compile(r"^(?:explanations?|solutions?|हल|व्याख्या)\s*:?\s*$", re.IGNORECASE)
PASSAGE_RANGE = re.compile(
    r"(?:questions?|q\.?\s*nos?\.?|प्रश्न(?:ों)?\s*(?:संख्या)?)\s*\(?(\d{1,3})\)?\s*"
    rf"(?:{_DASH}|to|से|and|तक)\s*\(?(\d{{1,3}})\)?",
    re.IGNORECASE,
)
PASSAGE_START = re.compile(r"^(?:directions?|read|निर्देश|पढ़)", re.IGNORECASE)
OPTION_INLINE = re.compile(r"(?:(?<=\s)|^)\(\s*([1-9]|[a-eA-E])\s*\)\s*")
OPTION_LINE_START = re.compile(r"^([a-eA-E])\s*[.)]\s+(.*)$")
INLINE_ANSWER = re.compile(
    rf"^(?:ans(?:wer)?|correct\s+answer|उत्तर)\s*(?:[.:;]|{_DASH})?\s*"
    r"(?:option\s*)?\(?\s*([1-9]|[a-eA-E])\s*\)?(?:\s|$|[.,;])",
    re.IGNORECASE,
)
# Any answer line, recognised or not.
# (OCR often reads the colon as ";".)
ANSWER_LABEL = re.compile(
    rf"^(?:ans(?:wer)?|correct\s+answer|उत्तर)\s*(?:[.:;]|{_DASH})\s*(.*)$", re.IGNORECASE
)
INLINE_EXPLANATION = re.compile(
    rf"^(?:sol(?:ution)?|explanation|exp|हल|व्याख्या)\s*(?:[.:]|{_DASH})\s*(.*)$",
    re.IGNORECASE,
)
KEY_PAIR = re.compile(
    rf"(?:Q\.?\s*)?(\d{{1,3}})\s*(?:[.):]|{_DASH})\s*\(?\s*([1-9]|[a-eA-E])\s*\)?(?![\w])"
    r"|(?:Q\.?\s*)?(\d{1,3})\s*\(\s*([1-9]|[a-eA-E])\s*\)",
)
# Answer-key tables. Their text comes out as a row of question numbers and a row of answers
# ("Q. No. 1 2 3 4 5" / "Ans. b c a d b"), possibly over several lines, or one cell per line
# when a PDF lists columns ("1", "b", "2", "c"), or as "1 | b" rows.
KEY_NUMBERS_LABEL = re.compile(
    r"^(?:q(?:uestions?)?\.?\s*(?:nos?|numbers?)\.?|q\.?\s*n\.?|प्रश्न\s*(?:संख्या|सं\.?)?)\s*[:.]?\s*",
    re.IGNORECASE,
)
KEY_ANSWERS_LABEL = re.compile(r"^(?:ans(?:wers?)?|keys?|उत्तर)\s*[:.]?\s*", re.IGNORECASE)
_KEY_CELL_SPLIT = re.compile(r"[\s|,;]+")
_KEY_ANSWER_CELL = re.compile(r"^\(?([1-9]|[a-eA-E])\)?\.?$")
_KEY_NUMBER_CELL = re.compile(r"^(?:Q\.?)?(\d{1,3})\.?$", re.IGNORECASE)
# "Option 1:" / "Option (b)" with the option's text after it or on the next lines.
# The colon (or "." / ")") is required: a bare "Option 4" line is an option's text (in "where
# does the sentence fit" questions the options are "Option 1" ... "Option 4").
OPTION_WORD = re.compile(r"^option\s*\(?\s*([1-9]|[a-eA-E])\s*\)?\s*[:.)]\s*(.*)$", re.IGNORECASE)
# "Question" / "Question: ..." after a passage: the passage ends, the question begins.
QUESTION_LABEL = re.compile(r"^(?:question|प्रश्न)\s*:?\s*(.*)$", re.IGNORECASE)
_COMPREHENSION_PREFIX = re.compile(r"^(?:comprehension|passage)\s*:\s*", re.IGNORECASE)
# "Key in the number ...": a typed-in (TITA) question even when its sentences are numbered.
KEY_IN = re.compile(r"\bkey\s*in\b|\btype\s+in\b", re.IGNORECASE)
# "The correct answer is 3)" / "Correct option is (b)" inside a solution.
SOLUTION_ANSWER = re.compile(
    r"correct\s+(?:answer|option)\s+is\s*(?:option\s*)?\(?\s*([1-9]|[a-eA-E])\s*\)",
    re.IGNORECASE,
)
# How alike an OCR'd answer line and an option's text must be to count as that option.
FUZZY_OPTION_MATCH = 0.9
_BARE_LABEL = re.compile(r"^(?:option\s*)?\(?\s*([1-9]|[a-eA-E])\s*\)?\.?$", re.IGNORECASE)
IMAGE_HINTS = (
    "figure",
    "diagram",
    "mirror image",
    "water image",
    "cube",
    "dice",
    "paper is folded",
    "folded",
    "embedded",
    "following image",
    "given image",
    "pie chart",
    "bar graph",
    "venn diagram",
    "चित्र",
    "आकृति",
    "दर्पण",
    "पासा",
)
MAX_STEM_CHARS = 2500


def _hint_pattern(hint: str) -> re.Pattern[str]:
    """Match ``hint`` even when its first letters were an unreadable glyph (PDF ligatures:
    "figure" is often extracted as U+001F + "gure")."""
    variants = [re.escape(hint)] + [
        UNREADABLE_CHARS + re.escape(hint[k:]) for k in (1, 2) if len(hint) - k >= 3
    ]
    return re.compile("|".join(variants))


_IMAGE_HINT_PATTERNS = [(hint, _hint_pattern(hint)) for hint in IMAGE_HINTS]


def image_hint(text: str) -> str | None:
    """The first image hint found in ``text`` (case-insensitive), else None."""
    folded = text.casefold()
    return next((hint for hint, pattern in _IMAGE_HINT_PATTERNS if pattern.search(folded)), None)


def option_position(label: str) -> int:
    """'1'/'a'/'A' -> 1, '2'/'b'/'B' -> 2, ..."""
    return int(label) if label.isdigit() else ord(label.lower()) - ord("a") + 1


@dataclass(slots=True)
class _Line:
    text: str
    page: int


def _lines(pages: Sequence[PageText]) -> list[_Line]:
    return [
        _Line(stripped, page.number)
        for page in pages
        for raw in page.text.split("\n")
        if (stripped := raw.strip())
    ]


def section_heading(line: str, extra: frozenset[str] = frozenset()) -> str | None:
    """The section name if ``line`` is a section heading, else None. ``extra`` holds more
    known headings (case-folded), e.g. the subjects of the paper's exam."""
    if len(line) > 80:
        return None
    normalized = line.rstrip(f" :.{_DASHES}").strip()
    folded = normalized.casefold()
    if folded in KNOWN_SECTION_HEADINGS or folded in extra:
        return normalized
    match = SECTION_PREFIX.match(line)
    if match and (match.group(1) or match.group(2)):
        label, rest = match.group(1), match.group(2).strip(f" :.{_DASHES}")
        if len(rest) > 60:
            return None  # a sentence that happens to start with "Part", not a heading
        return rest or f"Section {label}"
    return None


# --- main entry point ------------------------------------------------------------------


@dataclass(slots=True)
class _State:
    expected_options: int
    strong_numbering: bool
    extra_headings: frozenset[str] = frozenset()
    questions: list[ParsedQuestion] = field(default_factory=list)
    passages: list[ParsedPassage] = field(default_factory=list)
    sections: list[str] = field(default_factory=list)
    key_entries: list[tuple[int, str]] = field(default_factory=list)
    # An answer-key table being read: numbers waiting for their answers (in order).
    key_numbers: list[int] = field(default_factory=list)
    key_answers: list[str] = field(default_factory=list)
    key_issues: list[str] = field(default_factory=list)
    explanations: dict[int, list[str]] = field(default_factory=lambda: defaultdict(list))
    mode: str = "questions"  # "questions" | "answer_key" | "explanations"
    section: str | None = None
    current: ParsedQuestion | None = None
    passage: ParsedPassage | None = None
    explanation_target: int | None = None
    inline_explanation: list[str] | None = None
    answer_line_seen: bool = False  # the current question had an answer line
    # Text after an empty "Correct Answer:" line (the answer is on the next lines).
    answer_text: list[str] | None = None
    # Earlier questions each had their own answer line: the paper answers inline.
    inline_answers: bool = False
    restarted_numbering: bool = False
    last_number: int | None = None
    last_section: str | None = None

    def finish_question(self) -> None:
        if self.current is not None:
            _settle_answer_text(self)
            if self.inline_explanation:
                self.current.explanation = "\n".join(self.inline_explanation).strip() or None
            _answer_from_solution(self.current)
            _resolve_typed(self.current)
            self.questions.append(self.current)
        self.current = None
        self.inline_explanation = None
        if self.answer_line_seen:
            self.inline_answers = True
        self.answer_line_seen = False


def _resolve_typed(question: ParsedQuestion) -> None:
    """An answer line that names no option makes a typed-in (TITA) question when it gives a
    typed answer and either the question has no options or the answer refers to its listed items
    ("Sentence 5", an order "3-4-2-1"); the listed items then go back into the stem. Otherwise the
    unrecognised answer stays for the reviewer."""
    issue = next((i for i in question.issues if i.code == IssueCode.UNRECOGNISED_ANSWER), None)
    if issue is None:
        return
    typed = typed_answers.from_paper(issue.detail)
    lists_items = (
        typed_answers.names_an_item(issue.detail)
        or typed_answers.orders_items(issue.detail, len(question.options))
        or bool(KEY_IN.search(question.stem))  # "key in the number of that sentence"
    )
    if typed is None or (question.options and not lists_items):
        return
    if question.options:
        listed = "\n".join(f"{o.label}. {o.text}".strip() for o in question.options)
        question.stem = f"{question.stem}\n{listed}".strip()
        question.options = []
    question.issues = [
        i
        for i in question.issues
        if i.code not in (IssueCode.UNRECOGNISED_ANSWER, IssueCode.REPEATED_OPTION_LABELS)
    ]
    question.answer_type = "typed"
    question.typed_answer = typed
    question.answer_position = None
    question.answer_source = "inline"


def segment(
    pages: Sequence[PageText],
    *,
    expected_options: int = EXPECTED_OPTIONS,
    extra_headings: Sequence[str] = (),
) -> SegmentationResult:
    lines = _lines(pages)
    state = _State(
        expected_options=expected_options,
        extra_headings=frozenset(h.strip().casefold() for h in extra_headings if h.strip()),
        strong_numbering=uses_strong_numbering([line.text for line in lines]),
    )
    for line in lines:
        _handle_line(state, line)
    state.finish_question()
    _flush_key_table(state)

    document_issues: list[Issue] = [
        Issue(IssueCode.ANSWER_KEY_UNMATCHED, detail[:500]) for detail in state.key_issues
    ]
    _attach_answer_key(
        state.questions, state.key_entries, state.restarted_numbering, document_issues
    )
    _attach_explanations(state.questions, state.explanations, state.restarted_numbering)
    _validate(state.questions, pages, expected_options, document_issues)
    return SegmentationResult(
        state.questions, state.passages, document_issues, state.sections, state.strong_numbering
    )


def _handle_line(state: _State, line: _Line) -> None:
    text = line.text

    # Mode switches: answer key / explanation sections.
    if len(text) <= 60 and ANSWER_KEY_HEADING.match(text):
        state.finish_question()
        state.passage = None
        state.mode = "answer_key"
        rest = ANSWER_KEY_HEADING.sub("", text).strip(" :.-")
        pairs = _key_pairs(rest)
        if pairs:
            state.key_entries.extend(pairs)
        elif rest:
            _key_table_line(state, rest)
        return
    # Inside a question's solution, another heading ("Solution:" then "Explanation:") is part
    # of that solution, not the start of a solutions section.
    # In a paper whose questions carry their own answers, "Solution:" also belongs to the current
    # question when its answer line couldn't be read.
    in_solution = state.current is not None and (
        state.inline_explanation is not None or state.inline_answers
    )
    if EXPLANATION_HEADING.match(text) and not _explains_current(state) and not in_solution:
        if not state.questions and state.current is None:
            return  # a title ("... Question Paper with / Solutions"), not a solutions section
        state.finish_question()
        state.passage = None
        state.mode = "explanations"
        return

    if state.mode == "answer_key":
        pairs = _key_pairs(text)
        if pairs:
            state.key_entries.extend(pairs)
            return
        if _key_table_line(state, text):
            return
        # A heading or a question after the key means the paper continues.
        if not (section_heading(text, state.extra_headings) or strong_start(text)):
            return
        _flush_key_table(state)
        state.mode = "questions"

    if state.mode == "explanations":
        start = strong_start(text) or WEAK_QUESTION.match(text)
        if start:
            state.explanation_target = int(start.group(1))
            state.explanations[state.explanation_target].append(start.group(2))
        elif state.explanation_target is not None:
            state.explanations[state.explanation_target].append(text)
        return

    name = section_heading(text, state.extra_headings)
    if name is not None:
        state.finish_question()
        state.passage = None
        state.section = name
        if name not in state.sections:
            state.sections.append(name)
        return

    range_match = PASSAGE_RANGE.search(text)
    if PASSAGE_START.match(text) and range_match:
        state.finish_question()
        state.passage = ParsedPassage(
            text=text,
            first_question=int(range_match.group(1)),
            last_question=int(range_match.group(2)),
            pages=[line.page],
        )
        state.passages.append(state.passage)
        return

    number, rest = _question_start(text, state.current, state)
    if number is not None:
        _start_question(state, number, rest, line.page)
        return

    current = state.current
    if current is None:
        if state.passage is not None:
            state.passage.text += "\n" + text
            if line.page not in state.passage.pages:
                state.passage.pages.append(line.page)
        return

    if line.page not in current.pages:
        current.pages.append(line.page)
    if state.answer_text is not None:
        if not (INLINE_EXPLANATION.match(text) or EXPLANATION_HEADING.match(text)):
            state.answer_text.append(text)
            return
        _settle_answer_text(state)
    label = ANSWER_LABEL.match(text)
    if label and state.inline_explanation is None:
        rest = label.group(1).strip()
        if not rest:
            state.answer_line_seen = True
            state.answer_text = []  # "Correct Answer:" with the answer on the next lines
            return
        position = _option_by_text(current, rest)
        if position is not None:
            current.answer_position, current.answer_source = position, "inline"
            state.answer_line_seen = True
            return
    answer = INLINE_ANSWER.match(text)
    # Without options, "Correct Answer: 4" is a typed-in answer, not option 4 (and so it is
    # when the question asks to key the number in).
    if answer and current.options and not KEY_IN.search(current.stem):
        current.answer_position = option_position(answer.group(1))
        current.answer_source = "inline"
        state.answer_line_seen = True
        return
    label = ANSWER_LABEL.match(text)
    if label and state.inline_explanation is None:
        state.answer_line_seen = True
        current.issues.append(Issue(IssueCode.UNRECOGNISED_ANSWER, label.group(1).strip()[:500]))
        return
    explanation = INLINE_EXPLANATION.match(text)
    if explanation:
        state.inline_explanation = [explanation.group(1)]
        return
    if state.inline_explanation is not None:
        state.inline_explanation.append(text)
        return
    question_label = QUESTION_LABEL.match(text)
    if question_label and (current.stem or current.options):
        _split_passage(state, current)
        if question_label.group(1).strip():
            _consume(current, question_label.group(1).strip(), state.expected_options)
        return
    _consume(current, text, state.expected_options)


def _norm_option_text(text: str) -> str:
    """Letters and digits only, lower case: OCR spacing ("Inthe") and punctuation don't count."""
    return re.sub(r"[^0-9a-z\u0900-\u097f]", "", text.casefold())


def _option_by_text(question: ParsedQuestion, text: str) -> int | None:
    """The one option whose text is the given answer text (exactly, ignoring spacing and
    punctuation). None when no option, or more than one, matches."""
    wanted = _norm_option_text(text)
    if not wanted or not question.options:
        return None
    matches = [i + 1 for i, o in enumerate(question.options) if _norm_option_text(o.text) == wanted]
    if matches:
        return matches[0] if len(matches) == 1 else None
    # OCR reads the answer line and the options separately ("advamces" / "advances"): accept
    # a near-identical option only when it clearly stands out from all the others.
    scores = sorted(
        (
            (difflib.SequenceMatcher(None, wanted, _norm_option_text(o.text)).ratio(), i + 1)
            for i, o in enumerate(question.options)
        ),
        reverse=True,
    )
    best, second = scores[0], scores[1] if len(scores) > 1 else (0.0, 0)
    if len(wanted) >= 12 and best[0] >= FUZZY_OPTION_MATCH and best[0] - second[0] >= 0.2:
        return best[1]
    return None


def _settle_answer_text(state: _State) -> None:
    """Resolves the answer written on the lines after "Correct Answer:": an option's text, an
    option label ("3", "(c)"), or else (a typed-in answer, or text matching no option) it is
    kept as found for the reviewer."""
    question, lines = state.current, state.answer_text
    state.answer_text = None
    if question is None or lines is None:
        return
    text = " ".join(line.strip() for line in lines).strip()
    position = _option_by_text(question, text) if question.options else None
    bare = _BARE_LABEL.match(text)
    if position is None and bare and question.options and not KEY_IN.search(question.stem):
        position = option_position(bare.group(1))
    if position is not None:
        question.answer_position, question.answer_source = position, "inline"
        return
    question.issues.append(Issue(IssueCode.UNRECOGNISED_ANSWER, text[:500]))


def _answer_from_solution(question: ParsedQuestion) -> None:
    """No answer found but the solution says "The correct answer is 3)": use that."""
    if question.answer_position is not None or not question.options or not question.explanation:
        return
    if any(i.code == IssueCode.CONFLICTING_ANSWERS for i in question.issues):
        return
    found = {option_position(m.group(1)) for m in SOLUTION_ANSWER.finditer(question.explanation)}
    if len(found) != 1:
        return
    position = found.pop()
    unrecognised = [i for i in question.issues if i.code == IssueCode.UNRECOGNISED_ANSWER]
    # The answer line gave text: it must be that option's text (else it stays for review).
    if unrecognised and unrecognised[0].detail:
        option = question.options[position - 1] if position <= len(question.options) else None
        if option is None or _norm_option_text(option.text) != _norm_option_text(
            unrecognised[0].detail
        ):
            return
    question.issues = [i for i in question.issues if i.code != IssueCode.UNRECOGNISED_ANSWER]
    question.answer_position, question.answer_source = position, "inline"


def _split_passage(state: _State, question: ParsedQuestion) -> None:
    """Text before a "Question" line is the question's passage. Papers that print the same
    passage again for each of its questions share one passage. "Options" read from the passage
    (e.g. "(1) ... (4)" in a data set) are passage text: they go back into it."""
    listed = "\n".join(f"({o.label}) {o.text}".strip() for o in question.options)
    text = _COMPREHENSION_PREFIX.sub("", f"{question.stem}\n{listed}".strip()).strip()
    question.stem = ""
    question.options = []
    question.issues = [
        i
        for i in question.issues
        if i.code not in (IssueCode.REPEATED_OPTION_LABELS, IssueCode.OPTION_LABEL_UNCLEAR)
    ]
    if not text:
        return
    key = _norm_option_text(text)[:400]
    previous = state.passages[-1] if state.passages else None
    if (
        previous is not None
        and previous.last_question is not None
        and previous.last_question == question.number - 1
        and _norm_option_text(previous.text)[:400] == key
    ):
        previous.last_question = question.number
        question.passage_index = len(state.passages) - 1
        return
    state.passages.append(
        ParsedPassage(
            text=text,
            first_question=question.number,
            last_question=question.number,
            pages=list(question.pages),
        )
    )
    question.passage_index = len(state.passages) - 1


def _explains_current(state: _State) -> bool:
    """True when the current question just got its answer inline ("Correct Answer: ...") and
    has no explanation yet: an "Explanation:" heading then belongs to it."""
    current = state.current
    return (
        state.mode == "questions"
        and current is not None
        and state.answer_line_seen
        and state.inline_explanation is None
    )


def _start_question(state: _State, number: int, rest: str, page: int) -> None:
    if (
        state.last_number is not None
        and number <= state.last_number
        and state.section != state.last_section
    ):
        state.restarted_numbering = True  # e.g. Q.1-25 in every section
    state.last_number, state.last_section = number, state.section
    state.finish_question()

    passage = state.passage
    if passage is not None and passage.last_question is not None and number > passage.last_question:
        state.passage = passage = None
    question = ParsedQuestion(
        number=number, section=state.section, stem="", options=[], pages=[page]
    )
    if (
        passage is not None
        and passage.first_question is not None
        and passage.first_question <= number <= (passage.last_question or number)
    ):
        question.passage_index = state.passages.index(passage)
    state.current = question
    _consume(question, rest, state.expected_options)


def _question_start(
    text: str, current: ParsedQuestion | None, state: _State
) -> tuple[int | None, str]:
    # In a plainly numbered paper a stray "Q1 ..." line is text, not a question.
    strong = strong_start(text) if state.strong_numbering else None
    if strong:
        return int(strong.group(1)), strong.group(2)
    weak = None if state.strong_numbering else WEAK_QUESTION.match(text) or BARE_NUMBER.match(text)
    if weak is None:
        return None, text
    number = int(weak.group(1))
    rest = (weak.group(2) or "") if weak.re is WEAK_QUESTION else ""
    if current is None:
        # Between questions (after directions or a heading) only the next number, or the first
        # question a passage names, starts one: "1. ..." lines inside directions are not
        # questions. A new section may start again at any number.
        allowed = set()
        if state.last_number is not None and state.section == state.last_section:
            allowed.add(state.last_number + 1)
            if state.passage is not None and state.passage.first_question is not None:
                allowed.add(state.passage.first_question)
        if allowed and number not in allowed:
            return None, text
        return number, rest
    # "2. ..." while option 2 is expected is an option line, not question 2.
    if len(current.options) < state.expected_options and number == len(current.options) + 1:
        return None, text
    if number == current.number + 1:
        # In a paper that answers each question inline, the next question doesn't start
        # before this one's answer line: "5. ..." is then a fifth item (e.g. sentence 5 of an
        # odd-one-out question), not question 5.
        if (
            state.inline_answers
            and not state.answer_line_seen
            and number == len(current.options) + 1
        ):
            return None, text
        return number, rest
    return None, text


def _consume(question: ParsedQuestion, text: str, expected_options: int) -> None:
    """Add a line to the question: text before the first option marker extends the stem
    (or the last option); each option marker starts a new option."""
    word = OPTION_WORD.match(text)
    if word:
        label = word.group(1)
        expected = len(question.options) + 1
        if label.isdigit() and int(label) > expected_options and expected <= expected_options:
            # "Option 7:" in a four-option question: OCR misread the digit. Kept in order,
            # flagged. (A possible label that skips, e.g. "Option 2" first because the line
            # for option 1 was unreadable, is not renumbered.)
            question.issues.append(
                Issue(IssueCode.OPTION_LABEL_UNCLEAR, f"read as {label}, used as {expected}")
            )
            label = str(expected)
        _add_option(question, label, (word.group(2) or "").strip())
        return
    if not OPTION_INLINE.search(text):
        line_start = OPTION_LINE_START.match(text)
        if line_start:
            _add_option(question, line_start.group(1), line_start.group(2))
            return
        numbered = WEAK_QUESTION.match(text)
        if (
            numbered
            and len(question.options) < expected_options
            and int(numbered.group(1)) == len(question.options) + 1
        ):
            for label, option_text in _numbered_options(text, len(question.options) + 1):
                _add_option(question, label, option_text)
            return
        _append_text(question, text)
        return

    markers = list(OPTION_INLINE.finditer(text))
    leading = text[: markers[0].start()].strip()
    if leading:
        _append_text(question, leading)
    for i, marker in enumerate(markers):
        end = markers[i + 1].start() if i + 1 < len(markers) else len(text)
        _add_option(question, marker.group(1), text[marker.end() : end].strip())


_NUMBERED_MARKER = re.compile(r"(?:^|(?<=\s))(\d)\.\s+")


def _numbered_options(text: str, first: int) -> list[tuple[str, str]]:
    """Split "1. a 2. b" into options when the markers count up from ``first``; anything else
    (a lone "1. a", or numbers out of sequence) stays one option."""
    markers = [m for m in _NUMBERED_MARKER.finditer(text)]
    chosen = []
    expected = first
    for marker in markers:
        if int(marker.group(1)) == expected:
            chosen.append(marker)
            expected += 1
    if len(chosen) < 2 or chosen[0].start() != 0:
        match = WEAK_QUESTION.match(text)
        return [(match.group(1), match.group(2))] if match else []
    parts = []
    for i, marker in enumerate(chosen):
        end = chosen[i + 1].start() if i + 1 < len(chosen) else len(text)
        parts.append((marker.group(1), text[marker.end() : end].strip()))
    return parts


def _append_text(question: ParsedQuestion, text: str) -> None:
    if question.options:
        last = question.options[-1]
        last.text = f"{last.text} {text}".strip()
    else:
        question.stem = f"{question.stem}\n{text}".strip() if question.stem else text.strip()


def _add_option(question: ParsedQuestion, label: str, text: str) -> None:
    if option_position(label) != len(question.options) + 1:
        # Labels restarting (e.g. options repeated in a second language) or skipping:
        # keep the first set and record the rest for the reviewer.
        dropped = f"({label}) {text}".strip()
        existing = [i for i in question.issues if i.code == IssueCode.REPEATED_OPTION_LABELS]
        if existing:
            question.issues.remove(existing[0])
            dropped = f"{existing[0].detail} {dropped}"
        question.issues.append(Issue(IssueCode.REPEATED_OPTION_LABELS, dropped[:500]))
        return
    question.options.append(ParsedOption(label=label, text=text.strip()))


def _key_pairs(text: str) -> list[tuple[int, str]]:
    pairs = []
    for match in KEY_PAIR.finditer(text):
        number = match.group(1) or match.group(3)
        label = match.group(2) or match.group(4)
        pairs.append((int(number), label))
    return pairs


def _key_table_line(state: _State, text: str) -> bool:
    """Reads one line of an answer-key table into the state. False when the line isn't one
    (it is then handled like any other line in the answer key)."""
    numbers_label = KEY_NUMBERS_LABEL.match(text)
    answers_label = None if numbers_label else KEY_ANSWERS_LABEL.match(text)
    label = numbers_label or answers_label
    cells = [c for c in _KEY_CELL_SPLIT.split(text[label.end() :] if label else text) if c]
    numbers = [_KEY_NUMBER_CELL.match(c) for c in cells]
    answers = [_KEY_ANSWER_CELL.match(c) for c in cells]
    # "3 | a": a number and a letter on one line (digits alone also look like answers).
    if not label and not state.key_numbers and _spaced_pairs(state, cells):
        return True
    if not cells or not (all(numbers) or all(answers)):
        return label is not None  # a header cell such as "Q. No. | Answer"
    values = [int(m.group(1)) for m in numbers if m] if all(numbers) else []
    if numbers_label or not state.key_numbers:
        is_answers = bool(answers_label) and all(answers)
    elif answers_label or not values:
        is_answers = all(answers)  # letters, or labelled as answers
    else:
        # Digits after a numbers row: more numbers if they carry on the sequence (a long row
        # split over lines), otherwise the answers.
        continues = not state.key_answers and values[0] == state.key_numbers[-1] + 1
        is_answers = not (continues and _consecutive(values))
    if not is_answers:
        if not values:
            return label is not None
        if state.key_answers:
            _flush_key_table(state)
        state.key_numbers.extend(values)
        return True
    state.key_answers.extend(m.group(1) for m in answers if m)
    if len(state.key_answers) >= len(state.key_numbers):
        _flush_key_table(state)
    return True


def _spaced_pairs(state: _State, cells: list[str]) -> bool:
    """ "1 b 2 c" or "1 | b": number-letter pairs without other separators. Letters only, as
    digit pairs ("1 2") are a row of numbers."""
    if len(cells) < 2 or len(cells) % 2:
        return False
    pairs = []
    for number, answer in zip(cells[::2], cells[1::2], strict=True):
        n, a = _KEY_NUMBER_CELL.match(number), _KEY_ANSWER_CELL.match(answer)
        if not (n and a and a.group(1).isalpha()):
            return False
        pairs.append((int(n.group(1)), a.group(1)))
    state.key_entries.extend(pairs)
    return True


def _consecutive(values: list[int]) -> bool:
    return all(b == a + 1 for a, b in itertools.pairwise(values))


def _flush_key_table(state: _State) -> None:
    """Pairs the table's numbers with its answers. A row whose counts differ is reported and
    left out (answers are never shifted onto the wrong questions)."""
    numbers, answers = state.key_numbers, state.key_answers
    if numbers and len(numbers) == len(answers):
        state.key_entries.extend(zip(numbers, answers, strict=True))
    elif numbers:
        state.key_issues.append(
            f"Answer-key table: {len(numbers)} question numbers ({numbers[0]}-{numbers[-1]}) "
            f"but {len(answers)} answers; these answers were not used."
        )
    state.key_numbers, state.key_answers = [], []


def _attach_answer_key(
    questions: list[ParsedQuestion],
    entries: list[tuple[int, str]],
    restarted_numbering: bool,
    document_issues: list[Issue],
) -> None:
    if not entries:
        return
    numbers = Counter(q.number for q in questions)
    if restarted_numbering and any(count > 1 for count in numbers.values()):
        document_issues.append(
            Issue(
                IssueCode.ANSWER_KEY_AMBIGUOUS,
                "Question numbers restart in each section, so the answer key cannot be "
                "matched by number. Assign answers during review.",
            )
        )
        return
    by_number = {q.number: q for q in questions}
    key: dict[int, set[int]] = defaultdict(set)
    for number, label in entries:
        key[number].add(option_position(label))
    unmatched = sorted(n for n in key if n not in by_number)
    if unmatched:
        document_issues.append(
            Issue(IssueCode.ANSWER_KEY_UNMATCHED, _number_list("Key entries for", unmatched))
        )
    for number, positions in key.items():
        question = by_number.get(number)
        if question is None:
            continue
        if len(positions) > 1 or (
            question.answer_position is not None and question.answer_position not in positions
        ):
            found = sorted(
                {*positions, *([question.answer_position] if question.answer_position else [])}
            )
            question.issues.append(
                Issue(IssueCode.CONFLICTING_ANSWERS, f"Different answers found: {found}")
            )
            question.answer_position = None
            question.answer_source = None
            continue
        question.answer_position = next(iter(positions))
        question.answer_source = "answer_key"


def _attach_explanations(
    questions: list[ParsedQuestion], explanations: dict[int, list[str]], restarted: bool
) -> None:
    if restarted:
        return  # cannot match by number reliably; reviewers can add explanations
    by_number = {q.number: q for q in questions}
    for number, parts in explanations.items():
        question = by_number.get(number)
        if question is not None and question.explanation is None:
            question.explanation = "\n".join(parts).strip() or None


def _validate(
    questions: list[ParsedQuestion],
    pages: Sequence[PageText],
    expected_options: int,
    document_issues: list[Issue],
) -> None:
    if not questions:
        document_issues.append(Issue(IssueCode.NO_QUESTIONS_FOUND))
        return
    flagged_pages = {p.number for p in pages if p.needs_review}
    seen: Counter[tuple[str | None, int]] = Counter()
    for question in questions:
        seen[(question.section, question.number)] += 1
        if seen[(question.section, question.number)] > 1:
            question.issues.append(Issue(IssueCode.DUPLICATE_NUMBER))
        question.issues.extend(validate_question_content(question, expected_options))
        hint = image_hint(question.stem)
        if hint or (
            not question.options and question.answer_type == "choice" and len(question.stem) < 40
        ):
            question.image_dependent = True
            question.issues.append(
                Issue(IssueCode.IMAGE_DEPENDENT, f"matched '{hint}'" if hint else "no options")
            )
        if len(question.stem) > MAX_STEM_CHARS or any(
            strong_start(part.strip()) for part in question.stem.split("\n")[1:]
        ):
            question.issues.append(Issue(IssueCode.AMBIGUOUS_BOUNDARY))
        if question.answer_position is not None and question.answer_position > len(
            question.options
        ):
            question.issues.append(
                Issue(IssueCode.ANSWER_NOT_IN_OPTIONS, f"answer {question.answer_position}")
            )
        if flagged_pages.intersection(question.pages):
            question.issues.append(Issue(IssueCode.SOURCE_PAGE_NEEDS_REVIEW))

    numbers = sorted({q.number for q in questions})
    missing = sorted(set(range(numbers[0], numbers[-1] + 1)) - set(numbers))
    if missing:
        document_issues.append(Issue(IssueCode.NUMBERING_GAPS, _number_list("Missing", missing)))


def validate_question_content(
    question: ParsedQuestion, expected_options: int, option_figures: Collection[int] = ()
) -> list[Issue]:
    """Checks that also apply after a reviewer edits a question."""
    return content_issues(
        option_texts=[o.text for o in question.options],
        answer_position=question.answer_position,
        expected_options=expected_options,
        option_figures=option_figures,
        answer_type=question.answer_type,
        typed_answer=question.typed_answer,
    )


def content_issues(
    *,
    option_texts: Sequence[str],
    answer_position: int | None,
    expected_options: int,
    option_figures: Collection[int] = (),
    answer_type: str = "choice",
    typed_answer: str | None = None,
    model_answer: str | None = None,
) -> list[Issue]:
    """``option_figures``: 1-based positions of options that are figures (their text may be
    empty). Typed-in questions have no options; they only need their typed answer, and
    written questions (Q&A notes) only their written answer."""
    if answer_type == "typed":
        return [] if typed_answer else [Issue(IssueCode.MISSING_ANSWER)]
    if answer_type == "written":
        return [] if model_answer and model_answer.strip() else [Issue(IssueCode.MISSING_ANSWER)]
    issues: list[Issue] = []
    if len(option_texts) != expected_options:
        issues.append(
            Issue(
                IssueCode.INCOMPLETE_OPTIONS,
                f"{len(option_texts)} of {expected_options} options found",
            )
        )
    if any(
        not text.strip() and position not in option_figures
        for position, text in enumerate(option_texts, start=1)
    ):
        issues.append(Issue(IssueCode.EMPTY_OPTION))
    if answer_position is None:
        issues.append(Issue(IssueCode.MISSING_ANSWER))
    return issues


def check_against_format(
    result: SegmentationResult,
    *,
    total_questions: int,
    sections: Iterable[tuple[str, int]],
) -> list[Issue]:
    """Compare found questions with a *verified* exam format. Sections are matched by name
    only, never by position (SSC notices list parts "not in sequence")."""
    issues: list[Issue] = []
    found = len({(q.section, q.number) for q in result.questions})
    if found != total_questions:
        issues.append(
            Issue(
                IssueCode.COUNT_MISMATCH,
                f"Found {found} questions; the format has {total_questions}.",
            )
        )
    counts = Counter(q.section for q in result.questions if q.section)
    for subject, expected in sections:
        matched = [s for s in counts if same_subject(s, subject)]
        if len(matched) == 1 and counts[matched[0]] != expected:
            issues.append(
                Issue(
                    IssueCode.SECTION_COUNT_MISMATCH,
                    f"{matched[0]}: found {counts[matched[0]]}, format has {expected}.",
                )
            )
    return issues


def same_subject(found: str, subject: str) -> bool:
    """Loose name match: 'General Intelligence and Reasoning' ~ 'General Intelligence'."""

    def key(value: str) -> str:
        return re.sub(r"\(.*?\)", "", value).casefold().replace("&", "and").strip()

    a, b = key(found), key(subject)
    return bool(a) and bool(b) and (a in b or b in a)


def _number_list(prefix: str, numbers: list[int]) -> str:
    shown = ", ".join(str(n) for n in numbers[:30])
    more = f" (+{len(numbers) - 30} more)" if len(numbers) > 30 else ""
    return f"{prefix}: {shown}{more}"
