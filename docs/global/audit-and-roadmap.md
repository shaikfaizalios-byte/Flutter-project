# PrepLoop global direction: repository audit and roadmap

Phase 0 deliverable for `PrepLoop_Global_Product_Development_Brief.md` (the "brief").
Checked against branch `claude/global-product-716ab9` (cut from `main` at `d5cce17`) on 31 Oct 2026.
Alembic head `0028`, Drift schema v7, 27 server tables, ~100 API operations.

No application code, migrations or existing docs were changed for this audit. Every status below
cites the code or test that backs it. Where the brief's section 2 inventory (taken from the feature
guide) and the code disagree, the code wins and the difference is called out.

Status labels are the brief's: **EXISTS** (built, code + tests), **PARTIAL** (some parts),
**HIDDEN** (built but off), **MISSING**, **NEEDS_VALIDATION** (built, but correctness, security,
legal suitability or device behaviour not demonstrated).

---

## 1. Current architecture overview

### 1.1 Shape

```
apps/mobile (Flutter, Riverpod 3, GoRouter, Dio, Drift v7)        services/api (FastAPI modular monolith)
  features/<f>/{presentation,application,domain,data}               api/v1/endpoints  -> services -> models (SQLAlchemy 2, sync)
  core/database (Drift: offline store + sync outbox)                 domain/ (pure rules: scoring, segmentation, rag, radar ...)
  core/network (one dioProvider, AuthInterceptor)                    integrations/ (AIProvider, OcrEngine, EmailSender, DocumentStorage)
  gen-l10n EN + HI                                                   workers/document_worker.py (DB queue, lease + SKIP LOCKED)
            \__________________ REST /api/v1 (OpenAPI: contracts/openapi/openapi.json) ________/
                                                    |
                                     PostgreSQL 17 (+ local PDF volume, Tesseract eng+hin, Anthropic API optional)
infra/: docker-compose (dev), infra/production (VPS + Caddy + nightly backup.sh)
CI: .github/workflows/ci.yml (ruff, mypy, pytest, alembic check, flutter analyze/test, image, APK),
    device-tests.yml (Android emulator), test-apk.yml / test-ipa.yml (unsigned test builds), pages.yml (website)
```

The brief's recommended direction (modular monolith, PostgreSQL, Postgres full-text search before a
search service, durable job queue, Docker) is **already the architecture**. No technology migration is
needed for any phase below.

### 1.2 Brief's logical domains (§4.2) mapped to existing modules

| # | Brief domain | Existing code | State |
|---|---|---|---|
| 1 | Identity and Access | `app/services/auth_service.py`, `app/core/security.py`, `models/user.py` (users, refresh_tokens, account_codes) | Accounts, rotation, reuse detection exist; no device list, roles, orgs, consent records |
| 2 | Exam Catalog | `models/exam.py` (exams), `models/question.py` `ExamFormat`, `services/topic_service.py`, `endpoints/exams.py`, `exam_topics.py` | Exam = data; no country/authority/version split |
| 3 | Syllabus and Taxonomy | `topics`, `syllabus_imports`, `question_patterns`, `topic_completions`; `domain/syllabus.py`, `domain/topics.py` | Exam-scoped topic lists; no canonical layer |
| 4 | Documents | `services/document_service.py`, `processing_service.py`, `extraction.py`, `workers/document_worker.py`, `integrations/storage.py`, `ocr.py` | Solid pipeline; local storage only |
| 5 | Question Bank | `models/question.py`, `domain/segmentation.py`, `figures.py`, `qa_notes.py`, `services/question_service.py`, `segmentation_service.py` | Rich; answer provenance overwritten on edit |
| 6 | Content Rights and Publishing | `services/shared_bank.py`, `cli/shared_bank.py`, `cli/starter_papers.py`, `documents.shared_*` columns | Per-paper rights basis only |
| 7 | Practice and Assessment | `services/practice_service.py`, `domain/scoring.py`, `typed_answers.py` | Exists; per-item marks snapshotted |
| 8 | Learning Profile | mobile `features/mastery`, `features/analytics` (rules on device) | Rules-based levels; no diagnosis |
| 9 | Revision | mobile `features/revision` (Drift `revision_cards`, `card_reviews`), synced | Fixed ladder + ratings |
| 10 | AI Services | `services/ai_service.py`, `rag_service.py`, `ai_paper_reader.py`, `domain/ai_content.py`, `rag.py`, `ai_reading.py`, `integrations/ai.py` | Validated, logged without text |
| 11 | Insights | `services/insights_service.py`, `analytics_service.py`, `radar_service.py`, `domain/similarity.py`, `radar.py` | Descriptive, sample-size aware |
| 12 | Notifications | mobile `features/reminders` (local notifications) | Device-only; email transactional only |
| 13 | Billing and Entitlements | `models/plus.py`, `services/plus_service.py`, `cli/plus.py` | Entitlement only; no payments |
| 14 | Institution Management | — | MISSING (intentionally deferred) |
| 15 | Audit and Compliance | `ai_generations` (AI audit), JSON request logs with request_id, `auth/me/export`, `auth/me/delete` | No audit-event table, no consent records |

