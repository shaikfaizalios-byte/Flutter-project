"""Rate limiters for expensive or sensitive endpoints.

- ``SlidingWindowRateLimiter``: in-process (development, tests, a single process).
- ``PostgresRateLimiter``: shared by every API process and instance through a small
  PostgreSQL table (fixed windows). Required in staging/production
  (``PREPLOOP_RATE_LIMIT_BACKEND=postgres``) so limits hold when scaled out.

Keys (which may contain an email address) are stored only as SHA-256 hashes.
"""

import hashlib
import math
import random
import threading
import time
from collections import deque
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from typing import Protocol

from sqlalchemy import Engine, text

from app.domain.errors import RateLimitedError


class RateLimiter(Protocol):
    def check(self, key: str) -> None:
        """Record a hit for ``key`` or raise ``RateLimitedError`` if over the limit."""
        ...


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


class PostgresRateLimiter:
    """Fixed-window counter shared across processes: one row per (hashed key, window)."""

    def __init__(
        self,
        engine: Engine,
        limit: int,
        window_seconds: int,
        *,
        message: str,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._engine = engine
        self._limit = limit
        self._window = window_seconds
        self._message = message
        self._clock = clock

    def check(self, key: str) -> None:
        now = self._clock()
        start_epoch = int(now.timestamp()) // self._window * self._window
        window_start = datetime.fromtimestamp(start_epoch, UTC)
        digest = hashlib.sha256(f"{self._window}:{key}".encode()).hexdigest()
        with self._engine.begin() as connection:
            hits = connection.execute(
                text(
                    "INSERT INTO rate_limit_counters (key_hash, window_start, hits) "
                    "VALUES (:key, :start, 1) "
                    "ON CONFLICT (key_hash, window_start) "
                    "DO UPDATE SET hits = rate_limit_counters.hits + 1 RETURNING hits"
                ),
                {"key": digest, "start": window_start},
            ).scalar_one()
            if random.random() < 0.01:  # noqa: S311 - housekeeping, not security
                connection.execute(
                    text("DELETE FROM rate_limit_counters WHERE window_start < :cutoff"),
                    {"cutoff": now - timedelta(days=2)},
                )
        if hits > self._limit:
            retry_after = start_epoch + self._window - int(now.timestamp())
            raise RateLimitedError(self._message, max(retry_after, 1))
