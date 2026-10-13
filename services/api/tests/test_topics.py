import uuid

from app.domain.topics import TopicCandidate, subject_for_section, suggest_topic

PERCENT = TopicCandidate(
    uuid.uuid4(), "Quantitative Aptitude", "Percentage", ["percent", "%", "प्रतिशत"]
)
RATIO = TopicCandidate(uuid.uuid4(), "Quantitative Aptitude", "Ratio", ["ratio"])
SYNONYM = TopicCandidate(uuid.uuid4(), "English Language", "Synonyms", ["synonym"])
TOPICS = [PERCENT, RATIO, SYNONYM]


def test_suggests_the_best_keyword_match() -> None:
    assert suggest_topic("What is 20% of 150?", subject=None, topics=TOPICS) == PERCENT.id
    assert suggest_topic("150 का 20 प्रतिशत कितना है?", subject=None, topics=TOPICS) == PERCENT.id


def test_whole_word_matching_for_ascii_keywords() -> None:
    # "ratios" contains "ratio" but "operation" must not match "ratio".
    assert suggest_topic("Find the operation result", subject=None, topics=TOPICS) is None


def test_ties_and_no_matches_give_no_suggestion() -> None:
    assert suggest_topic("ratio and percent", subject=None, topics=TOPICS) is None
    assert suggest_topic("Who wrote Gitanjali?", subject=None, topics=TOPICS) is None


def test_subject_restricts_candidates() -> None:
    stem = "Choose the synonym; the percent sign is irrelevant"
    assert suggest_topic(stem, subject="English Language", topics=TOPICS) == SYNONYM.id


def test_subject_for_section() -> None:
    subjects = ["English Language", "General Intelligence", "Quantitative Aptitude"]
    assert (
        subject_for_section("General Intelligence and Reasoning", subjects)
        == "General Intelligence"
    )
    assert subject_for_section("Section A", subjects) is None
    assert subject_for_section(None, subjects) is None
