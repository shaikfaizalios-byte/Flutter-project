"""Load test for the weeks before an exam, when traffic peaks.

    python scripts/load_test.py --base http://127.0.0.1:8000 --tokens TOKENS.json \
        --profile scripts/load_profiles/exam_week.json --report report.json

TOKENS comes from `python -m app.cli.load_seed create`. Each virtual learner signs in with one token
and, until the time is up, takes a computer-based mock (answering, marking, moving around, then the
analysis), practises, searches the library or reads chapters, pausing between steps as people do.
The report gives each endpoint's requests, errors and p50/p95/p99 in milliseconds, and says whether
the profile's targets were met (exit code 1 if not).

Only for servers you run: anything other than a local address needs --allow-remote, and the seed
refuses staging and production databases.
"""

import argparse
import asyncio
import json
import random
import statistics
import sys
import time
from collections import defaultdict
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import httpx

LOCAL = {"127.0.0.1", "localhost", "::1"}


class Recorder:
    def __init__(self) -> None:
        self.times: dict[str, list[float]] = defaultdict(list)
        self.errors: dict[str, int] = defaultdict(int)

    async def call(
        self, client: httpx.AsyncClient, name: str, method: str, url: str, **kwargs: Any
    ) -> httpx.Response | None:
        started = time.perf_counter()
        try:
            response = await client.request(method, url, **kwargs)
        except httpx.HTTPError:
            self.errors[name] += 1
            self.times[name].append((time.perf_counter() - started) * 1000)
            return None
        self.times[name].append((time.perf_counter() - started) * 1000)
        if response.status_code >= 400:
            self.errors[name] += 1
        return response


def percentile(values: list[float], share: float) -> float:
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(share * len(ordered)))] if ordered else 0.0


async def mock(
    client: httpx.AsyncClient,
    rec: Recorder,
    seed: dict[str, Any],
    rng: random.Random,
    think: list[float],
) -> None:
    started = await rec.call(
        client,
        "start mock",
        "POST",
        "/api/v1/practice/mock-tests",
        json={"exam_format_code": seed["format"]},
    )
    if started is None or started.status_code != 201:
        return
    session = started.json()
    for seq, item in enumerate(session["items"], start=1):
        body: dict[str, Any] = {"client_seq": seq, "time_spent_ms": rng.randint(20000, 90000)}
        roll = rng.random()
        if roll < 0.15:
            body["visit"] = True
        else:
            body["selected_position"] = rng.randint(1, 4)
            body["marked_for_review"] = roll > 0.9
        await rec.call(
            client,
            "answer",
            "PUT",
            f"/api/v1/practice/sessions/{session['id']}/answers/{item['position']}",
            json=body,
        )
        await asyncio.sleep(rng.uniform(*think) / 4)
    await rec.call(client, "submit", "POST", f"/api/v1/practice/sessions/{session['id']}/submit")
    await rec.call(client, "analysis", "GET", f"/api/v1/practice/sessions/{session['id']}/analysis")


async def practice(
    client: httpx.AsyncClient,
    rec: Recorder,
    seed: dict[str, Any],
    rng: random.Random,
    think: list[float],
) -> None:
    started = await rec.call(
        client,
        "start practice",
        "POST",
        "/api/v1/practice/sessions",
        json={"exam_code": seed["exam"], "count": 10},
    )
    if started is None or started.status_code != 201:
        return
    session = started.json()
    for seq, item in enumerate(session["items"], start=1):
        await rec.call(
            client,
            "answer",
            "PUT",
            f"/api/v1/practice/sessions/{session['id']}/answers/{item['position']}",
            json={"selected_position": rng.randint(1, 4), "client_seq": seq},
        )
        await asyncio.sleep(rng.uniform(*think) / 4)


async def library(
    client: httpx.AsyncClient,
    rec: Recorder,
    seed: dict[str, Any],
    rng: random.Random,
    think: list[float],
) -> None:
    await rec.call(
        client, "library search", "GET", "/api/v1/library/search", params={"exam": seed["exam"]}
    )
    await rec.call(
        client, "chapter packs", "GET", "/api/v1/library/packs", params={"exam": seed["exam"]}
    )


