"""Purchases for PrepLoop Plus: Google Play in the app, Paytm or Razorpay on the website
(docs/plus.md)."""

import html
import json
import logging
from typing import Annotated, Any

from fastapi import APIRouter, Body, Depends, Request, Response, status
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy import select

from app.api.deps import CurrentUser
from app.api.v1.endpoints.plus import Service as PlusServiceDep
from app.api.v1.endpoints.plus import (
    billing_service,
    razorpay_billing_service,
    web_billing_service,
)
from app.core.config import Settings, get_settings
from app.database.session import DbSession
from app.domain import paytm, razorpay
from app.domain.errors import NotFoundError, StoreUnavailableError, UnauthorizedError
from app.integrations.play_billing import PlayBillingError
from app.models.plus import WebPayment
from app.schemas.errors import ErrorResponse
from app.schemas.plus import PlayPurchaseVerify, PlusStatus, WebOrderCreated, WebOrderRead

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/billing",
    tags=["billing"],
    responses={503: {"model": ErrorResponse, "description": "Purchases not available"}},
)


@router.post(
    "/play/verify",
    response_model=PlusStatus,
    responses={
        422: {"model": ErrorResponse, "description": "Purchase refused"},
        502: {"model": ErrorResponse, "description": "Google Play unreachable"},
    },
    summary="Add a Google Play purchase to your account (checked with Google first)",
)
def verify_play_purchase(
    body: PlayPurchaseVerify,
    request: Request,
    session: DbSession,
    user: CurrentUser,
    settings: Annotated[Settings, Depends(get_settings)],
    plus: PlusServiceDep,
) -> PlusStatus:
    billing_service(request, session, settings).verify_play(
        user.id, body.product_id, body.purchase_token
    )
    return plus.status()


@router.post(
    "/play/rtdn",
    status_code=status.HTTP_204_NO_CONTENT,
    include_in_schema=False,  # called by Google Pub/Sub only
)
def play_notification(
    request: Request,
    session: DbSession,
    settings: Annotated[Settings, Depends(get_settings)],
    body: Annotated[dict[str, Any], Body()],
) -> Response:
    verifier = request.app.state.play_push_verifier
    if verifier is None:
        raise UnauthorizedError("Notifications are not accepted on this server.")
    try:
        verifier.verify(request.headers.get("authorization"))
    except PlayBillingError as exc:
        logger.warning("Play notification refused: %s", exc.reason)
        raise UnauthorizedError("Not a valid Google push request.") from exc
    billing_service(request, session, settings).handle_notification(body)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


def _return_to(settings: Settings, order_id: str) -> RedirectResponse:
    target = (settings.paytm_return_url or "/").replace("{order}", order_id)
    return RedirectResponse(target, status_code=status.HTTP_303_SEE_OTHER)


def _order_read(payment: WebPayment) -> WebOrderRead:
    return WebOrderRead(
        order_id=payment.order_id,
        status=payment.status,
        amount_paise=payment.amount_paise,
        days=payment.days,
        granted_until=payment.granted_until,
        test_payment=payment.environment != "production",
    )


@router.post(
    "/paytm/orders",
    response_model=WebOrderCreated,
    status_code=status.HTTP_201_CREATED,
    responses={
        429: {"model": ErrorResponse, "description": "Too many payment attempts"},
        502: {"model": ErrorResponse, "description": "Paytm unreachable"},
    },
    summary="Start paying for PrepLoop Plus on the website (Paytm)",
    deprecated=True,  # use /billing/web/orders
)
def create_paytm_order(
    request: Request,
    session: DbSession,
    user: CurrentUser,
    settings: Annotated[Settings, Depends(get_settings)],
) -> WebOrderCreated:
    order = web_billing_service(request, session, settings).create_order(user.id)
    return WebOrderCreated(
        order_id=order.order_id,
        pay_path=order.pay_path,
        amount_paise=order.amount_paise,
        days=order.days,
    )