### 1.3 Server entities and relationships (27 tables)

- **Identity:** `users` 1─* `refresh_tokens` (family_id = one signed-in device chain), `account_codes`,
  `rate_limit_counters`, `subscriptions` (1─1 users), `suggestions`.
- **Exam catalog:** `exams` (PK `code`; `owner_id` NULL = catalog, set = private exam; `category`,
  `featured`) 1─* `exam_formats` (sections JSONB, totals, duration, negative marks, source title/url/
  reference/published/verified dates — only CHSL 2026 Tier-I `0003` and CGL 2026 Tier-I `0018`).
- **Syllabus:** `topics` (subject, name, keywords, `owner_id`, `exam_codes[]`, `syllabus_import_id`)
  1─* `question_patterns`; `syllabus_imports` (owner, exam, pdf|typed); `topic_completions` (owner × topic).
- **Documents:** `documents` (owner, exam, language en|hi, sha256, storage_key, status, AI-read status,
  paper date/shift + status, `shared_at` + `shared_rights_basis` + `shared_source` CHECK) 1─*
  `document_pages` (method text|ocr|none, text, OCR confidence, review reasons).
- **Question bank:** `questions` (origin source|ai with provenance CHECKs, owner, exam, exam_format,
  section/subject, topic + status/suggester/reason, pattern + status/reason, document + number + pages,
  passage, answer_type choice|typed|written, correct position / typed / model answer, `answer_source`
  answer_key|inline|manual, `extracted_by` rules|ai, `verification_status`, AI provenance fields)
  1─* `question_options` (position, printed label, text), `question_issues` (code, detail, resolved),
  `question_figures` (stem|option|original, page, box, PNG bytes); `passages` (document, range, pages).
- **Practice:** `practice_sessions` (practice|mock, exam, `exam_format_id`, selection JSON incl. seed,
  deadline, result JSON) 1─* `session_items` (snapshot: marks_correct, marks_wrong, correct answer,
  question_verified) and `session_answers` (client_seq, time_spent_ms); `bookmarks` (question_id only).
- **Learning content:** `concepts` (old REST store, deprecated — the app syncs concepts via `sync_items`).
- **AI:** `ai_explanations` (draft→approved/rejected), `ai_generations` (task, model, prompt version,
  outcome, tokens; no text).
- **Sync:** `sync_items` (owner × entity × item_id, JSON data, tombstone, global `seq`).

Device (Drift v7, `apps/mobile/lib/core/database/tables.dart`): `concepts`, `app_settings`,
`study_profiles`, `pending_answers`, `revision_cards`, `card_reviews`, `sync_outbox`,
`offline_questions`, `offline_sessions`.

### 1.4 API contract map (from `contracts/openapi/openapi.json`)

| Area | Operations |
|---|---|
| Auth | register, login, refresh, logout, me, me/export, me/delete, verify-email request/confirm, password-reset request/confirm |
| Exams / topics | `GET /exams` (public), `GET/POST/PATCH/DELETE /me/exams`, `/exams/{code}/topics`, `/exams/{code}/syllabus` (+`/text`), `/exams/{code}/syllabus-imports`, `/syllabus-imports/{id}`, `/topics` (+bulk, bulk-delete, completion), `/patterns`, `GET /exam-formats` |
| Documents | upload/list/get/delete, pages, page image, parse-summary, segment, exam-format, paper-date, topics/accept, questions/verify-clean |
| Questions | list/search, get, patch, figures, history, report, bookmark |
| Practice | sessions (create/list/get/answer/submit), mock-tests (availability/create), offline-pack, offline-sessions, bookmarks, incorrect |
| Insights | repeats, shared-bank, radar (+settings), analytics/overview |
| AI | status, explanation (+review), questions/generate, topic-suggestion(s), topic-draft, quick-answer, search-answer, documents/{id}/read, answer-check, topic-lesson, topic-quiz |
| Other | me/plus (+test), suggestions, sync push/pull, health/ready, metrics |

### 1.5 Mobile navigation (`apps/mobile/lib/app/routes.dart`, `router.dart`)

Sign-in gate → optional onboarding → 5-tab `StatefulShellRoute`: **Home** (Today card, plan, focus,
weekly-review prompt) · **Study** (concepts, documents → review / solve / read, revision, topics,
search + RAG/quick answer) · **Practice** (sessions, bank, bookmarks, incorrect, repeats/not-repeated)
· **Progress** (analytics, weekly review) · **Profile** (my exams, Plus, suggestions, legal, radar card).
Current-exam switch: `ExamSwitcher` (sidebar or Home app bar). Hidden routes: `/learn/*`.

---

## 2. Existing versus missing features

### 2.1 Baseline inventory (brief §2) verified in code

