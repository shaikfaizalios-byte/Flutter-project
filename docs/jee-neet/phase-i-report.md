# Phase I: scale

## Question bank and versions

Questions already live on the server with their history: every change to wording or answer is a
`question_revisions` row (global Phase 2), library questions add numbered versions (Phase E), and a final key
re-marks attempts (Phase C). This phase adds nothing there.

## Figures through a CDN

Figures every learner may see (shared bank and library) get a signed link named by the hash of the image
(migration 0060 hashes existing figures). The link needs no sign-in, so a CDN can cache it once for everyone.
It expires on a fixed boundary, so everyone in the same window gets the same link. A learner's own papers
never get one. The app fetches linked figures without its access token and falls back to the signed-in
endpoint, then to a saved chapter. Set-up: docs/deployment.md.

## Chapter packs cached

The app brings changed saved chapters up to date when the library opens, fetching only what changed. The
server keeps each exam's chapter list for up to 5 minutes, and only while nothing in that exam's library has
changed.

## Attempt events

`attempt_events` gets a row when an answer becomes final and when a key change re-marks it. Practice answers
are final when given, and a test's answers when it is submitted. Calibration now reads events after its
cursor (`job_cursors`) and works out again only the questions they touch. Its first run writes events for
older answers. Events are the learner's data: exported with the account and removed with it.

Weak-topic tracking still reads sessions, as before. Events carry the exam and topic, so it can move to them
when sessions grow too large to read. That switch isn't made here, because the rules and their tests would
change with it.

## Load test

```
python -m app.cli.load_seed create --learners 300 --tokens PATH    # test databases only
python scripts/load_test.py --base URL --tokens PATH --profile scripts/load_profiles/exam_week.json
python -m app.cli.load_seed clean
```

Each virtual learner takes computer-based mocks (answers, review marks, visits, submit, analysis),
practises, searches the library and reads chapters, with pauses between steps. The seed refuses staging and
production, and the runner refuses anything but a local address unless `--allow-remote`. The exam-week
profile (300 learners, 10 minutes, p95 within 800 ms, under 1 % errors) is a guess to replace with real
numbers.

Run on this PC with 20 learners for 60 seconds (`smoke.json`), the load generator on the same machine:

| Server | Requests/s | Errors | Worst p95, server log | Worst p95, client |
| --- | --- | --- | --- | --- |
| 1 process | 21 | 0 % | not measured | 2,750 ms (requests queued) |
| 4 processes | 50 | 0.15 % (client connection errors) | 488 ms (start mock) | 1,587 ms |

With nothing else running, an answer takes 24 ms and starting a mock 100-160 ms. One process saturates
around 20 requests/s, so the image now runs `WEB_CONCURRENCY` processes (default 2). Starting a mock is the
slowest step: it reads the exam's eligible questions each time. Cache that if a real run shows it matters.

## Limits

- No CDN was set up or tried: links and cache headers are tested, the CDN's behaviour isn't.
- Not run on a server or at exam-week size. Local numbers share one CPU between server, database and load
  generator.
- Figures are still stored in PostgreSQL. A CDN takes the reads off it; moving the bytes to object storage is
  the S3 adapter already in the backlog.
- Practice answers count for calibration when given; test answers only once submitted, so an abandoned test
  never counts.