@router.get(
    "/paytm/orders/{order_id}",
    response_model=WebOrderRead,
    responses={
        404: {"model": ErrorResponse, "description": "Not your order"},
        502: {"model": ErrorResponse, "description": "Paytm unreachable"},
    },
    summary="Your website payment, checked with Paytm while it is not settled",
    deprecated=True,  # use /billing/web/orders/{order_id}
)
def read_paytm_order(
    order_id: str,
    request: Request,
    session: DbSession,
    user: CurrentUser,
    settings: Annotated[Settings, Depends(get_settings)],
) -> WebOrderRead:
    payment = web_billing_service(request, session, settings).order_for(user.id, order_id)
    return _order_read(payment)


@router.get("/paytm/pay/{order_id}", include_in_schema=False, response_class=HTMLResponse)
def paytm_pay_page(
    order_id: str,
    request: Request,
    session: DbSession,
    settings: Annotated[Settings, Depends(get_settings)],
    e: int = 0,
    s: str = "",
) -> HTMLResponse:
    """Opened by the browser (no access token): sends it on to Paytm's payment page."""
    form = web_billing_service(request, session, settings).pay_form(order_id, e, s)
    fields = "".join(
        f'<input type="hidden" name="{name}" value="{html.escape(value)}">'
        for name, value in (
            ("mid", form.mid),
            ("orderId", form.order_id),
            ("txnToken", form.txn_token),
        )
    )
    page = (
        '<!doctype html><html><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>PrepLoop Plus</title></head><body style="font-family:sans-serif;padding:24px">'
        f'<form id="pay" method="post" action="{html.escape(form.action)}">{fields}'
        "<p>Taking you to Paytm to pay…</p>"
        '<button type="submit">Continue to Paytm</button></form>'
        "<script>document.getElementById('pay').submit();</script></body></html>"
    )
    return HTMLResponse(
        page, headers={"Cache-Control": "no-store", "Referrer-Policy": "no-referrer"}
    )


async def _form_or_json(request: Request) -> dict[str, str]:
    content_type = request.headers.get("content-type", "")
    if content_type.startswith("application/json"):
        try:
            data = await request.json()
        except ValueError:
            return {}
        if isinstance(data, dict) and isinstance(data.get("body"), dict):
            data = data["body"]
        return {str(k): str(v) for k, v in data.items()} if isinstance(data, dict) else {}
    form = await request.form()
    return {k: v for k, v in form.items() if isinstance(v, str)}


def _order_id(values: dict[str, str]) -> str:
    return values.get("ORDERID") or values.get("orderId") or ""


@router.post("/paytm/callback", include_in_schema=False)
async def paytm_callback(
    request: Request,
    session: DbSession,
    settings: Annotated[Settings, Depends(get_settings)],
) -> RedirectResponse:
    """Paytm sends the browser back here after paying (a form post). The result is taken from
    Paytm's status API, never from the form; then the browser goes back to the app."""
    values = await _form_or_json(request)
    order_id = _order_id(values)
    service = web_billing_service(request, session, settings)
    client = request.app.state.paytm
    if client is None or not paytm.order_id_valid(order_id):
        return _return_to(settings, "")
    try:
        await run_in_threadpool(
            service.refresh, order_id, "callback", checksum_ok=client.checksum_valid(values)
        )
    except StoreUnavailableError:
        logger.warning("Paytm status check failed after a callback; the app will ask again")
    return _return_to(settings, order_id)


