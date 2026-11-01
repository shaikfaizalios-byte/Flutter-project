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
  - Nothing is filled in with a default. The pure `app/domain/exam_format.py` `format_problems()`
    lists every missing fact (a section without subject, question count or `max_marks`; counts that
    don't add up to `total_questions`; no duration; negative marking not stated — `0` means "none",
    `NULL` means "not verified"). A format with problems is listed with `available: false` and
    `format_problems` (English details; the app shows a localised "missing official details" line),
    and starting it returns `422 format_incomplete`. `tests/test_exam_format.py` also checks that
    every seeded format is complete.
- `GET /practice/mock-tests` lists each format with `available` and per-section `needed` / `available`
  counts. If any section lacks enough verified questions, starting it returns
  `422 not_enough_questions`, and the message says which sections are short. Sections are matched by subject name,
  never by position.
- **Sectional timers** (global Phase 5, migration 0033): a format with `sectional_timing` (SSC CGL
  2026 Tier-I: 4 × 15 min, fixed order) gives the mock a section plan copied into
  `selection.sections` (name, first/last position, minutes) plus `current_section` /
  `section_started_at`. Pure rules in `app/domain/sections.py`: a section closes when its own time is
  up (the next opens at that moment) or when the learner finishes it early
  (`POST /practice/sessions/{id}/next-section` with `from_section`, harmless when retried); a closed
  section can't be reopened; closing the last one submits (`time_up` at the last section's end, or
  `user`). Answers outside the open section → `409 section_closed`; questions of sections not open yet
  come without content. `SessionRead` adds `sections`, `current_section`, `section_deadline_at`. The
  app shows "Section x of n", the section's own countdown, Finish section (no way back), and loads the
  next section when the time is up. Finishing a section early is this mock's choice; the official
  notice records the timers, not whether a section can be left early. Mocks started before 0033 keep
  one overall timer. Formats without sectional timing (CHSL) are unchanged.
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
- Online sessions need a connection to **start** or **open**; without one, practice falls back
  to an offline session (below). Mock tests always need the server (its timer is authoritative).

### Offline practice (mobile, schema v7)

- **Offline pack.** `GET /api/v1/practice/offline-pack?limit=500` returns the questions a learner
  may practise (verified, answer known, own + shared bank), **without figures** (images aren't
  stored offline), answers included. The app saves them in Drift `offline_questions`; the
  Practice tab refreshes them whenever it opens online and shows how many are saved.
- **Starting offline.** When `POST /practice/sessions` fails for lack of a connection, the
  repository picks questions from the pack with the same filters (exam, subject, topic, type,
  shared bank) and creates a local session (Drift `offline_sessions`, a client UUID). With no
  matching saved question, the connection error is shown as before.
- **Device marking is a preview.** Answers are marked on the device (typed answers with the same
  rules as `app/domain/typed_answers.py`) and are final once given, as online. The screen says
  the session is offline; bookmarks and reports need the server and are hidden.
- **Upload.** Finishing uploads at once when possible (the server's result is then shown);
  otherwise `flush` uploads finished sessions oldest first. `POST /api/v1/practice/offline-sessions`
  is idempotent by `client_id` (the server's session id), **marks every answer again**, drops
  questions the learner can no longer see, keeps answer times within the session and never in
  the future, and records the session as submitted with `submit_reason = "offline"`, so history,
  analytics and "questions to revisit" include it.
- **Signing out** erases saved questions and offline sessions not yet uploaded (as all device data).

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

## Typed-in answers (TITA)

Questions with `answer_type = "typed"` (e.g. CAT's type-in-the-answer questions) have no options and a
`typed_answer`. The learner types the answer (`PUT .../answers/{n}` with `typed_answer` instead of
`selected_position`); `app/domain/typed_answers.py` decides: numbers are equal by value (`2.5` = `2.50`,
never rounded, PDF minus sign and thousands separators handled), anything else must match ignoring spaces
and case. Practice scores them like other questions (1 point, no negative marking). **Mocks leave typed
questions out** until a verified exam format records their marking. The app shows a number keyboard when
the expected answer is a number; offline, typed answers wait in the Drift `pending_answers` queue
(schema v6) like option answers.

From papers, an answer line that names no option becomes a typed answer when it is a number, "Sentence 5"
(-> `5`) or an order like "3-4-2-1" (-> `3421`) and the question has no options or the answer refers to
its listed items (which go back into the stem). Words are never turned into typed answers; reviewers can
switch a question's type and type any answer.

