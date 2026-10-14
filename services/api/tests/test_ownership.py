"""One learner can never read or change another learner's data (real Postgres)."""

from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models.document import Document
from app.models.user import User
from tests.conftest import auth_headers, make_user
from tests.test_practice import document, make_formats_ready, make_question

__all__ = ["document"]  # fixture re-used from test_practice


def as_user(client: TestClient, user: User) -> dict[str, str]:
    return auth_headers(user)


def test_documents_questions_and_sessions_are_private(
    db_client: TestClient, db_session: Session, document: Document, user: User
) -> None:
    question = make_question(db_session, document, explanation=None)
    session = db_client.post("/api/v1/practice/sessions", json={"count": 1}).json()
    db_client.put(f"/api/v1/questions/{question.id}/bookmark")
    other = as_user(db_client, make_user(db_session, "other@example.com"))

    def get(path: str, **kw: Any) -> int:
        return db_client.get(path, headers=other, **kw).status_code

    # Lists show nothing of the first learner's data.
    assert db_client.get("/api/v1/documents", headers=other).json()["total"] == 0
    assert db_client.get("/api/v1/questions", headers=other).json()["total"] == 0
    assert db_client.get("/api/v1/practice/sessions", headers=other).json()["items"] == []
    assert db_client.get("/api/v1/practice/bookmarks", headers=other).json()["items"] == []
    analytics = db_client.get(
        "/api/v1/analytics/overview", params={"timezone": "UTC"}, headers=other
    ).json()
    assert analytics["answered"] == 0 and analytics["sessions"] == 0

    # Direct access by id looks exactly like "not found".
    for path in (
        f"/api/v1/documents/{document.id}",
        f"/api/v1/documents/{document.id}/pages",
        f"/api/v1/documents/{document.id}/parse-summary",
        f"/api/v1/questions/{question.id}",
        f"/api/v1/questions/{question.id}/history",
        f"/api/v1/practice/sessions/{session['id']}",
    ):
        assert get(path) == 404, path

    # Writes are refused the same way.
    writes = [
        db_client.patch(f"/api/v1/questions/{question.id}", json={"stem": "x"}, headers=other),
        db_client.post(
            f"/api/v1/questions/{question.id}/report", json={"reason": "unclear"}, headers=other
        ),
        db_client.put(f"/api/v1/questions/{question.id}/bookmark", headers=other),
        db_client.put(
            f"/api/v1/practice/sessions/{session['id']}/answers/1",
            json={"selected_position": 1, "client_seq": 1},
            headers=other,
        ),
        db_client.post(f"/api/v1/practice/sessions/{session['id']}/submit", headers=other),
        db_client.post(f"/api/v1/documents/{document.id}/segment", headers=other),
        db_client.delete(f"/api/v1/documents/{document.id}", headers=other),
        db_client.post(f"/api/v1/ai/questions/{question.id}/explanation", headers=other),
    ]
    assert [w.status_code for w in writes] == [404, 404, 404, 404, 404, 404, 404, 503]
    # (AI is not configured here, so the AI call stops at 503 before touching data; the
    # AI service's own ownership check is covered in test_ai.py.)

    # The second learner's practice and mocks never draw the first learner's questions.
    empty = db_client.post("/api/v1/practice/sessions", json={"count": 5}, headers=other)
    assert empty.status_code == 422
    make_formats_ready(db_session, document)
    mocks = db_client.get("/api/v1/practice/mock-tests", headers=other).json()
    assert all(not m["available"] for m in mocks)

    # And the owner still has everything.
    assert db_client.get(f"/api/v1/questions/{question.id}").status_code == 200
    assert db_client.get("/api/v1/practice/bookmarks").json()["total"] == 1


def test_concepts_are_private(db_client: TestClient, db_session: Session) -> None:
    created = db_client.post(
        "/api/v1/concepts",
        json={
            "exam_code": "SSC_CGL",
            "title": "Mine",
            "subject": "Quantitative Aptitude",
            "topic": "Percentage",
            "language": "en",
        },
    ).json()
    other = auth_headers(make_user(db_session, "other@example.com"))

    assert db_client.get("/api/v1/concepts", headers=other).json()["total"] == 0
    assert db_client.get(f"/api/v1/concepts/{created['id']}", headers=other).status_code == 404
    assert (
        db_client.patch(
            f"/api/v1/concepts/{created['id']}", json={"title": "Theirs"}, headers=other
        ).status_code
        == 404
    )
    assert db_client.delete(f"/api/v1/concepts/{created['id']}", headers=other).status_code == 404
