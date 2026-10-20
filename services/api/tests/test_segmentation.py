"""Segmenter unit tests on synthetic paper text (no database, no PDFs)."""

from collections.abc import Sequence
from pathlib import Path
from textwrap import dedent

from app.domain.segmentation import (
    Issue,
    IssueCode,
    PageText,
    ParsedQuestion,
    SegmentationResult,
    check_against_format,
    same_subject,
    segment,
)


def run(*pages: str, flagged: set[int] | None = None) -> SegmentationResult:
    return segment(
        [
            PageText(i + 1, dedent(text).strip(), needs_review=(i + 1) in (flagged or set()))
            for i, text in enumerate(pages)
        ]
    )


def codes(issues: Sequence[Issue]) -> list[str]:
    return [i.code for i in issues]


def by_number(result: SegmentationResult, number: int) -> ParsedQuestion:
    return next(q for q in result.questions if q.number == number)


BASIC_PAPER = """
    General Intelligence
    Q.1 Select the odd one out.
    (1) Apple (2) Mango (3) Potato (4) Banana
    Q.2 If CAT is coded as DBU, how is DOG coded?
    (1) EPH
    (2) EOH
    (3) DPH
    (4) FPH
    Quantitative Aptitude
    Q.3 What is 20% of 150?
    (a) 20 (b) 30 (c) 40 (d) 50
    Answer Key
    1-(3) 2-(1) 3-(b)
"""


def test_basic_paper_questions_options_sections_and_key() -> None:
    result = run(BASIC_PAPER)

    assert [q.number for q in result.questions] == [1, 2, 3]
    assert result.sections == ["General Intelligence", "Quantitative Aptitude"]
    q1, q2, q3 = result.questions
    assert q1.stem == "Select the odd one out."
    assert [(o.label, o.text) for o in q1.options] == [
        ("1", "Apple"),
        ("2", "Mango"),
        ("3", "Potato"),
        ("4", "Banana"),
    ]
    assert [o.text for o in q2.options] == ["EPH", "EOH", "DPH", "FPH"]
    assert q3.section == "Quantitative Aptitude"
    # Key uses digits for some, letters for others: joined by number, mapped by position.
    assert (q1.answer_position, q1.answer_source) == (3, "answer_key")
    assert q2.answer_position == 1
    assert q3.answer_position == 2
    assert all(q.issues == [] for q in result.questions)
    assert result.document_issues == []


def test_hindi_question_markers_and_inline_answers() -> None:
    result = run(
        """
        प्रश्न 1. भारत की राजधानी क्या है?
        (1) मुंबई (2) नई दिल्ली (3) कोलकाता (4) चेन्नई
        उत्तर: (2)
        प्रश्न 2. 5 + 7 = ?
        (1) 10 (2) 11 (3) 12 (4) 13
        उत्तर: 3
        """
    )

    assert [q.number for q in result.questions] == [1, 2]
    assert result.questions[0].stem == "भारत की राजधानी क्या है?"
    assert result.questions[0].options[1].text == "नई दिल्ली"
    assert (result.questions[0].answer_position, result.questions[0].answer_source) == (
        2,
        "inline",
    )
    assert result.questions[1].answer_position == 3


def test_plain_numbering_with_numbered_options() -> None:
    result = run(
        """
        1. Which number is prime?
        1. 21
        2. 23
        3. 25
        4. 27
        2. Which is the largest planet?
        1. Earth
        2. Jupiter
        3. Mars
        4. Venus
        """
    )

    assert [q.number for q in result.questions] == [1, 2]
    assert [o.text for o in result.questions[0].options] == ["21", "23", "25", "27"]
    assert result.questions[1].stem == "Which is the largest planet?"


def test_numbered_statements_inside_strongly_numbered_question_stay_in_stem() -> None:
    result = run(
        """
        Q.7 Read the statements.
        Statements:
        All cats are dogs.
        Q.8 Next question?
        (1) a (2) b (3) c (4) d
        """
    )

    assert [q.number for q in result.questions] == [7, 8]
    assert "All cats are dogs." in result.questions[0].stem


def test_shared_passage_is_linked_to_its_question_range() -> None:
    result = run(
        """
        Directions (Questions 21 to 22): Read the passage and answer.
        The river was calm. Farmers depended on it.
        Q.21 What was calm?
        (1) Sea (2) River (3) Lake (4) Pond
        Q.22 Who depended on it?
        (1) Farmers (2) Kings (3) Traders (4) Priests
        Q.23 Unrelated question?
        (1) w (2) x (3) y (4) z
        """
    )

    [passage] = result.passages
    assert (passage.first_question, passage.last_question) == (21, 22)
    assert "The river was calm." in passage.text
    assert by_number(result, 21).passage_index == 0
    assert by_number(result, 22).passage_index == 0
    assert by_number(result, 23).passage_index is None
    # The passage text is linked, not copied into each stem.
    assert "river was calm" not in by_number(result, 21).stem


