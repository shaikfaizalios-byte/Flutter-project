# Any-exam work: Phase 0 audit

Audited `main` at a343bd5 (migrations at head 0040). No code was changed. The dev database was only read, with a
read-only connection and aggregate counts.

Line numbers are for that commit. "P1" to "P7" are the phases of the brief.

## 1. The short version

PrepLoop is much less tied to SSC than the brief assumes. Exams are already data, and there is no SSC wording in the app's
text. The real SSC assumptions are concentrated in a few places:

| Area | State today |
| --- | --- |
| App text (EN and HI ARB files) | No "SSC", "CGL", "CHSL" or "Tier" at all |
| Exam catalog, private exams, exam switcher | Already built |
| Every paper has an exam | Already true: `documents.exam_code` is required, and 0 of 30 dev papers lack one |
| Versioned, sourced exam formats | Already built (`exam_formats`), but only one marking number per format |
| Fixed four options | Real assumption, in 3 constants or literals, used in about 15 places |
| One correct answer | The deepest assumption: stored as one integer on the server, on the device and in scoring |
| Parser word lists | SSC section headings and subject words are built into the code |
| Seed data | 60 topics, 91 models and 607 keywords sit in migrations, not data files |
| Repeat thresholds | Fixed in the app, and not the numbers the brief states (see decision 1) |
| Challenge Ladder prompt | 4 lines carry SSC assumptions |

The brief's larger items are new work, not refactoring: question formats (P3), partial marks and cutoffs (P6) and descriptive
marking (P7). None of that exists yet, so the risk is in the size of those phases rather than in finding SSC references.

## 2. Findings by phase

### P1: Exam profile

**Exam names and facts in code**

| Where | What | Fix |
| --- | --- | --- |
| `apps/mobile/lib/core/exams/exam_catalog.dart:53-68` | `builtInExams`: SSC CGL and CHSL hard-coded as the fallback before the catalog loads | Generate from template data, or show an empty state |
| `apps/mobile/lib/features/exams/application/exam_catalog_controller.dart:15` | Comment on that fallback | Follows the line above |
| `services/api/migrations/versions/0001_create_exams_and_concepts.py:23-24` | The two SSC exams | History, stays (decision 5) |
| `services/api/migrations/versions/0012_exam_catalog_and_own_topics.py:30-45` | 14 catalog exams | History, stays; templates become the source |
| `services/api/migrations/versions/0014_exam_short_names.py:22` | Short names | History, stays |
| `services/api/migrations/versions/0003_question_bank.py:28-57` | CHSL Tier-I format (100 questions, 60 min, -0.5) | History, stays; template must equal it, enforced by a test |
| `services/api/migrations/versions/0018_ssc_cgl_2026_format.py:30-70` | CGL Tier-I format (100 questions, 60 min, 4 × 15 min, -0.5) | Same |

**The exam model today, against the brief**

| Brief field | Exists as | Gap |
| --- | --- | --- |
| `id`, `name` | `exams.code`, `name`, `short_name` (`app/models/exam.py`) | None |
| `conductingBody` | `exams.authority` | Name only |
| `languages[]` | `exams.languages` | Set for RRB NTPC only, on purpose |
| `isCustom` | `owner_id` set, code `MY_...` | None |
| `kind` | Nothing | New |
| `optionsPerQuestion` | Nothing | New |
| `thresholds`, `countingUnit` | Nothing | New |
| `examDates[]` | One device-side `targetExamDate` for the whole study profile (`apps/mobile/lib/core/database/tables.dart:65`) | Needs to be per exam |
| `stages[]` | `exam_formats` rows, one per stage; the stage name is in `tier` (`app/models/question.py:76`) | Rename to stage |
| `Section` | `exam_formats.sections` JSON (`part`, `subject`, `questions`, `max_marks`, `timer_minutes`) | `cutoff` missing |
| `MarkingScheme` | `negative_marks_per_wrong`, and `max_marks` ÷ questions for marks per question | See P6 |

**The word "tier"**

- `app/models/question.py:76`, `app/schemas/question.py:44`, `app/cli/exam_formats.py:59,96`. The app itself never reads it.
- Also in the format codes (`SSC_CGL_2026_TIER1`), which are data and can stay.

