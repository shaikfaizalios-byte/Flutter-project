# Phase E: question library

PrepLoop's curated questions, kept apart from learners' imports.

## How a question gets to learners

1. An editor adds it as a draft: a question from their own account, or a new one. Rights start as
   `pending`. Learners' imports can't enter: the service accepts only the editor's own questions.
2. A second reviewer answers it without seeing the key. A match moves it to `solved`; a different
   answer leaves it a draft. The author can't do this.
3. Someone other than the author approves it. Refused while its topic or model is private.
4. Learners see it only while it is approved and its rights are `licensed` or `owned`
   (`library_question()` in `app/services/shared_bank.py`, joined into `visible_question`).

Editors are set by the operator: `python -m app.cli.library role EMAIL editor`. The review screens
are in `/review-tool` under Library.

## Corrections

"Report a mistake" uses the existing report button; reports on library questions fill the queue at
`GET /library/reports`. A correction (`POST /library/entries/{id}/correct`) stores a new version with
its reason, re-marks every attempt through `apply_final_key`, and closes the report if one is named.
Once a question has been solved, `PATCH /questions/{id}` and the answer-key endpoint refuse it, so
nothing changes outside a version.

## Search and offline chapters

`GET /library/search`: exam, chapter (the syllabus Unit, as the sources have no Chapter level), topic,
model, format, year, difficulty, text.

`GET /library/packs?exam=` lists chapters with the newest change number. `GET /library/packs/{key}`
with `since` returns only changed questions, their figures and removed ids. A chapter left empty stays
listed so devices holding it learn its questions went. Packs carry the formats the offline pack does.
The app stores chapters in Drift v10: `offline_questions.pack_key`, `library_packs`, `offline_figures`.
Refreshing the daily pack leaves them alone, and sign-out erases them.

## Difficulty and "x% got this right"

`python -m app.cli.library calibrate` counts marked answers. From `calibration_min_attempts` (200) the
level comes from accuracy bands, one level harder when the median time passes `slow_multiple` (1.5) of
the paper's base time. Until then the assigned level stands. The percentage appears from
`percent_min_attempts` (30). All in `data/exam_templates/defaults.json` `library`; the bands, 30 and 1.5
are product choices, not research. Run calibrate on a schedule: nothing runs it yet.

## Rules kept

- AI-written questions never reach mocks, whatever their review, and are labelled as AI everywhere.
- An official question must come from a paper.
- Generated questions are never labelled as previous-year questions.

## Limits

- Library questions live in an editor's account, so deleting it or the paper removes them. Use a
  dedicated account, as with the shared bank.
- Corrections in the tool cover wording, the key and (by API) typed answers and `answer_spec`, not options.
- Search matches text with a simple contains, not the question bank's word rules.
- A rights decision applies per question; there is no bulk action yet.
