"""Plus bought on the website with Paytm: checksums as Paytm's own library makes them, orders
priced by the server, Plus given only on Paytm's status answer (once), refunds taken back."""

import http.client
import re
import urllib.error
import urllib.request
import uuid
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
from app.domain import paytm
from app.integrations.paytm import PaytmError, PaytmGateway
from app.integrations.storage import LocalDocumentStorage
from app.main import create_app
from app.models.plus import BillingEvent, Subscription, WebPayment
from app.models.user import User
from tests.conftest import auth_headers, make_user

KEY = "TESTKEY123456789"  # made up, 16 characters
MID = "TESTMID0000000000001"
RETURN = "https://app.example.test/#/profile/plus/paytm?order={order}"
NOW = datetime.now(UTC)

# Made with Paytm's own library (paytmchecksum 1.7.0, github.com/paytm/Paytm_Python_Checksum).
BODY = (
    '{"requestType":"Payment","mid":"TESTMID0000000000001","websiteName":"WEBSTAGING",'
    '"orderId":"PLUS-0123456789abcdef0123456789abcdef","txnAmount":{"value":"99.00",'
    '"currency":"INR"},"userInfo":{"custId":"CUST_1"},'
    '"callbackUrl":"https://api.example.test/api/v1/billing/paytm/callback"}'
)
BODY_SALT_AB12 = (
    "H48riK8NrzEmf6ljgOlDJYq5kFcv1QFCd+AtEWgLrSlxiXFPz0Wr2SHvpb5m63avl2PAInJZ7mlE4uoznNFPZr/"
    "TUlmfVEbZ0dlgo0e3wr0="
)
FORM = {
    "MID": MID,
    "ORDERID": "PLUS-1",
    "TXNAMOUNT": "99.00",
    "STATUS": "TXN_SUCCESS",
    "BANKTXNID": "null",
    "TXNID": "2026111000000001",
    "RESPCODE": "01",
    "CURRENCY": "INR",
}
FORM_JOINED = "|INR|TESTMID0000000000001|PLUS-1|01|TXN_SUCCESS|99.00|2026111000000001"
FORM_SALT_ZZ90 = (
    "wlkrEl/yEaD6tDNzvzJvAESk1ALxtNph201l/DmwghVOXbAO1Uwhg4xHSMK05fcGyt0iwi5x05FCKPbqWEFmbvmRLU"
    "bZOkNH9MkE1bzIzp4="
)
FORM_SIGNED = (
    "F93enMj+/b3O8K0hnZb30k4NRSNRALqAYsiRYMj8+ZKCut/OGPnNt5I3HrIHej97E0ml+hn5wGqATn+kn3nAkPyaIo9L"
    "lz8M4vPLqOoz0S8="
)


# --- checksums and rules -----------------------------------------------------------------


def test_checksums_match_paytms_library() -> None:
    assert paytm.checksum(BODY, KEY, salt="ab12") == BODY_SALT_AB12
    assert paytm.joined(FORM) == FORM_JOINED
    assert paytm.checksum(FORM_JOINED, KEY, salt="Zz90") == FORM_SALT_ZZ90
    assert paytm.form_valid({**FORM, "CHECKSUMHASH": FORM_SIGNED}, KEY)
    assert paytm.checksum_valid(BODY, KEY, paytm.checksum(BODY, KEY))  # random salt


def test_a_changed_value_or_another_key_fails_the_checksum() -> None:
    signed = {**FORM, "CHECKSUMHASH": FORM_SIGNED}
    assert not paytm.form_valid({**signed, "TXNAMOUNT": "1.00"}, KEY)
    assert not paytm.form_valid(signed, "OTHERKEY12345678")
    assert not paytm.form_valid(FORM, KEY)  # no checksum at all
    assert not paytm.checksum_valid(BODY, KEY, "not base64!")
    assert not paytm.checksum_valid(BODY, KEY, "AAAA")


