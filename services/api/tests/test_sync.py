"""Device-data sync: push/pull, conflicts, last-writer-wins, tombstones, validation, ownership."""

from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from tests.conftest import auth_headers, make_user

CONCEPT = {
    "exam_code": "SSC_CGL",
    "title": "Percent change",
    "notes": "new − old ÷ old",
    "subject": "Quantitative Aptitude",
    "topic": "Percentage",
    "language": "en",
    "tags": ["formula"],
    "created_at": "2026-10-14T09:00:00Z",
    "updated_at": "2026-10-14T09:00:00Z",
}
CARD_ID = "7f2c3a1e-1111-4b6f-9e3a-000000000001"
CONCEPT_ID = "7f2c3a1e-2222-4b6f-9e3a-000000000002"


def push(client: TestClient, *changes: dict[str, Any], headers: Any = None) -> dict[str, Any]:
    response = client.post("/api/v1/sync/push", json={"changes": list(changes)}, headers=headers)
    assert response.status_code == 200, response.text
    data: dict[str, Any] = response.json()
    return data


def pull(client: TestClient, cursor: int = 0, headers: Any = None, **params: Any) -> dict[str, Any]:
    response = client.get("/api/v1/sync/pull", params={"cursor": cursor, **params}, headers=headers)
    assert response.status_code == 200, response.text
    data: dict[str, Any] = response.json()
    return data


def concept(title: str = "Percent change", **extra: Any) -> dict[str, Any]:
    return {"entity": "concept", "id": CONCEPT_ID, "data": {**CONCEPT, "title": title, **extra}}


def test_push_then_pull_round_trip_with_cursor(db_client: TestClient) -> None:
    result = push(
        db_client,
        concept(),
        {
            "entity": "study_profile",
            "id": "profile",
            "data": {
                "exam_codes": ["SSC_CGL"],
                "target_exam_date": "2027-06-01",
                "daily_study_minutes": 60,
                "updated_at": "2026-10-14T09:00:00Z",
            },
        },
        {"entity": "setting", "id": "revision_day_offsets", "data": {"value": "1,4,7"}},
    )
    assert (result["accepted"], result["ignored_deleted"], result["rejected"]) == (3, [], {})
    assert result["conflicts"] == []
    assert set(result["seqs"]) == {
        f"concept:{CONCEPT_ID}",
        "study_profile:profile",
        "setting:revision_day_offsets",
    }

    page = pull(db_client)
    assert [(c["entity"], c["id"]) for c in page["changes"]] == [
        ("concept", CONCEPT_ID),
        ("study_profile", "profile"),
        ("setting", "revision_day_offsets"),
    ]
    assert page["changes"][0]["data"]["notes"] == "new − old ÷ old"
    assert page["has_more"] is False

    # Nothing new after the cursor; a later change appears alone.
    assert pull(db_client, page["cursor"])["changes"] == []
    push(db_client, concept("Percentage change"))
    later = pull(db_client, page["cursor"])
    assert [c["data"]["title"] for c in later["changes"]] == ["Percentage change"]


def test_last_writer_wins_per_record(db_client: TestClient) -> None:
    push(db_client, concept("From phone"))
    push(db_client, concept("From tablet"))  # arrives later → wins

    changes = pull(db_client)["changes"]
    assert len(changes) == 1
    assert changes[0]["data"]["title"] == "From tablet"


def test_deletes_win_over_later_edits(db_client: TestClient) -> None:
    push(db_client, concept())
    push(db_client, {"entity": "concept", "id": CONCEPT_ID, "deleted": True})
    stale = push(db_client, concept("Edited offline on another device"))

    assert stale["accepted"] == 0
    assert stale["ignored_deleted"] == [f"concept:{CONCEPT_ID}"]
    [change] = pull(db_client)["changes"]
    assert (change["deleted"], change["data"]) == (True, None)


def test_replaying_a_push_is_harmless(db_client: TestClient) -> None:
    review = {
        "entity": "card_review",
        "id": "r-1",
        "data": {
            "card_id": CARD_ID,
            "reviewed_at": "2026-10-14T09:00:00Z",
            "rating": "good",
            "due_before": "2026-10-14",
            "due_after": "2026-10-17",
            "gap_days": 3,
        },
    }
    push(db_client, review)
    push(db_client, review)  # the device retried after a timeout

    changes = pull(db_client)["changes"]
    assert [(c["entity"], c["id"]) for c in changes] == [("card_review", "r-1")]


# --- conflicts (base_seq) ------------------------------------------------------------------