@router.post("/paytm/webhook", include_in_schema=False)
async def paytm_webhook(
    request: Request,
    session: DbSession,
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict[str, str]:
    """Paytm's payment status webhook: only says which order to ask Paytm about."""
    values = await _form_or_json(request)
    order_id = _order_id(values)
    client = request.app.state.paytm
    if client is None:
        raise UnauthorizedError("Paytm notifications are not accepted on this server.")
    if not paytm.order_id_valid(order_id):
        return {"status": "ignored"}
    await run_in_threadpool(
        web_billing_service(request, session, settings).refresh,
        order_id,
        "webhook",
        checksum_ok=client.checksum_valid(values) if "CHECKSUMHASH" in values else None,
    )
    return {"status": "ok"}


@router.post("/paytm/refund-webhook", include_in_schema=False)
async def paytm_refund_webhook(
    request: Request,
    session: DbSession,
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict[str, str]:
    """Paytm's refund webhooks (refund accepted, refund done): they only say which order and
    refund to ask Paytm about."""
    values = await _form_or_json(request)
    order_id = _order_id(values)
    if request.app.state.paytm is None:
        raise UnauthorizedError("Paytm notifications are not accepted on this server.")
    if not paytm.order_id_valid(order_id):
        return {"status": "ignored"}
    ref_id = values.get("refId") or values.get("REFID") or None
    await run_in_threadpool(
        web_billing_service(request, session, settings).refund_notice, order_id, ref_id
    )
    return {"status": "ok"}


# --- the website, whichever provider this server uses ---------------------------------------


@router.post(
    "/web/orders",
    response_model=WebOrderCreated,
    status_code=status.HTTP_201_CREATED,
    responses={
        429: {"model": ErrorResponse, "description": "Too many payment attempts"},
        502: {"model": ErrorResponse, "description": "Payment provider unreachable"},
    },
    summary="Start paying for PrepLoop Plus on the website (the provider in web_offer)",
)
def create_web_order(
    request: Request,
    session: DbSession,
    user: CurrentUser,
    settings: Annotated[Settings, Depends(get_settings)],
) -> WebOrderCreated:
    if request.app.state.razorpay is not None:
        order = razorpay_billing_service(request, session, settings).create_order(user.id)
    else:
        order = web_billing_service(request, session, settings).create_order(user.id)
    return WebOrderCreated(
        order_id=order.order_id,
        pay_path=order.pay_path,
        amount_paise=order.amount_paise,
        days=order.days,
    )


@router.get(
    "/web/orders/{order_id}",
    response_model=WebOrderRead,
    responses={
        404: {"model": ErrorResponse, "description": "Not your order"},
        502: {"model": ErrorResponse, "description": "Payment provider unreachable"},
    },
    summary="Your website payment, checked with its provider while it is not settled",
)
def read_web_order(
    order_id: str,
    request: Request,
    session: DbSession,
    user: CurrentUser,
    settings: Annotated[Settings, Depends(get_settings)],
) -> WebOrderRead:
    provider = session.scalar(
        select(WebPayment.provider).where(
            WebPayment.order_id == order_id, WebPayment.owner_id == user.id
        )
    )
    if provider is None:
        raise NotFoundError("Order not found.")
    if provider == "razorpay":
        payment = razorpay_billing_service(request, session, settings).order_for(user.id, order_id)
    else:
        payment = web_billing_service(request, session, settings).order_for(user.id, order_id)
    return _order_read(payment)


# --- Razorpay ---------------------------------------------------------------------------------


def _script_json(value: object) -> str:
    """JSON safe to place inside a <script> element."""
    return json.dumps(value).replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")


@router.get("/razorpay/pay/{order_id}", include_in_schema=False, response_class=HTMLResponse)
def razorpay_pay_page(
    order_id: str,
    request: Request,
    session: DbSession,
    settings: Annotated[Settings, Depends(get_settings)],
    e: int = 0,
    s: str = "",
) -> HTMLResponse:
    """Opened by the browser (no access token): opens Razorpay's checkout for the order.
    After paying, Razorpay posts to our callback; closing the checkout goes back to the app."""
    checkout = razorpay_billing_service(request, session, settings).checkout(order_id, e, s)
    options = {
        "key": checkout.key_id,
        "order_id": checkout.razorpay_order_id,
        "amount": checkout.amount_paise,
        "currency": "INR",
        "name": "PrepLoop",
        "description": "PrepLoop Plus",
        "callback_url": checkout.callback_url,
        "redirect": True,
    }
    back = html.escape(checkout.return_url)
    page = (
        '<!doctype html><html><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>PrepLoop Plus</title></head><body style="font-family:sans-serif;padding:24px">'
        "<p>Opening Razorpay to pay…</p>"
        '<p><button id="pay" type="button">Pay with Razorpay</button></p>'
        f'<p><a href="{back}">Back to PrepLoop</a></p>'
        f'<script src="{razorpay.CHECKOUT_SCRIPT}"></script>'
        "<script>(function(){"
        f"var options={_script_json(options)};var back={_script_json(checkout.return_url)};"
        "options.modal={ondismiss:function(){window.location.href=back;}};"
        "function open(){if(window.Razorpay){new window.Razorpay(options).open();}}"
        "document.getElementById('pay').addEventListener('click',open);open();"
        "})();</script></body></html>"
    )
    return HTMLResponse(
        page, headers={"Cache-Control": "no-store", "Referrer-Policy": "no-referrer"}
    )


def _callback_order(values: dict[str, str]) -> tuple[str, str, str]:
    """(razorpay order id, payment id, signature) from the checkout's form post. A failed
    payment, if posted, names them in error[metadata]."""
    order = values.get("razorpay_order_id", "")
    payment = values.get("razorpay_payment_id", "")
    if not order:
        try:
            meta = json.loads(values.get("error[metadata]", "") or "{}")
        except ValueError:
            meta = {}
        if isinstance(meta, dict):
            order = str(meta.get("order_id") or "")
            payment = payment or str(meta.get("payment_id") or "")
    return order, payment, values.get("razorpay_signature", "")


@router.post("/razorpay/callback", include_in_schema=False)
async def razorpay_callback(
    request: Request,
    session: DbSession,
    settings: Annotated[Settings, Depends(get_settings)],
) -> RedirectResponse:
    """Razorpay's checkout sends the browser here after paying (a form post). The result is taken
    from Razorpay's Orders API, never from the form; then the browser goes back to the app."""
    form = await request.form()
    values = {k: v for k, v in form.items() if isinstance(v, str)}
    service = razorpay_billing_service(request, session, settings)

    def back(order_id: str) -> RedirectResponse:
        return RedirectResponse(service.return_url(order_id), status_code=status.HTTP_303_SEE_OTHER)

    if request.app.state.razorpay is None:
        return back("")
    rz_order, payment_id, signature = _callback_order(values)
    order_id = await run_in_threadpool(service.order_id_for, rz_order)
    if order_id is None:
        return back("")
    signature_ok = service.signature_valid(rz_order, payment_id, signature) if signature else None
    try:
        await run_in_threadpool(service.refresh, order_id, "callback", signature_ok=signature_ok)
    except StoreUnavailableError:
        logger.warning("Razorpay check failed after a callback; the app will ask again")
    return back(order_id)


@router.post("/razorpay/webhook", include_in_schema=False)
async def razorpay_webhook(
    request: Request,
    session: DbSession,
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict[str, str]:
    """Razorpay's webhooks (payment, order and refund events). Signed with the webhook secret;
    they only say which order to ask Razorpay about."""
    client = request.app.state.razorpay
    if client is None:
        raise UnauthorizedError("Razorpay notifications are not accepted on this server.")
    body = await request.body()
    if not client.webhook_valid(body, request.headers.get("x-razorpay-signature")):
        raise UnauthorizedError("Not a valid Razorpay webhook.")
    try:
        event = json.loads(body)
    except ValueError:
        return {"status": "ignored"}
    rz_order = razorpay.webhook_order_id(event) if isinstance(event, dict) else None
    service = razorpay_billing_service(request, session, settings)
    order_id = await run_in_threadpool(service.order_id_for, rz_order) if rz_order else None
    if order_id is None:
        return {"status": "ignored"}
    await run_in_threadpool(service.refresh, order_id, "webhook")
    return {"status": "ok"}