def status_answer(
    result: str = "TXN_SUCCESS",
    *,
    order_id: str,
    amount: str = "99.00",
    mid: str = MID,
    refund: str | None = None,
    code: str = "01",
) -> dict[str, Any]:
    body: dict[str, Any] = {
        "resultInfo": {"resultStatus": result, "resultCode": code, "resultMsg": "x"},
        "mid": mid,
        "orderId": order_id,
        "txnAmount": amount,
        "txnId": "2026111000000001",
        "paymentMode": "UPI",
    }
    if refund is not None:
        body["refundAmt"] = refund
    return {"head": {"signature": "s"}, "body": body}


def refund_answer(
    result: str = "TXN_SUCCESS",
    *,
    order_id: str,
    total: str = "99.00",
    mid: str = MID,
) -> dict[str, Any]:
    return {
        "head": {"signature": "s"},
        "body": {
            "resultInfo": {"resultStatus": result, "resultCode": "10", "resultMsg": "x"},
            "mid": mid,
            "orderId": order_id,
            "refId": "REF-1",
            "txnAmount": "99.00",
            "refundAmount": total,
            "totalRefundAmount": total,
        },
    }


def test_only_a_full_confirmed_refund_counts() -> None:
    order = paytm.new_order_id()

    def out(data: dict[str, Any]) -> str:
        return paytm.refund_outcome(data, mid=MID, order_id=order, amount_paise=9900)

    assert out(refund_answer(order_id=order)) == "refunded"
    assert out(refund_answer(order_id=order, total="50.00")) == "partial"
    assert out(refund_answer("PENDING", order_id=order)) == "pending"
    assert out(refund_answer("TXN_FAILURE", order_id=order)) == "failed"
    assert out(refund_answer("NO_RECORD_FOUND", order_id=order)) == "failed"
    assert out(refund_answer(order_id=order, mid="OTHER")) == "mismatch"
    assert out(refund_answer(order_id=paytm.new_order_id())) == "mismatch"
    assert out({}) == "pending"


def test_only_a_matching_success_counts() -> None:
    order = paytm.new_order_id()

    def out(data: dict[str, Any]) -> str:
        return paytm.outcome(paytm.read_status(data), mid=MID, order_id=order, amount_paise=9900)

    assert out(status_answer(order_id=order)) == "success"
    assert out(status_answer(order_id=order, amount="1.00")) == "mismatch"
    assert out(status_answer(order_id=order, mid="OTHER")) == "mismatch"
    assert out(status_answer(order_id=paytm.new_order_id())) == "mismatch"
    assert out(status_answer("PENDING", order_id=order, code="402")) == "pending"
    assert out(status_answer("TXN_FAILURE", order_id=order, code="227")) == "failed"
    assert out(status_answer("NO_RECORD_FOUND", order_id=order, code="331")) == "unpaid"
    assert out(status_answer("SOMETHING_NEW", order_id=order)) == "pending"
    assert out(status_answer(order_id=order, refund="99.00")) == "refunded"
    assert out(status_answer(order_id=order, refund="10.00")) == "success"  # partial refund
    assert out({}) == "pending"


def test_amounts_orders_windows_and_links() -> None:
    assert paytm.rupees(9900) == "99.00"
    assert paytm.paise("99.00") == 9900 and paytm.paise(Decimal("99")) == 9900
    assert paytm.paise("abc") is None and paytm.paise("-1") is None
    order = paytm.new_order_id()
    assert paytm.order_id_valid(order) and len(order) <= 50
    assert not paytm.order_id_valid("PLUS-1") and not paytm.order_id_valid("X" + order[1:])
    start, until = paytm.granted_window(NOW, None, 30)
    assert (start, until) == (NOW, NOW + timedelta(days=30))
    later = NOW + timedelta(days=5)
    assert paytm.granted_window(NOW, later, 30) == (later, later + timedelta(days=30))
    assert paytm.granted_window(NOW, NOW - timedelta(days=1), 30)[0] == NOW
    key = b"k" * 32
    expires = int(NOW.timestamp()) + 60
    sig = paytm.link_signature(order, expires, key)
    assert paytm.link_valid(order, expires, sig, key, NOW)
    assert not paytm.link_valid(order, expires, sig, key, NOW + timedelta(minutes=2))
    assert not paytm.link_valid(order, expires + 1, sig, key, NOW)