async def chapters(
    client: httpx.AsyncClient,
    rec: Recorder,
    seed: dict[str, Any],
    rng: random.Random,
    think: list[float],
) -> None:
    await rec.call(
        client, "chapters", "GET", "/api/v1/insights/chapters", params={"exam": seed["exam"]}
    )
    await rec.call(
        client, "mock list", "GET", "/api/v1/practice/mock-tests", params={"exam": seed["exam"]}
    )


SCENARIOS = {"mock": mock, "practice": practice, "library": library, "chapters": chapters}


async def learner(
    base: str,
    token: str,
    seed: dict[str, Any],
    profile: dict[str, Any],
    rec: Recorder,
    delay: float,
    until: float,
    rng: random.Random,
) -> None:
    await asyncio.sleep(delay)
    names = list(profile["mix"])
    weights = [profile["mix"][n] for n in names]
    headers = {"Authorization": f"Bearer {token}"}
    async with httpx.AsyncClient(base_url=base, headers=headers, timeout=30) as client:
        while time.monotonic() < until:
            scenario = SCENARIOS[rng.choices(names, weights)[0]]
            await scenario(client, rec, seed, rng, profile["think_seconds"])
            await asyncio.sleep(rng.uniform(*profile["think_seconds"]))


async def run(base: str, seed: dict[str, Any], profile: dict[str, Any]) -> Recorder:
    rec = Recorder()
    rng = random.Random(profile.get("random_seed", 1))  # noqa: S311 - traffic, not secrets
    tokens = seed["tokens"][: profile["learners"]]
    until = time.monotonic() + profile["duration_seconds"]
    ramp = profile["ramp_seconds"]
    await asyncio.gather(
        *(
            learner(
                base,
                token,
                seed,
                profile,
                rec,
                ramp * i / max(len(tokens), 1),
                until,
                random.Random(rng.random()),  # noqa: S311 - traffic, not secrets,
            )
            for i, token in enumerate(tokens)
        )
    )
    return rec


def report(rec: Recorder, profile: dict[str, Any], seconds: float) -> dict[str, Any]:
    rows = {}
    for name, times in sorted(rec.times.items()):
        rows[name] = {
            "requests": len(times),
            "errors": rec.errors[name],
            "p50_ms": round(statistics.median(times)),
            "p95_ms": round(percentile(times, 0.95)),
            "p99_ms": round(percentile(times, 0.99)),
        }
    total = sum(r["requests"] for r in rows.values())
    errors = sum(r["errors"] for r in rows.values())
    targets = profile["targets"]
    worst = max((r["p95_ms"] for r in rows.values()), default=0)
    return {
        "endpoints": rows,
        "requests": total,
        "requests_per_second": round(total / seconds, 1) if seconds else 0,
        "error_rate": round(errors / total, 4) if total else 0,
        "worst_p95_ms": worst,
        "targets": targets,
        "met": bool(total)
        and worst <= targets["p95_ms"]
        and errors / total <= targets["error_rate"],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--tokens", type=Path, required=True)
    parser.add_argument("--profile", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--allow-remote", action="store_true")
    args = parser.parse_args()
    host = urlparse(args.base).hostname or ""
    if host not in LOCAL and not args.allow_remote:
        print(
            "Refused: only local servers, unless --allow-remote for a server you run.",
            file=sys.stderr,
        )
        return 2
    seed = json.loads(args.tokens.read_text(encoding="utf-8"))
    profile = json.loads(args.profile.read_text(encoding="utf-8"))
    started = time.monotonic()
    rec = asyncio.run(run(args.base, seed, profile))
    result = report(rec, profile, time.monotonic() - started)
    width = max((len(n) for n in result["endpoints"]), default=10)
    print(f"{'endpoint':<{width}}  requests errors   p50   p95   p99 (ms)")
    for name, row in result["endpoints"].items():
        print(
            f"{name:<{width}}  {row['requests']:>8} {row['errors']:>6} {row['p50_ms']:>5} "
            f"{row['p95_ms']:>5} {row['p99_ms']:>5}"
        )
    print(
        f"{result['requests']} requests, {result['requests_per_second']}/s, "
        f"error rate {result['error_rate']:.2%}, worst p95 {result['worst_p95_ms']} ms: "
        + ("targets met" if result["met"] else "targets NOT met")
    )
    if args.report:
        args.report.write_text(json.dumps(result, indent=2), encoding="utf-8")
    return 0 if result["met"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
