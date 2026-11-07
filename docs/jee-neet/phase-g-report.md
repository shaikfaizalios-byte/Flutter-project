# Phase G: Challenge Ladder for JEE and NEET

An exam with a file in `services/api/data/ladder_rules` uses the stricter ladder. Every other exam,
SSC included, keeps the ladder it had, with the same prompt and one solve.

## Levels and formats

Each file holds what the levels mean for that exam and the formats to write, for apps that can show
them (`include_new_formats`). JEE Main: single correct and numerical. JEE Advanced: multiple correct,
numerical, matching and paragraph. NEET: single correct, assertion-reason and statement-based.

## The checks

1. The generator returns `structured`: kind, given values, formula, steps and an expression.
2. `app/domain/recompute.py` recalculates it with SymPy: units must work out, the value must give the
   key under the stated rounding, and exactly one option may match. A question whose options are all
   numbers must have working, whatever kind it claims. Formula answers are compared by value at several
   points. Expressions are read through an allow-list, never evaluated as code.
3. Independent solves, by level, from `defaults.json` `ladder.strict`: easy 1, medium 2, medium-hard 2,
   hard 3, extreme hard 3, and fact recall at least 2. Any disagreement discards the question.
4. Generated extreme-hard questions that pass also go to the queue in the review tool. Accepting one
   makes a library draft with rights pending, which still needs a second solve and approval.
5. A question that can't be checked gives way to an approved library question of the same chapter and
   level, then to one of the learner's own reviewed questions.

## The benchmark

Hard and extreme-hard generation stays off for a subject until it passes.

```
python -m app.cli.ladder_benchmark threshold NEET_UG Physics 0.95 --by NAME
python -m app.cli.ladder_benchmark run NEET_UG FILE.json
python -m app.cli.ladder_benchmark status NEET_UG Physics
```

Each past question is treated as generated: the AI answers it with working and no key, the checks run,
and an accepted answer is compared with the known one. The report gives items, accepted and correct by
subject and format. Accuracy is correct over accepted. Only totals are stored; the file stays with the
operator, and nothing reaches learners. A subject opens when its newest run reaches the threshold with
at least `gate_min_accepted` (20) accepted items. With no threshold set, it stays off.

## Marks

Steps use the exam's marking, including partial marks. Where a subject has a section per format, marks
follow the format of the question (`ExamContext.marking_for`).

## Limits

- JEE formats can't publish until mocks key marks by section (Phase H), so JEE ladders have no marks
  yet. JEE exams join the catalog when their templates are applied.
- Solves come from the same model as the generator, so they can share a mistake. The benchmark is what
  measures this; it has not run, because it needs your file.
- None of this has run on the real model: cost and latency per question are unmeasured. A hard question
  takes at least 4 AI calls, and up to 12 with retries.
- Paragraph questions are one question per passage, not a group of questions on it.
- Multiple-correct and matching answers rest on solves alone: they have no single value to recalculate.
- Units are a fixed list; working in any other unit fails, and the question is replaced.
- Accepted drafts are stored as English; a question in another language needs correcting there.