def test_answer_key_and_explanations_joined_by_number_not_position() -> None:
    result = run(
        """
        Q.2 Second?
        (1) a (2) b (3) c (4) d
        Q.1 First?
        (1) a (2) b (3) c (4) d
        Answer Key
        1. (4)  2. (1)  9. (2)
        Solutions
        1. Because four.
        Continued reasoning.
        2) Because one.
        """
    )

    assert by_number(result, 1).answer_position == 4
    assert by_number(result, 2).answer_position == 1
    assert by_number(result, 1).explanation == "Because four.\nContinued reasoning."
    assert by_number(result, 2).explanation == "Because one."
    [unmatched] = [i for i in result.document_issues if i.code == IssueCode.ANSWER_KEY_UNMATCHED]
    assert "9" in unmatched.detail


def test_conflicting_answers_are_not_guessed() -> None:
    result = run(
        """
        Q.1 Pick one?
        (1) a (2) b (3) c (4) d
        Ans: 2
        Answer Key
        1-(3)
        """
    )

    question = result.questions[0]
    assert question.answer_position is None
    assert IssueCode.CONFLICTING_ANSWERS in codes(question.issues)
    assert IssueCode.MISSING_ANSWER in codes(question.issues)


def test_missing_answers_duplicates_gaps_and_incomplete_options() -> None:
    result = run(
        """
        Q.1 One?
        (1) a (2) b (3) c (4) d
        Q.1 One again?
        (1) a (2) b
        Q.4 Four?
        (1) a (2) (3) c (4) d
        """
    )

    first, duplicate, fourth = result.questions
    assert IssueCode.MISSING_ANSWER in codes(first.issues)
    assert IssueCode.DUPLICATE_NUMBER in codes(duplicate.issues)
    assert IssueCode.INCOMPLETE_OPTIONS in codes(duplicate.issues)
    assert IssueCode.EMPTY_OPTION in codes(fourth.issues)
    [gaps] = [i for i in result.document_issues if i.code == IssueCode.NUMBERING_GAPS]
    assert gaps.detail == "Missing: 2, 3"


def test_image_dependent_questions_are_flagged_with_page_reference() -> None:
    result = run(
        "Q.1 Select the correct mirror image of the given figure.\n(1) (2) (3) (4)",
        "Q.2 Which figure completes the pattern?",
    )

    first, second = result.questions
    assert first.image_dependent and second.image_dependent
    assert IssueCode.IMAGE_DEPENDENT in codes(first.issues)
    assert first.pages == [1]
    assert second.pages == [2]


def test_bilingual_repeated_options_keep_first_set_and_flag() -> None:
    result = run(
        """
        Q.1 What is 2 + 2? / 2 + 2 कितना है?
        (1) 3 (2) 4 (3) 5 (4) 6
        (1) तीन (2) चार (3) पाँच (4) छह
        """
    )

    question = result.questions[0]
    assert [o.text for o in question.options] == ["3", "4", "5", "6"]
    [issue] = [i for i in question.issues if i.code == IssueCode.REPEATED_OPTION_LABELS]
    assert "चार" in issue.detail


def test_question_spanning_pages_records_both_pages() -> None:
    result = run(
        "Q.1 A long question that\ncontinues", "on the next page?\n(1) a (2) b (3) c (4) d"
    )

    assert result.questions[0].pages == [1, 2]
    assert result.questions[0].stem == "A long question that\ncontinues\non the next page?"


def test_questions_on_flagged_pages_carry_a_review_issue() -> None:
    result = run("Q.1 Fine?\n(1) a (2) b (3) c (4) d\nAns: 1", flagged={1})

    assert IssueCode.SOURCE_PAGE_NEEDS_REVIEW in codes(result.questions[0].issues)


def test_numbering_restarting_per_section_makes_answer_key_ambiguous() -> None:
    result = run(
        """
        Section A: Reasoning
        Q.1 R1?
        (1) a (2) b (3) c (4) d
        Section B: Maths
        Q.1 M1?
        (1) a (2) b (3) c (4) d
        Answer Key
        1-(2)
        """
    )

    assert [q.section for q in result.questions] == ["Reasoning", "Maths"]
    assert all(q.answer_position is None for q in result.questions)
    assert IssueCode.ANSWER_KEY_AMBIGUOUS in codes(result.document_issues)
    # Same number in different sections is not a duplicate.
    assert all(IssueCode.DUPLICATE_NUMBER not in codes(q.issues) for q in result.questions)


