# Any-exam work: Phase 1 report (exam profile)

Decisions from the Phase 0 audit were taken as recommended. Everything visible to learners is behind the
`examProfiles` flag, which is off, so SSC students see no change.

## What changed

**Characterization tests, added before anything moved**
- `tests/test_ssc_characterization.py`: generated SSC-style papers go through the real parser, suggestions, review and
  repeats report. Pinned in `tests/golden/`: question reading, topics, models, counts by year, sort order, worded-alike
  links, the Not repeated view, and the seeded exams, syllabus, models and formats.
- `test/features/insights/repeat_rules_characterization_test.dart`: the "seen in most papers" and small-sample lines.
- `python -m app.cli.characterize save|compare`: the same check on real imported papers. It writes hashes and counts only,
  to `~/.preploop/characterization`, never to the repository.

**Structural (results unchanged)**
- `exam_formats.tier` is now `stage` (column, API, operator tool, format files).
- Exam profile fields on `exams`: kind, options per question, repeat share, minimum papers, reliable papers, counting unit,
  exam dates. Unset values come from `data/exam_templates/defaults.json`.
- SSC CGL and CHSL templates and format files are now JSON data, and tests hold them equal to the migrated rows.
- The parser, AI prompts and the app's repeat rules read the profile. `EXPECTED_OPTIONS`, `OPTIONS_PER_QUESTION` and the
  fixed `RepeatRules` numbers are gone.
- The app's built-in exam list is generated from the templates (`scripts/export_exam_data.py` → `exam_data.g.dart`).
- A test now fails if an exam name appears in app code. All such names and examples were removed from `app/` and `lib/`.
- `Dockerfile` copies `data/`, which the server now reads at run time.

**Behaviour (flag `examProfiles`, off; `--dart-define=EXAM_PROFILES=true`)**
- Custom exam builder (`exam_builder_screen.dart`): name, conducting body, question style, options, languages, dates,
  stages with sections, timers, cutoffs and marking. Only the name is needed.
- Onboarding asks "What are you preparing for?" and offers "Custom exam".
- `POST /me/exams` and `PATCH /me/exams/{code}` take the profile; a plain name still works. New `GET /me/exams/{code}/stages`:
  reviewed formats for catalog exams, the learner's own entry for their exams, marked `verified: false`.
- Operator tool: `python -m app.cli.exam_formats template FILE [--apply --reviewer NAME]`. It refuses templates with
  unsourced facts, missing facts or uncertain flags, and examples.

## Migrations

All three are reversible. Checked by a round trip on the test database.

| Migration | Change |
| --- | --- |
| 0041 | Renames `exam_formats.tier` to `stage` |
| 0042 | Adds the profile fields; writes today's values on SSC CGL and CHSL |
| 0043 | Adds `exams.custom_stages` |

No paper, question, topic or model needed moving: all 30 dev papers already have an exam. No general SSC profile was made.
The dev database is still at 0040, because the API running from the main checkout expects `tier`. Run `alembic upgrade head`
after merging.

## Tests added

| File | Covers |
| --- | --- |
| `tests/test_ssc_characterization.py` | The golden comparisons above |
| `tests/test_exam_profile.py` | Defaults, SSC data equal to migrated rows, parser follows the exam, generated app data current, no exam names in code |
| `tests/test_custom_exam_profile.py` | Builder API, refusals, privacy, stages, templates and their sources |
| `test/features/insights/repeat_rules_characterization_test.dart` | Rule boundaries, exams with their own numbers, old cached exams |
| `test/features/exams/exam_builder_test.dart` | Flag off keeps today's wording; builder from onboarding and My exams |

Real papers: 13 of 13 checks (9 SSC papers and the reports of their accounts) were unchanged after migrations 0041 to 0043,
compared inside a transaction that was rolled back, so the dev database stayed at 0040.

## Templates

| Template | Status | Source | State |
| --- | --- | --- | --- |
| SSC CGL, SSC CHSL | Verified | Existing sourced formats | `options_per_question` flagged: kept from behaviour, not yet checked against the notice's wording |
| NEET UG | Draft | NTA Information Bulletin 2026, Chapter 4 (third-party copy) | 180 questions, 180 min, +4/−1/0, 4 options, 13 languages. Publication date is from news. A June re-exam with 195 minutes was reported in the news and not confirmed |
| IBPS PO | Draft | IBPS CRP PO/MT-XV (third-party copy) | Prelims: 30/35/35 questions, 20 min each. **Option count not stated. Penalty left empty** (see below) |
| UPSC CSE Prelims | Draft, no facts | None | upsc.gov.in refused automated reading |
| JEE Main | Draft, no facts | None | Only coaching sites were reachable. Not in the catalog until applied |
| University exam | Example only | None | No university chosen; claims no facts |

## Corrections to the audit

- **IBPS PO may not be the 5-option exam.** Its notification doesn't state an option count, so the acceptance test's
  "5 options, negative marking" template is still unconfirmed.
- **Marking is less simple than the audit said.** IBPS deducts one fourth of the marks assigned to the question, and those
  marks differ by section (30 marks for 35 questions in one). One number per format can't hold that, so the format stays
  incomplete and can't start a mock until Phase 6.

## Found along the way

- **Tied worded-alike groups have no fixed order.** Groups are ranked by papers and then size, but ties follow the database's
  row order, so they can swap between requests. This existed already and is left as it is. The test pins the defined part.
  A fix is one `ORDER BY`, if you want it.

## Limits

- `options_per_question: variable` is stored, but the parser still checks those papers against the default count. Phase 3
  handles it properly.
- Challenge Ladder still has its literal 4 options and Tier wording (Phase 5).
- The builder has no edit screen yet. The API supports it. Languages offer English and Hindi only (Phase 6).
- Stages a learner enters are stored and shown by the API, but mocks and the ladder don't use them until Phases 5 and 6.
- `countingUnit` and `examDates` are stored and not used yet (Phase 4).
- Hindi strings have had no native-speaker review.

## Open questions

1. Which official source do you have for IBPS's option count, and is CRP XV still the latest? Search results mention XVI.
2. Can you supply the UPSC notification and JEE Main bulletin as PDFs, as with RRB? Those two sites couldn't be read here.
3. Which university exam should the descriptive template use?
4. Should the Phase 5 ladder times follow the brief (about 40 % shorter for SSC) or stay near today's?
