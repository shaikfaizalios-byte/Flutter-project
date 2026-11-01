"""Google Play purchases for PrepLoop Plus: verified only with (a fake of) the Play Developer
API, attached only to the buying account, kept current by notifications, audited without tokens."""

import base64
import json
import uuid
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.security import TokenSigner
from app.database.session import get_session
from app.domain import billing
from app.integrations.play_billing import PlayBillingError
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.plus import BillingEvent, PlayPurchase, Subscription
from app.models.user import User
from tests.conftest import TEST_AUTH_SECRET, auth_headers, make_user

PACKAGE = "com.preploop.test"
PRODUCT = "plus_monthly"
TOKEN = "play-token-" + "x" * 40
NOW = datetime.now(UTC)


def account_id(user: User) -> str:
    return billing.play_account_id(TEST_AUTH_SECRET, user.id)


def purchase(
    user: User,
    *,
    state: str = "SUBSCRIPTION_STATE_ACTIVE",
    expires: datetime | None = None,
    acknowledged: bool = False,
    product: str = PRODUCT,
    linked: str | None = None,
) -> dict[str, Any]:
    data: dict[str, Any] = {
        "subscriptionState": state,
        "lineItems": [
            {
                "productId": product,
                "expiryTime": (expires or NOW + timedelta(days=30))
                .isoformat()
                .replace("+00:00", "Z"),
            }
        ],
        "acknowledgementState": "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"
        if acknowledged
        else "ACKNOWLEDGEMENT_STATE_PENDING",
        "externalAccountIdentifiers": {"obfuscatedExternalAccountId": account_id(user)},
        "testPurchase": {},
    }
    if linked:
        data["linkedPurchaseToken"] = linked
    return data


class FakePlay:
    """The Play Developer API: purchases by token, with call counts."""

    def __init__(self) -> None:
        self.purchases: dict[str, dict[str, Any]] = {}
        self.acknowledged: list[str] = []
        self.reads = 0
        self.down = False

    def get_subscription(self, purchase_token: str) -> dict[str, Any]:
        self.reads += 1
        if self.down:
            raise PlayBillingError("play_unreachable")
        if purchase_token not in self.purchases:
            raise PlayBillingError("play_status_404", not_found=True)
        return self.purchases[purchase_token]

    def acknowledge(self, product_id: str, purchase_token: str) -> None:
        self.acknowledged.append(purchase_token)
        self.purchases[purchase_token]["acknowledgementState"] = (
            "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"
        )


class FakeVerifier:
    def verify(self, authorization: str | None) -> None:
        if authorization != "Bearer google-signed":
            raise PlayBillingError("push_token_invalid")


@pytest.fixture
def play() -> FakePlay:
    return FakePlay()


@pytest.fixture
def api(
    settings: Settings,
    db_engine: Any,
    db_session: Session,
    storage: LocalDocumentStorage,
    user: User,
    play: FakePlay,
) -> Iterator[TestClient]:
    configured = settings.model_copy(
        update={"play_package_name": PACKAGE, "play_subscription_ids": [PRODUCT]}
    )
    app = create_app(
        configured,
        engine=db_engine,
        storage=storage,
        play_billing=play,
        play_push_verifier=FakeVerifier(),
    )
    app.dependency_overrides[get_session] = lambda: db_session
    with TestClient(app, raise_server_exceptions=False) as client:
        client.headers.update(auth_headers(user))
        yield client


def verify(api: TestClient, token: str = TOKEN, product: str = PRODUCT, **kw: Any) -> Any:
    return api.post(
        "/api/v1/billing/play/verify",
        json={"product_id": product, "purchase_token": token},
        **kw,
    )


def notify(api: TestClient, payload: dict[str, Any], message_id: str = "m-1") -> Any:
    data = base64.b64encode(json.dumps(payload).encode()).decode()
    return api.post(
        "/api/v1/billing/play/rtdn",
        json={"message": {"data": data, "messageId": message_id}, "subscription": "s"},
        headers={"Authorization": "Bearer google-signed"},
    )


def renewal(token: str = TOKEN, kind: int = 2) -> dict[str, Any]:
    return {
        "version": "1.0",
        "packageName": PACKAGE,
        "eventTimeMillis": "1",
        "subscriptionNotification": {
            "version": "1.0",
            "notificationType": kind,
            "purchaseToken": token,
            "subscriptionId": PRODUCT,
        },
    }


