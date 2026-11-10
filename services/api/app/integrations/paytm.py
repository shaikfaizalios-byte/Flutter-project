"""Paytm Payment Gateway: Initiate Transaction and Transaction Status APIs (docs/plus.md "Paytm").

Requests are signed with the merchant key (app/domain/paytm.py). Standard library only. The key,
transaction tokens and payment details are never logged.
"""

import json
import logging
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import Any, Protocol

from app.core.config import Settings
from app.domain import paytm

logger = logging.getLogger(__name__)

TIMEOUT_SECONDS = 20


class PaytmError(Exception):
    """Paytm could not be reached, or refused the request."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


class PaytmClient(Protocol):
    mid: str
    environment: paytm.Environment

    def initiate(self, order_id: str, amount: str, customer_id: str, callback_url: str) -> str:
        """Creates the transaction at Paytm; returns the token that opens its payment page."""
        ...

    def status(self, order_id: str) -> dict[str, Any]:
        """The Transaction Status API answer for an order."""
        ...

    def payment_page_url(self, order_id: str) -> str:
        """Where the browser posts mid, orderId and txnToken to show Paytm's payment page."""
        ...

    def checksum_valid(self, form: dict[str, str]) -> bool:
        """Whether a callback or webhook form carries Paytm's checksum for these values."""
        ...


@dataclass
class PaytmGateway:
    mid: str
    merchant_key: str = field(repr=False)
    website_name: str
    environment: paytm.Environment

    @property
    def _hosts(self) -> tuple[str, str]:
        return paytm.HOSTS[self.environment]

    def initiate(self, order_id: str, amount: str, customer_id: str, callback_url: str) -> str:
        body = {
            "requestType": "Payment",
            "mid": self.mid,
            "websiteName": self.website_name,
            "orderId": order_id,
            "txnAmount": {"value": amount, "currency": "INR"},
            "userInfo": {"custId": customer_id},
            "callbackUrl": callback_url,
        }
        query = urllib.parse.urlencode({"mid": self.mid, "orderId": order_id})
        data = self._post(f"{self._hosts[0]}/theia/api/v1/initiateTransaction?{query}", body)
        result = (data.get("body") or {}).get("resultInfo") or {}
        token = (data.get("body") or {}).get("txnToken")
        if result.get("resultStatus") != "S" or not isinstance(token, str) or not token:
            raise PaytmError(f"initiate refused: {result.get('resultCode', '?')}")
        return token

    def status(self, order_id: str) -> dict[str, Any]:
        return self._post(
            f"{self._hosts[1]}/v3/order/status", {"mid": self.mid, "orderId": order_id}
        )

    def payment_page_url(self, order_id: str) -> str:
        query = urllib.parse.urlencode({"mid": self.mid, "orderId": order_id})
        return f"{self._hosts[0]}/theia/api/v1/showPaymentPage?{query}"

    def checksum_valid(self, form: dict[str, str]) -> bool:
        return paytm.form_valid(form, self.merchant_key)

    def _post(self, url: str, body: dict[str, Any]) -> dict[str, Any]:
        # Paytm signs the body exactly as sent, so it is serialised once and reused.
        text = json.dumps(body, separators=(",", ":"))
        signature = paytm.checksum(text, self.merchant_key)
        payload = f'{{"body":{text},"head":{{"signature":"{signature}"}}}}'.encode()
        request = urllib.request.Request(  # noqa: S310 - fixed https Paytm URL
            url, data=payload, method="POST", headers={"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:  # noqa: S310
                data = json.loads(response.read())
        except urllib.error.HTTPError as exc:
            raise PaytmError(f"HTTP {exc.code}") from exc
        except (urllib.error.URLError, TimeoutError, ValueError) as exc:
            raise PaytmError("unreachable") from exc
        if not isinstance(data, dict):
            raise PaytmError("unexpected answer")
        return data


def paytm_client_from_settings(settings: Settings) -> PaytmClient | None:
    if not settings.paytm_configured or not settings.paytm_mid or not settings.paytm_merchant_key:
        return None
    environment = settings.paytm_environment
    return PaytmGateway(
        mid=settings.paytm_mid,
        merchant_key=settings.paytm_merchant_key.get_secret_value(),
        website_name=settings.paytm_website_name or paytm.DEFAULT_WEBSITE[environment],
        environment=environment,
    )
