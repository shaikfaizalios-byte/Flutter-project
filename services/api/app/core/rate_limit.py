"""A small in-process sliding-window rate limiter for expensive endpoints.

Limits are per API process. Behind several workers or instances, the effective limit
multiplies; a shared store (e.g. Redis) replaces this before horizontal scaling
(see docs/security.md)."""

import math
import threading
import time
from collections import deque
from collections.abc import Callable

from app.domain.errors import RateLimitedError


class SlidingWindowRateLimiter:
    def __init__(
        self,
        limit: int,
        window_seconds: float,
        clock: Callable[[], float] = time.monotonic,
        message: str = "Too many uploads. Please try again later.",
    ) -> None:
        self._message = message
        self._limit = limit
        self._window = window_seconds
        self._clock = clock
        self._hits: dict[str, deque[float]] = {}
        self._lock = threading.Lock()

    def check(self, key: str) -> None:
        """Record a hit for ``key`` or raise ``RateLimitedError`` if over the limit."""
        now = self._clock()
        with self._lock:
            hits = self._hits.setdefault(key, deque())
            while hits and hits[0] <= now - self._window:
                hits.popleft()
            if len(hits) >= self._limit:
                retry_after = math.ceil(hits[0] + self._window - now)
                raise RateLimitedError(self._message, max(retry_after, 1))
            hits.append(now)
            # Drop keys with no recent hits so memory stays bounded.
            if len(self._hits) > 10_000:
                cutoff = now - self._window
                for stale in [k for k, v in self._hits.items() if not v or v[-1] <= cutoff]:
                    del self._hits[stale]
