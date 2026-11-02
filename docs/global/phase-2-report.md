# Global Phase 2 — Answer provenance and question history: acceptance report

Scope from [audit-and-roadmap.md](audit-and-roadmap.md) §5 "Phase 2". Branch
`claude/global-product-716ab9`, 1 Nov 2026.

## Decision: one table, not two

The audit proposed `question_answer_records` + `question_revisions`. Built as **one** append-only
`question_revisions` table of snapshots: the paper's answer is the first `extracted` snapshot,
and every later answer is in an `edited` snapshot, so a separate answer table would duplicate the
same facts. `questions.correct_option_position` etc. stay the effective answer, so practice,
mocks, scoring and sync are untouched.

## What changed

- **Data:** migration `0030_question_revisions` (CHECKs on action/actor, index on
  question + time, `ON DELETE CASCADE`). Existing questions get one `baseline` revision built in
  SQL. Downgrade drops the table.
- **Backend:** first revision at every creation path (segmenter, Q&A notes, AI reading, AI
  generation); `PATCH /questions/{id}` appends an `edited` revision when a tracked field changed;
  `QuestionRead.answer_origin` / `paper_answer` (additive); `GET /questions/{id}/revisions`
  (owner only). Export/deletion: `question_revisions` classified as a child of `questions`.
- **App:** answer-origin line under the answer (review screen and shared read-only view), "Approving
  … is not an official answer key", Edit history (each entry expands to the wording, options and
  answer at that point). EN + HI.

## Tests

- `tests/test_question_history.py` (8): rules; a read paper's first revision is the paper as found;
  changing the answer keeps the paper's answer and lists `changed`; a paper with no answer says so;
  status-only edits add nothing; other accounts → 404. `tests/test_account_data.py` covers the new
  table.
- `test/features/question_bank/question_history_test.dart` (4): key answer note + not-official
  note, reviewer answer with the paper's, unknown original stays unknown, history list.
- Full runs: backend pytest all passing (migrations up → down → up incl. 0030), ruff, mypy,
  `alembic check`; mobile analyze clean, 408 tests passing.

## Not done / risks

- The `baseline` backfill was exercised only on an empty test database (the SQL runs in every
  migration test, but no pre-existing rows); run it on a copy of real data before production.
- "Official key matched" and "independently checked" states are not built (no official key
  source, no second reviewer). The status label "Verified" was kept app-wide; the review screen
  now says approving is not official. Renaming "Verified" to "Reviewed" everywhere is a follow-up.
- Status changes are not in the history (approve/reject/verify-clean/reports).
- Snapshots duplicate question text per edit; fine at current volumes.

## How to verify by hand

1. `.\scripts\check.ps1` (runs `alembic upgrade` on your dev DB first: `alembic upgrade head`).
2. Import a paper with an answer key, open a question, change its answer, save: the line says
   "You set this answer. The paper said (x) …"; Edit history shows "Read from the paper" and
   "Changed in review: answer".