def test_settings_keep_test_and_real_money_apart(settings: Settings) -> None:
    configured = paytm_settings(settings)
    assert configured.paytm_configured
    with pytest.raises(ValidationError, match="production server only"):
        Settings.model_validate({**configured.model_dump(), "paytm_environment": "production"})
    with pytest.raises(ValidationError, match="16, 24 or 32"):
        Settings.model_validate(
            {**configured.model_dump(), "paytm_merchant_key": SecretStr("short")}
        )
    assert not settings.paytm_configured  # nothing set: paying on the website is off
    assert configured.environment is Environment.TEST


# --- the website flow --------------------------------------------------------------------


class FakePaytm:
    """Paytm's initiate and status APIs, with what each order's status answer will be."""

    mid = MID
    environment: paytm.Environment = "staging"

    def __init__(self) -> None:
        self.answers: dict[str, dict[str, Any]] = {}
        self.refunds: dict[tuple[str, str], dict[str, Any]] = {}
        self.refund_calls: list[tuple[str, str]] = []
        self.initiated: list[tuple[str, str, str, str]] = []
        self.status_calls = 0
        self.down = False

    def initiate(self, order_id: str, amount: str, customer_id: str, callback_url: str) -> str:
        if self.down:
            raise PaytmError("unreachable")
        self.initiated.append((order_id, amount, customer_id, callback_url))
        return "txn-token-" + order_id[-6:]

    def status(self, order_id: str) -> dict[str, Any]:
        self.status_calls += 1
        if self.down:
            raise PaytmError("unreachable")
        return self.answers.get(
            order_id, status_answer("NO_RECORD_FOUND", order_id=order_id, code="331")
        )

    def refund_status(self, order_id: str, ref_id: str) -> dict[str, Any]:
        self.refund_calls.append((order_id, ref_id))
        if self.down:
            raise PaytmError("unreachable")
        return self.refunds.get(
            (order_id, ref_id), refund_answer("NO_RECORD_FOUND", order_id=order_id)
        )

    def payment_page_url(self, order_id: str) -> str:
        return f"https://securestage.paytmpayments.com/theia/api/v1/showPaymentPage?mid={MID}&orderId={order_id}"

    def checksum_valid(self, form: dict[str, str]) -> bool:
        return paytm.form_valid(form, KEY)


def paytm_settings(settings: Settings) -> Settings:
    return settings.model_copy(
        update={
            "paytm_mid": MID,
            "paytm_merchant_key": SecretStr(KEY),
            "paytm_plus_price": Decimal("99.00"),
            "paytm_plus_days": 30,
            "paytm_callback_url": "https://api.example.test/api/v1/billing/paytm/callback",
            "paytm_return_url": RETURN,
        }
    )


@pytest.fixture
def gateway() -> FakePaytm:
    return FakePaytm()


@pytest.fixture
def api(
    settings: Settings,
    db_engine: Any,
    db_session: Session,
    storage: LocalDocumentStorage,
    user: User,
    gateway: FakePaytm,
) -> Iterator[TestClient]:
    app = create_app(paytm_settings(settings), engine=db_engine, storage=storage, paytm=gateway)
    app.dependency_overrides[get_session] = lambda: db_session
    with TestClient(app, raise_server_exceptions=False, follow_redirects=False) as client:
        client.headers.update(auth_headers(user))
        yield client


def start(api: TestClient) -> dict[str, Any]:
    response = api.post("/api/v1/billing/paytm/orders")
    assert response.status_code == 201, response.text
    body: dict[str, Any] = response.json()
    return body


def callback(api: TestClient, order_id: str, **extra: str) -> Any:
    form = {**FORM, "ORDERID": order_id, **extra}
    form["CHECKSUMHASH"] = paytm.checksum(paytm.joined(form), KEY)
    return api.post("/api/v1/billing/paytm/callback", data=form)


def plus(api: TestClient) -> dict[str, Any]:
    body: dict[str, Any] = api.get("/api/v1/me/plus").json()
    return body


