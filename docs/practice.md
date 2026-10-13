# Practice and mock tests (Phase 6)

Code: `services/api/app/services/practice_service.py`, `app/domain/scoring.py`,
`app/models/practice.py`; mobile `apps/mobile/lib/features/practice/`.

## Which questions are used

A question is eligible only when **all** of these hold (`_eligible` in the service):

- `origin = source`. AI questions are never mixed in; they arrive in Phase 9, with a label.
- `verification_status = verified`. Unverified questions are used only if the learner turns on
  "Include questions not yet reviewed". Each item then carries `source.verified = false`, and the app
  labels it "Not yet reviewed". Rejected questions are never used.
- Not `image_dependent` (the figure is not available in the app).
- It has a correct answer and at least two options.

Each session stores a **snapshot** per item (`session_items`): section, subject, topic, correct
option, option count, marks for correct and wrong, and whether the question was verified. Later
review edits to a question therefore never change a session that has already started or been scored.

## Practice (untimed)

- Filters: `exam_code`, `subject`, `section`, `topic_id`; no filter means a mixed session. `count` is 1–100.
- Questions are chosen at random from the eligible pool. If none match, the response is `422 no_questions_available`.
- **Answers are final.** The first non-null answer is locked, and the response includes immediate feedback (correct
  option, right or wrong, and the explanation when the source had one).
- Scoring: 1 point per correct answer, no negative marking (stated in the result's `marking_note`).

## Mock tests (timed)

- Only **verified exam formats** (`exam_formats`, each with an official source) are offered. Question
  count per section, duration and negative marks all come from the format row.
  - Marks per question = section `max_marks` ÷ section `questions`.
  - Wrong answer = −`negative_marks_per_wrong`.
- `GET /practice/mock-tests` lists each format with `available` and per-section `needed` / `available`
  counts. If any section lacks enough verified questions, starting it returns
  `422 not_enough_questions`, and the message says which sections are short. Sections are matched by subject name,
  never by position.
- Questions are sampled with a recorded random seed (`selection.seed`) for reproducibility.
- Answers can be changed until submission. **No feedback** is shown until the test is submitted.

### Timer

- The server records `started_at` and `deadline_at = started_at + duration`. The app shows
  `deadline_at − now`, using the offset between the device clock and the server's `server_now`. Closing
  the app, reinstalling it or changing the device clock cannot reset or extend the time.
- When `now ≥ deadline_at`, the next read, answer or submit **auto-submits** the session with the answers
  already saved (`submit_reason = time_up`). The time taken is capped at the deadline. Any answer that arrives
  after that gets `409 session_closed`.
- The app also submits by itself when its countdown reaches zero, retrying every 15 s while offline.

## Saving answers and idempotency

- `PUT /practice/sessions/{id}/answers/{position}` with `{selected_position | null, client_seq, time_spent_ms}`.
- `client_seq` increases monotonically per device (microseconds, bumped if the clock repeats). The server
  applies an answer only if its `client_seq` is greater than the stored one. Replays and out-of-order
  deliveries are therefore harmless, and the response's `applied` says whether this request changed anything.
- `POST /practice/sessions/{id}/submit` is idempotent. A second call returns the same result without rescoring.

### Offline queue (mobile)

- Every answer is first written to the Drift table `pending_answers`. The primary key is
  (session, position), so a newer answer replaces an older queued one. The answer is then sent.
  - If the send succeeds, the row is deleted (only if its `client_seq` still matches).
  - Network errors, timeouts and 5xx responses leave it queued. The UI shows "Saved on this device".
  - Any other server error (for example `session_closed`) drops it, so it is never retried forever.
- `flush` replays the queue oldest first and stops at the first connectivity problem. It runs:
  - when the Practice tab opens,
  - before a session is loaded (queued answers are re-applied on top of the server's state),
  - before submit.
- A session needs a connection to **start** or **open**. Only answers are offline-tolerant.

## Scoring and explanation

`score_session` (pure, `Decimal`, rounded half-up to 2 places) returns totals plus per-section and
per-topic tallies: correct, wrong, unattempted, score, max score and accuracy (correct ÷ attempted).
Every tally has a human-readable explanation, for example:

```
Correct 18 × 2.00 = 36.00; Wrong 4 × −0.50 = −2.00; Unattempted 3 × 0 = 0; Total 34.00 of 50.00
```

The result also includes `marking_note`, which names the format and its source for mocks, or the practice
rule. Unit tests: `tests/test_scoring.py`.

## Review tools

- Bookmarks: `PUT`/`DELETE /questions/{id}/bookmark`, listed by `GET /practice/bookmarks`.
- Incorrect answers: `GET /practice/incorrect` lists questions whose **latest** answer was wrong. Mock
  answers count only after the mock is submitted, since no feedback was shown before then.
- History: `GET /practice/sessions` (newest first, with score) and `GET /questions/{id}/history`
  (attempts, correct count, last result and when).

## Data recorded for analytics (Phase 8)

`session_answers` keeps, per question: the selected option, correctness, time spent and answered-at. Combined with
each item's section/subject/topic snapshot, this is enough for per-topic and per-section analytics. No analytics
UI exists yet beyond the session summary.
