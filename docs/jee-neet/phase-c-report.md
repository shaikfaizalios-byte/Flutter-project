# JEE and NEET work: Phase C report (question formats and rendering)

Built on Phase B, on branch `claude/jee-neet-phase-c`. New screens and rendering are behind the `examProfiles` flag, which is off.
The server-side key rules aren't flagged, but do nothing until a key is entered.

## What changed

**Formats**

| Your list | State |
| --- | --- |
| Single correct | Already built |
| Multiple correct with partial rules as data | Already built, and proved exact against JEE Advanced in Phase A |
| Integer | **New** format `integer`: a whole number, compared by value. JEE Main Section B now uses it |
| Decimal numerical with rounding or range rule | **New** `decimals` rule: an answer counts if right as typed, truncated or rounded to that many places. Works with a tolerance or a range |
| Matching (List-I/List-II) | Both kinds exist: `match` for pairing, and single correct with a table for JEE Advanced's four-option sets |
| Paragraph groups | Passages and passage kinds already exist. See limits |
| Assertion-reason, statement-based | Already built |

**Answer-key states**
- A key can be provisional or final, and a question can have one answer, several accepted answers, or be dropped.
- `PUT /questions/{id}/answer-key` records it, and the review screen has a card for it. Each change goes into the question's history.
- **Always scored with the final key:** saving a final key updates every attempt at that question, in any account, and marks those
  sessions again. A provisional key only affects new attempts.
- Dropped questions give the marks to everyone, attempted or not, and don't count toward accuracy. They stop being practised.
- Several accepted: any accepted answer earns the marks. That covers NEET's "any of the correct options" and its all-correct case.
- The learner sees a note on the question: dropped, several accepted, or changed in the final key. Their result says it was marked again.

**Rendering**
- Maths and tables now work in options, solutions and explanations, not only question text. That covers practice, results, review,
  Solve this paper, the ladder and written practice.
- New `\ce{...}` chemistry: formulas, charges, coefficients and arrows, inside or outside maths.
- For low-end phones: parsed text is cached, and display maths gets its own repaint boundary.
- Already in place: offline maths (fonts are bundled), maths following dark mode, and figures kept on white in dark mode.

## Migrations

| Migration | Change |
| --- | --- |
| 0054 | Key columns on `questions` and `session_items`, and the `integer` format. Reversible; downgrading turns whole-number questions back into numeric, which marks the same |

## Tests added

| File | Covers |
| --- | --- |
| `tests/test_answer_key_states.py` | Whole numbers, decimal rules, several and dropped in scoring, re-marking, other accounts, history, offline packs, ownership |
| `test/features/question_bank/answer_key_card_test.dart` | Chemistry, the parse cache, spec building, learner notes, the key card |

## Limits

- **Not measured on a low-end phone.** There's no device here, so "smooth" is unproven. The changes are sensible, not benchmarked.
- **SMILES isn't built.** You marked it optional, and it needs a new package. Structures work as images, through the existing figures.
- **Offline is partial.** Maths and tables render offline, but offline packs still leave out figures and every format beyond single
  correct and typed. Your Phase E chapter packs are the place to fix this.
- **`\ce{}` covers common cases,** not everything mhchem does. Anything unusual shows as written.
- **Solve this paper** marks on the device with the single stored answer, so it doesn't know several accepted or dropped.
- **"Changed" is detected only through the key card.** Editing the answer elsewhere after a provisional key isn't flagged.
- **Re-marking runs inside the request.** That's fine now, but a popular shared question at scale needs a background job (Phase I).
- **A rule for the whole section isn't applied automatically.** JEE Advanced's two-decimal rule is in the template, but each question's
  `decimals` is set per question. Phase D's import should fill it in.
- **Importing keys:** key files still don't set a stage or overwrite answers. Matching by question ID and final-over-provisional are
  Phase D.
- **Paragraph groups** can be split up by random practice order, and mocks don't keep them together.

## Open questions

- Should a dropped question stay visible in practice with a note, instead of disappearing? I removed it because there's no answer to
  mark.
- Do you want SMILES rendering? I'd skip it unless a real need appears, since images already work.
