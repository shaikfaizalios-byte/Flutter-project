"""Plus bought on the website with Razorpay: signatures as Razorpay documents them, orders priced
by the server, Plus given only on Razorpay's own list of the order's payments (once), refunds
taken back, webhooks refused without the webhook secret's signature."""

import hashlib
import hmac
import http.client
import json
import re
import urllib.error
import urllib.request
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Any

import pytest
from fastapi.testclient import TestClient
from pydantic import SecretStr, ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Environment, Settings
from app.database.session import get_session
from app.domain import paytm, razorpay
from app.integrations.razorpay import RazorpayError, RazorpayGateway
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.plus import BillingEvent, Subscription, WebPayment
from app.models.user import User
from tests.conftest import auth_headers, make_user

KEY_ID = "rzp_test_MadeUp000001"  # made up
SECRET = "testsecret123456"
WEBHOOK_SECRET = "whsecret"
RETURN = "https://app.example.test/#/profile/plus/payment?order={order}"
CALLBACK = "https://api.example.test/api/v1/billing/razorpay/callback"

# Made with openssl: printf '%s' 'order_TEST000000001|pay_TEST000000001' |
#   openssl dgst -sha256 -hmac testsecret123456
CHECKOUT_SIGNATURE = "8fcf84d3cbda7f4f5e16458b7b5a9540fe4775f2172fac01f34a03d855c045de"
# printf '%s' '{"event":"payment.captured"}' | openssl dgst -sha256 -hmac whsecret
WEBHOOK_BODY = b'{"event":"payment.captured"}'
WEBHOOK_SIGNATURE = "ecb84b56ebec4842703542b4f4772b1cc5eb6dcf7f98a2195ab5afbd728cfd47"


# --- signatures and rules ----------------------------------------------------------------


def test_signatures_match_razorpays_formula() -> None:
    assert razorpay.payment_signature("order_TEST000000001", "pay_TEST000000001", SECRET) == (
        CHECKOUT_SIGNATURE
    )
    assert razorpay.payment_signature_valid(
        "order_TEST000000001", "pay_TEST000000001", CHECKOUT_SIGNATURE, SECRET
    )
    assert not razorpay.payment_signature_valid(
        "order_OTHER", "pay_TEST000000001", CHECKOUT_SIGNATURE, SECRET
    )
    assert not razorpay.payment_signature_valid("order_TEST000000001", "", "", SECRET)
    assert razorpay.webhook_signature_valid(WEBHOOK_BODY, WEBHOOK_SIGNATURE, WEBHOOK_SECRET)
    assert not razorpay.webhook_signature_valid(WEBHOOK_BODY + b" ", WEBHOOK_SIGNATURE, "whsecret")
    assert not razorpay.webhook_signature_valid(WEBHOOK_BODY, WEBHOOK_SIGNATURE, "other")
    assert not razorpay.webhook_signature_valid(WEBHOOK_BODY, None, WEBHOOK_SECRET)


def test_keys_tell_test_from_live() -> None:
    assert razorpay.environment_of("rzp_test_abc") == "staging"
    assert razorpay.environment_of("rzp_live_abc") == "production"
    assert razorpay.environment_of("rzp_test_") is None
    assert razorpay.environment_of("pk_live_abc") is None


def payment(
    status: str = "captured",
    *,
    order: str,
    amount: int = 9900,
    refunded: int = 0,
    currency: str = "INR",
    captured: bool | None = None,
) -> dict[str, Any]:
    return {
        "id": "pay_TEST000000001",
        "entity": "payment",
        "amount": amount,
        "currency": currency,
        "status": status,
        "order_id": order,
        "method": "upi",
        "amount_refunded": refunded,
        "refund_status": None if not refunded else ("full" if refunded >= amount else "partial"),
        "captured": status in ("captured", "refunded") if captured is None else captured,
    }


def payments(*items: dict[str, Any]) -> dict[str, Any]:
    return {"entity": "collection", "count": len(items), "items": list(items)}


