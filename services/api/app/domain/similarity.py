"""Grouping questions that are worded alike across papers ("the same model, new numbers").

Pure and deterministic. Stems are compared after normalisation: case and Unicode folded,
numbers replaced by one placeholder (so "20% of 150" and "25% of 300" read the same), and
punctuation dropped. Similarity is the cosine of word unigram + bigram counts; pairs at or
above ``THRESHOLD`` are linked, and linked questions form a group (union-find). Only groups
that span at least two different papers are reported. Options are ignored: they change from
paper to paper even when the question type is the same.

These groups are *suggestions* of repetition based on wording. They are shown apart from the
reviewed topic/pattern counts and never change any question.
"""

import itertools
import math
import re
import unicodedata
from collections import Counter
from collections.abc import Hashable, Sequence
from dataclasses import dataclass

THRESHOLD = 0.8
MIN_TOKENS = 4  # very short stems ("Select the odd one.") say too little to compare
_NUMBER = re.compile(r"\d+(?:[.,]\d+)*")
_TOKEN = re.compile(r"[^\W_]+|#")


@dataclass(frozen=True, slots=True)
class StemItem:
    id: Hashable
    paper_id: Hashable
    block: Hashable  # only items in the same block are compared (e.g. topic or subject)
    stem: str


def normalise(stem: str) -> list[str]:
    text = unicodedata.normalize("NFKC", stem).casefold()
    text = _NUMBER.sub(" # ", text)
    return _TOKEN.findall(text)


def _vector(tokens: list[str]) -> Counter[str]:
    grams = Counter(tokens)
    grams.update(f"{a} {b}" for a, b in itertools.pairwise(tokens))
    return grams


def _cosine(a: Counter[str], b: Counter[str], norm_a: float, norm_b: float) -> float:
    if len(a) > len(b):
        a, b = b, a
    dot = sum(count * b[gram] for gram, count in a.items() if gram in b)
    return dot / (norm_a * norm_b)


def similar_groups(items: Sequence[StemItem], threshold: float = THRESHOLD) -> list[list[Hashable]]:
    """Groups of item ids (each group spans >= 2 papers), largest first, ids in input order."""
    vectors: list[tuple[int, Counter[str], float]] = []
    for index, item in enumerate(items):
        tokens = normalise(item.stem)
        if len(tokens) < MIN_TOKENS:
            continue
        vector = _vector(tokens)
        vectors.append((index, vector, math.sqrt(sum(c * c for c in vector.values()))))

    parent = list(range(len(items)))

    def find(i: int) -> int:
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    by_block: dict[Hashable, list[tuple[int, Counter[str], float]]] = {}
    for entry in vectors:
        by_block.setdefault(items[entry[0]].block, []).append(entry)
    for entries in by_block.values():
        for x, (i, vi, ni) in enumerate(entries):
            for j, vj, nj in entries[x + 1 :]:
                if items[i].paper_id == items[j].paper_id:
                    continue  # repetition means across papers
                if _cosine(vi, vj, ni, nj) >= threshold:
                    parent[find(i)] = find(j)

    groups: dict[int, list[int]] = {}
    for index, _, _ in vectors:
        groups.setdefault(find(index), []).append(index)
    result = [
        sorted(members)
        for members in groups.values()
        if len({items[m].paper_id for m in members}) >= 2
    ]
    result.sort(key=lambda g: (-len({items[m].paper_id for m in g}), -len(g), g[0]))
    return [[items[m].id for m in group] for group in result]
