# Global Phase 6 — Canonical topics: acceptance report

Scope from [audit-and-roadmap.md](audit-and-roadmap.md) §5 "Phase 6". Branch
`claude/global-product-716ab9`, 1 Nov 2026.

## What changed

- **Migration 0034:** `taxonomy_nodes` (stable `key`, subject/topic, parent), `taxonomy_labels`
  (per language, aliases), `topic_taxonomy_links` (status suggested/confirmed/rejected, source,
  reason, decided time; one confirmed link per topic). Seeded from the 60 shared topics: one
  canonical node each (English labels only: no reviewed Hindi labels exist), every shared topic
  linked to its own node as `confirmed` by the migration. Learners' existing topics got
  `suggested` links where the name matches exactly one canonical topic. Reversible.
- **Rules** (`app/domain/taxonomy.py`): name comparison (case, spacing, punctuation, "&"/"and",
  simple plurals incl. "-ies", invariant words like "series"); a suggestion needs exactly one
  candidate.
- **Service/API:** `app/services/taxonomy_service.py` (suggest on create and rename, never re-suggest
  a rejected pair, decide, read); `OwnTopicRead.canonical`; `PUT /topics/{id}/canonical` (own
  topics only, 404 otherwise); `GET /taxonomy`. Export/deletion: links are children of topics;
  nodes and labels are reference data.
- **Mocks:** a section also takes questions whose topic is confirmed-linked to a canonical topic of
  the section's subject (by id), in addition to the name rules. Suggestions never count.
- **App:** topics screen shows the suggestion with "Yes, same / No", and "Counts as the shared
  topic …" once confirmed. EN + HI.

## Decisions

- **No syllabus-version columns yet.** Official syllabus versions need official syllabus documents
  with rights; adding empty columns now would be speculative. `syllabus_imports` already keeps
  each learner's syllabus as a separate, removable version.
- **Analytics don't aggregate by canonical topic yet** (repeats, mastery and Radar still count
  exam topics), so there is nothing to disclose as "unmapped" yet. When they do, only confirmed
  links count, and the unmapped share must be shown (brief §3.2).
- **No Hindi labels** were generated: canonical labels in other languages must be reviewed by a
  person and added as data.

## Tests

- Backend `tests/test_taxonomy.py` (8): name rules, ambiguity, seeded identity links and English-only
  labels, the tree endpoint, suggestions on create, confirm/reject (rejection sticks through a
  rename), owner-only decisions, a confirmed own topic counting toward the CGL reasoning section
  while a suggestion doesn't. `test_account_data.py` covers the new table. Full suite, ruff, mypy,
  `alembic check` (up → down → up incl. 0034) passing.
- Mobile `test/features/exams/canonical_topics_test.dart` (3). 435 tests passing, analyze clean.

## Not done / risks

- The seeding migration ran only on the test database's shared topics and own topics created by
  tests; run it on a copy of real data before production.
- Canonical nodes come only from PrepLoop's existing shared topics; topics of other exams (NEET,
  UPSC, …) have no canonical topic until an operator adds them (no CLI for nodes yet: SQL or a
  follow-up command).
- Name matching is English-centric; Hindi-named own topics get no suggestion.