def test_the_offer_shows_only_when_paytm_is_set_up(api: TestClient, db_client: TestClient) -> None:
    offer = plus(api)["web_offer"]
    assert offer == {
        "provider": "paytm",
        "amount_paise": 9900,
        "currency": "INR",
        "days": 30,
        "test_payments": True,
    }
    assert db_client.get("/api/v1/me/plus").json()["web_offer"] is None
    assert db_client.post("/api/v1/billing/paytm/orders").status_code == 503


def test_an_order_is_priced_by_the_server_and_opens_paytms_page(
    api: TestClient, gateway: FakePaytm, db_session: Session, user: User
) -> None:
    order = start(api)
    assert order["amount_paise"] == 9900 and order["days"] == 30
    assert gateway.initiated[0][1:] == (
        "99.00",
        f"CUST_{user.id.hex}",
        "https://api.example.test/api/v1/billing/paytm/callback",
    )
    row = db_session.scalar(select(WebPayment).where(WebPayment.order_id == order["order_id"]))
    assert row is not None and row.status == "created" and row.environment == "staging"
    page = api.get(order["pay_path"], headers={"Authorization": ""})  # the browser has no token
    assert page.status_code == 200
    assert "showPaymentPage" in page.text and str(row.txn_token) in page.text
    assert page.headers["cache-control"] == "no-store"
    tampered = re.sub(r"s=\w+", "s=" + "0" * 32, order["pay_path"])
    assert api.get(tampered).status_code == 404


def test_paying_turns_plus_on_once(
    api: TestClient, gateway: FakePaytm, db_session: Session
) -> None:
    order_id = start(api)["order_id"]
    gateway.answers[order_id] = status_answer(order_id=order_id)
    back = callback(api, order_id)
    assert back.status_code == 303
    assert back.headers["location"] == RETURN.replace("{order}", order_id)
    status = plus(api)
    assert status["active"] and status["source"] == "web"
    until = datetime.fromisoformat(status["active_until"])
    assert timedelta(days=29, hours=23) < until - datetime.now(UTC) <= timedelta(days=30)
    # The same news again (webhook, refresh, a second callback) adds nothing.
    callback(api, order_id)
    api.post("/api/v1/billing/paytm/webhook", json={"body": {"orderId": order_id}})
    assert plus(api)["active_until"] == status["active_until"]
    read = api.get(f"/api/v1/billing/paytm/orders/{order_id}").json()
    assert read["status"] == "success" and read["test_payment"] is True
    events = db_session.scalars(select(BillingEvent).where(BillingEvent.provider == "paytm")).all()
    assert {e.kind for e in events} == {"order", "callback", "webhook"}
    assert all(order_id not in (e.detail + (e.token_hash or "")) for e in events)


def test_paying_again_adds_after_the_current_end(api: TestClient, gateway: FakePaytm) -> None:
    for _ in range(2):
        order_id = start(api)["order_id"]
        gateway.answers[order_id] = status_answer(order_id=order_id)
        callback(api, order_id)
    until = datetime.fromisoformat(plus(api)["active_until"])
    assert timedelta(days=59, hours=23) < until - datetime.now(UTC) <= timedelta(days=60)


def test_the_callback_form_itself_is_never_believed(
    api: TestClient, gateway: FakePaytm, db_session: Session
) -> None:
    order_id = start(api)["order_id"]
    # The form says success, Paytm's status API has no payment: nothing happens.
    callback(api, order_id)
    assert not plus(api)["active"]
    # Paytm says paid, but not this amount: refused and recorded.
    gateway.answers[order_id] = status_answer(order_id=order_id, amount="1.00")
    callback(api, order_id, TXNAMOUNT="1.00")
    assert not plus(api)["active"]
    refused = db_session.scalars(
        select(BillingEvent).where(BillingEvent.outcome == "refused")
    ).all()
    assert len(refused) == 1 and refused[0].detail.startswith("mismatch")
    # A forged form with a bad checksum is noted, but the status answer still decides.
    gateway.answers[order_id] = status_answer(order_id=order_id)
    form = {**FORM, "ORDERID": order_id, "CHECKSUMHASH": FORM_SIGNED}
    api.post("/api/v1/billing/paytm/callback", data=form)
    assert plus(api)["active"]
    last = db_session.scalars(select(BillingEvent).where(BillingEvent.kind == "callback")).all()[-1]
    assert "checksum_failed" in last.detail