| Brief item | Status | Evidence | Note |
|---|---|---|---|
| Email/password, 18+ confirmation | EXISTS | `app/schemas/auth.py` (`MINIMUM_AGE`, `confirms_minimum_age`), migration `0016`, `tests/test_auth.py` | |
| Email verification / password reset codes | EXISTS | `models/user.py` `AccountCode`, `tests/test_account_codes.py`, mobile `test/features/auth/account_recovery_test.dart` | Unverified emails can still use the app |
| Refresh rotation + reuse detection | EXISTS | `auth_service.py` (`_revoke_family`), `tests/test_auth.py`, `test/core/auth_interceptor_test.dart` | |
| Onboarding, profile, sign-out | EXISTS | `features/onboarding`, `test/features/onboarding/onboarding_flow_test.dart` | |
| JSON data export | **PARTIAL** | `auth_service.export` exports only `OWNED_MODELS` (concepts, documents, questions, practice_sessions, ai_generations, suggestions) + options, answers, subscription, sync_items | Missing: own exams, own topics/patterns, syllabus_imports, topic_completions, bookmarks, session_items, question_issues, passages, figure metadata, ai_explanations, document page text. Test `test_export_contains_only_the_accounts_data` checks isolation, not completeness |
| Account deletion | EXISTS / NEEDS_VALIDATION | `auth_service.delete_account` (password, deletes stored PDFs), FK cascades | No test that every owner table is emptied; backups keep data 14 days (`infra/production/backup.sh`) — must be stated in policy |
| EN/HI, theme, server status | EXISTS | `features/settings`, `arb_parity_test.dart`, `settings_screen_test.dart` | Hindi strings not native-reviewed |
| Legal texts | PARTIAL (drafts) | `features/legal`, `docs/legal/play-data-safety.md`; CLAUDE.md "DRAFTS with [placeholders]" | Needs counsel |
| Exam catalog, private exams, My exams, switcher | EXISTS | `models/exam.py`, migrations `0012`/`0014`, `tests/test_exam_topics.py`, `test/features/exams/*` | |
| Syllabus import PDF/typed, sections, revised ticks | EXISTS | `domain/syllabus.py`, migrations `0020`/`0021`, `tests/test_syllabus.py`, `syllabus_test.dart` | |
| AI topic draft (Plus) | EXISTS | `POST /ai/exams/{code}/topic-draft`, `tests/test_ai_taxonomy.py` | Never saved without learner |
| Verified formats CGL/CHSL Tier-I | EXISTS | migrations `0003`, `0018` with source fields | Only two |
| PDF upload ≤25 MB, magic bytes, PDFium | EXISTS | `document_service.py`, `tests/test_documents_upload.py` | No malware scan |
| Text layer / OCR en+hi, low-confidence flags | EXISTS / NEEDS_VALIDATION | `extraction.py`, `integrations/ocr.py`, `tests/test_document_processing.py`, `test_text_quality.py` | Accuracy on real scans unmeasured |
| Question/option/passage/answer-key detection | EXISTS (supported layouts) | `domain/segmentation.py`, `tests/test_segmentation.py` | `EXPECTED_OPTIONS = 4` default; passages need a stated range |
| Typed answers, Q&A notes | EXISTS | `domain/typed_answers.py`, `qa_notes.py`, `tests/test_typed_answers.py`, `test_written.py` | |
| Figures from text PDFs; scanned → flagged | EXISTS / PARTIAL | `domain/figures.py`, `services/page_layout.py`, `tests/test_figures.py` | Scanned / multi-column / rotated give no crops |
| Import progress, solve / read / review | EXISTS | `import_progress.dart`, `paper_solve_read_test.dart`, `documents_screen_test.dart` | |
| Manual correction, verify, bulk verify-clean | EXISTS | `question_service.update`, `tests/test_question_bank.py` | Edits overwrite the as-found answer (see §3) |
| Rule topic/pattern suggestions, AI topic suggestions | EXISTS | `domain/topics.py`, `services/patterns.py`, `tests/test_topics.py`, `test_ai.py` | 83/100 coverage on one sample, accuracy unvalidated |
| Paper date/shift suggestion | EXISTS | `domain/paper_date.py`, `tests/test_paper_date.py` | |
| AI paper reading (Plus) | EXISTS / NEEDS_VALIDATION | `ai_paper_reader.py`, `domain/ai_reading.py`, `tests/test_ai_reading.py` | No real provider call yet |
| Concepts, filters, mastery, topic evidence | EXISTS | `features/concepts`, `features/mastery`, `mastery_rules_test.dart`, `study_syllabus_test.dart` | |
| Search + Google on tap | EXISTS | `question_service._text_conditions`, `paper_search_test.dart` | |
| RAG answer / quick answer (Plus) | EXISTS / NEEDS_VALIDATION | `rag_service.py`, `domain/rag.py`, `tests/test_rag.py`, `ai_flow_test.dart` | Quality, cost, latency unmeasured |
| Report a question | EXISTS | `POST /questions/{id}/report` | Creates an issue; no operator queue for shared content |
| Practice 1–100, filters, verified default, shared toggle | EXISTS | `practice_service.py`, `tests/test_practice.py`, `practice_flow_test.dart` | |
| Mocks with server timer, auto-submit, shortfall | EXISTS | `practice_service.create_mock`/`_availability` | One overall timer; sectional timers recorded only |
| Offline packs + re-marked upload | EXISTS | `tests/test_offline_practice.py`, `practice_offline_test.dart`, `answer_queue_test.dart` | Unsent sessions erased on sign-out |
| Bookmarks, incorrect list, history | EXISTS | `endpoints/practice.py`, `question_bank_test.dart` | Shared questions not bookmarkable |
| AI explanations / AI questions (Plus) | EXISTS | `ai_explanations`, `origin='ai'` CHECKs, `tests/test_ai.py` | |
| Revision ladder 1/4/7, ratings, due counts | EXISTS | `features/revision/domain/revision_schedule.dart`, `revision_schedule_test.dart` | |
| Daily reminders | NEEDS_VALIDATION | `features/reminders`, `reminder_controller_test.dart` | Never run on a device; web unsupported |
| Repeats, not-repeated, similarity, sample warning | EXISTS | `insights_service.py`, `domain/similarity.py`, `tests/test_insights.py`, `repeats_test.dart`, `not_repeated_test.dart` | |
| Shared bank + starter papers | EXISTS (empty) | `shared_bank.py`, migration `0017`, `tests/test_shared_bank.py`, `test_starter_papers.py` | No published content |
| Repeat Radar | HIDDEN | `domain/radar.py`, `tests/test_radar.py`; `AppFeatures.repeatRadar=false` (`lib/app/app_features.dart`) | |
| Home Today, plan, weak topics, progress, weekly review, focus, recall, streak | EXISTS | `home_screen_test.dart`, `study_plan_section_test.dart`, `weekly_review_test.dart`, `focus_*_test.dart` | |
| Daily quote | HIDDEN | `AppFeatures.quotes=false` | |
| Topic lesson / topic quiz | HIDDEN | `AppFeatures.learnStart` (env `LEARN_START`), `learn_flow_test.dart` | Waits for buyable Plus |
| Plus entitlement + 300/month allowance | EXISTS | `plus_service.py`, migration `0023`, `tests/test_plus.py`, `plus_gating_test.dart` | |
| Payments (Play / web / Apple) | MISSING | `subscriptions.source` allows `play`,`web` but nothing writes them | |
| AI validation, content-free AI logging | EXISTS | `domain/ai_content.py` validators, `ai_generations` has no text column | |
| Sync concepts, cards, reviews, profile, settings | EXISTS / NEEDS_VALIDATION | `sync_service.py`, `schemas/sync.py` (`EntityName`), `tests/test_sync.py`, `sync_engine_test.dart` | LWW; two real devices never tested |
| Device list / remote sign-out | MISSING | refresh_tokens has no device label; no endpoint | |
| iOS build | PARTIAL | `.github/workflows/test-ipa.yml` builds an **unsigned** test IPA | The brief says "not built"; signing/store build is missing |
| Multi-select questions | MISSING | `answer_type IN ('choice','typed','written')` CHECK in `models/question.py` | |
| Response-sheet checker | MISSING | — | Needs real sample |