def test_no_questions_found() -> None:
    result = run("This page is only instructions for candidates.")

    assert result.questions == []
    assert codes(result.document_issues) == [IssueCode.NO_QUESTIONS_FOUND]


def test_long_sentence_starting_with_part_is_not_a_heading() -> None:
    result = run(
        "Q.1 Choose the word.\n"
        "Part of the reason the committee delayed the decision was the weather in the hills.\n"
        "(1) a (2) b (3) c (4) d"
    )

    assert result.sections == []
    assert "Part of the reason" in result.questions[0].stem


def test_format_check_counts_total_and_sections_by_name() -> None:
    result = run(BASIC_PAPER)
    issues = check_against_format(
        result,
        total_questions=100,
        sections=[
            ("General Intelligence", 25),
            ("Quantitative Aptitude (Basic Arithmetic Skill)", 25),
        ],
    )

    assert codes(issues) == [
        IssueCode.COUNT_MISMATCH,
        IssueCode.SECTION_COUNT_MISMATCH,
        IssueCode.SECTION_COUNT_MISMATCH,
    ]
    assert "Found 3 questions" in issues[0].detail


def test_same_subject_matching() -> None:
    assert same_subject("General Intelligence and Reasoning", "General Intelligence")
    assert same_subject("Quantitative Aptitude", "Quantitative Aptitude (Basic Arithmetic Skill)")
    assert not same_subject("English Language", "General Awareness")


# --- papers answered inline, CAT style (synthetic text) ----------------------------------

CAT_STYLE = """
    VARC Questions with Solutions
    1. Which word best completes the sentence?
    1. Option 3
    2. Option 2
    3. Option 4
    4. Option 1
    Correct Answer: Option 2
    Explanation:
    The second option fits the tone of the sentence.
    DIRECTIONS for questions 2-3: Five jumbled sentences (labelled 1, 2, 3, 4, and 5) are
    given. Key in the number of the odd sentence out.
    2.
    1. The first sentence of the set.
    2. The second sentence of the set.
    3. The third sentence of the set.
    4. The fourth sentence of the set.
    5. The fifth sentence of the set.
    Correct Answer: Sentence 1
    Explanation:
    Sentence 1 is about something else.
    3. How many quarters had growth?
    Correct Answer: 4
    Explanation:
    Q1 Q2 Q3 Q4
    10 12 14 16
    All four quarters grew.
    4: What is the trade balance?
    1. Deficit of 10.0 Billion USD 2. Surplus of 15.0 Billion USD
    3. Surplus of 10.0 Billion USD 4. Deficit of 15.0 Billion USD
    Correct answer: option (4)
    Solution:
    Exports minus imports is -15.
"""


def test_inline_answered_paper_with_label_rows_and_typed_answers() -> None:
    result = run(CAT_STYLE)
    by_number = {q.number: q for q in result.questions}
    assert sorted(by_number) == [1, 2, 3, 4]
    # "Q1 Q2 Q3 Q4" table rows are not question markers.
    assert result.strong_numbering is False

    q1 = by_number[1]
    assert [o.text for o in q1.options] == ["Option 3", "Option 2", "Option 4", "Option 1"]
    assert q1.answer_position == 2  # "Correct Answer: Option 2"
    assert q1.explanation == "The second option fits the tone of the sentence."

    # Odd-one-out with five sentences: "5." is still question 2 (its answer comes later);
    # "Sentence 1" makes it a typed-in question and the sentences go back into the stem.
    q2 = by_number[2]
    assert q2.answer_type == "typed" and q2.typed_answer == "1"
    assert q2.options == [] and q2.answer_position is None
    assert "5. The fifth sentence of the set." in q2.stem
    assert "unrecognised_answer" not in codes(q2.issues)

    # A number for a question without options is a typed-in answer, not "option 4".
    q3 = by_number[3]
    assert q3.answer_type == "typed" and q3.typed_answer == "4"
    assert q3.options == [] and q3.answer_position is None
    assert codes(q3.issues) == []

    # "4:" numbering, two options per line, decimals intact, lower-case answer label.
    q4 = by_number[4]
    assert [o.text for o in q4.options] == [
        "Deficit of 10.0 Billion USD",
        "Surplus of 15.0 Billion USD",
        "Surplus of 10.0 Billion USD",
        "Deficit of 15.0 Billion USD",
    ]
    assert q4.answer_position == 4
    assert q4.explanation == "Exports minus imports is -15."
    assert codes(result.document_issues) == []