**UI text**

- `apps/mobile/lib/core/localization/arb/app_en.arb:140` "Select one or both." The onboarding hint assumes exactly two exams
  (used at `features/onboarding/presentation/onboarding_screen.dart:151`). It is an SSC leftover with no SSC word in it, so a
  word search would have missed it.
- `app_en.arb:139` "Which exam are you preparing for?" becomes the brief's "What are you preparing for?".
- Custom exam, several exams per student and the switcher on Home already exist. New work is the template choice and the
  builder for stages, sections and marking.

**Text that names SSC but isn't a defect**

- API docs examples: `app/api/v1/endpoints/analytics.py:44`, `insights.py:34`, `radar.py:32`. These reach OpenAPI, so replace
  them with a neutral example.
- Comments and tool help: `app/cli/exam_formats.py:3-11`, `app/cli/starter_papers.py:16-19`,
  `features/practice/domain/practice_models.dart:329,458`, `app/models/exam.py:31`, `app/domain/rag.py:95`,
  `app/domain/study_requests.py:130`, `app/domain/segmentation.py:1095`, `app/domain/paper_date.py:56`,
  `app/domain/topics.py:7`.
- Public text: `website/pages/index.html:32,151,159,197`, `website/pages/hi/index.html:32,95-96,104`,
  `apps/mobile/assets/legal/terms.md:9`, `README.md`. These use SSC as an example among others (decision 5).

### P2: Syllabus tree and topics

| Where | What | Fix |
| --- | --- | --- |
| `migrations/versions/0009_question_figures_and_topic_taxonomy.py:30` | Built-in syllabus: 4 subjects, 60 topics, 341 keywords | Move to template data, unchanged |
| `migrations/versions/0003_question_bank.py:63` | Older starter list (26 topics) | History; replaced by 0009 |
| `migrations/versions/0012_exam_catalog_and_own_topics.py:48-60` | `SHARED_TAXONOMY_EXAMS`: 11 exams share that syllabus, including banking and railways | Decision 7 |
| `migrations/versions/0038_rrb_ntpc_from_cen_2026.py` | 25 RRB NTPC topics and an alias | Move to template data |
| `app/models/question.py` (`Topic`) | Exactly two levels: `subject` and `name` | Needs tree of any depth |
| `app/models/taxonomy.py:27-28` | Canonical nodes are limited to subject and topic by a CHECK | Needs relaxing |
| `app/models/question.py:152` (`syllabus_imports`) | Imports are flat and have no version or effective year | New version table |
| `app/domain/syllabus.py:28` | `SUBJECT_WORDS`: aptitude, reasoning, awareness and similar decide what counts as a heading | Move to data, widen for other subjects |
| `app/services/insights_service.py:173` | Not repeated view uses the topics visible today, with no version | Use the version in force; add "Dropped" |

Already there and reusable: canonical topics, keyword suggestions that are never auto-confirmed, the optional AI topic step,
the PDF syllabus parser and its review, and `topic_scope`/`visible_topics` as the single visibility rule.

### P3: Question formats and paper import

**Fixed four options**

| Where | What |
| --- | --- |
| `app/domain/segmentation.py:31` | `EXPECTED_OPTIONS = 4`. The parser already accepts other counts as an argument |
| `app/services/segmentation_service.py:114,289,474`, `app/services/question_service.py:485` | The four callers that always pass 4 |
| `app/domain/ai_content.py:17` | `OPTIONS_PER_QUESTION = 4`, with a comment naming SSC |
| `app/domain/ai_content.py:140,161,589` | Prompts that say four options |
| `app/domain/ai_content.py:342,351` | Validation that rejects any other count |
| `app/domain/challenge_ladder.py:305-321` | Literal 4 and 0-3 (P5) |
| `app/domain/prompts/challenge_ladder_generator.txt:40,57` | Literal 4 (P5) |
| `app/schemas/question.py:286-287` | Editing allows 2 to 6 options, a fixed limit |
| `features/question_bank/presentation/question_review_screen.dart:526` | Same limit of 6 in the app |

