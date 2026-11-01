# Global Phase 9 — Learning diagnosis, readiness, FSRS evaluation: acceptance report

Scope from [audit-and-roadmap.md](audit-and-roadmap.md) §5 "Phase 9". Branch
`claude/global-product-716ab9`, 1 Nov 2026. Details: [docs/analytics.md](../analytics.md),
[docs/revision.md](../revision.md) "FSRS check".

## Finding first

`session_answers.time_spent_ms` existed, but the app never sent it (only offline answers had a
field for it), so there was no time data to diagnose with. The session screen now records it;
**older answers stay untimed**, so the speed signal says nothing until learners answer again.

## What changed (no migration)

- **Time per question:** `SessionController` sends the time from when a question was shown until
  it was answered (`timeOnQuestion`; over 10 minutes is dropped as "probably away").
- **Raw diagnosis counts** on `GET /analytics/overview`: per topic `timed_answered`,
  `time_spent_ms`, `last_answered_on` (local day), `repeated_mistakes` (questions answered wrong in
  two or more sessions); overall timed totals. All optional for older clients.
- **Diagnosis rules** (`AnalyticsRules`, shown in the Progress tab): weak also for 3+ repeated
  mistakes (even with few answers) and for "slower than your usual pace" (≥ 1.5 × the learner's
  own average, 10+ timed answers in the topic and overall). Topics with 10+ answers not practised
  for 21+ days are suggested for a refresh (new plan item, not called weak). Topics below every
  threshold stay "needs more data" (insufficient evidence), never guessed.
- **Every plan reason lists its rules:** a weak-topic item shows its evidence (accuracy, forgetting,
  seconds per answer, repeated mistakes) and each rule that applies.
- **Readiness card** (Progress tab, `buildReadiness`): syllabus coverage (practised / strong or
  mastered, per subject) and evidence (14-day answers and accuracy, 30-day mocks with the latest
  score, days to the exam). **No score or pass probability**; the card says it is not a
  prediction. Offline and without a syllabus it says so instead of showing zeros.
- **FSRS offline check** (operator): pure `app/domain/fsrs.py` (FSRS-4.5 formulas, published
  default weights) and `python -m app.cli.fsrs_eval`, which replays synced `card_review` events
  and prints aggregates only: log loss / RMSE against a constant guess, calibration, recall at the
  ladder's gaps, and a verdict (`insufficient_data` under 1 000 scored reviews or 100 cards). The
  ladder remains the only scheduler.
- EN + HI strings; OpenAPI exported; docs/analytics.md, docs/revision.md, CLAUDE.md updated.

## Tests

- Backend `test_analytics.py` (+2): timed totals, local last day, repeated mistakes, one wrong
  answer is not repeated. `test_fsrs.py` (6): recall 90 % at S days, rating directions, no
  verdict without history, a small history measured but not judged, FSRS wins only on data that
  follows it (synthetic), synced history read per account and card with no ids in the report.
- Mobile: diagnosis rules (repeated mistakes, slow vs own pace, not enough timed answers, refresh
  vs weak, plan ordering), readiness (coverage, windows, offline), the Progress card, answers
  carrying time (and none after 11 minutes).

## Not done / risks

- **FSRS was not run on real data** (no synced reviews from real learners yet) and its weights are
  not fitted; the default weights should be checked against the reference implementation.
- An in-app FSRS option and per-learner fitting are not built: only worth it after a positive
  verdict on real data.
- Thresholds (3 repeated mistakes, 1.5 × pace, 21 days, 10-minute cap) are product choices, not
  validated research. The time includes reading a passage or figure, which can make passage
  topics look slow.
- Topic counts are all-time while the 30-day window applies to charts and flashcards (unchanged
  behaviour, now documented by the refresh rule needing old answers).
- Readiness coverage counts a topic as "practised" from a single answer, review or revised mark.
- No analytics by canonical topic across exams yet (Phase 6 note still open).
