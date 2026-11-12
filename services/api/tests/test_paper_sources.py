"""Official paper pages: every listed page is https, dated and described; the API serves them."""

from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.domain.paper_sources import load_sources, read_sources, source_problems

GOOD: dict[str, Any] = {
    "title": "Official site",
    "url": "https://example.org/papers",
    "publisher": "Exam body",
    "offers": "Question papers",
    "checked_on": "2026-11-12",
    "checked_by": "Reviewer",
}


def test_the_shipped_list_is_valid() -> None:
    sources = load_sources()
    assert sources  # read_sources raises on any bad entry
    assert all(s.url.startswith("https://") for pages in sources.values() for s in pages)


@pytest.mark.parametrize(
    ("change", "problem"),
    [
        ({"url": "http://example.org"}, "https"),
        ({"url": "javascript:alert(1)"}, "https"),
        ({"checked_by": " "}, "missing checked_by"),
        ({"checked_on": "last week"}, "checked_on"),
    ],
)
def test_a_page_without_https_a_date_or_a_checker_is_refused(
    change: dict[str, str], problem: str
) -> None:
    assert any(problem in p for p in source_problems({**GOOD, **change}))
    with pytest.raises(ValueError, match=problem):
        read_sources({"exams": {"X": [{**GOOD, **change}]}})
    assert source_problems(GOOD) == []


def test_the_api_lists_an_exams_pages_and_nothing_for_others(client: TestClient) -> None:
    listed = client.get("/api/v1/exams/JEE_ADVANCED/paper-sources")
    assert listed.status_code == 200
    assert listed.json()[0]["url"].startswith("https://") and listed.json()[0]["checked_on"]
    assert client.get("/api/v1/exams/MY_OWN_EXAM/paper-sources").json() == []
