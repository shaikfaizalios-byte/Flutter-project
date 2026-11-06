# Any-exam work: Phase 3 report (question formats and paper import)

Built on Phase 2, on branch `claude/any-exam-phase-3`. New screens and new formats are behind the `examProfiles` flag, which
is off.

## What changed

**Question formats**
- Every question has a format: one correct option, assertion–reason, statement-based, true/false, typed-in, descriptive,
  several correct options, numerical (tolerance or range), fill in the blank, match, and ordering.
- Existing questions took the plain formats and keep the same path. Assertion–reason, statement-based and true/false are
  single-answer questions shown differently.
- The others keep their answer in `answer_spec`, marked by pure rules (`app/domain/question_formats.py`): exact set, decimals
  with nothing rounded, exact pairing, exact order.
- Only apps that ask get these formats. Older apps can't show them, and mocks and offline packs leave them out.
- The app answers them, queues them offline (Drift v9), and states the right answer after answering.

**Paper details and counting once**
- Papers record stage, session, set and extra languages.
- A paper can be marked as another set of a paper, and a question as a translation of another. Repeat counts and Radar then
  count them once.
- Papers that look like another set are only suggested: at least 90 % of the questions word for word, numbers included, so
  shifts with the same questions but different numbers stay separate. Nothing changes until a person confirms.

**Descriptive fields and groups**
- Questions take marks, a word limit, sub-parts and an internal-choice group.
- A passage says what it is: text, chart, table or case. Each question in it keeps its own topic and model.

**Import**
- A separate answer key, as a PDF or pasted text. It reuses the rules for keys inside papers and only fills in what's
  missing. A different existing answer stays and is flagged. The file isn't kept.
- Section headings run past Part D, and exams whose option count varies now accept any count.

**Rich content**
- LaTeX and pipe tables in questions, options, passages and explanations (`flutter_math_fork` 0.7.4, Apache-2.0, fonts
  bundled, works offline). Money such as "$5 and $6" stays text. TeX that can't be read is shown as written.

**Review**
- The review screen sets the format, its answer, marks, word limit and choice group.
- A new paper screen holds details, other-set suggestions and the answer key.

## Migrations

All reversible; each round trip was checked on the test database.

| Migration | Change |
| --- | --- |
| 0045 | `format` and `answer_spec` on questions and session items; `response` on answers |
| 0046 | Paper details, duplicate and translation links, descriptive fields, passage kind |
| Drift v9 | `pending_answers.response_json`. A test keeps queued answers across the upgrade |

Downgrading 0045 deletes questions that only `answer_spec` can mark, along with their session rows, because the older schema
has no way to hold them.

## Tests added

| File | Covers |
| --- | --- |
| `tests/test_question_formats.py` | Answer rules for every format |
| `tests/test_question_formats_api.py` | Who gets the formats, answering, secrecy, review, history |
| `tests/test_paper_details.py` | Details, other sets, translations, descriptive fields, passage kinds, privacy |
| `tests/test_answer_key_file.py` | Reading keys, never overwriting, flags, PDF and text |
| `test/features/practice/question_formats_test.dart` | Models, correct answer in words, answer widgets |
| `test/core/rich_question_text_test.dart` | Splitting, money, tables, flag off, bad TeX, dark mode |
| `test/features/question_bank/format_spec_test.dart` | Building and reloading answers, review card |
| `test/features/documents/paper_details_test.dart` | Details, suggestions, key results |

## Problems caught along the way

- **A real bug, caught before commit.** Once every question had a format, the "has an answer" check counted `format` as an
  answer, so a paper with no answer key would have said "answered by reviewer". This would have affected SSC. Fixed.
- **Tied worded-alike groups.** The order issue from Phase 1 showed up as a real-paper difference when a new filter changed
  database row order. Running the previous commit and this one on the same data gave identical reports once ties were in a
  fixed order. The real-paper tool now ignores tie order, and its baseline was re-saved from that proven state.

## Not done in this phase

These parts of the brief are only partly covered, or not at all:

- **Scanned maths.** No new work. Tesseract can't read formulas, so the route is the existing "Read with AI", which hasn't
  been tested on maths.
- **Formats aren't detected.** The parser reads every paper as single-answer. A reviewer sets the format afterwards, one
  question at a time. Assertion–reason, match and the rest aren't recognised on import.
- **Numerical answer keys.** A key file fills in option answers only.
- **Answer keys by question ID.** Matching is by question number. JEE-style IDs are Phase D of the JEE brief.
- **Bilingual papers.** The parser still keeps only the first language's options, so translations are linked by hand, and only
  through the API so far: the app has no screen for it, nor for setting a passage's kind.
- **Grouping fixes in review.** Questions can't yet be moved in or out of a passage from the app.
- **Chemical formulas.** Simple ones work as TeX subscripts. `\ce{}` isn't supported, and structures would be images.
- **Images in options** work as before, for practice. Nothing changed there.
- **Descriptive practice.** Marks and sub-parts are stored and not used yet (Phase 7).
- **Paper solving** says to practise questions of the new formats instead of offering them.
- **Device checks.** Rendering speed on low-end phones hasn't been measured. No device is available here.

## Open questions

1. Should the import gaps above come before Phase 4, or should Phase 4 go next? Detecting formats on import matters most for
   JEE/NEET, and it could fold into your Phase D.
2. Still open: the official documents, IBPS's option count, the university exam and the ladder times.