The parser's labels are not the problem: `segmentation.py:201-202,230,235,248` already accept a to e and 1 to 9. Six dev
questions already have 5 options; today those are flagged as wrong.

**One correct answer (the largest single change)**

| Where | What |
| --- | --- |
| `app/models/question.py:227` | `answer_type` allows only choice, typed and written, and the column is 8 characters |
| `app/models/question.py:98` | `question_types` has the same 8-character limit |
| `app/models/question.py:235` | `correct_option_position` is one integer |
| `app/models/practice.py:127` | `selected_position` is one integer |
| `app/domain/scoring.py:24` | `correct_position` is one integer |
| `apps/mobile/lib/core/database/tables.dart:85` | Device queue is one integer (needs Drift v9) |
| 14 mobile files | They read or write the single position, including `session_screen.dart`, `result_view.dart`, `offline_practice.dart`, `paper_solve.dart` and `question_review_screen.dart` |

**Parser rules from SSC papers**

| Where | What |
| --- | --- |
| `app/domain/segmentation.py:160` | `KNOWN_SECTION_HEADINGS`: SSC section names, English and Hindi |
| `app/domain/segmentation.py:155-156` | Section letters stop at D ("Part E" is not recognised) |
| `app/domain/segmentation.py:1118` | `same_subject`: loose name match tuned on SSC names |
| `app/domain/paper_date.py:48` | Day-first dates (Indian order) |
| `app/domain/paper_date.py:53-57` | Shift pattern and first-page reading based on SSC paper layout |
| `app/domain/topics.py:21,73` | First sentence scores 3×, chosen for SSC stems. Harmless elsewhere, needs a check |

**Fields that don't exist yet**

- Paper: stage and set code. `language` is a single value. `exam_shift` is a number only.
- Group: `passages` (`app/models/question.py:186-194`) holds shared text only: no chart, table or case.
- Rich content: no LaTeX support anywhere. Images in questions and options already exist.
- Descriptive: marks, word limit, sub-parts and internal choice don't exist. `written` questions have only `model_answer`.
- Duplicates: only identical files are caught (`sha256`). Same paper in different sets, and translations, are not.
- Known limit: bilingual papers keep only the first language's options.
- Separate answer-key files: not supported. Keys must be inside the paper.
- Maths OCR: Tesseract can't read formulas. AI reading of the page image is the available route (decision 9).

### P4: Models and repeat analysis

| Where | What | Fix |
| --- | --- | --- |
| `migrations/versions/0010_paper_dates_and_question_patterns.py:32` | Starter list: 91 models, 266 keywords, on 37 topics | Move to data, unchanged |
| `apps/mobile/lib/features/insights/domain/repeats.dart:287` | `minPapers = 3` | Exam profile (decision 1) |
| `repeats.dart:288` | `share = 0.5` | Exam profile |
| `repeats.dart:292` | `reliablePapers = 5` (small-sample warning) | Exam profile |
| `features/insights/presentation/repeats_screen.dart:155,420-428,454,595-596` | Where those rules are used and shown | Read from the active exam |
| `app/services/insights_service.py:66-72` | Counts are per paper only, always | Add `countingUnit` |
| `app/domain/similarity.py:22-23` | 0.8 and 4 words | Unchanged: the brief keeps this matcher |
| `app/domain/radar.py:23` | 2 accounts | Privacy rule, not an exam fact: stays in code |

Missing: creating, renaming or merging models; "These look alike. Name this type?"; marks-weighted ranking; embeddings
(nothing exists: no pgvector, no provider; decision 8). Radar already counts by shift, so `countingUnit` has a working
example to follow.

### P5: Challenge Ladder

| Where | What |
| --- | --- |
| `app/domain/prompts/challenge_ladder_generator.txt:28` | "Tier 1 paper" |
| `challenge_ladder_generator.txt:29` | "Tier 2 / mains level" |
| `challenge_ladder_generator.txt:30` | "English, General Awareness and Reasoning": SSC subject names. The brief doesn't mention this line |
| `challenge_ladder_generator.txt:25-29` | Fixed seconds per level (30, 60, 75, 90, 2-3 min) |
| `challenge_ladder_generator.txt:18,40,57` | One multiple-choice format, 4 options |
| `app/domain/challenge_ladder.py:38-39` | Time limits 15 and 600 seconds |
| `app/domain/challenge_ladder.py:283-284` | `web_query` has no stage |
| `app/domain/challenge_ladder.py:305-321` | `validate_generated` is 4 options only |
| `app/domain/challenge_ladder.py:176-181,274,344-347` | Solver schema, prompt and check are single-answer only |
| `app/services/ladder_service.py` | Right or wrong only: no marks |

