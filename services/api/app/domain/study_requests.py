"""Requests a learner types into the Study search that need more than one short answer (pure).

Two kinds are recognised (app/services/ai_service.py runs them):
  - TOPICS   "10 important topics in iOS across pdfs": the topics the learner's material covers
             most, each with an answer from that material.
  - SUMMARY  "summarize this pdf": a whole paper in 10-15 simple points.
Anything else stays an ordinary search (app/domain/rag.py).

Same rules as RAG: the AI writes only from the numbered sources we send, every item names its
sources, and an item citing something we didn't send rejects the whole result. A list is never
padded: fewer topics than asked means the material covers fewer. "Important" here means covered
most by the learner's own material. It is not a prediction of what an exam will ask.
"""

import re
import unicodedata
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any, Literal

from app.domain.ai_content import LANGUAGE_NAMES
from app.domain.rag import RagSource
from app.domain.untrusted import UNTRUSTED_RULE, material

DEFAULT_TOPICS = 10
MAX_TOPICS = 15  # each comes with an answer: more would not fit one reply
MIN_SUMMARY_POINTS = 10
MAX_SUMMARY_POINTS = 15

# How much is read for a topic list: many short excerpts, spread over the papers.
BROAD_SOURCES = 24
BROAD_SNIPPET_CHARS = 1500

# A paper is read in batches of whole pages; each batch is one AI call, then one more call
# merges them. Past the last batch the summary says which pages it covers.
SUMMARY_BATCH_CHARS = 90_000
SUMMARY_MAX_BATCHES = 4

MAX_ITEM_TITLE = 120
MAX_ITEM_TEXT = 900

_WORD = re.compile(r"[\wऀ-ॿ]+")
_NUMBER_WORDS = {"five": 5, "ten": 10, "twelve": 12, "fifteen": 15, "twenty": 20}

_TOPIC_WORDS = frozenset({"topic", "topics", "concept", "concepts", "टॉपिक", "विषय"})
_QUESTION_WORDS = frozenset({"question", "questions", "प्रश्न"})
_IMPORTANT_WORDS = frozenset(
    {
        "important", "key", "main", "major", "top", "best", "repeated", "common", "frequent",
        "महत्वपूर्ण", "मुख्य", "ज़रूरी", "जरूरी",
    }
)  # fmt: skip
_SUMMARY_WORDS = frozenset(
    {"summarize", "summarise", "summary", "summarized", "summarised", "सारांश", "संक्षेप"}
)
# Words of the request itself: what is left names the subject or the paper.
_FILLER = frozenset(
    {
        "a", "about", "across", "all", "along", "an", "and", "answer", "answers", "are", "based",
        "brief", "briefly", "can", "each", "easy", "explain", "explanation", "explanations",
        "file", "files", "find", "for", "from", "get", "give", "in", "is", "it", "list", "make",
        "material", "me", "most", "my", "note", "notes", "of", "on", "our", "paper", "papers",
        "pdf", "pdfs", "please", "pls", "point", "points", "provide", "quick", "quickly",
        "related", "shortly", "short", "show", "simple", "simpler", "tell", "that", "the",
        "their", "them", "these", "this", "those", "to", "uploaded", "version", "what", "which",
        "with", "write", "you", "document", "documents", "imported", "kindly", "share",
        "और", "का", "की", "के", "को", "कीजिए", "करो", "करें", "दीजिए", "दो", "बताओ", "बताएँ",
        "में", "मेरे", "मेरी", "सभी", "से", "इस", "यह", "उत्तर", "उनके", "पीडीएफ", "पेपर",
        "पेपरों", "नोट्स", "बिंदु", "बिंदुओं", "दें",
    }
)  # fmt: skip


@dataclass(frozen=True, slots=True)
class StudyRequest:
    kind: Literal["topics", "summary"]
    count: int = DEFAULT_TOPICS  # topics asked for
    subject: str = ""  # topics: what about ("" = everything in the papers)
    paper: str = ""  # summary: words naming the paper ("" = "this pdf")


def _words(text: str) -> list[str]:
    return _WORD.findall(unicodedata.normalize("NFC", text))


