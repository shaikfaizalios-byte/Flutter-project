"""Request-ID and request logging middleware (pure ASGI, so it also wraps error responses)."""

import logging
import re
import time
import uuid

from starlette.datastructures import MutableHeaders
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.core.logging import request_id_var
from app.core.metrics import RequestMetrics, route_label

REQUEST_ID_HEADER = "X-Request-ID"
# Accept a caller-supplied ID only if it is short and safe to log.
_VALID_REQUEST_ID = re.compile(r"^[A-Za-z0-9._-]{1,64}$")

logger = logging.getLogger("app.request")


class RequestContextMiddleware:
    def __init__(self, app: ASGIApp, metrics: RequestMetrics | None = None) -> None:
        self.app = app
        self.metrics = metrics

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        incoming = None
        for name, value in scope.get("headers", []):
            if name.decode("latin-1").lower() == REQUEST_ID_HEADER.lower():
                incoming = value.decode("latin-1")
                break
        request_id = (
            incoming if incoming and _VALID_REQUEST_ID.match(incoming) else uuid.uuid4().hex
        )
        token = request_id_var.set(request_id)
        scope.setdefault("state", {})["request_id"] = request_id

        status_code = 500
        started = time.perf_counter()

        async def send_wrapper(message: Message) -> None:
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
                MutableHeaders(scope=message)[REQUEST_ID_HEADER] = request_id
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        finally:
            elapsed = time.perf_counter() - started
            if self.metrics is not None:
                route = route_label(str(scope.get("path"))) if scope.get("route") else "unmatched"
                self.metrics.record(str(scope.get("method")), route, status_code, elapsed)
            logger.info(
                "request completed",
                extra={
                    "fields": {
                        "method": scope.get("method"),
                        # Path only: query strings may carry user data.
                        "path": scope.get("path"),
                        "status": status_code,
                        "duration_ms": round(elapsed * 1000, 2),
                    }
                },
            )
            request_id_var.reset(token)