The round plan (`challenge_ladder.py:27-28`) and the copy and variety checks don't depend on the exam and can stay. Generated
questions already can't reach repeat counts: they are stored apart, and `tests/test_ladder.py` checks it.

### P6: Mock tests and languages

| Where | What | Fix |
| --- | --- | --- |
| `app/models/question.py:83` | One `negative_marks_per_wrong` per format; can't vary by section or question type | Per-section or per-type marking |
| `app/services/practice_service.py:488` | Marks per question = section marks ÷ questions, so all equal in a section | Allow varied marks |
| `app/domain/scoring.py:80-105` | Right, wrong or blank; blank always scores 0; no partial marks | `marksUnanswered`, `partialRules` |
| `app/services/practice_service.py:387,520` | Mocks leave typed-in questions out | JEE-style numeric sections need them |
| `app/services/practice_service.py:86-88,246,343,432` | Practice marks 1 and 0 | Fine for practice, except the brief's ladder scoring |
| `app/services/practice_service.py:92-93` | Starter check: 5 per subject, 20 at most | Product rule, stays |
| `app/domain/exam_format.py:49-94` | Completeness rules cover only today's fields | Extend |
| Nothing yet | Sectional cutoffs | New |

Already built: section order, sectional timers, marks by section, the languages reference list and per-exam language lists.
Missing: the bilingual toggle and regional-script rendering. The app bundles only Devanagari, and Tamil, Telugu, Bengali and
others would show as boxes because the web build fetches nothing from Google. Bundling them adds size.

`ai_content.py:441` decides a query's language as Hindi or English only, which regional languages would break.

### P7: Descriptive practice and marking

Nothing to fix, because nothing exists yet beyond `written` questions, the single-answer AI check (`POST
/ai/questions/{id}/answer-check`) and `written` flashcards. The whole phase is new: ladder, rubrics, photo capture,
double marking.

The dev database has 790 `written` questions in private exams, so descriptive material is already being imported and there
is real data to try this phase on.

## 3. Data found in the dev database

| Item | Count |
| --- | --- |
| Papers | 30: 9 SSC (2 CGL, 7 CHSL), 21 in 4 private exams |
| Papers without an exam | 0 |
| Questions without a paper | 0 |
| `choice` questions by number of options | 0: 90 · 1: 16 · 2: 4 · 3: 19 · 4: 1029 · 5: 6 |
| Shared topics | 85 (60 + 25 RRB NTPC) |
| Private topics | 43 |
| Models | 91 |
| Ladder sessions | 0 |

The 129 `choice` questions with 0 to 3 options look like incomplete extraction. I didn't look at each one, and this audit
doesn't change them. The characterization tests should pin how they're treated today.

## 4. Decisions needed before Phase 1

**1. Repeat thresholds: the brief and the code disagree.** The brief says "50%, 5 papers". The code has three numbers: at
least **3** papers and **50 %** to say "seen in most papers", and **5** papers before the small-sample warning goes away.
Setting `minPapers` to 5 would change what SSC students see, breaking the first ground rule.
*Recommendation:* three profile fields (`repeatShare` 0.5, `minPapers` 3, `reliablePapers` 5), which also become the defaults
for new exams.

**2. Characterization tests can't use real papers in the repo.** CLAUDE.md says test PDFs are generated, never real papers,
and papers are private.
*Recommendation:* two layers. Committed tests use generated SSC-style papers and run in CI. A local-only script compares the
9 real SSC dev papers before and after each phase and commits nothing. Your dev database then becomes part of the check.