### 2.2 Brief §3 requirements

| Requirement | Status | Evidence / gap |
|---|---|---|
| **3.1 Exam configuration engine** | PARTIAL | Exams are data (`exams`); formats are data with sources (`exam_formats`). Missing: country/region, authority, aliases, languages, exam version vs identity, effective/retired dates, verification status (a row's existence = verified), reviewer, question types, scoring rules beyond one negative mark, partial credit, sectional timing enforcement, navigation/calculator policy, change history, validation tool. Past attempts **are** reproducible: `session_items.marks_correct/marks_wrong` snapshot + `practice_sessions.exam_format_id` (RESTRICT). Mocks only exist for formats; unverified formats can't run mocks (no row). **Defect:** `practice_service.create_mock` uses `negative_marks_per_wrong or 0.0` and `per_question = 1.0` when `max_marks` is missing — a missing official fact silently becomes a rule (both current rows are complete, so no live impact). |
| 3.2 Canonical taxonomy | MISSING | `topics` are exam-scoped strings (`exam_codes[]`, owner); mock sections map to questions by subject-name string match (`same_subject` in `_availability`). Learner topics are already separate from shared ones (`owner_id`). Original wording is preserved (questions keep their text; topics only link). |
| 3.3 Content sources / cold start | PARTIAL | Personal library EXISTS (private by `owner_id`, `tests/test_ownership.py`); curated library PARTIAL (shared bank with rights basis + source CHECK, operator CLI, empty); educator collections MISSING; no-upload diagnostic MISSING; takedown/complaint workflow MISSING; publication audit MISSING (only `shared_at`); territory/expiry/attribution MISSING. |
| 3.4 Document intelligence | PARTIAL | Page number + pages per question, figure page + box, source document id + sha256, `extracted_by`, issues with reason codes EXIST. Missing: per-page language detection, languages beyond en/hi (CHECK constraints on `documents`, `questions`, `concepts`, `ai_explanations`), scanned-figure crops, multi-column reading order, cross-page continuation, multi-select/matching, **original-as-found answer and wording kept after manual edit**, review history, separate answer/explanation/topic verification states (one `verification_status` today). |
| 3.5 Learning diagnosis / adaptive practice | MISSING (foundation EXISTS) | Mastery levels and weak-topic rules with visible thresholds exist (`features/mastery`, `analytics_rules_test.dart`); `session_answers.time_spent_ms` is recorded but unused; no difficulty field anywhere; no error categorisation. |
| 3.6 Spaced repetition (FSRS) | MISSING | Ladder + ratings only; review history kept (`card_reviews`) so FSRS could be evaluated offline against it. |
| 3.7 Readiness dashboard | MISSING | Progress shows raw counts and accuracy; no readiness/coverage indicator. |
| 3.8 Historical analytics | PARTIAL | Year/shift counts, reviewed-only, sample warnings, personal vs shared EXIST; syllabus-version coverage, trend comparisons, difficulty, country/version filters MISSING. Radar thresholds (≥2 accounts) EXIST but are low for privacy (k-anonymity) and don't de-duplicate one learner uploading many copies beyond shift-level counting. |
| 3.9 Localisation | PARTIAL | UI strings localised (ARB, parity test); Devanagari fonts; timezone-aware analytics. Missing: separate exam / question / explanation / AI-response language settings, RTL, more scripts, locale currency. AI prompts hard-code "Indian students … SSC CGL and SSC CHSL" (`domain/ai_content.py` `SYSTEM`). |
| 3.10 Accessibility / low bandwidth | PARTIAL | `test/a11y/accessibility_test.dart` exists; offline packs exist. No WCAG audit, no reduced-motion setting, no figure descriptions, no low-bandwidth mode. |
| 3.11 Sync & devices | PARTIAL | Outbox, cursor, tombstones, advisory lock, idempotent offline-session upload (`client_id`) EXIST. Missing: device list, remote sign-out, entity versions / conflict detection (push overwrites; `sync_service.push`), sync-status UI with recoverable errors, multi-device tests, documented restore drill. |
| 3.12 Payments / entitlements | PARTIAL | Central server entitlement (`subscriptions`, `guard_ai`) EXISTS; provider verification, events, renewals, refunds, grace, prices MISSING. |
| 3.13 Institutions | MISSING | Defer (brief agrees). |
| §5 AI rules | PARTIAL | Labelling, schema validation, rejection of invalid output, provenance CHECKs, quotas, content-free logs EXIST. Missing: explicit "document content is untrusted data" framing and prompt-injection tests (no matches for "injection"/"untrusted" in `app/` or `tests/`); AI rate limit per process; provider fallback none (fine). |
| §8 Product metrics | MISSING (by design) | No telemetry. Any metric must be designed privacy-first (aggregate, server-side, no content). |

---

## 3. Technical debt and scalability risks

Ordered by risk to data integrity and trust first, then scale.

1. **As-found answer is overwritten.** `question_service.update` sets `correct_option_position` and
   `answer_source="manual"`, discarding what the key said; stem/option edits likewise replace the text.
   This breaks the brief's traceability rule ("original answer as found", "version history after manual
   correction") and makes "official-key matched" impossible to show later. Fix before any curated
   publishing.
2. **Missing format facts default to rules.** `negative_marks_per_wrong or 0.0`, `max_marks` → 1.0 per
   question (`practice_service.create_mock`). Must refuse instead.
3. **Export is incomplete** (see §2.1). A data-access request today would omit topics, syllabus imports,
   bookmarks, revisions-of-questions etc. There is no test that new owner tables join the export.
4. **Sync is unconditional LWW.** A stale device can overwrite a newer note; card reviews are
   synchronised as entities (upsertable) rather than append-only events. No version token on push.
5. **Language is a CHECK constraint (`'en','hi'`)** on four tables plus Pydantic `Literal`s
   (`schemas/sync.py`) and Dart enums. Adding a language is a migration + app release. Fine for
   India-first; must become a reference list before any non-Hindi market.
6. **Prompt framing is SSC-specific and injection-naive.** `SYSTEM` names SSC CGL/CHSL for every
   exam; paper text and RAG sources are sent without an explicit untrusted-data boundary or tests.
7. **Single-VPS operations.** PDFs on a local volume (`LocalDocumentStorage`), figures as PNG bytes in
   Postgres (`question_figures.data`), per-process AI rate limit and metrics, nightly dump only (no
   restore drill documented as tested). Acceptable for a controlled launch; S3-compatible storage and a
   restore test are needed before growth.
8. **Section matching by name strings.** Mock sections pick questions by subject/section name
   (`same_subject` in `_availability`), and topics are per-exam rows with no shared identity, so the
   same topic in two exams (or two syllabus versions) counts separately. Canonical IDs fix this.
9. **Deprecated `/api/v1/concepts` store** coexists with synced concepts; the model is still exported
   (`OWNED_MODELS`). Retire it (with an export of any remaining rows) to avoid confusion.
10. **No typed Dart client** — every feature hand-parses DTOs; contract drift is caught only by tests.
11. **Unvalidated heuristics presented with rules**: weak-topic thresholds, mastery rules, topic-rule
    coverage. They are labelled as rules in the UI, which is right; they need outcome data before being
    called "diagnosis".
12. **Device behaviour unverified**: notifications, secure storage, PDF picker, R8, two-device sync.

Scalability is not the bottleneck: one Postgres + one worker handle the expected first-launch load.
The real constraints are content rights, verification throughput and AI cost — the roadmap targets
those first.

---

## 4. Database and API changes required

### 4.1 Brief §4.4 concepts compared with existing models

"Reuse" = already modelled, do not add a table. "Extend" = add columns/constraints to the existing
table. "New" = a genuinely missing concept. "Defer" = not until its phase is validated.

| Brief concept | Existing | Decision |
|---|---|---|
| Country / Region | — | **Extend** `exams` with `country_code` (ISO 3166-1, nullable for private exams). No table until >1 country. |
| ExamAuthority | `exams.category` (free text) | **New** small `exam_authorities` (code, name, country, website) referenced by `exams.authority_code`, only in the exam-config phase. |
| Exam | `exams` | **Reuse** (+ `aliases text[]`, `languages text[]`, `country_code`, `authority_code`). |
| ExamVersion / ExamFormat | `exam_formats` (one row = one sourced format, e.g. `SSC_CGL_2026_TIER1`) | **Extend** `exam_formats` into the versioned format: `status` draft/verified/retired, `effective_from/to`, `supersedes_id`, `languages`, `question_types`, `sectional_timing`, `scoring` JSONB (validated by a pure schema), `reviewed_by`, `review_notes`. Existing rows migrate to `verified`. Don't add a separate `exam_versions` table — the format row already *is* the version. |
| ExamSection | `exam_formats.sections` JSONB | **Reuse** JSONB, validated by a pure `domain/exam_format.py` validator; add `taxonomy_node_id` per section when the taxonomy exists. |
| ScoringRule | `negative_marks_per_wrong`, section `max_marks`, `session_items.marks_*` snapshot | **Extend** via `scoring` JSONB (per section / per answer type; multi-select rule only when needed). Snapshot stays in `session_items`. |
| SyllabusVersion | `syllabus_imports` (per learner) | **Extend**: official syllabus = `syllabus_imports` row with `owner_id` NULL, `exam_format_id`, `source_*` fields, `status`. Same table serves learner and official versions. |
| SyllabusNode | `topics` (+ `subject`, `syllabus_import_id`) | **Reuse** topics as exam-specific nodes; add optional `parent_id` only if a target exam needs depth > 2. |
| CanonicalConcept / ConceptAlias | — (`concepts` is learner notes — name clash!) | **New** `taxonomy_nodes` (stable key, kind subject/topic/subtopic, parent) + `taxonomy_labels` (node, language, label, is_alias). Do **not** reuse the name "concept". |
| ExamTopicMapping | — | **New** `topic_taxonomy_links` (topic_id, node_id, status suggested/confirmed/rejected, confidence, reviewer, created_at); many-to-many; history by never updating in place (supersede rows). |
| Document / DocumentPage | `documents`, `document_pages` | **Reuse**; add `detected_language` per page later. |
| ExtractionJob | `documents.status/attempts/lease_*`, `ai_read_*` | **Reuse** (queue on the row). A jobs table only if a third job type appears. |
| Question / QuestionOption / QuestionPassage | `questions`, `question_options`, `passages` | **Reuse**. |
| QuestionAsset | `question_figures` | **Reuse**; add `source` (pdf_object / scanned_region / reviewer) when scanned crops arrive. |
| AnswerKeyRecord | `correct_option_position` + `answer_source` | **New** `question_answer_records` (question, kind found_in_key / inline / learner / reviewer / official_match / ai_suggestion, value, evidence, actor, created_at). `questions.correct_option_position` stays the *effective* answer so practice/scoring code is unchanged. |
| QuestionReview | `question_issues`, `verification_status`, `verified_at` | **New** `question_revisions` (append-only before/after of stem/options/answer/topic, actor, reason). Issues stay as they are. |
| QuestionSourceLink | `document_id`, `source_question_number`, `source_pages`, figure boxes | **Reuse**; add `source_sha256` copy only if documents become replaceable. |
| ContentRightsRecord | `documents.shared_rights_basis/shared_source/shared_at` | **New** `content_rights` (document or collection, rights holder, basis, permitted uses, territory, attribution, review_by, decided_by) once a second collection type exists; keep the existing CHECK as the minimum. |
| QuestionCollection / CollectionMembership | shared bank = set of shared documents | **Defer** until educator collections or a curated diagnostic set needs grouping across papers; then `collections` + `collection_items`. |
| PracticeSession / PracticeResponse / MockAttempt | `practice_sessions` (mode practice/mock), `session_items`, `session_answers` | **Reuse**. Do not split mocks into a separate table. |
| MasteryEvidence / LearningDiagnosis / StudyRecommendation | computed on device from analytics | **Compute, don't store** at first (pure functions + server raw counts, like `buildStudyPlan`). Store only if recommendations must be audited or synced. |
| RevisionCard / RevisionReviewEvent | Drift `revision_cards`, `card_reviews`, synced | **Reuse**; make `card_review` append-only in sync (reject updates). |
| DeviceSession | `refresh_tokens.family_id` | **Extend** `refresh_tokens` (`device_label`, `platform`, `last_used_at`); a "device" = a token family. No new table. |
| SyncChange / entity version | `sync_items.seq` | **Extend**: client sends `base_seq`; server rejects stale writes for entities whose policy is "detect". |
| Subscription | `subscriptions` | **Reuse**. |
| Entitlement | `PlusService` computed from subscription | **Reuse** (computed). |
| PaymentProviderEvent | — | **New** `billing_events` (provider, event id UNIQUE, type, purchase token hash, raw status, processed_at) for idempotency. |
| Organisation / Classroom / Assignment | — | **Defer** (brief §3.13). |
| ConsentRecord | `users.radar_opt_in(_at)`, `age_confirmed_at` | **New** `consents` (user, purpose, version, granted_at, withdrawn_at) only when a second consent purpose (e.g. AI processing, telemetry) appears; until then columns are enough. |
| AuditEvent | `ai_generations` (AI only), request logs | **New** `audit_events` (actor, action, target type/id, at, request_id; no content) for publishing, takedown, operator grants, account deletion. |

Net: of ~40 brief concepts, ~22 are already modelled; **8 new tables** are proposed across all phases
(`exam_authorities`, `taxonomy_nodes`, `taxonomy_labels`, `topic_taxonomy_links`,
`question_answer_records`, `question_revisions`, `billing_events`, `audit_events`) plus `content_rights`
and `collections` later.

### 4.2 API changes (all additive under `/api/v1`)

- `GET /auth/sessions`, `DELETE /auth/sessions/{family_id}`, `POST /auth/sessions/revoke-others`.
- `GET /exam-formats` gains `status`, `effective_from/to`, `languages`, `question_types`; mocks list
  only `verified` formats. Operator: `python -m app.cli.exam_formats validate|publish|retire` (no
  public write API).
- `GET /questions/{id}` gains `answer_provenance[]` and `revisions` (owner only); `PATCH` writes a
  revision + answer record instead of overwriting history.
- `POST /sync/push` accepts optional `base_seq` per change; response adds `conflicts[]` (backward
  compatible: old clients omit it and keep LWW).
- `POST /billing/play/verify`, `POST /billing/play/rtdn` (Pub/Sub push), later web/Apple.
- `GET /taxonomy/...` read endpoints when the taxonomy lands.
- `GET /diagnostic`, `POST /diagnostic/{id}/answers` (or reuse practice sessions with a
  `mode='diagnostic'` CHECK extension — preferred, no new tables).

---

## 5. Prioritised roadmap (vertical slices)

Each phase ships: Alembic migration(s) with downgrade, pure domain rules with unit tests, service +
API tests on real Postgres, mobile UI with l10n (EN + HI) and widget tests, OpenAPI export, docs
(`docs/*.md` + CLAUDE.md), and an acceptance report (implemented / tested / not tested / risks).
Unfinished UI goes behind `AppFeatures`.

Order follows brief §14 with two deliberate changes: **answer provenance moves early** (it is cheap,
blocks curated publishing and costs trust if done late), and **payments come after sync/devices** but
before global exam config, because Plus (and the hidden learn features) cannot launch without them.

### Phase 1 — Release safety (proposed first; small, no new product surface)

Scope:
1. **Devices & remote sign-out.** Migration `0029`: `refresh_tokens` + `device_label`, `platform`,
   `last_used_at`. `GET /auth/sessions`, `DELETE /auth/sessions/{family}`, revoke-others. Mobile:
   Profile → "Signed-in devices" list with "Sign out" per device. Tests: revoking a family makes its
   refresh fail; current-device marker; other accounts → 404.
2. **Complete data export.** Add the missing owner-scoped data (own exams, topics, patterns,
   syllabus_imports, topic_completions, bookmarks, session_items, question_issues, passages, figure
   metadata, ai_explanations, page text). Guard test that walks `Base.metadata` and fails when a table
   with `owner_id` (or a child of one) is not covered by export **and** delete.
3. **Format integrity guard.** Pure `domain/exam_format.py` `validate_format()`; mocks refuse a format
   with any missing scoring fact instead of defaulting (`or 0.0`, `1.0`); tests for both seeded formats
   and for nulls.
4. **AI untrusted-input boundary.** Wrap paper text / RAG sources in delimited "data, not instructions"
   blocks; make `SYSTEM` exam-agnostic (exam name from the catalog row); tests with injected
   instructions in fixture PDFs (`tests/pdf_factory.py`) proving output validation still rejects.

Out of scope: payments, sync conflicts, legal text (counsel), device testing (needs hardware).
Exit: export/delete coverage test green; sessions revocable from another device; no scoring default
can invent a rule; injection fixtures covered.

### Phase 2 — Answer provenance and question history

Migration: `question_answer_records`, `question_revisions`; backfill one `found_in_key`/`inline`
record from current `answer_source` (manual rows get a `learner` record with "original unknown").
`PATCH /questions/{id}` appends instead of overwriting. Visible states per brief: Extracted · Needs
review · Learner reviewed · Official-key matched (only when an official key is attached) · AI-generated.
Mobile: provenance panel on the question screen. Tests: state transitions, learner review never shows
as official, practice/scoring unchanged (effective answer column untouched).

### Phase 3 — Conflict-aware sync and sync status

`base_seq` on push; per-entity policy (`card_review` append-only, `concept` detect + keep both as
"conflicted copy", `setting`/`study_profile` LWW); sync-status UI with retry and last-synced time;
two-device integration tests with `FakeSyncServer` and a server test with interleaved pushes; backup
restore drill documented in `docs/deployment.md`.

### Phase 4 — Payments and entitlements (Google Play first)

`billing_events`; server-side Play Developer API verification + RTDN; renewals/grace/refund →
`subscriptions.active_until`; idempotency on event id; Plus purchase UI; then flip
`AppFeatures.learnStart`. Web/Apple are later slices (same table). Needs founder decisions: prices,
regions, tax registration, Play merchant account.

### Phase 5 — Exam configuration engine v1

Extend `exams` (country, authority, aliases, languages) and `exam_formats` (status, effective dates,
supersedes, question_types, sectional timing, scoring JSONB, reviewer). Operator CLI validate /
publish / retire; mocks only from `verified` + effective formats; **sectional timers enforced** in
mocks when `sectional_timing` is true (CGL); attempts keep their `exam_format_id` and snapshot.
Tests: positive/negative/no-negative marks, version change mid-history, unverified format cannot mock.
No new exam formats are added without an official source (operator task, not code).

### Phase 6 — Canonical taxonomy and syllabus versions

`taxonomy_nodes`, `taxonomy_labels`, `topic_taxonomy_links`; official syllabus versions as
`syllabus_imports` rows with source fields. Seed only the SSC shared topics (mapping reviewed by a
human, suggestions flagged). Mock section ↔ question matching moves from name strings to node IDs
with string fallback. Analytics show unmapped/uncertain counts.

### Phase 7 — Cold start and content governance

`mode='diagnostic'` sessions over a small **original or licensed** sample set (needs content first:
founder/operator task); preliminary topic profile + sample plan using existing `buildStudyPlan`.
`content_rights`, `audit_events`, takedown/complaint flow (operator CLI + learner "report content"),
publication audit. Populate the shared bank via `starter_papers` only with recorded rights.

### Phase 8 — Document intelligence for the India launch

Scanned-page figure regions (from retained page images + reviewer-adjustable boxes), multi-column
reading order, cross-page passages, per-page language detection; extraction-accuracy benchmark on
generated fixtures + a consented private sample set; multi-select only if CGL/CHSL or the next Indian
exam needs it.

### Phase 9 — Learning diagnosis, readiness, FSRS evaluation

Use `time_spent_ms`, recency and repeat errors; "insufficient evidence" fallback; every
recommendation carries its reason (extends `buildStudyPlan`). FSRS evaluated offline against
`card_reviews` history before any default change; ladder kept as an option. Readiness = coverage +
evidence panel, never a pass probability.

### Phase 10 — Next Indian exam, then localisation for one international pilot

Second exam end-to-end (format + syllabus + taxonomy mapping, all sourced). Then lift `en|hi` CHECKs
to a reference list, separate exam/question/explanation/AI languages, RTL if the chosen market needs
it, local pricing. Market chosen with the brief's §6.2 scorecard (founder decision).

### Later — Institutions (brief Phase 6)

Only after B2B demand is shown: organisations, roles, collections, assignments.

---

## 6. Decisions needed from the founder

1. Confirm Phase 1 scope above (or start with Phase 2 / payments instead).
2. Payments: Google Play only at launch? Prices and regions?
3. Cold start: who provides the sample diagnostic content and under what rights?
4. Second Indian exam category for Phase 10 (banking, railways, state PSC …).
5. Age strategy: stay 18+ (recommended until a minors' design exists).