def parse_study_request(text: str) -> StudyRequest | None:
    """What the search asks for, or None for an ordinary search. Word lists rather than AI, so
    recognising a request costs nothing and behaves the same every time."""
    words = _words(text)
    folded = [w.casefold() for w in words]
    if any(w in _SUMMARY_WORDS for w in folded):
        # A year stays part of a paper's name; "in 12 points" doesn't.
        rest = [
            w
            for w, f in zip(words, folded, strict=True)
            if _is_subject_word(f) or (f.isdecimal() and len(f) > 2)
        ]
        return StudyRequest(kind="summary", paper=" ".join(rest))
    numbers = [int(w) for w in folded if w.isdecimal() and 0 < int(w) < 100]
    numbers += [_NUMBER_WORDS[w] for w in folded if w in _NUMBER_WORDS]
    important = any(w in _IMPORTANT_WORDS for w in folded)
    # "topics in history" is a search; a count or "important" makes it a request for a list.
    # "10 questions on ratio" asks for questions, so those need "important" as well.
    if not (
        (any(w in _TOPIC_WORDS for w in folded) and (numbers or important))
        or (any(w in _QUESTION_WORDS for w in folded) and important)
    ):
        return None
    rest = [w for w, f in zip(words, folded, strict=True) if _is_subject_word(f)]
    return StudyRequest(
        kind="topics",
        count=min(numbers[0], MAX_TOPICS) if numbers else DEFAULT_TOPICS,
        subject=" ".join(rest),
    )


def _is_subject_word(word: str) -> bool:
    return (
        word not in _FILLER
        and word not in _TOPIC_WORDS
        and word not in _QUESTION_WORDS
        and word not in _IMPORTANT_WORDS
        and word not in _SUMMARY_WORDS
        and word not in _NUMBER_WORDS
        and not word.isdecimal()
    )


def matches_paper(hint: str, filename: str) -> bool:
    """Every word of [hint] starts a word of the file name ("maths 2024" ~ "Maths-2024.pdf")."""
    names = [w.casefold() for w in _words(filename)]
    wanted = [w.casefold() for w in _words(hint)]
    return bool(wanted) and all(any(n.startswith(w) for n in names) for w in wanted)


def spread_sources(sources: Sequence[RagSource], limit: int) -> list[RagSource]:
    """At most [limit] sources, taking turns between papers (best first within each), so one
    long PDF can't fill the whole context. Questions and concepts each count as one group."""
    groups: dict[str, list[RagSource]] = {}
    for source in sources:
        groups.setdefault(source.document_id or source.kind, []).append(source)
    spread: list[RagSource] = []
    while len(spread) < limit and any(groups.values()):
        for group in groups.values():
            if group and len(spread) < limit:
                spread.append(group.pop(0))
    return spread


# --- prompts ---------------------------------------------------------------------------------

_COMMON_RULES = (
    "Use ONLY the sources: every item names the sources it comes from in its cited list, using "
    "their markers. Sources may contain OCR mistakes; never guess at garbled text. Never invent "
    "exam patterns, cut-offs, marks or statistics, and never call something official unless a "
    "source says so."
)

TOPICS_SYSTEM = (
    "You list the most important topics in a learner's own study material, with an answer for "
    "each, from numbered sources. A topic is important when the material covers it most: in "
    "several sources, or at length. Most covered comes first. Never say a topic will appear in "
    "an exam. If the sources are not about the subject, set found to false and return no "
    "items. List only what the sources really cover: fewer items than asked is right when "
    "they cover fewer; never pad. " + _COMMON_RULES + UNTRUSTED_RULE
)

SUMMARY_SYSTEM = (
    "You summarise a learner's PDF in short, simple points anyone can follow, from its numbered "
    "pages. Cover the whole document, in its order, and keep the key facts, names and numbers "
    "exactly as written. If it is a question paper, say which subjects and topics it covers and "
    "how, and do not list its questions one by one. If the pages have no readable content, set "
    "found to false and return no items. " + _COMMON_RULES + UNTRUSTED_RULE
)

# Structured output: the API guarantees JSON of this shape, so we never parse free text.
STUDY_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "found": {"type": "boolean"},
        "items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "text": {"type": "string"},
                    "cited": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["title", "text", "cited"],
                "additionalProperties": False,
            },
        },
        "confident": {"type": "boolean"},
    },
    "required": ["found", "items", "confident"],
    "additionalProperties": False,
}


def _blocks(sources: Sequence[RagSource]) -> str:
    return "\n\n".join(
        f"[{s.key}] {s.label}{'' if s.verified else ' (not checked by a reviewer)'}\n"
        + material(s.text)
        for s in sources
    )


def topics_prompt(
    *, request: StudyRequest, exam_name: str | None, sources: Sequence[RagSource], language: str
) -> str:
    exam = f" for {exam_name}" if exam_name else ""
    subject = f"about {material(request.subject)}" if request.subject else "in this material"
    return (
        f"Sources from the learner's material{exam}:\n\n{_blocks(sources)}\n\n"
        f"List up to {request.count} of the most important topics {subject}, most covered "
        f"first, in {LANGUAGE_NAMES[language]}. For each: title (the topic, a few words); text "
        "(its answer: what the material says about it, in simple words, at most 60 words, no "
        "[S#] markers); cited (the markers of the sources it comes from). Ignore sources that "
        "are not about the subject. Set confident to false if the sources are unclear or "
        "disagree."
    )


