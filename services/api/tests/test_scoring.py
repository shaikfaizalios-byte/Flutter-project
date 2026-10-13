from decimal import Decimal

from app.domain.scoring import ScoredItem, explain, score_session, tally_json, to_decimal

TWO = Decimal("2")
HALF = Decimal("0.5")


def item(
    position: int, section: str = "English", correct: int = 1, topic: str | None = None
) -> ScoredItem:
    return ScoredItem(position, section, topic, correct, TWO, HALF)


def test_correct_wrong_and_unattempted_with_negative_marking() -> None:
    items = [item(1), item(2), item(3, correct=4), item(4)]

    result = score_session(items, {1: 1, 2: 3, 3: 4, 4: None})

    total = result.total
    assert (total.correct, total.wrong, total.unattempted) == (2, 1, 1)
    assert total.score == Decimal("3.5")  # 2 + 2 - 0.5
    assert total.max_score == Decimal("8")
    assert total.accuracy == 2 / 3
    assert result.outcomes == {1: True, 2: False, 3: True, 4: None}


def test_unanswered_positions_are_unattempted() -> None:
    result = score_session([item(1), item(2)], {})

    assert result.total.unattempted == 2
    assert result.total.score == 0
    assert result.total.accuracy is None


def test_all_wrong_can_go_negative() -> None:
    result = score_session([item(1), item(2)], {1: 2, 2: 3})

    assert result.total.score == Decimal("-1.0")


def test_section_and_topic_totals() -> None:
    items = [
        item(1, "English", topic="t1"),
        item(2, "English", topic="t1"),
        item(3, "Reasoning", topic="t2"),
    ]

    result = score_session(items, {1: 1, 2: 2, 3: 1})

    assert result.sections["English"].score == Decimal("1.5")
    assert result.sections["Reasoning"].score == Decimal("2")
    assert result.topics["t1"].wrong == 1
    assert sum(s.max_score for s in result.sections.values()) == result.total.max_score


def test_chsl_format_marking_25_questions_50_marks_half_negative() -> None:
    # CHSL 2026 Tier-I per section: 25 questions / 50 marks -> 2 per question; -0.50 per wrong.
    per_question = to_decimal(50 / 25)
    items = [
        ScoredItem(i, "General Awareness", None, 1, per_question, to_decimal(0.5))
        for i in range(1, 26)
    ]
    selections = {i: 1 for i in range(1, 19)} | {i: 2 for i in range(19, 23)}  # 18 right, 4 wrong

    result = score_session(items, selections)

    assert result.total.score == Decimal("34.0")  # 36 - 2
    assert result.total.max_score == Decimal("50.0")
    assert explain(result.total) == (
        "Correct 18 × 2.00 = 36.00; Wrong 4 × −0.50 = −2.00; Unattempted 3 × 0 = 0; "
        "Total 34.00 of 50.00"
    )


def test_practice_marking_explanation_has_no_negative() -> None:
    items = [
        ScoredItem(1, None, None, 1, Decimal(1), Decimal(0)),
        ScoredItem(2, None, None, 1, Decimal(1), Decimal(0)),
    ]

    result = score_session(items, {1: 1, 2: 2})

    assert explain(result.total) == (
        "Correct 1 × 1.00 = 1.00; Wrong 1 × 0.00 = 0.00; Unattempted 0 × 0 = 0; Total 1.00 of 2.00"
    )


def test_tally_json_shape() -> None:
    data = tally_json(score_session([item(1)], {1: 1}).total)

    assert data["score"] == 2.0
    assert data["max_score"] == 2.0
    assert data["accuracy"] == 1.0
    assert "Total 2.00 of 2.00" in str(data["explanation"])
