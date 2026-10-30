"""Pure AI rules (validation, topic picking) and the Anthropic adapter with a stub client."""

from types import SimpleNamespace
from typing import Any

import pytest

from app.core.config import Settings
from app.domain import ai_content
from app.integrations.ai import AIProviderError, AnthropicProvider, provider_from_settings


def good(**changes: Any) -> dict[str, Any]:
    item: dict[str, Any] = {
        "stem": "What is 25% of 80?",
        "options": ["10", "20", "30", "40"],
        "correct_option": 2,
        "explanation": "25/100 × 80 = 20.",
    }
    item.update(changes)
    return item


@pytest.mark.parametrize(
    ("item", "problems"),
    [
        (good(), []),
        (good(stem="Too short"), ["bad_stem"]),
        (good(options=["1", "2", "3"]), ["wrong_option_count"]),
        (good(options=["1", "2", "3", " "]), ["bad_option"]),
        (good(options=["Delhi", "delhi ", "Agra", "Pune"]), ["duplicate_options"]),
        (good(correct_option=0), ["bad_answer"]),
        (good(correct_option=5), ["bad_answer"]),
        (good(correct_option=True), ["bad_answer"]),
        (good(correct_option="2"), ["bad_answer"]),
        (good(explanation=""), ["bad_explanation"]),
        ("not a dict", ["not_an_object"]),
    ],
)
def test_generated_question_validation(item: Any, problems: list[str]) -> None:
    question, found = ai_content.validate_generated(item)
    assert found == problems
    assert (question is None) == bool(problems)


def test_valid_questions_are_normalised_not_rewritten() -> None:
    question, _ = ai_content.validate_generated(good(stem="  What   is 25% of 80?  "))
    assert question is not None
    assert question.stem == "What   is 25% of 80?"  # trimmed only; inner text kept as written
    assert question.correct_option == 2


def test_copies_of_given_stems_are_rejected() -> None:
    _, problems = ai_content.validate_generated(good(), avoid_stems=["what is 25%  of 80?"])
    assert problems == ["copied_source"]


def test_topic_must_be_one_of_the_offered_names() -> None:
    topics = ["Percentage", "Ratio and Proportion"]
    assert (
        ai_content.pick_topic({"topic": "ratio and proportion"}, topics) == "Ratio and Proportion"
    )
    assert ai_content.pick_topic({"topic": "Profit"}, topics) is None
    assert ai_content.pick_topic({"topic": None}, topics) is None


def test_paper_topics_keep_only_exact_single_answers_for_asked_numbers() -> None:
    labels = ["English Language > Synonyms", "Quantitative Aptitude > Percentage"]
    data = {
        "answers": [
            {"number": 1, "topic": "english language > synonyms"},
            {"number": 2, "topic": "Quantitative Aptitude > Percentage"},
            {"number": 2, "topic": "English Language > Synonyms"},  # answered twice
            {"number": 3, "topic": "Made Up > Topic"},
            {"number": 4, "topic": None},
            {"number": 9, "topic": "English Language > Synonyms"},  # not asked
            {"number": True, "topic": "English Language > Synonyms"},
            "junk",
        ]
    }
    assert ai_content.pick_paper_topics(data, [1, 2, 3, 4], labels) == {
        1: "English Language > Synonyms"
    }
    assert ai_content.pick_paper_topics({"answers": "x"}, [1], labels) == {}


def test_paper_topics_prompt_lists_topics_and_truncates_questions() -> None:
    prompt = ai_content.paper_topics_prompt(
        [ai_content.TopicQuestion(1, "Q" * 2000, ["a", "b"], "English Language")],
        ["English Language > Synonyms"],
    )
    assert "- English Language > Synonyms" in prompt
    expected = "[1] (subject: English Language) " + "Q" * ai_content.MAX_TOPIC_STEM
    assert expected + "\nOptions:" in prompt
    assert "Options: a | b" in prompt


def test_explanation_validation() -> None:
    assert ai_content.validate_explanation({"explanation": " Because. ", "confident": False}) == (
        "Because.",
        False,
    )
    assert ai_content.validate_explanation({"explanation": "", "confident": True}) == (None, True)


