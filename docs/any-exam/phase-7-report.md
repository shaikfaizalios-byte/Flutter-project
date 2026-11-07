# Any-exam work: Phase 7 report (descriptive practice and marking), and the brief's acceptance

Built on Phase 5, on branch `claude/any-exam-phase-7`. Everything in the app is behind the `examProfiles` flag, which is off.

## What changed

**Written practice**
- Exams of kind descriptive or mixed get five questions on a topic: define or list, short explanation, full explanation, analyse or
  compare, case study or critical evaluation.
- Marks scale to the exam: each level takes a share of the marks of the exam's question (20, 40, 60, 80 and 100 %). A 15-mark
  question gives 3, 6, 9, 12 and 15. With no marks stated, a default of 10 is used.
- The app shows a suggested length, labelled as PrepLoop's suggestion and not an exam rule.
- Multiple-choice exams never see any of this.

**Rubrics**
- Each question is written with a rubric and a model answer. The rubric must add up to the question's marks.
- As a check, the model answer is marked against its own rubric and must earn at least 80 %. Otherwise the question is rewritten,
  up to twice more, then the learner sees an error. Nothing unchecked is shown.
- The rubric and model answer stay on the server until the answer is marked.

**Marking**
- The AI marks against the rubric, and comments on structure, relevance and length. It returns marks per point, missing points and
  the model answer. It doesn't take off marks for length.
- Every answer is marked twice by separate requests. If the two agree, the result is their average, point by point.
- If they differ by more than 20 % of the marks, a third marking runs. The middle one is shown with the range.
- If marking fails, nothing is saved and the app keeps the text to send again.
- The label "Estimated marks from AI feedback, not an official grade." shows on the start screen, each result and the final total.

**Answers from a photo**
- The learner picks a photo, the AI copies the handwriting into the answer box, and they correct it before sending. Nothing is
  marked until they do. `[?]` shows what couldn't be read. The photo isn't stored.

**Separate storage**
- `descriptive_sessions` and `descriptive_steps`, never `questions`, so nothing reaches repeat counts. Both are in the account
  export and deleted with the account. The draft privacy policy now covers this.

## Added after approval: real written questions

- Written practice can now use the learner's own reviewed written questions, as printed, instead of AI-written ones. Up to 5 per
  session, ones not yet answered first. Never the shared bank, translations, confirmed duplicates or questions that need a figure.
- Marks are those on the question, else the exam's, else the default.
- The AI drafts the rubric, from the paper's own answer when there is one, and the same check applies. That rubric is reused so the
  question is marked the same way each time, and redrafted only if the wording, marks or paper's answer change.
- The paper's own answer is always the one shown. Rubrics are labelled as drafted by AI, not the exam's official scheme.
- Migration 0052, reversible. Downgrading removes these sessions, because the older schema would show them as AI-written.
- Tests: `tests/test_descriptive_papers.py` and additions to `descriptive_flow_test.dart`.

## Decisions you may want to check

- **Handwriting is read by the AI, not Tesseract.** Tesseract is built for print and does badly on handwriting. This means photos
  go to the AI provider, and the screen says so.
- **The photo comes from the file picker, not a camera button.** A learner takes the photo first, then chooses it. A camera button
  needs a new package (`image_picker`) and device permissions I can't test here.

## Migrations

Reversible; the round trip was checked on the test database.

| Migration | Change |
| --- | --- |
| 0051 | `descriptive_sessions`, `descriptive_steps`, and AI tasks `written_question`, `written_mark`, `written_read` |

## Tests added

| File | Covers |
| --- | --- |
| `tests/test_descriptive.py` | Levels, scaled marks, rubric and marking checks, the third marking and range, failed marking, ownership, photos |
| `tests/test_any_exam_acceptance.py` | The acceptance chain below |
| `test/features/descriptive/descriptive_flow_test.dart` | Answering, the label, the range, photo then correction, failure keeps the text, flag off |

## A bug the tests caught before commit

The new AI task names were too long for their column, so every question would have crashed on the log write. They are now shorter.

## Acceptance of the any-exam brief

| Item | State |
| --- | --- |
| All characterization tests pass | Yes, and real papers are unchanged, 13 of 13 |
| An SSC student sees no change apart from new features | Yes on screen, flag off. Ladder prompt wording changed, as you asked |
| A custom exam works end to end with no SSC wording | Yes on the server: syllabus, import, review, counts, ladder (`test_any_exam_acceptance.py`). The app's own wording was only reviewed per phase, with no single test across all screens |
| One non-SSC MCQ template (5 options, negative marking) | **Partly.** Tested with a learner's own exam and made-up exam data. IBPS PO is still a draft with no sourced option count |
| One descriptive template | **Partly.** Tested with a learner's own exam. The university template is shape only, as no university was chosen |
| Generated questions never enter repeat counts | Yes, tested |
| Exam names, thresholds, option counts, time limits and marking only in template data | Yes for exam facts; a test forbids exam names in code. Product defaults live in `defaults.json` |

## Limits

- **Nothing has run on the real model.** Marking quality, how often two markings agree, handwriting accuracy, Hindi and cost are all
  unmeasured. I'd try real answers before showing marks to anyone. A round costs about 2 requests per question and 2 or 3 per answer.
- **Real written questions are reached by topic.** They need a topic and a review, and appear in written practice, not in Solve this
  paper, which keeps its existing answer check.
- **A model answer checked by the same AI** catches a broken rubric, not a shared mistake. Rubrics aren't reviewed by a person.
- **Word limits are suggestions.** Exam formats have no word limit field yet.
- **One photo adds to the box at a time.** Several pages work by repeating it. Diagrams in answers aren't read or marked.
- **No descriptive mock tests,** and attempts don't feed weak topics yet.
- **Hindi strings** are unreviewed by a native speaker, as before.

## Open questions

- Do you want a camera button? It needs `image_picker` (BSD-3, from the Flutter team) and testing on a phone.
- Are the level shares and 20 words per mark right? Both are one-line changes in the defaults.
- Still open: the official documents for the JEE/NEET work, IBPS's option count, the university exam, embeddings, ladder time
  factors, and regional languages for learners.
