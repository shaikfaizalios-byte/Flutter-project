# Any-exam work: Phase 6 report (mock tests and languages)

Built on Phase 4, on branch `claude/any-exam-phase-6`. Phase 5 comes after this, because the ladder's scoring needs this
marking. New screens are behind the `examProfiles` flag, which is off.

## What changed

**Marking from the format**
- A section can state its own `marks_wrong` and `marks_unanswered`, a `cutoff`, an `attempt_limit`, a `partial` rule and the
  `formats` it uses. A format can state its penalty as a share of a question's marks (`penalty_fraction`).
- The order is fixed: a section's own number, then the fraction, then the format's negative mark. Nothing gets a default: if none
  is stated, the format is incomplete and can't start a mock, as before.
- Scoring gives partial credit from the rule (`{"per_correct": "1"}`: some correct options and no wrong one). A partly right
  answer earns marks but still counts as not correct, so accuracy stays honest.
- Sessions snapshot marks and rules, so later format changes never touch an attempt.
- A format that states none of this marks exactly as it did. The SSC tests and real papers confirm it.

**Mocks**
- A format names its question types, so typed, numerical and multiple correct questions can join a mock, and a section can take
  only its own formats.
- An app that can't show a format's questions can't start that mock.
- Results show marks by section and, where a format states a cutoff, whether the attempt reached it.
- "Attempt any n" limits stop the next new answer only. Changing or clearing an answer is always allowed.
- Section timers were already built.

**Languages**
- Ten Indic languages join the reference list: Assamese, Bengali, Gujarati, Kannada, Malayalam, Marathi, Odia, Punjabi, Tamil and
  Telugu. AI text in them is flagged for review, as Hindi's is.
- Fonts for their scripts are bundled (about 1.1 MB, SIL OFL), so they render offline and the web app still loads nothing from
  Google.
- The Docker image installs their Tesseract data.
- A linked translation travels with its question and is never asked as a separate one. The app can switch language per question.
  Answers are marked the same either way, because options keep their position.
- Per-exam language lists were already built; the builder now offers these languages too.

**Templates**
- IBPS PO's penalty can now be stored as the notice states it: one fourth of the question's marks. Its draft format is complete
  apart from the option count, which still needs a source.

## Migrations

All reversible; the round trip was checked on the test database.

| Migration | Change |
| --- | --- |
| 0048 | `penalty_fraction`, wider `question_types`, session snapshots of blank marks and partial rules |
| 0049 | The ten languages. Downgrading is blocked if content in them exists, rather than deleting it |

## Tests added

| File | Covers |
| --- | --- |
| `tests/test_mock_marking.py` | Marking order, penalties, partial credit, blanks, cutoffs, limits, formats in real mocks |
| `tests/test_session_languages.py` | Translations in sessions, never asked twice, no answer leak, regional languages |
| `test/features/practice/mock_marking_test.dart` | Cutoffs and partial counts, translations, language names |

## Bugs the tests caught before commit

- **Every mock would have crashed on submit.** Reading a result expected a new field that's only stored when it isn't zero. This
  would have hit SSC.
- **Offline uploads would have crashed.** New items had no blank-marks value until saved, and that path scores them first.

## Limits

- **Regional OCR is unverified.** The language data isn't installed here, and the Docker change is checked only by CI. Scanned
  regional papers can't be read on this machine. Text-layer PDFs don't need it.
- **Regional AI text and rendering are unchecked** by anyone who reads these languages.
- **Only regular weight** is bundled for these scripts, so bold is synthesized.
- **Urdu isn't included.** It runs right to left, which the app doesn't lay out yet. An exam can still list it as a paper language.
- **Linking translations has no app screen**, so the language switch only appears for questions linked through the API. The parser
  also keeps only one language's options from bilingual papers.
- **The AI's language guess for searches** still knows only English and Hindi.
- **Cutoffs are whatever a format states.** Real cutoffs often change yearly or aren't published, and IBPS's aren't stated.
- **Only one partial rule exists.** JEE Advanced's real scheme must be checked against its instructions in your Phase A.
- Mock screens are the existing session screen. The NTA-style palette is your Phase H.

## Open questions

- Do you want regional languages offered to learners once the flag is on, before anyone has checked OCR on real regional papers?
  I'd keep them for reviewers until then.
- Still open: the official documents, IBPS's option count, the university exam and the ladder times (needed next, for Phase 5).