def test_only_a_captured_payment_of_the_whole_amount_counts() -> None:
    order = "order_TEST000000001"

    def out(*items: dict[str, Any]) -> str:
        return razorpay.outcome(payments(*items), razorpay_order_id=order, amount_paise=9900)[0]

    assert out() == "unpaid"
    assert out(payment("failed", order=order)) == "failed"
    assert out(payment("failed", order=order), payment("authorized", order=order)) == "pending"
    assert out(payment("failed", order=order), payment(order=order)) == "success"
    assert out(payment(order=order, refunded=5000)) == "success"  # partial refund
    assert out(payment("refunded", order=order, refunded=9900)) == "refunded"
    # An authorization Razorpay returned without capturing it was never paid.
    assert out(payment("refunded", order=order, refunded=9900, captured=False)) == "failed"
    assert out(payment(order=order, amount=100)) == "mismatch"
    assert out(payment(order=order, currency="USD")) == "mismatch"
    assert out(payment(order="order_OTHER")) == "mismatch"


def test_webhooks_name_their_order() -> None:
    def event(name: str, entity: dict[str, Any]) -> dict[str, Any]:
        return {"event": "x", "payload": {name: {"entity": entity}}}

    assert razorpay.webhook_order_id(event("payment", {"order_id": "order_A"})) == "order_A"
    assert razorpay.webhook_order_id(event("order", {"id": "order_B"})) == "order_B"
    assert razorpay.webhook_order_id(event("refund", {"payment_id": "pay_1"})) is None
    assert razorpay.webhook_order_id({"payload": "nonsense"}) is None


def razorpay_settings(settings: Settings) -> Settings:
    return settings.model_copy(
        update={
            "razorpay_key_id": KEY_ID,
            "razorpay_key_secret": SecretStr(SECRET),
            "razorpay_webhook_secret": SecretStr(WEBHOOK_SECRET),
            "razorpay_plus_price": Decimal("99.00"),
            "razorpay_plus_days": 30,
            "razorpay_callback_url": CALLBACK,
            "razorpay_return_url": RETURN,
        }
    )


def test_settings_keep_test_and_real_money_apart(settings: Settings) -> None:
    configured = razorpay_settings(settings)
    assert configured.razorpay_configured and configured.environment is Environment.TEST
    values = configured.model_dump()
    with pytest.raises(ValidationError, match="production server only"):
        Settings.model_validate({**values, "razorpay_key_id": "rzp_live_MadeUp000001"})
    with pytest.raises(ValidationError, match="rzp_test_ or rzp_live_"):
        Settings.model_validate({**values, "razorpay_key_id": "MadeUp000001"})
    with pytest.raises(ValidationError, match="not both"):
        Settings.model_validate(
            {
                **values,
                "paytm_mid": "TESTMID0000000000001",
                "paytm_merchant_key": SecretStr("TESTKEY123456789"),
                "paytm_plus_price": Decimal("99.00"),
                "paytm_plus_days": 30,
                "paytm_callback_url": "https://api.example.test/api/v1/billing/paytm/callback",
                "paytm_return_url": RETURN,
            }
        )
    assert not settings.razorpay_configured


# --- the website flow --------------------------------------------------------------------


class FakeRazorpay:
    """Razorpay's Orders API, with what each order's payments will be."""

    key_id = KEY_ID
    environment: paytm.Environment = "staging"

    def __init__(self) -> None:
        self.orders: dict[str, tuple[int, str]] = {}
        self.answers: dict[str, dict[str, Any]] = {}
        self.calls = 0
        self.down = False

    def create_order(self, amount_paise: int, receipt: str) -> str:
        if self.down:
            raise RazorpayError("unreachable")
        order = f"order_T{len(self.orders):013d}"
        self.orders[order] = (amount_paise, receipt)
        return order

    def order_payments(self, razorpay_order_id: str) -> dict[str, Any]:
        self.calls += 1
        if self.down:
            raise RazorpayError("unreachable")
        return self.answers.get(razorpay_order_id, payments())

    def signature_valid(self, razorpay_order_id: str, payment_id: str, signature: str) -> bool:
        return razorpay.payment_signature_valid(razorpay_order_id, payment_id, signature, SECRET)

    def webhook_valid(self, body: bytes, signature: str | None) -> bool:
        return razorpay.webhook_signature_valid(body, signature, WEBHOOK_SECRET)


@pytest.fixture
def gateway() -> FakeRazorpay:
    return FakeRazorpay()