def test_pending_then_paid_is_found_when_the_app_asks(api: TestClient, gateway: FakePaytm) -> None:
    order_id = start(api)["order_id"]
    gateway.answers[order_id] = status_answer("PENDING", order_id=order_id, code="402")
    callback(api, order_id)
    assert api.get(f"/api/v1/billing/paytm/orders/{order_id}").json()["status"] == "pending"
    gateway.answers[order_id] = status_answer(order_id=order_id)
    assert api.get(f"/api/v1/billing/paytm/orders/{order_id}").json()["status"] == "success"
    assert plus(api)["active"]


def test_a_failed_payment_is_final(api: TestClient, gateway: FakePaytm) -> None:
    order_id = start(api)["order_id"]
    gateway.answers[order_id] = status_answer("TXN_FAILURE", order_id=order_id, code="227")
    callback(api, order_id)
    calls = gateway.status_calls
    assert api.get(f"/api/v1/billing/paytm/orders/{order_id}").json()["status"] == "failed"
    assert gateway.status_calls == calls  # settled: Paytm isn't asked again
    assert not plus(api)["active"]
    assert api.get(start(api)["pay_path"]).status_code == 200  # a new order works


def test_a_full_refund_takes_the_days_back(api: TestClient, gateway: FakePaytm) -> None:
    order_id = start(api)["order_id"]
    gateway.answers[order_id] = status_answer(order_id=order_id)
    callback(api, order_id)
    gateway.answers[order_id] = status_answer(order_id=order_id, refund="99.00")
    api.post("/api/v1/billing/paytm/webhook", data={"ORDERID": order_id})
    assert not plus(api)["active"]
    assert api.get(f"/api/v1/billing/paytm/orders/{order_id}").json()["status"] == "refunded"


def test_orders_are_private_and_paytm_down_is_reported(
    api: TestClient, gateway: FakePaytm, db_session: Session
) -> None:
    order_id = start(api)["order_id"]
    other = make_user(db_session, "other@example.com")
    assert (
        api.get(f"/api/v1/billing/paytm/orders/{order_id}", headers=auth_headers(other))
    ).status_code == 404
    gateway.down = True
    assert api.post("/api/v1/billing/paytm/orders").status_code == 502
    assert api.get(f"/api/v1/billing/paytm/orders/{order_id}").status_code == 502
    # The browser still goes back to the app, which asks again later.
    assert callback(api, order_id).status_code == 303
    assert api.post("/api/v1/billing/paytm/webhook", data={"ORDERID": "nonsense"}).json() == {
        "status": "ignored"
    }
    count = db_session.scalar(select(WebPayment.id).where(WebPayment.order_id == order_id))
    assert count is not None


def test_too_many_orders_are_refused(api: TestClient, db_session: Session, user: User) -> None:
    for _ in range(10):
        db_session.add(
            WebPayment(
                owner_id=user.id,
                environment="staging",
                order_id=paytm.new_order_id(),
                amount_paise=9900,
                days=30,
            )
        )
    db_session.flush()
    assert api.post("/api/v1/billing/paytm/orders").status_code == 429


def test_an_unknown_order_changes_nothing(api: TestClient, db_session: Session) -> None:
    order_id = paytm.new_order_id()
    assert callback(api, order_id).status_code == 303
    assert db_session.scalar(select(Subscription)) is None
    event = db_session.scalars(select(BillingEvent)).all()[-1]
    assert event.outcome == "unknown_token" and event.owner_id is None
    assert uuid.UUID(int=0) != event.id


