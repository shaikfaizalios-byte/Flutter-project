"""Wording-similarity groups: same question model with new numbers, across papers only."""

from app.domain.similarity import StemItem, normalise, similar_groups

PCT = "Anu spends 90% of her income. If her expenditure increases by 10%, what is her saving?"


def test_numbers_are_masked() -> None:
    assert normalise("What is 20% of 1,500.5?") == ["what", "is", "#", "of", "#"]


def test_groups_same_model_with_different_numbers_across_papers() -> None:
    items = [
        StemItem(1, "paper-a", "pct", PCT),
        StemItem(2, "paper-b", "pct", "What is 20% of 150?"),
        StemItem(3, "paper-c", "pct", PCT.replace("90%", "75%").replace("10%", "20%")),
    ]
    assert similar_groups(items) == [[1, 3]]


def test_same_paper_alone_is_not_a_repeat() -> None:
    items = [StemItem(1, "p", "pct", PCT), StemItem(2, "p", "pct", PCT.replace("90", "80"))]
    assert similar_groups(items) == []


def test_only_items_in_the_same_block_are_compared() -> None:
    items = [StemItem(1, "a", "topic-1", PCT), StemItem(2, "b", "topic-2", PCT)]
    assert similar_groups(items) == []


def test_short_stems_are_ignored_and_groups_sorted_by_papers() -> None:
    venn = "Select the Venn diagram that best illustrates the relationship between the classes"
    items = [
        StemItem(1, "a", "x", "Odd one?"),
        StemItem(2, "b", "x", "Odd one?"),
        StemItem(3, "a", "y", PCT),
        StemItem(4, "b", "y", PCT.replace("90", "60")),
        StemItem(5, "a", "z", venn),
        StemItem(6, "b", "z", venn),
        StemItem(7, "c", "z", venn + " given below"),
    ]
    assert similar_groups(items) == [[5, 6, 7], [3, 4]]