def test_prompts_ask_for_the_learners_language() -> None:
    hindi = ai_content.explanation_prompt(
        stem="प्रश्न", options=["a", "b"], correct=1, subject=None, language="hi"
    )
    assert "Hindi (Devanagari script)" in hindi
    notes = ai_content.questions_from_notes_prompt(
        title="T", notes="", subject="S", topic="P", language="en", count=2
    )
    assert "(no notes)" in notes and "Write 2" in notes


# --- provider wiring ---------------------------------------------------------------------


def test_ai_is_off_without_a_key() -> None:
    assert provider_from_settings(Settings(_env_file=None)) is None
    assert provider_from_settings(Settings(_env_file=None, ai_api_key=" ")) is None
    provider = provider_from_settings(Settings(_env_file=None, ai_api_key="sk-test"))
    assert isinstance(provider, AnthropicProvider)
    assert provider.model == "claude-haiku-5-5"


def test_the_key_is_never_shown_in_settings() -> None:
    settings = Settings(_env_file=None, ai_api_key="sk-secret-value")
    assert "sk-secret-value" not in repr(settings)
    assert "sk-secret-value" not in str(settings.model_dump())


class StubMessages:
    def __init__(self, reply: Any) -> None:
        self.reply = reply
        self.kwargs: dict[str, Any] = {}

    def create(self, **kwargs: Any) -> Any:
        self.kwargs = kwargs
        if isinstance(self.reply, Exception):
            raise self.reply
        return self.reply


def provider_with(reply: Any) -> tuple[AnthropicProvider, StubMessages]:
    provider = AnthropicProvider("sk-test", "claude-haiku-5-5", 5)
    messages = StubMessages(reply)
    provider._client = SimpleNamespace(messages=messages)  # type: ignore[assignment]
    return provider, messages


def message(text: str, stop_reason: str = "end_turn") -> Any:
    return SimpleNamespace(
        content=[SimpleNamespace(type="text", text=text)],
        stop_reason=stop_reason,
        usage=SimpleNamespace(input_tokens=11, output_tokens=7),
    )


def test_anthropic_adapter_requests_structured_output_and_parses_it() -> None:
    provider, messages = provider_with(message('{"topic": "Percentage"}'))

    result = provider.complete_json(
        system="sys", prompt="pick", schema=ai_content.TOPIC_SCHEMA, max_tokens=300
    )

    assert result.data == {"topic": "Percentage"}
    assert (result.input_tokens, result.output_tokens) == (11, 7)
    assert messages.kwargs["model"] == "claude-haiku-5-5"
    assert messages.kwargs["system"] == "sys"
    assert messages.kwargs["output_config"] == {
        "format": {"type": "json_schema", "schema": ai_content.TOPIC_SCHEMA}
    }


@pytest.mark.parametrize(
    ("reply", "reason", "retryable"),
    [
        (message("{}", stop_reason="refusal"), "refused", False),
        (message('{"a": ', stop_reason="max_tokens"), "truncated", True),
        (message("not json"), "invalid_json", True),
        (message("[1, 2]"), "invalid_json", True),
    ],
)
def test_anthropic_adapter_turns_bad_replies_into_errors(
    reply: Any, reason: str, retryable: bool
) -> None:
    provider, _ = provider_with(reply)
    with pytest.raises(AIProviderError) as error:
        provider.complete_json(system="s", prompt="p", schema={}, max_tokens=10)
    assert (error.value.reason, error.value.retryable) == (reason, retryable)


def test_anthropic_adapter_maps_sdk_errors() -> None:
    import anthropic
    import httpx2

    request = httpx2.Request("POST", "https://api.anthropic.com/v1/messages")
    provider, _ = provider_with(anthropic.APITimeoutError(request=request))
    with pytest.raises(AIProviderError) as timeout:
        provider.complete_json(system="s", prompt="p", schema={}, max_tokens=10)
    assert timeout.value.reason == "timeout"

    response = httpx2.Response(401, request=request)
    provider, _ = provider_with(
        anthropic.AuthenticationError("bad key", response=response, body=None)
    )
    with pytest.raises(AIProviderError) as auth:
        provider.complete_json(system="s", prompt="p", schema={}, max_tokens=10)
    assert (auth.value.reason, auth.value.retryable) == ("provider_auth", False)