@pytest.mark.parametrize(
    "failure",
    [
        http.client.RemoteDisconnected("closed"),
        ConnectionResetError("reset"),
        TimeoutError("slow"),
        urllib.error.URLError("no route"),
        http.client.IncompleteRead(b""),
    ],
)
def test_a_dropped_connection_is_paytm_unreachable(
    failure: Exception, monkeypatch: pytest.MonkeyPatch
) -> None:
    def broken(*args: object, **kwargs: object) -> None:
        raise failure

    monkeypatch.setattr(urllib.request, "urlopen", broken)
    gateway = PaytmGateway(
        mid=MID, merchant_key=KEY, website_name="WEBSTAGING", environment="staging"
    )
    with pytest.raises(PaytmError, match="unreachable"):
        gateway.status(paytm.new_order_id())


def refund_notice(api: TestClient, order_id: str, ref_id: str | None = "REF-1") -> Any:
    body: dict[str, Any] = {"orderId": order_id, "refundAmount": "99.00", "status": "SUCCESS"}
    if ref_id:
        body["refId"] = ref_id
    return api.post(
        "/api/v1/billing/paytm/refund-webhook", json={"head": {"signature": "s"}, "body": body}
    )


def paid_order(api: TestClient, gateway: FakePaytm) -> str:
    order_id: str = start(api)["order_id"]
    gateway.answers[order_id] = status_answer(order_id=order_id)
    callback(api, order_id)
    assert plus(api)["active"]
    return order_id


def test_a_refund_notice_is_checked_with_paytm_before_days_go(
    api: TestClient, gateway: FakePaytm, db_session: Session
) -> None:
    order_id = paid_order(api, gateway)
    # The notice alone changes nothing: Paytm knows no such refund.
    assert refund_notice(api, order_id).json() == {"status": "ok"}
    assert plus(api)["active"]
    # A partial refund keeps the days.
    gateway.refunds[(order_id, "REF-1")] = refund_answer(order_id=order_id, total="50.00")
    refund_notice(api, order_id)
    assert plus(api)["active"]
    # Paytm confirms the whole amount: the days go, once.
    gateway.refunds[(order_id, "REF-1")] = refund_answer(order_id=order_id)
    refund_notice(api, order_id)
    assert not plus(api)["active"]
    assert api.get(f"/api/v1/billing/paytm/orders/{order_id}").json()["status"] == "refunded"
    calls = len(gateway.refund_calls)
    refund_notice(api, order_id)
    assert len(gateway.refund_calls) == calls  # settled: Paytm isn't asked again
    details = [
        e.detail
        for e in db_session.scalars(
            select(BillingEvent).where(BillingEvent.detail.like("refund%"))
        ).all()
    ]
    assert details == ["refund failed", "refund partial", "refund refunded"]


def test_a_refund_for_another_merchant_is_refused(
    api: TestClient, gateway: FakePaytm, db_session: Session
) -> None:
    order_id = paid_order(api, gateway)
    gateway.refunds[(order_id, "REF-1")] = refund_answer(order_id=order_id, mid="OTHER")
    refund_notice(api, order_id)
    assert plus(api)["active"]
    refused = db_session.scalars(
        select(BillingEvent).where(BillingEvent.outcome == "refused")
    ).all()
    assert [e.detail for e in refused] == ["refund mismatch"]


def test_a_refund_notice_without_a_reference_asks_the_order_status(
    api: TestClient, gateway: FakePaytm
) -> None:
    order_id = paid_order(api, gateway)
    gateway.answers[order_id] = status_answer(order_id=order_id, refund="99.00")
    refund_notice(api, order_id, ref_id=None)
    assert not plus(api)["active"]
    assert gateway.refund_calls == []


def test_refund_notices_for_unknown_orders_or_while_paytm_is_down(
    api: TestClient, gateway: FakePaytm
) -> None:
    assert refund_notice(api, "ORDERID_98765").json() == {"status": "ignored"}
    assert refund_notice(api, paytm.new_order_id()).json() == {"status": "ok"}
    order_id = paid_order(api, gateway)
    gateway.down = True
    assert refund_notice(api, order_id).status_code == 502  # Paytm sends it again later
    gateway.down = False
    assert plus(api)["active"]