def test_numbered_lines_in_directions_are_not_questions() -> None:
    result = run(
        """
        1. First question?
        (1) a (2) b (3) c (4) d
        Ans: 1
        DIRECTIONS for questions 2-3: Read the facts below.
        1. Asha was in group A.
        2. Bunty was in group B.
        2. Second question?
        (1) a (2) b (3) c (4) d
        3. Third question?
        (1) a (2) b (3) c (4) d
        """
    )
    assert [q.number for q in result.questions] == [1, 2, 3]
    assert "Asha was in group A." in result.passages[0].text


def test_a_stray_q_marker_does_not_switch_a_plainly_numbered_paper() -> None:
    result = run(
        """
        1. Sales in Q1 rose. What happened next?
        (1) a (2) b (3) c (4) d
        2. Second question?
        (1) a (2) b (3) c (4) d
        Q1 results were good.
        3. Third question?
        (1) a (2) b (3) c (4) d
        """
    )
    assert result.strong_numbering is False
    assert [q.number for q in result.questions] == [1, 2, 3]


def test_an_end_of_paper_solutions_section_still_works() -> None:
    result = run(
        """
        Q.1 First?
        (1) a (2) b (3) c (4) d
        Q.2 Second?
        (1) a (2) b (3) c (4) d
        Q.3 Third?
        (1) a (2) b (3) c (4) d
        Answer Key
        1-(2) 2-(3) 3-(1)
        Solutions
        1. Because b.
        2. Because c.
        """
    )
    by_number = {q.number: q for q in result.questions}
    assert by_number[1].answer_position == 2
    assert by_number[1].explanation == "Because b."


def test_typed_answers_from_paper_and_what_stays_flagged() -> None:
    result = run(
        """
        1. Arrange the sentences.
        1. First. 2. Second. 3. Third. 4. Fourth.
        Correct Answer: 3-4-2-1
        2. How many?
        Correct Answer: 2.50
        3. Pick the right one.
        (1) a (2) b (3) c (4) d
        Correct Answer: see solution
        4. Type the city.
        Correct Answer: see solution
        """
    )
    by_number = {q.number: q for q in result.questions}
    assert (by_number[1].answer_type, by_number[1].typed_answer) == ("typed", "3421")
    assert "4. Fourth." in by_number[1].stem
    assert (by_number[2].answer_type, by_number[2].typed_answer) == ("typed", "2.50")
    # An answer that isn't a typed answer for a question with options is never guessed.
    assert by_number[3].answer_type == "choice" and by_number[3].answer_position is None
    assert "unrecognised_answer" in codes(by_number[3].issues)
    # Words are never turned into a typed answer by the parser.
    assert by_number[4].answer_type == "choice"
    assert "unrecognised_answer" in codes(by_number[4].issues)


def _paper(count: int) -> str:
    """A plain paper with ``count`` questions of four options each."""
    return "\n".join(
        f"Q.{n} Question {n}?\n(a) one (b) two (c) three (d) four" for n in range(1, count + 1)
    )


def _answers(result: SegmentationResult) -> list[int | None]:
    return [q.answer_position for q in result.questions]


def test_answer_key_table_rows_of_numbers_then_answers() -> None:
    key = dedent(
        """
        Answer Key
        Q. No. | Answer
        Q.No. 1 2 3 4 5
        Ans. b c a d b
        6 7 8 9 10
        (a) (d) (c) (b) (a)
        """
    )
    result = run(_paper(10) + key)
    assert _answers(result) == [2, 3, 1, 4, 2, 1, 4, 3, 2, 1]
    assert {q.answer_source for q in result.questions} == {"answer_key"}
    assert result.document_issues == []


def test_answer_key_table_with_digit_answers_and_split_rows() -> None:
    # Digit answers: a row after the numbers is answers unless it carries on the sequence.
    key = dedent(
        """
        Answer Key
        1 2 3
        4 5 6
        2 3 1
        4 2 1
        """
    )
    result = run(_paper(6) + key)
    assert _answers(result) == [2, 3, 1, 4, 2, 1]


def test_answer_key_table_read_one_cell_per_line_and_spaced_pairs() -> None:
    columns = "\nAnswer Key\n1\nb\n2\nc\n3 | a\n4 d\n"
    result = run(_paper(4) + columns)
    assert _answers(result) == [2, 3, 1, 4]


