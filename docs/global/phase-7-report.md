# Global Phase 7 — Content governance and the starter check: acceptance report

Scope from [audit-and-roadmap.md](audit-and-roadmap.md) §5 "Phase 7". Branch
`claude/global-product-716ab9`, 1 Nov 2026. Details: [docs/shared-bank.md](../shared-bank.md).

## Decision on content

The founder had not chosen where starter content comes from. So PrepLoop writes **no sample
questions**: the starter check draws only from shared-bank papers whose recorded rights include
the `diagnostic` use. Until the operator publishes such papers, the check simply isn't offered.

## What changed

- **Migration 0035:** `content_rights` (one per shared paper: basis, holder, permitted uses
  practice|diagnostic, territory, attribution, review-by, decided by/at; CHECKs), `content_reports`
  (owned by the reporting learner; deleted with the account), `audit_events` (operator decisions,
  no content), practice mode `diagnostic`. Existing shared papers got a rights record for practice
  only. Reversible.
- **Publishing:** `shared_bank.publish` records rights and uses and writes an audit event;
  `unpublish` removes the rights record and is audited. CLI flags `--by`, `--use`, `--holder`,
  `--territory`, `--attribution`, `--review-by`; starter-paper manifests take `"uses"`.
- **Reports and takedown:** `POST/GET /content-reports`; operator `python -m app.cli.content`
  (reports, resolve, takedown, audit). Exam-format publish/retire are audited too.
- **Starter check:** `GET/POST /practice/starter-check` (≤ 5 per subject, ≤ 20, never one's own
  papers); untimed, marked after submitting; result explains it's a starting point. App: Home
  starter card button, a starter-check banner, result note, history label. Shared questions get a
  "Report this shared paper" flag (question screen and practice).

## Tests

- Backend `tests/test_content.py` (10): rights and uses recorded and audited, unknown uses refused,
  reports (visibility rules, daily limit, status), takedown (paper withdrawn at once, reports upheld,
  owner keeps the paper, reason required), resolving once, starter check only from papers allowed
  for it, spread across subjects, answers hidden until submitted, publisher excluded.
  `test_account_data.py` covers the new tables. Full suite, ruff, mypy, `alembic check` passing.
- Mobile: `starter_check_test.dart` (3), `shared_report_test.dart` (1). 439 tests passing, analyze
  clean.

## Not done / risks

- **No starter content exists**; the operator must publish papers with a recorded diagnostic right.
- The "preliminary profile" is the result's subject/topic breakdown plus the normal Home plan; there
  is no separate profile screen.
- Learners see report statuses only through the API (no "My reports" screen yet).
- Rights review dates are recorded but nothing reminds the operator when they pass.
- Legal review of the rights wording and the takedown process is still needed.