def lesson_data(**changes: Any) -> dict[str, Any]:
    data: dict[str, Any] = {
        "overview": "  Percentage means per hundred.  ",
        "key_points": ["x% of y = x*y/100", "Increase then decrease is a net loss"],
        "example_question": "What is 20% of 150?",
        "example_answer": "20/100 × 150 = 30",
        "common_mistakes": ["Adding successive percentages"],
        "confident": True,
    }
    data.update(changes)
    return data


def test_lesson_validation_keeps_text_as_given_and_rejects_broken_parts() -> None:
    lesson = ai_content.validate_lesson(lesson_data())
    assert lesson is not None
    assert lesson.overview == "Percentage means per hundred."
    assert lesson.example_answer == "20/100 × 150 = 30" and lesson.confident

    no_example = ai_content.validate_lesson(lesson_data(example_question="", example_answer=" "))
    assert no_example is not None and no_example.example_question is None

    broken: dict[str, Any]
    for broken in (
        {"overview": "  "},
        {"key_points": []},
        {"key_points": ["ok", ""]},
        {"key_points": ["p"] * (ai_content.MAX_KEY_POINTS + 1)},
        {"common_mistakes": "not a list"},
        {"example_question": "A question without its answer", "example_answer": ""},
        {"example_answer": None},
    ):
        assert ai_content.validate_lesson(lesson_data(**broken)) is None, broken


def test_topic_prompts_name_the_topic_exam_and_language() -> None:
    lesson = ai_content.topic_lesson_prompt(
        topic="Percentage", subject="Quantitative Aptitude", exam_name="SSC CGL", language="hi"
    )
    assert "Percentage (Quantitative Aptitude)" in lesson and "SSC CGL" in lesson
    assert "Hindi" in lesson and "new to it" in lesson
    quiz = ai_content.topic_quiz_prompt(
        topic="Percentage", subject=None, exam_name=None, language="en", count=5
    )
    assert "Write 5 original" in quiz and "a competitive exam" in quiz and "English" in quiz
    assert "previous-year" in ai_content.TOPIC_SYSTEM


def check_data(**changes: Any) -> dict[str, Any]:
    data: dict[str, Any] = {
        "verdict": "partly",
        "feedback": " Right idea, but the unit is missing. ",
        "ideal_answer": "30 rupees",
        "paper_answer": "agrees",
        "confident": True,
    }
    data.update(changes)
    return data


def test_answer_check_validation_matches_what_was_sent() -> None:
    check = ai_content.validate_answer_check(check_data(), has_paper_answer=True)
    assert check is not None
    assert (check.verdict, check.feedback) == ("partly", "Right idea, but the unit is missing.")
    assert check.paper_answer == "agrees"

    without = ai_content.validate_answer_check(
        check_data(paper_answer="none"), has_paper_answer=False
    )
    assert without is not None and without.paper_answer is None

    broken: dict[str, Any]
    for broken, has_paper in (
        ({"verdict": "maybe"}, True),
        ({"feedback": ""}, True),
        ({"ideal_answer": None}, True),
        ({"paper_answer": "none"}, True),  # a paper answer was sent: it must be compared
        ({"paper_answer": "agrees"}, False),  # nothing to agree with
    ):
        assert (
            ai_content.validate_answer_check(check_data(**broken), has_paper_answer=has_paper)
            is None
        )


def test_answer_check_prompt_marks_the_paper_answer_as_possibly_wrong() -> None:
    prompt = ai_content.answer_check_prompt(
        stem="What is 20% of 150?", passage=None, paper_answer="30", answer="25", language="en"
    )
    assert (
        "may contain reading errors, or be wrong" in prompt
        and "The learner's answer:\n25" in prompt
    )
    none = ai_content.answer_check_prompt(
        stem="Define GDP.", passage="About economics", paper_answer=None, answer="x", language="hi"
    )
    assert "prints no answer" in none and "Passage:\nAbout economics" in none and "Hindi" in none