def summary_prompt(
    *, filename: str, pages: Sequence[RagSource], language: str, part: tuple[int, int] | None = None
) -> str:
    """One batch of pages. [part] = (this batch, batches) when the paper needs more than one."""
    where = f" (part {part[0]} of {part[1]})" if part else ""
    return (
        f"Pages of the learner's PDF {material(filename)}{where}:\n\n{_blocks(pages)}\n\n"
        f"Summarise these pages in {MIN_SUMMARY_POINTS} to {MAX_SUMMARY_POINTS} short points "
        f"in simple words, in {LANGUAGE_NAMES[language]} (fewer if there is little content; "
        "never pad). For each: title (empty); text (one point, at most 40 words, no [S#] "
        "markers); cited (the markers of its pages). Set confident to false if the text is "
        "garbled or hard to follow."
    )


def merge_prompt(*, filename: str, points: Sequence["StudyItem"], language: str) -> str:
    """The points of every batch, to become one summary of the whole paper."""
    lines = "\n".join(f"- {p.text} ({', '.join(p.cited)})" for p in points)
    return (
        f"Points summarising the learner's PDF {material(filename)}, in page order:\n"
        f"{material(lines)}\n\n"
        f"Merge them into {MIN_SUMMARY_POINTS} to {MAX_SUMMARY_POINTS} short points covering "
        f"the whole document, in simple words, in {LANGUAGE_NAMES[language]}, using only these "
        "points. For each: title (empty); text (one point, at most 40 words, no markers); cited "
        "(the markers of the points it comes from). Set confident to false if they don't "
        "fit together."
    )


# --- checks ----------------------------------------------------------------------------------

_MARKER = re.compile(r"\s*\[(S\d+)\]")


@dataclass(frozen=True, slots=True)
class StudyItem:
    title: str
    text: str
    cited: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class StudyResult:
    found: bool
    items: tuple[StudyItem, ...]
    confident: bool


def validate_study(
    data: dict[str, Any], source_keys: Sequence[str], *, limit: int, titled: bool = False
) -> StudyResult | None:
    """The items, or None when they can't be trusted. Each needs text and at least one source;
    any marker that isn't a source we sent rejects the whole result rather than being "cleaned
    up". Markers in the text are removed: the cited list carries them. Extra items past [limit]
    and repeated titles are dropped. [titled]: each item must have a title (topics do)."""
    confident = data.get("confident") is True
    if data.get("found") is not True:
        return StudyResult(found=False, items=(), confident=confident)
    raw = data.get("items")
    if not isinstance(raw, list) or not raw:
        return None
    allowed = set(source_keys)
    items: list[StudyItem] = []
    seen: set[str] = set()
    for entry in raw[: limit * 2]:
        item = _item(entry, allowed)
        if item is None or (titled and not item.title):
            return None
        key = (item.title or item.text).casefold()
        if key not in seen:
            seen.add(key)
            items.append(item)
    return StudyResult(found=True, items=tuple(items[:limit]), confident=confident)


def _item(entry: Any, allowed: set[str]) -> StudyItem | None:
    if not isinstance(entry, dict):
        return None
    title, text, cited = entry.get("title"), entry.get("text"), entry.get("cited")
    if not isinstance(title, str) or not isinstance(text, str) or not isinstance(cited, list):
        return None
    inline = _MARKER.findall(text)
    keys = [c for c in cited if isinstance(c, str)]
    if not (keys or inline) or any(key not in allowed for key in [*keys, *inline]):
        return None
    title = unicodedata.normalize("NFC", title.strip())
    text = unicodedata.normalize("NFC", _MARKER.sub("", text).strip())
    if not 0 < len(text) <= MAX_ITEM_TEXT or len(title) > MAX_ITEM_TITLE:
        return None
    return StudyItem(title=title, text=text, cited=tuple(dict.fromkeys([*keys, *inline])))


def page_batches(pages: Sequence[RagSource]) -> tuple[list[list[RagSource]], int]:
    """Pages grouped into batches of whole pages, and how many pages they hold (past
    SUMMARY_MAX_BATCHES the rest is left out; the summary then says what it covers)."""
    batches: list[list[RagSource]] = []
    size = 0
    for page in pages:
        if not batches or size + len(page.text) > SUMMARY_BATCH_CHARS:
            if len(batches) == SUMMARY_MAX_BATCHES:
                break
            batches.append([])
            size = 0
        batches[-1].append(page)
        size += len(page.text)
    return batches, sum(len(b) for b in batches)
