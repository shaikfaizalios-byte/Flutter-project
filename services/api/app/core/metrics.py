"""Minimal request metrics in Prometheus text format (no client library).

Counts and total duration per method, route template and status class, per process. Labels
never contain ids or user data (``/api/v1/questions/{id}``); unrouted paths are "unmatched".
"""

import re
import threading
from collections import defaultdict

_UUID = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")


def route_label(path: str) -> str:
    """The request path with ids replaced (``/api/v1/questions/{id}``), so labels never
    carry identifiers and stay few."""
    parts = [
        "{id}" if _UUID.match(segment) or segment.isdigit() else segment
        for segment in path.split("/")
    ]
    return "/".join(parts)


class RequestMetrics:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._count: dict[tuple[str, str, str], int] = defaultdict(int)
        self._seconds: dict[tuple[str, str, str], float] = defaultdict(float)

    def record(self, method: str, route: str, status: int, seconds: float) -> None:
        key = (method, route, f"{status // 100}xx")
        with self._lock:
            self._count[key] += 1
            self._seconds[key] += seconds

    def render(self) -> str:
        with self._lock:
            items = sorted(self._count.items())
            seconds = dict(self._seconds)
        lines = [
            "# HELP preploop_http_requests_total HTTP requests by route and status class.",
            "# TYPE preploop_http_requests_total counter",
        ]
        for (method, route, status), count in items:
            lines.append(
                f'preploop_http_requests_total{{method="{method}",route="{route}",'
                f'status="{status}"}} {count}'
            )
        lines += [
            "# HELP preploop_http_request_duration_seconds_sum Total time spent per route.",
            "# TYPE preploop_http_request_duration_seconds_sum counter",
        ]
        for (method, route, status), _ in items:
            lines.append(
                f'preploop_http_request_duration_seconds_sum{{method="{method}",route="{route}",'
                f'status="{status}"}} {seconds[(method, route, status)]:.6f}'
            )
        return "\n".join(lines) + "\n"