@pytest.fixture
def api(
    settings: Settings,
    db_engine: Any,
    db_session: Session,
    storage: LocalDocumentStorage,
    user: User,
    gateway: FakeRazorpay,
) -> Iterator[TestClient]:
    app = create_app(
        razorpay_settings(settings), engine=db_engine, storage=storage, razorpay=gateway
    )
    app.dependency_overrides[get_session] = lambda: db_session
    with TestClient(app, raise_server_exceptions=False, follow_redirects=False) as client:
        client.headers.update(auth_headers(user))
        yield client


def start(api: TestClient) -> dict[str, Any]:
    response = api.post("/api/v1/billing/web/orders")
    assert response.status_code == 201, response.text
    body: dict[str, Any] = response.json()
    return body


def rz_order_of(db_session: Session, order_id: str) -> str:
    row = db_session.scalar(select(WebPayment).where(WebPayment.order_id == order_id))
    assert row is not None and row.provider_order_id
    return row.provider_order_id


def callback(api: TestClient, rz_order: str, *, signature: str | None = None) -> Any:
    sig = signature or razorpay.payment_signature(rz_order, "pay_TEST000000001", SECRET)
    form = {
        "razorpay_payment_id": "pay_TEST000000001",
        "razorpay_order_id": rz_order,
        "razorpay_signature": sig,
    }
    return api.post("/api/v1/billing/razorpay/callback", data=form)


def webhook(api: TestClient, event: dict[str, Any], *, secret: str = WEBHOOK_SECRET) -> Any:
    body = json.dumps(event).encode()
    signature = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return api.post(
        "/api/v1/billing/razorpay/webhook",
        content=body,
        headers={"Content-Type": "application/json", "X-Razorpay-Signature": signature},
    )


def payment_event(name: str, rz_order: str) -> dict[str, Any]:
    entity = payment(order=rz_order)
    return {"entity": "event", "event": name, "payload": {"payment": {"entity": entity}}}


def plus(api: TestClient) -> dict[str, Any]:
    body: dict[str, Any] = api.get("/api/v1/me/plus").json()
    return body


def test_the_offer_names_razorpay(api: TestClient, db_client: TestClient) -> None:
    assert plus(api)["web_offer"] == {
        "provider": "razorpay",
        "amount_paise": 9900,
        "currency": "INR",
        "days": 30,
        "test_payments": True,
    }
    assert db_client.post("/api/v1/billing/web/orders").status_code == 503


def test_an_order_is_priced_by_the_server_and_opens_the_checkout(
    api: TestClient, gateway: FakeRazorpay, db_session: Session
) -> None:
    order = start(api)
    assert order["amount_paise"] == 9900 and order["days"] == 30
    rz_order = rz_order_of(db_session, order["order_id"])
    assert gateway.orders[rz_order] == (9900, order["order_id"])  # receipt = our order id
    page = api.get(order["pay_path"], headers={"Authorization": ""})  # the browser has no token
    assert page.status_code == 200
    assert razorpay.CHECKOUT_SCRIPT in page.text
    assert f'"order_id": "{rz_order}"' in page.text and f'"key": "{KEY_ID}"' in page.text
    assert SECRET not in page.text and WEBHOOK_SECRET not in page.text
    assert page.headers["cache-control"] == "no-store"
    tampered = re.sub(r"s=\w+", "s=" + "0" * 32, order["pay_path"])
    assert api.get(tampered).status_code == 404