**3. Extend the exam tables or replace them.** The brief describes a new `Exam` with nested stages. `exam_formats` already
gives versions, sources, a reviewer and effective dates.
*Recommendation:* extend. One stage stays one `exam_formats` row, `tier` is renamed `stage`, and the new fields go on
`exams`. JSON templates go in the existing `services/api/data/exam_formats/` and load through the existing check and publish
tool. A second parallel model would mean two sources of truth.

**4. Exam facts need official notices.** Templates for a bank PO exam, UPSC CSE Prelims, JEE Main, NEET UG and a descriptive
university exam need current notices, and I may not be able to reach those sites, as with RRB. They would stay drafts until a
named reviewer publishes them. Two specific questions:
- Which **bank PO exam**? It's also the only exam on your list likely to meet the "5 options, negative marking" acceptance
  test. I recall that pattern for IBPS PO, but that is from memory and must come from the notice.
- Which **university exam**? There's no general one, so I need a real exam and its official scheme. Otherwise the template
  would have to be a labelled example with no claimed facts.

**5. "Only in template data, nowhere else in the code" can't be literally true.** Past migrations contain exam names and
can't be rewritten, and tests name exams.
*Recommendation:* apply the rule to `services/api/app` and `apps/mobile/lib` and enforce it with a test that fails on any
exam name there. Exempt migrations and tests. Keep the website and terms naming SSC, UPSC and others as examples, since they
describe who the product is for.

**6. Phase 5's time rule would change SSC ladders.** Both SSC formats give 60 min ÷ 100 questions = 36 seconds:

| Level | Today | Brief's rule |
| --- | --- | --- |
| Easy | 30 s | 18 s |
| Medium | 60 s | 36 s |
| Medium-hard | 75 s | 45 s |
| Hard | 90 s | 54 s |
| Extreme hard | 120-180 s | 72-108 s |

That's roughly 40 % less time on every step, and it conflicts with "an SSC student sees no change". Extreme hard also needs
one number, not 2-3×.
*Recommendation:* accept the rule as a deliberate, listed change if the shorter times are what you want; otherwise rescale it
so SSC stays near today's values. This is your call. It doesn't block Phases 1 to 4.

**7. Who keeps the shared syllabus and models?** Today 11 exams use them, including IBPS, SBI and RRB, not just SSC. Marking
them SSC-only would remove topics from those learners.
*Recommendation:* keep the same 11 exams on the same data for now. Each can get its own list later.

**8. Embeddings need a new provider (Phase 4).** Nothing is in place, and Anthropic doesn't offer an embeddings model as far
as I know. A provider such as Voyage means sending paper text to another company, which needs a privacy policy change and a
new cost. A local model avoids that but adds memory use on the VPS, which I haven't measured.
*Recommendation:* decide at Phase 4. It's labelled a hint and could ship last or be dropped without touching the rest.

**9. AI cost and scanned content (Phases 3 and 7).** Formula OCR and handwriting both depend on AI reading images. Marking
twice or three times makes one answer cost 2-3 requests against the 300 a month allowance, and handwriting photos would go to
the AI provider, which needs consent and a privacy update.

**10. The general SSC profile may not be needed.** The brief expects papers with unknown exams. There are none, because the
field is required. The exam is already known and only the stage is missing.
*Recommendation:* no general SSC profile. Add a nullable `stage`, suggested from the paper's text and confirmed by the
learner, never guessed. The data migration then adds very little and stays reversible.

## 5. Also noted

- **RRB NTPC isn't in the brief.** It has four draft formats and its own topics. They need to move with the rest, so RRB
  becomes a third template that must not change.
- **Feature flags** exist only in the app (`AppFeatures`, `lib/app/app_features.dart`). There are none on the server. Phase 1
  needs one server setting, or new endpoints must stay unused until the app flag is on.
- **The `tier` rename changes the API.** No released app reads it, so this is safe now and harder after a store release.
- **Size.** Phase 3 touches the server, device database, offline pack, sync and 14 app files. It should land as several PRs.

## 6. What Phase 1 would start with

If you approve, in this order:
1. Characterization tests, on their own, before anything moves (decision 2).
2. Structural commits: move seed data to JSON files, rename `tier`, replace constants with values from the profile while the
   results stay the same.
3. Behaviour commits, behind a flag: template choice, the custom exam builder, profile fields.
