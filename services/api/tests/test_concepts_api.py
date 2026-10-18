import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient

URL = "/api/v1/concepts"


def _payload(**overrides: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "exam_code": "SSC_CGL",
        "title": "Percentage basics",
        "notes": "x% of y equals y% of x.",
        "subject": "Quantitative Aptitude",
        "topic": "Percentage",
        "language": "en",
        "tags": ["Formula", "formula", "shortcut"],
    }
    payload.update(overrides)
    return payload


def _create(client: TestClient, **overrides: Any) -> dict[str, Any]:
    response = client.post(URL, json=_payload(**overrides))
    assert response.status_code == 201, response.text
    body: dict[str, Any] = response.json()
    return body


def test_list_exams_returns_seeded_reference_data(db_client: TestClient) -> None:
    response = db_client.get("/api/v1/exams")

    assert response.status_code == 200
    exams = response.json()
    assert [e["code"] for e in exams][:2] == ["SSC_CGL", "SSC_CHSL"]
    assert exams[0] == {
        "code": "SSC_CGL",
        "name": "SSC Combined Graduate Level",
        "category": "Staff Selection",
        "featured": True,
        "custom": False,
    }
    assert all(not e["custom"] for e in exams)  # nobody's own exams in the public catalog


def test_create_concept_normalises_input(db_client: TestClient) -> None:
    body = _create(db_client, title="  Percentage basics  ", subtopic="", source_reference=" ")

    assert body["title"] == "Percentage basics"
    assert body["tags"] == ["formula", "shortcut"]
    assert body["subtopic"] is None
    assert body["source_reference"] is None
    assert body["archived_at"] is None
    uuid.UUID(body["id"])


def test_get_concept_round_trips(db_client: TestClient) -> None:
    created = _create(db_client, language="hi", title="प्रतिशत")

    response = db_client.get(f"{URL}/{created['id']}")

    assert response.status_code == 200
    assert response.json() == created


@pytest.mark.parametrize(
    ("overrides", "field"),
    [
        ({"title": "   "}, "body.title"),
        ({"title": "x" * 201}, "body.title"),
        ({"language": "fr"}, "body.language"),
        ({"subject": ""}, "body.subject"),
        ({"tags": ["ok"] * 21}, "body.tags"),
        ({"unexpected": "field"}, "body.unexpected"),
    ],
)
def test_create_rejects_invalid_input(
    db_client: TestClient, overrides: dict[str, Any], field: str
) -> None:
    response = db_client.post(URL, json=_payload(**overrides))

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "validation_error"
    assert field in [d["field"] for d in error["details"]]


def test_create_rejects_unknown_exam(db_client: TestClient) -> None:
    response = db_client.post(URL, json=_payload(exam_code="UPSC_CSE"))

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "invalid_reference"


def test_missing_concept_returns_404(db_client: TestClient) -> None:
    response = db_client.get(f"{URL}/{uuid.uuid4()}")

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_malformed_id_returns_422(db_client: TestClient) -> None:
    assert db_client.get(f"{URL}/not-a-uuid").status_code == 422


def test_patch_updates_only_given_fields(db_client: TestClient) -> None:
    created = _create(db_client, subtopic="Successive change")

    response = db_client.patch(f"{URL}/{created['id']}", json={"topic": "Profit & Loss"})

    assert response.status_code == 200
    body = response.json()
    assert body["topic"] == "Profit & Loss"
    assert body["subtopic"] == "Successive change"
    assert body["title"] == created["title"]


def test_patch_can_clear_optional_field(db_client: TestClient) -> None:
    created = _create(db_client, subtopic="Successive change")

    body = db_client.patch(f"{URL}/{created['id']}", json={"subtopic": None}).json()

    assert body["subtopic"] is None


def test_patch_rejects_null_for_required_field(db_client: TestClient) -> None:
    created = _create(db_client)

    response = db_client.patch(f"{URL}/{created['id']}", json={"title": None})

    assert response.status_code == 422


def test_patch_missing_concept_returns_404(db_client: TestClient) -> None:
    response = db_client.patch(f"{URL}/{uuid.uuid4()}", json={"topic": "x"})

    assert response.status_code == 404


def test_archive_hides_from_default_list_and_unarchive_restores(db_client: TestClient) -> None:
    created = _create(db_client)

    archived = db_client.post(f"{URL}/{created['id']}/archive").json()
    assert archived["archived_at"] is not None
    assert db_client.get(URL).json()["total"] == 0
    assert db_client.get(URL, params={"include_archived": True}).json()["total"] == 1

    restored = db_client.post(f"{URL}/{created['id']}/unarchive").json()
    assert restored["archived_at"] is None
    assert db_client.get(URL).json()["total"] == 1


def test_delete_is_permanent(db_client: TestClient) -> None:
    created = _create(db_client)

    assert db_client.delete(f"{URL}/{created['id']}").status_code == 204
    assert db_client.get(f"{URL}/{created['id']}").status_code == 404
    assert db_client.delete(f"{URL}/{created['id']}").status_code == 404


def test_search_and_filters(db_client: TestClient) -> None:
    _create(db_client, title="Percentage basics")
    _create(db_client, title="Ratio tricks", topic="Ratio", tags=["shortcut"])
    _create(
        db_client,
        exam_code="SSC_CHSL",
        title="Synonyms list",
        subject="English",
        topic="Vocabulary",
        tags=[],
    )
    _create(db_client, title="प्रतिशत सूत्र", topic="प्रतिशत", notes="", language="hi", tags=[])

    def titles(**params: Any) -> list[str]:
        return sorted(item["title"] for item in db_client.get(URL, params=params).json()["items"])

    assert titles(q="ratio") == ["Ratio tricks"]
    assert titles(q="PERCENT") == ["Percentage basics"]
    assert titles(q="प्रतिशत") == ["प्रतिशत सूत्र"]
    assert titles(exam="SSC_CHSL") == ["Synonyms list"]
    assert titles(subject="english") == ["Synonyms list"]
    assert titles(topic="ratio") == ["Ratio tricks"]
    assert titles(language="hi") == ["प्रतिशत सूत्र"]
    assert titles(tag="SHORTCUT") == ["Percentage basics", "Ratio tricks"]


def test_search_treats_like_wildcards_literally(db_client: TestClient) -> None:
    _create(db_client, title="Plain title", notes="")
    _create(db_client, title="Discount 10% off", notes="")

    items = db_client.get(URL, params={"q": "%"}).json()["items"]

    assert [i["title"] for i in items] == ["Discount 10% off"]


def test_pagination(db_client: TestClient) -> None:
    for i in range(5):
        _create(db_client, title=f"Concept {i}")

    page = db_client.get(URL, params={"limit": 2, "offset": 4}).json()

    assert page["total"] == 5
    assert page["limit"] == 2
    assert page["offset"] == 4
    assert len(page["items"]) == 1


@pytest.mark.parametrize("params", [{"limit": 0}, {"limit": 101}, {"offset": -1}])
def test_pagination_bounds_are_validated(db_client: TestClient, params: dict[str, int]) -> None:
    assert db_client.get(URL, params=params).status_code == 422