def test_paying_turns_plus_on_once(
    api: TestClient, gateway: FakeRazorpay, db_session: Session
) -> None:
    order_id = start(api)["order_id"]
    rz_order = rz_order_of(db_session, order_id)
    gateway.answers[rz_order] = payments(payment(order=rz_order))
    back = callback(api, rz_order)
    assert back.status_code == 303
    assert back.headers["location"] == RETURN.replace("{order}", order_id)
    status = plus(api)
    assert status["active"] and status["source"] == "web"
    until = datetime.fromisoformat(status["active_until"])
    assert timedelta(days=29, hours=23) < until - datetime.now(UTC) <= timedelta(days=30)
    # The same news again (webhooks, a second callback, the app asking) adds nothing.
    callback(api, rz_order)
    assert webhook(api, payment_event("payment.captured", rz_order)).json() == {"status": "ok"}
    read = api.get(f"/api/v1/billing/web/orders/{order_id}").json()
    assert read["status"] == "success" and read["test_payment"] is True
    assert plus(api)["active_until"] == status["active_until"]
    row = db_session.scalar(select(WebPayment).where(WebPayment.order_id == order_id))
    assert row is not None and row.txn_id == "pay_TEST000000001" and row.payment_mode == "upi"
    events = db_session.scalars(
        select(BillingEvent).where(BillingEvent.provider == "razorpay")
    ).all()
    assert {e.kind for e in events} == {"order", "callback", "webhook"}
    assert all(order_id not in (e.detail + (e.token_hash or "")) for e in events)


def test_the_callback_form_itself_is_never_believed(
    api: TestClient, gateway: FakeRazorpay, db_session: Session
) -> None:
    order_id = start(api)["order_id"]
    rz_order = rz_order_of(db_session, order_id)
    # A correctly signed callback, but Razorpay has no captured payment: nothing is given.
    assert callback(api, rz_order).status_code == 303
    assert not plus(api)["active"]
    # A forged signature is recorded; only Razorpay's answer counts.
    gateway.answers[rz_order] = payments(payment(order=rz_order))
    callback(api, rz_order, signature="0" * 64)
    assert plus(api)["active"]
    notes = db_session.scalars(select(BillingEvent.detail)).all()
    assert any("signature_failed" in n for n in notes)


def test_a_failed_attempt_can_be_paid_again(
    api: TestClient, gateway: FakeRazorpay, db_session: Session
) -> None:
    order = start(api)
    rz_order = rz_order_of(db_session, order["order_id"])
    gateway.answers[rz_order] = payments(payment("failed", order=rz_order))
    read = api.get(f"/api/v1/billing/web/orders/{order['order_id']}").json()
    assert read["status"] == "failed" and not plus(api)["active"]
    assert api.get(order["pay_path"]).status_code == 200  # the checkout opens again
    gateway.answers[rz_order] = payments(payment("failed", order=rz_order), payment(order=rz_order))
    assert webhook(api, payment_event("order.paid", rz_order)).json() == {"status": "ok"}
    assert plus(api)["active"]
    assert api.get(order["pay_path"]).status_code == 404  # paid: no more checkout


def test_a_full_refund_takes_the_days_back(
    api: TestClient, gateway: FakeRazorpay, db_session: Session
) -> None:
    order_id = start(api)["order_id"]
    rz_order = rz_order_of(db_session, order_id)
    gateway.answers[rz_order] = payments(payment(order=rz_order))
    callback(api, rz_order)
    gateway.answers[rz_order] = payments(payment(order=rz_order, refunded=5000))
    webhook(api, {"event": "refund.processed", "payload": payment_event("x", rz_order)["payload"]})
    assert plus(api)["active"]  # a partial refund changes nothing
    gateway.answers[rz_order] = payments(payment("refunded", order=rz_order, refunded=9900))
    webhook(api, {"event": "refund.processed", "payload": payment_event("x", rz_order)["payload"]})
    assert not plus(api)["active"]
    read = api.get(f"/api/v1/billing/web/orders/{order_id}").json()
    assert read["status"] == "refunded"
    calls = gateway.calls
    webhook(api, payment_event("payment.captured", rz_order))
    assert gateway.calls == calls  # a refunded order is final


def test_a_refund_before_we_saw_the_payment_gives_nothing(
    api: TestClient, gateway: FakeRazorpay, db_session: Session, user: User
) -> None:
    db_session.add(
        Subscription(
            owner_id=user.id,
            plan="plus",
            source="test",
            active_until=datetime.now(UTC) + timedelta(days=3),
        )
    )
    db_session.flush()
    order_id = start(api)["order_id"]
    rz_order = rz_order_of(db_session, order_id)
    gateway.answers[rz_order] = payments(payment("refunded", order=rz_order, refunded=9900))
    webhook(api, payment_event("payment.captured", rz_order))
    status = plus(api)
    assert status["source"] == "test"  # the test subscription is left alone
    read = api.get(f"/api/v1/billing/web/orders/{order_id}").json()
    assert read["status"] == "refunded"