# --- rules -------------------------------------------------------------------------------


def test_entitlement_follows_googles_state() -> None:
    user_id = uuid.uuid4()
    later = NOW + timedelta(days=3)

    def until(state: str, expires: datetime | None = later) -> datetime | None:
        sub = billing.PlaySubscription(state, PRODUCT, expires, True, "a", None, False)
        return billing.entitled_until(sub, NOW)

    assert until("SUBSCRIPTION_STATE_ACTIVE") == later
    assert until("SUBSCRIPTION_STATE_CANCELED") == later  # paid period still runs
    assert until("SUBSCRIPTION_STATE_IN_GRACE_PERIOD") == later
    for state in ("ON_HOLD", "PAUSED", "EXPIRED", "PENDING"):
        assert until(f"SUBSCRIPTION_STATE_{state}") is None
    assert until("SUBSCRIPTION_STATE_ACTIVE", NOW - timedelta(seconds=1)) is None
    assert billing.play_account_id("s", user_id) == billing.play_account_id("s", user_id)
    assert billing.play_account_id("s", user_id) != billing.play_account_id("t", user_id)
    assert len(billing.play_account_id("s", user_id)) <= 64


def test_problems_refuse_other_products_and_accounts() -> None:
    user = User(id=uuid.uuid4(), email="a@example.com", password_hash="x")
    ours = billing.parse_subscription(purchase(user), [PRODUCT])
    assert billing.problems(ours, expected_account_id=account_id(user)) == []
    assert billing.problems(ours, expected_account_id="someone-else") == ["other_account"]
    other = billing.parse_subscription(purchase(user, product="coins"), [PRODUCT])
    assert "not_our_product" in billing.problems(other, expected_account_id=account_id(user))


# --- the app reports a purchase ------------------------------------------------------------


def test_a_verified_purchase_turns_plus_on_and_is_acknowledged(
    api: TestClient, db_session: Session, user: User, play: FakePlay
) -> None:
    before = api.get("/api/v1/me/plus").json()
    assert before["purchases_available"] is True
    assert before["play_product_ids"] == [PRODUCT]
    assert before["play_account_id"] == account_id(user)
    play.purchases[TOKEN] = purchase(user)

    response = verify(api)

    assert response.status_code == 200, response.text
    body = response.json()
    assert (body["active"], body["source"]) == (True, "play")
    assert play.acknowledged == [TOKEN]
    stored = db_session.scalar(select(PlayPurchase).where(PlayPurchase.purchase_token == TOKEN))
    assert stored is not None and stored.acknowledged and stored.test_purchase
    [event] = db_session.scalars(select(BillingEvent)).all()
    assert (event.kind, event.outcome) == ("verify", "applied")
    assert event.token_hash == billing.token_hash(TOKEN)
    assert TOKEN not in event.event_key and TOKEN not in event.detail
    assert verify(api).status_code == 200  # reporting again is harmless
    assert play.acknowledged == [TOKEN]


def test_a_purchase_from_another_account_is_refused(
    api: TestClient, db_session: Session, play: FakePlay
) -> None:
    other = make_user(db_session, email="other@example.com")
    play.purchases[TOKEN] = purchase(other)

    response = verify(api)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "purchase_refused"
    assert api.get("/api/v1/me/plus").json()["active"] is False
    [event] = db_session.scalars(select(BillingEvent)).all()
    assert (event.outcome, event.detail) == ("refused", "other_account")


def test_unknown_tokens_and_products_are_refused(api: TestClient) -> None:
    assert verify(api).json()["error"]["code"] == "purchase_refused"  # Google doesn't know it
    assert verify(api, product="coins").json()["error"]["code"] == "invalid_reference"


def test_google_down_is_reported_for_a_retry(api: TestClient, user: User, play: FakePlay) -> None:
    play.purchases[TOKEN] = purchase(user)
    play.down = True

    response = verify(api)

    assert response.status_code == 502
    assert response.json()["error"]["code"] == "store_unavailable"


def test_an_operator_grant_that_lasts_longer_is_kept(
    api: TestClient, db_session: Session, user: User, play: FakePlay
) -> None:
    db_session.add(
        Subscription(owner_id=user.id, source="operator", active_until=NOW + timedelta(days=365))
    )
    db_session.flush()
    play.purchases[TOKEN] = purchase(user)

    body = verify(api).json()

    assert body["source"] == "operator"


