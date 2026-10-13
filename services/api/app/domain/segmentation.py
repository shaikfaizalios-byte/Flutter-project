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

import re
from collections import Counter, defaultdict
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field

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
    # Document level
    NO_QUESTIONS_FOUND = "no_questions_found"
    NUMBERING_GAPS = "numbering_gaps"
    ANSWER_KEY_UNMATCHED = "answer_key_unmatched"
    ANSWER_KEY_AMBIGUOUS = "answer_key_ambiguous_numbering"
    COUNT_MISMATCH = "count_mismatch"
    SECTION_COUNT_MISMATCH = "section_count_mismatch"


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


# --- patterns --------------------------------------------------------------------------

STRONG_QUESTION = re.compile(
    r"^(?:Q(?:ues(?:tion)?)?\s*\.?\s*(?:no\.?\s*)?|प्रश्न\s*(?:सं(?:ख्या)?\.?\s*)?)"
    rf"(\d{{1,3}})\s*(?:[.):]|{_DASH})?\s*(.*)$",
    re.IGNORECASE,
)
WEAK_QUESTION = re.compile(r"^(\d{1,3})\s*[.)]\s+(.*)$")
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
    rf"^(?:ans(?:wer)?|correct\s+answer|उत्तर)\s*(?:[.:]|{_DASH})?\s*"
    r"\(?\s*([1-9]|[a-eA-E])\s*\)?(?:\s|$|[.,;])",
    re.IGNORECASE,
)
INLINE_EXPLANATION = re.compile(
    rf"^(?:sol(?:ution)?|explanation|exp|हल|व्याख्या)\s*(?:[.:]|{_DASH})\s*(.*)$",
    re.IGNORECASE,
)
KEY_PAIR = re.compile(
    rf"(?:Q\.?\s*)?(\d{{1,3}})\s*(?:[.):]|{_DASH})\s*\(?\s*([1-9]|[a-eA-E])\s*\)?(?![\w])"
    r"|(?:Q\.?\s*)?(\d{1,3})\s*\(\s*([1-9]|[a-eA-E])\s*\)",
)
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


def _section_name(line: str) -> str | None:
    if len(line) > 80:
        return None
    normalized = line.rstrip(f" :.{_DASHES}").strip()
    if normalized.casefold() in KNOWN_SECTION_HEADINGS:
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
    questions: list[ParsedQuestion] = field(default_factory=list)
    passages: list[ParsedPassage] = field(default_factory=list)
    sections: list[str] = field(default_factory=list)
    key_entries: list[tuple[int, str]] = field(default_factory=list)
    explanations: dict[int, list[str]] = field(default_factory=lambda: defaultdict(list))
    mode: str = "questions"  # "questions" | "answer_key" | "explanations"
    section: str | None = None
    current: ParsedQuestion | None = None
    passage: ParsedPassage | None = None
    explanation_target: int | None = None
    inline_explanation: list[str] | None = None
    restarted_numbering: bool = False
    last_number: int | None = None
    last_section: str | None = None

    def finish_question(self) -> None:
        if self.current is not None:
            if self.inline_explanation:
                self.current.explanation = "\n".join(self.inline_explanation).strip() or None
            self.questions.append(self.current)
        self.current = None
        self.inline_explanation = None


def segment(
    pages: Sequence[PageText], *, expected_options: int = EXPECTED_OPTIONS
) -> SegmentationResult:
    lines = _lines(pages)
    state = _State(
        expected_options=expected_options,
        strong_numbering=any(STRONG_QUESTION.match(line.text) for line in lines),
    )
    for line in lines:
        _handle_line(state, line)
    state.finish_question()

    document_issues: list[Issue] = []
    _attach_answer_key(
        state.questions, state.key_entries, state.restarted_numbering, document_issues
    )
    _attach_explanations(state.questions, state.explanations, state.restarted_numbering)
    _validate(state.questions, pages, expected_options, document_issues)
    return SegmentationResult(state.questions, state.passages, document_issues, state.sections)


def _handle_line(state: _State, line: _Line) -> None:
    text = line.text

    # Mode switches: answer key / explanation sections.
    if len(text) <= 60 and ANSWER_KEY_HEADING.match(text):
        state.finish_question()
        state.passage = None
        state.mode = "answer_key"
        state.key_entries.extend(_key_pairs(ANSWER_KEY_HEADING.sub("", text)))
        return
    if EXPLANATION_HEADING.match(text):
        state.finish_question()
        state.passage = None
        state.mode = "explanations"
        return

    if state.mode == "answer_key":
        pairs = _key_pairs(text)
        if pairs:
            state.key_entries.extend(pairs)
            return
        # A heading or a question after the key means the paper continues.
        if not (_section_name(text) or STRONG_QUESTION.match(text)):
            return
        state.mode = "questions"

    if state.mode == "explanations":
        start = STRONG_QUESTION.match(text) or WEAK_QUESTION.match(text)
        if start:
            state.explanation_target = int(start.group(1))
            state.explanations[state.explanation_target].append(start.group(2))
        elif state.explanation_target is not None:
            state.explanations[state.explanation_target].append(text)
        return

    name = _section_name(text)
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
    answer = INLINE_ANSWER.match(text)
    if answer:
        current.answer_position = option_position(answer.group(1))
        current.answer_source = "inline"
        return
    explanation = INLINE_EXPLANATION.match(text)
    if explanation:
        state.inline_explanation = [explanation.group(1)]
        return
    if state.inline_explanation is not None:
        state.inline_explanation.append(text)
        return
    _consume(current, text, state.expected_options)


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
    strong = STRONG_QUESTION.match(text)
    if strong:
        return int(strong.group(1)), strong.group(2)
    weak = None if state.strong_numbering else WEAK_QUESTION.match(text)
    if weak is None:
        return None, text
    number = int(weak.group(1))
    if current is None:
        return number, weak.group(2)
    # "2. ..." while option 2 is expected is an option line, not question 2.
    if len(current.options) < state.expected_options and number == len(current.options) + 1:
        return None, text
    if number == current.number + 1:
        return number, weak.group(2)
    return None, text


def _consume(question: ParsedQuestion, text: str, expected_options: int) -> None:
    """Add a line to the question: text before the first option marker extends the stem
    (or the last option); each option marker starts a new option."""
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
            _add_option(question, numbered.group(1), numbered.group(2))
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
        hint = next((h for h in IMAGE_HINTS if h in question.stem.casefold()), None)
        if hint or (not question.options and len(question.stem) < 40):
            question.image_dependent = True
            question.issues.append(
                Issue(IssueCode.IMAGE_DEPENDENT, f"matched '{hint}'" if hint else "no options")
            )
        if len(question.stem) > MAX_STEM_CHARS or any(
            STRONG_QUESTION.match(part.strip()) for part in question.stem.split("\n")[1:]
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


def validate_question_content(question: ParsedQuestion, expected_options: int) -> list[Issue]:
    """Checks that also apply after a reviewer edits a question."""
    return content_issues(
        option_texts=[o.text for o in question.options],
        answer_position=question.answer_position,
        expected_options=expected_options,
    )


def content_issues(
    *, option_texts: Sequence[str], answer_position: int | None, expected_options: int
) -> list[Issue]:
    issues: list[Issue] = []
    if len(option_texts) != expected_options:
        issues.append(
            Issue(
                IssueCode.INCOMPLETE_OPTIONS,
                f"{len(option_texts)} of {expected_options} options found",
            )
        )
    if any(not text.strip() for text in option_texts):
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