def test_a_stale_note_edit_is_returned_as_a_conflict_not_applied(db_client: TestClient) -> None:
    first = push(db_client, concept("Original"))
    base = first["seqs"][f"concept:{CONCEPT_ID}"]
    tablet = push(db_client, {**concept("Edited on tablet"), "base_seq": base})
    tablet_seq = tablet["seqs"][f"concept:{CONCEPT_ID}"]

    # The phone edited the same note offline, from the original version.
    phone = push(db_client, {**concept("Edited on phone"), "base_seq": base})

    assert (phone["accepted"], phone["seqs"]) == (0, {})
    [conflict] = phone["conflicts"]
    assert (conflict["id"], conflict["seq"]) == (CONCEPT_ID, tablet_seq)
    assert conflict["data"]["title"] == "Edited on tablet"
    [stored] = pull(db_client)["changes"]
    assert stored["data"]["title"] == "Edited on tablet"  # nothing was overwritten


def test_an_up_to_date_edit_is_applied_and_returns_its_new_version(db_client: TestClient) -> None:
    base = push(db_client, concept("Original"))["seqs"][f"concept:{CONCEPT_ID}"]

    result = push(db_client, {**concept("Edited"), "base_seq": base})

    assert result["accepted"] == 1 and result["conflicts"] == []
    assert result["seqs"][f"concept:{CONCEPT_ID}"] > base


def test_without_base_seq_older_apps_keep_last_writer_wins(db_client: TestClient) -> None:
    push(db_client, concept("From phone"))
    result = push(db_client, concept("From an older app"))

    assert (result["accepted"], result["conflicts"]) == (1, [])


def test_card_reviews_are_append_only(db_client: TestClient) -> None:
    data: dict[str, Any] = {
        "card_id": CARD_ID,
        "reviewed_at": "2026-10-14T09:00:00Z",
        "rating": "good",
        "due_before": "2026-10-14",
        "due_after": "2026-10-17",
        "gap_days": 3,
    }
    review = {"entity": "card_review", "id": "r-1", "data": data}
    first = push(db_client, review)
    changed = {**review, "data": {**data, "rating": "easy"}}
    again = push(db_client, changed)

    assert again["seqs"] == first["seqs"]  # same version: not rewritten, not re-sent
    [stored] = pull(db_client)["changes"]
    assert stored["data"]["rating"] == "good"


def test_invalid_records_are_rejected_individually(db_client: TestClient) -> None:
    result = push(
        db_client,
        concept(title=""),
        {"entity": "setting", "id": "unknown_setting", "data": {"value": "x"}},
        {"entity": "concept", "id": "c-2"},
        {
            "entity": "study_profile",
            "id": "profile",
            "data": {"daily_study_minutes": 2, "updated_at": "2026-10-14T09:00:00Z"},
        },
        {
            "entity": "revision_card",
            "id": CARD_ID,
            "data": {
                "kind": "concept",
                "concept_id": CONCEPT_ID,
                "step": 0,
                "gap_days": 1,
                "due_on": "2026-10-15",
                "created_at": "2026-10-14T09:00:00Z",
                "updated_at": "2026-10-14T09:00:00Z",
            },
        },
    )

    assert result["accepted"] == 1  # only the valid revision card
    assert set(result["rejected"]) == {
        f"concept:{CONCEPT_ID}",
        "setting:unknown_setting",
        "concept:c-2",
        "study_profile:profile",
    }
    assert result["rejected"]["concept:c-2"] == "Missing data."
    bad_entity = db_client.post(
        "/api/v1/sync/push", json={"changes": [{"entity": "password", "id": "x", "data": {}}]}
    )
    assert bad_entity.status_code == 422


def test_pull_pages_through_large_change_sets(db_client: TestClient) -> None:
    push(
        db_client,
        *[
            {"entity": "setting", "id": "revision_day_offsets", "data": {"value": f"1,{n}"}}
            for n in range(2, 5)
        ],
        *[concept(id_suffix) for id_suffix in ("A", "B")],
    )
    push(db_client, *[{**concept(), "id": f"c-{n}"} for n in range(5)])

    first = pull(db_client, limit=3)
    assert len(first["changes"]) == 3 and first["has_more"] is True
    rest = pull(db_client, first["cursor"], limit=100)
    ids = [c["id"] for c in first["changes"] + rest["changes"]]
    assert len(ids) == len(set(ids)) == 7  # each record once, latest version


def test_each_account_syncs_only_its_own_data(db_client: TestClient, db_session: Session) -> None:
    push(db_client, concept("Mine"))
    other = auth_headers(make_user(db_session, "other@example.com"))

    assert pull(db_client, headers=other)["changes"] == []
    push(db_client, concept("Theirs, same id"), headers=other)

    [mine] = pull(db_client)["changes"]
    assert mine["data"]["title"] == "Mine"
    [theirs] = pull(db_client, headers=other)["changes"]
    assert theirs["data"]["title"] == "Theirs, same id"