def test_answer_key_table_with_counts_that_differ_is_reported_not_shifted() -> None:
    key = dedent(
        """
        Answer Key
        1 2 3 4
        b c a
        """
    )
    result = run(_paper(4) + key)
    assert _answers(result) == [None, None, None, None]
    (issue,) = result.document_issues
    assert issue.code == IssueCode.ANSWER_KEY_UNMATCHED
    assert "4 question numbers (1-4) but 3 answers" in issue.detail


def test_answer_key_table_drawn_as_a_grid_in_a_real_pdf(tmp_path: Path) -> None:
    import pypdfium2 as pdfium

    from app.domain.text_quality import normalize_text
    from tests.pdf_factory import answer_key_table_pdf

    path = tmp_path / "key.pdf"
    path.write_bytes(answer_key_table_pdf())
    document = pdfium.PdfDocument(path)
    text = normalize_text(document[0].get_textpage().get_text_bounded())
    document.close()
    result = segment([PageText(1, text, needs_review=False)])
    assert _answers(result) == [2, 3, 1, 4, 2]
    assert result.document_issues == []


SOLUTIONS_LAYOUT = """
SAMPLE TEST PAPER WITH
SOLUTIONS
Reading Section
Q.1 Comprehension:
The passage below is accompanied by questions.
Rivers carry sand to the sea, and the sea slowly returns it to the shore.
Question
What does the sea return to the shore?
Option 1:
salt from the deep ocean
Option 2:
sand carried by rivers
Option 3:
rocks from distant hills
Option 4:
water from the clouds
Correct Answer:
sand carried by rlvers
Solution:
The correct answer is 2) sand carried by rivers.
Explanation: The passage says so directly.
Q.2 Comprehension:
The passage below is accompanied by questions.
Rivers carry sand to the sea, and the sea slowly returns it to the shore.
Question
Where does the sand finally go?
Option 7:
to the shore
Option 2:
to the clouds
Option 3:
to the hills
Option 4:
to the deep ocean
Correct Answer;
to the shore
Solution:
Explanation: Read the last line.
Q.3 Four sentences (labelled 1, 2, 3 and 4) are given. Key in the number of the odd sentence.
1. Sand moves.
2. Rivers flow.
3. The sea is blue.
4. Shores change.
Correct Answer:
3
Solution:
Sentence 3 is the odd one out.
Q.4 In a "where does it fit" question the options are positions.
Option 1:
Option 1
Option 2:
Option 2
Option 3:
Option 3
Option 4:
Option 4
Correct Answer:
Option 2
Solution:
It fits at position 2.
"""


def test_solutions_paper_with_option_words_and_answers_as_text() -> None:
    result = run(SOLUTIONS_LAYOUT)

    # A "Solutions" title line before any question doesn't swallow the paper.
    assert [q.number for q in result.questions] == [1, 2, 3, 4]
    q1, q2, q3, q4 = result.questions
    # "Option 1:" lines; the answer given as the option's text (OCR slip tolerated).
    assert [o.text for o in q1.options][1] == "sand carried by rivers"
    assert (q1.answer_position, q1.answer_source) == (2, "inline")
    # The text before "Question" is the passage, shared by both questions that repeat it.
    assert q1.stem == "What does the sea return to the shore?"
    assert q1.passage_index == q2.passage_index == 0
    assert len(result.passages) == 1
    assert result.passages[0].first_question == 1 and result.passages[0].last_question == 2
    # "Option 7:" in a four-option question is flagged and used in order; "Correct Answer;".
    assert q2.answer_position == 1
    assert [i.code for i in q2.issues] == [IssueCode.OPTION_LABEL_UNCLEAR]
    # "Key in the number": a typed-in answer even though the sentences are numbered.
    assert (q3.answer_type, q3.typed_answer) == ("typed", "3")
    # Options whose text is "Option N" are text, not labels.
    assert [o.text for o in q4.options] == ["Option 1", "Option 2", "Option 3", "Option 4"]
    assert q4.answer_position == 2


def test_answer_text_matching_no_option_is_kept_for_review() -> None:
    result = run(
        """
        Q.1 Pick one.
        Option 1:
        red
        Option 2:
        blue
        Option 3:
        green
        Option 4:
        yellow
        Correct Answer:
        purple
        """
    )
    (q1,) = result.questions
    assert q1.answer_position is None
    assert next((i.code, i.detail) for i in q1.issues) == (IssueCode.UNRECOGNISED_ANSWER, "purple")