def test_without_play_configured_purchases_are_unavailable(
    db_client: TestClient, user: User
) -> None:
    status = db_client.get("/api/v1/me/plus").json()
    assert (status["purchases_available"], status["play_account_id"]) == (False, None)

    response = verify(db_client)

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "billing_unavailable"


# --- Google's notifications ----------------------------------------------------------------


def test_a_renewal_notification_extends_plus_from_googles_answer(
    api: TestClient, user: User, play: FakePlay
) -> None:
    play.purchases[TOKEN] = purchase(user)
    verify(api)
    renewed = NOW + timedelta(days=60)
    play.purchases[TOKEN] = purchase(user, expires=renewed, acknowledged=True)

    response = notify(api, renewal())

    assert response.status_code == 204, response.text
    until = datetime.fromisoformat(api.get("/api/v1/me/plus").json()["active_until"])
    assert abs((until - renewed).total_seconds()) < 1


def test_a_notification_is_applied_once(
    api: TestClient, db_session: Session, user: User, play: FakePlay
) -> None:
    play.purchases[TOKEN] = purchase(user)
    verify(api)
    reads = play.reads

    notify(api, renewal(), message_id="same")
    notify(api, renewal(), message_id="same")

    assert play.reads == reads + 1
    events = db_session.scalars(
        select(BillingEvent).where(BillingEvent.kind == "subscription")
    ).all()
    assert len(events) == 1


def test_on_hold_and_refunds_end_plus(api: TestClient, user: User, play: FakePlay) -> None:
    play.purchases[TOKEN] = purchase(user)
    verify(api)

    play.purchases[TOKEN] = purchase(user, state="SUBSCRIPTION_STATE_ON_HOLD")
    notify(api, renewal(kind=5), message_id="hold")
    assert api.get("/api/v1/me/plus").json()["active"] is False

    play.purchases[TOKEN] = purchase(user, acknowledged=True)
    notify(api, renewal(kind=1), message_id="recovered")
    assert api.get("/api/v1/me/plus").json()["active"] is True

    voided = {
        "version": "1.0",
        "packageName": PACKAGE,
        "voidedPurchaseNotification": {"purchaseToken": TOKEN, "orderId": "GPA.1"},
    }
    notify(api, voided, message_id="refund")
    assert api.get("/api/v1/me/plus").json()["active"] is False
    # A refund is final, even if a later notification reads the old state again.
    notify(api, renewal(), message_id="late")
    assert api.get("/api/v1/me/plus").json()["active"] is False


def test_an_upgrade_replaces_the_old_purchase(
    api: TestClient, db_session: Session, user: User, play: FakePlay
) -> None:
    play.purchases[TOKEN] = purchase(user)
    verify(api)
    new_token = TOKEN + "-new"
    play.purchases[new_token] = purchase(user, linked=TOKEN)

    verify(api, token=new_token)

    old = db_session.scalar(select(PlayPurchase).where(PlayPurchase.purchase_token == TOKEN))
    new = db_session.scalar(select(PlayPurchase).where(PlayPurchase.purchase_token == new_token))
    assert old is not None and new is not None and old.replaced_by_id == new.id


def test_notifications_need_googles_token_and_our_package(
    api: TestClient, db_session: Session, play: FakePlay
) -> None:
    data = base64.b64encode(json.dumps(renewal()).encode()).decode()
    unsigned = api.post(
        "/api/v1/billing/play/rtdn",
        json={"message": {"data": data, "messageId": "x"}},
        headers={"Authorization": "Bearer forged"},
    )
    assert unsigned.status_code == 401

    notify(api, {**renewal(), "packageName": "com.other"}, message_id="other")
    notify(api, renewal(token="never-reported"), message_id="unknown")

    outcomes = {e.detail or e.outcome for e in db_session.scalars(select(BillingEvent)).all()}
    assert outcomes == {"other_package", "unknown_token"}
    assert play.reads == 0


def test_notifications_are_refused_when_not_configured(db_client: TestClient) -> None:
    response = db_client.post("/api/v1/billing/play/rtdn", json={"message": {}})
    assert response.status_code == 401


def test_the_account_id_needs_the_server_secret() -> None:
    signer = TokenSigner(TEST_AUTH_SECRET, 15)
    user_id = uuid.uuid4()
    assert billing.play_account_id(signer.secret, user_id) != str(user_id)
