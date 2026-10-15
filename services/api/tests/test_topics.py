import uuid

from app.domain.topics import TopicCandidate, subject_for_section, suggest_topic

PERCENT = TopicCandidate(
    uuid.uuid4(), "Quantitative Aptitude", "Percentage", ["percent", "%", "प्रतिशत"]
)
RATIO = TopicCandidate(uuid.uuid4(), "Quantitative Aptitude", "Ratio", ["ratio"])
SYNONYM = TopicCandidate(uuid.uuid4(), "English Language", "Synonyms", ["synonym"])
VOICE = TopicCandidate(
    uuid.uuid4(), "English Language", "Active and Passive Voice", ["passive", "active voice"]
)
JUMBLES = TopicCandidate(
    uuid.uuid4(), "English Language", "Para Jumbles", ["jumbled sentences", "correct order"]
)
BLOOD = TopicCandidate(
    uuid.uuid4(), "General Intelligence", "Blood Relations", ["sister", "husband", "married to"]
)
FIGURES = TopicCandidate(uuid.uuid4(), "General Intelligence", "Figure Series", ["figure series"])
TOPICS = [PERCENT, RATIO, SYNONYM, VOICE, JUMBLES, BLOOD, FIGURES]


def _topic(stem: str, subject: str | None = None) -> uuid.UUID | None:
    suggestion = suggest_topic(stem, subject=subject, topics=TOPICS)
    return suggestion.topic_id if suggestion else None


def test_suggests_the_best_keyword_match() -> None:
    assert _topic("What is 20% of 150?") == PERCENT.id
    assert _topic("150 का 20 प्रतिशत कितना है?") == PERCENT.id


def test_whole_word_matching_for_ascii_keywords() -> None:
    # "ratios" contains "ratio" but "operation" must not match "ratio".
    assert _topic("Find the operation result") is None


def test_ties_and_no_matches_give_no_suggestion() -> None:
    assert _topic("ratio and percent") is None
    assert _topic("Who wrote Gitanjali?") is None


def test_subject_restricts_candidates() -> None:
    stem = "Choose the synonym; the percent sign is irrelevant"
    assert _topic(stem, subject="English Language") == SYNONYM.id


def test_the_instruction_outweighs_words_in_the_content() -> None:
    # Real SSC questions: the first sentence says what is asked.
    passive = (
        "Select the correct passive form of the given sentence.\n"
        "Bill Gates has given away twenty seven percent of his wealth in charity."
    )
    assert _topic(passive) == VOICE.id
    jumbled = (
        "Given below are four jumbled sentences. Out of the given options pick the one that "
        "gives their correct order.\nA. Pip lives with his elder sister and her husband Joe."
    )
    assert _topic(jumbled) == JUMBLES.id


def test_keywords_match_across_an_unreadable_ligature() -> None:
    # PDFium returns U+001F for an unmapped "fi" ligature: "figure" reads "\x1fgure".
    assert _topic("Select the \x1fgure that will come next in the following \x1fgure series.") == (
        FIGURES.id
    )


def test_the_suggestion_says_why_and_names_the_subject() -> None:
    suggestion = suggest_topic(
        "Select the correct passive form of the given sentence.", subject=None, topics=TOPICS
    )
    assert suggestion is not None
    assert suggestion.subject == "English Language"
    assert suggestion.reason == 'Matched "passive"'


def test_subject_for_section() -> None:
    subjects = ["English Language", "General Intelligence", "Quantitative Aptitude"]
    assert (
        subject_for_section("General Intelligence and Reasoning", subjects)
        == "General Intelligence"
    )
    assert subject_for_section("Section A", subjects) is None
    assert subject_for_section(None, subjects) is None
