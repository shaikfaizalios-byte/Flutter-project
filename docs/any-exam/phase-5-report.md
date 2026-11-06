# Any-exam work: Phase 5 report (Challenge Ladder for any exam)

Built on Phase 6, on branch `claude/any-exam-phase-5`. New formats and marks in the app are behind the `examProfiles` flag, which
is off.

## What changed

**The prompt**
- It now takes the exam, stage, allowed formats, option count, marking and base time from data. Nothing about any one exam is left
  in the template; a test checks this.
- The Tier wording is replaced with your definitions. Hard is the toughest level in a paper of that exam and stage. Extreme hard
  is the next stage's level if there is one, otherwise multi-concept questions using syllabus methods.
- The line naming English, General Awareness and Reasoning is now generic.
- The web search also names the stage.

**Formats**
- The ladder can write single correct, statement, assertion and reason, multiple correct, numeric and match questions.
- A stage's question types decide which are allowed, and a section's own list narrows them. Anything else is refused.
- An exam whose formats the ladder can't write is refused at the start with a clear error, not given other questions.
- The option count is the exam's. Five options work end to end.
- Options are shuffled with the key following them. In match questions the right list moves and the pairs follow.

**The independent solve**
- It now covers every format: the same option, the same set of options, a number within the tolerance, or exactly the same pairs.
- The solver sees only what a learner would see.

**Times**
- Base time is stage duration divided by question count.
- The server now sets each step's target. The AI's own figure is ignored.
- Factors are in `data/exam_templates/defaults.json`: easy 0.8, medium 1.7, medium-hard 2.1, hard 2.5, extreme hard 4.
- At 36 seconds a question these give 30, 60, 75, 90 and 145 seconds, which are the ladder's old times. Exams with no stage use
  36 seconds, so they keep those times too.

**Marks**
- Each step keeps the marks of the matching section, and is scored by the same code as mocks, including penalties and partial marks.
- A partly right answer earns marks but doesn't count as correct, so a climb still needs a fully right answer.
- With no marks stated for the subject, the step is only right or wrong. No marks are invented.

**The app**
- Under the flag: number entry, multiple correct and match answers, rich text, "Partly right", the right answer in words, and marks
  per step and per round.
- With the flag off, requests don't ask for new formats, so questions stay single correct and no marks show.
- Descriptive exams get no ladder until Phase 7. The card hides and the server refuses a start.

## What an SSC student sees

No change on screen, apart from time targets now being fixed at the level's value instead of whatever the AI stated. The prompt
wording did change, as you asked, so questions may differ in style. In particular, extreme hard no longer says "Tier 2 / mains".
Only Tier-I formats are verified, so it now reads "multi-concept questions".

## Migrations

Reversible; the round trip was checked on the test database.

| Migration | Change |
| --- | --- |
| 0050 | `ladder_steps`: format, answer_spec, response, marks_correct, marks_wrong, partial_rule, marks_awarded. `ladder_sessions`: new_formats. Downgrading deletes steps with an `answer_spec`, because the older schema can't hold them. They are AI practice questions, counted nowhere |

## Tests added

| File | Covers |
| --- | --- |
| `tests/test_ladder_formats.py` | Times, prompt facts, allowed formats, validation, solver per format, shuffling, marks, and full rounds through the API: five options with a penalty, numeric, partial marks, match, a learner's own exam, an exam with no stage, a descriptive exam, older apps, no questions reaching the bank |
| `test/features/ladder/ladder_formats_test.dart` | Reading formats, adding up marks, answering each format, flag off, the hidden card |

## Limits

- **Not run on the real model.** Every test uses the fake AI. Whether the model follows the new formats, and how often the solver
  agrees on harder ones, is unmeasured. So is the cost of extra retries.
- **The ladder writes for the exam's first stage only.** There is no stage picker. Stages follow format code order for catalog
  exams and entered order for a learner's own.
- **The template test isn't a real template.** The five-option exam in the tests has made-up data. IBPS can't be used yet: its format
  is a draft and its option count has no source.
- **Fill in the blank and ordering aren't generated.** Your brief didn't list them. An exam that names only those is refused.
- **"typed" in a format means numeric here,** since the ladder can only check numbers.
- **A real paper question used as a fallback** is always single correct, even in an exam with other formats.
- **The solver is one request.** Your stricter checks (several solves, SymPy) are in the JEE/NEET Phase G.

## Open questions

- Time factors: I kept your rule but used factors that preserve today's SSC times, not your 0.5, 1, 1.25, 1.5 and 2-3. Your numbers
  would give an SSC easy question 18 seconds. Keep mine, or change one line in the defaults?
- Should learners be able to pick the stage when an exam has several? I'd add that with the JEE/NEET work.
- Still open: the official documents, IBPS's option count, the university exam, embeddings, regional languages for learners.