def test_webhooks_need_razorpays_signature(
    api: TestClient, gateway: FakeRazorpay, db_session: Session
) -> None:
    order_id = start(api)["order_id"]
    rz_order = rz_order_of(db_session, order_id)
    gateway.answers[rz_order] = payments(payment(order=rz_order))
    event = payment_event("payment.captured", rz_order)
    assert webhook(api, event, secret="guessed").status_code == 401
    unsigned = api.post("/api/v1/billing/razorpay/webhook", json=event)
    assert unsigned.status_code == 401
    assert not plus(api)["active"]
    other = payment_event("payment.captured", "order_SomeoneElse01")
    assert webhook(api, other).json() == {"status": "ignored"}


def test_orders_are_private_and_razorpay_down_is_reported(
    api: TestClient, gateway: FakeRazorpay, db_session: Session
) -> None:
    order_id = start(api)["order_id"]
    rz_order = rz_order_of(db_session, order_id)
    other = make_user(db_session, "other@example.com")
    assert (
        api.get(f"/api/v1/billing/web/orders/{order_id}", headers=auth_headers(other))
    ).status_code == 404
    gateway.down = True
    assert api.post("/api/v1/billing/web/orders").status_code == 502
    assert api.get(f"/api/v1/billing/web/orders/{order_id}").status_code == 502
    # The browser still goes back to the app, which asks again later.
    assert callback(api, rz_order).status_code == 303
    # Razorpay retries a webhook that fails.
    assert webhook(api, payment_event("payment.captured", rz_order)).status_code == 502


def test_an_unknown_callback_goes_back_to_the_app(api: TestClient, db_session: Session) -> None:
    back = callback(api, "order_Unknown000001")
    assert back.status_code == 303 and back.headers["location"].endswith("order=")
    failed = api.post(
        "/api/v1/billing/razorpay/callback",
        data={"error[metadata]": '{"order_id": "nonsense"}'},
    )
    assert failed.status_code == 303
    assert db_session.scalar(select(Subscription)) is None


@pytest.mark.parametrize(
    "failure",
    [
        http.client.RemoteDisconnected("closed"),
        ConnectionResetError("reset"),
        TimeoutError("slow"),
        urllib.error.URLError("no route"),
    ],
)
def test_a_dropped_connection_is_razorpay_unreachable(
    failure: Exception, monkeypatch: pytest.MonkeyPatch
) -> None:
    def broken(*args: object, **kwargs: object) -> None:
        raise failure

    monkeypatch.setattr(urllib.request, "urlopen", broken)
    gateway = RazorpayGateway(
        key_id=KEY_ID, key_secret=SECRET, webhook_secret=WEBHOOK_SECRET, environment="staging"
    )
    with pytest.raises(RazorpayError, match="unreachable"):
        gateway.order_payments("order_TEST000000001")


def test_the_gateway_sends_amount_receipt_and_basic_auth(monkeypatch: pytest.MonkeyPatch) -> None:
    seen: dict[str, Any] = {}

    class Answer:
        def __enter__(self) -> "Answer":
            return self

        def __exit__(self, *args: object) -> None:
            return None

        def read(self) -> bytes:
            return b'{"id": "order_FromRazorpay01", "status": "created"}'

    def fake_open(request: urllib.request.Request, timeout: float) -> Answer:
        seen["url"] = request.full_url
        seen["auth"] = request.get_header("Authorization")
        seen["body"] = json.loads(request.data or b"{}")  # type: ignore[arg-type]
        return Answer()

    monkeypatch.setattr(urllib.request, "urlopen", fake_open)
    gateway = RazorpayGateway(
        key_id=KEY_ID, key_secret=SECRET, webhook_secret=WEBHOOK_SECRET, environment="staging"
    )
    receipt = paytm.new_order_id()
    assert gateway.create_order(9900, receipt) == "order_FromRazorpay01"
    assert seen["url"] == "https://api.razorpay.com/v1/orders"
    assert seen["auth"].startswith("Basic ")
    assert seen["body"]["amount"] == 9900 and seen["body"]["currency"] == "INR"
    assert seen["body"]["receipt"] == receipt and len(receipt) <= 40
