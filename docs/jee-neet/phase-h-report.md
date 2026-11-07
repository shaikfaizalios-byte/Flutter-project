# Phase H: NTA-style computer-based mocks

## Rules come from the instructions

A format's `conduct.cbt` holds the rules with their reference, and a mock copies them into the attempt.
Only formats with this block get the CBT screen, so SSC mocks are unchanged.

| Rule | Value | Where it was read |
|---|---|---|
| Answered and marked for review | evaluated | JEE Main 2027 bulletin, PDF p.61 item 21; JEE Advanced 2026 brochure, PDF pp.39-40 para 18.1 d |
| Marked for review with no answer | not evaluated | same |
| An answer counts once saved | yes; the palette does not save | Bulletin PDF p.59 items 8-9; brochure para 18.2 |
| Sections and questions open at any time | yes | Bulletin PDF p.60 items 12-14 |
| Ends by itself at zero | yes | Bulletin PDF p.58 item 2; brochure para 18.1 b |
| Language | changes for the whole paper | Bulletin PDF p.58 item 5; brochure para 18.1 f |

The palette's five states and colours are the legend on bulletin PDF p.58: grey not visited, red not
answered, green answered, purple marked, purple with a green mark answered and marked.

**NEET:** no CBT instructions from NTA could be found on 7 November 2026, and no NEET 2027 bulletin. The
NEET format carries NTA's JEE Main instructions, and its `basis` says so on the mock screen. Replace them
when NTA publishes its own. The NEET format itself is the 2026 re-exam's, a pen-and-paper paper.

## Sections

Marks and limits are kept per section, so a subject can have several: `section_key` names them
"Mathematics Section A" and so on. `config_problems` no longer refuses these, so JEE formats can publish
once a named reviewer signs them off. A question is used once in a paper.

A sectional mock is one section on its share of the paper's time. That is a practice rule, not an exam
fact, and the app says so. Papers with sectional timers don't offer it.

## Answers

`PUT .../answers/{position}` takes `marked_for_review` and `visit` (seen and left without saving: the
saved answer stays). Time adds up in a computer-based mock, because learners come back to questions.
A replayed update adds nothing: `client_seq` guards it. Other mocks keep their behaviour.

## After the test

`GET /practice/sessions/{id}/analysis`: marks and time per question, accuracy by chapter, the learner's
attempts at this paper, and a percentile. The percentile needs `percentile_min_accounts` (100) accounts,
counts each account's first attempt once, and says it comes from real PrepLoop attempts and is not an
exam rank. Sectional mocks have none. There are no ranks anywhere.

## App

`cbt_view.dart`, a part of the session screen, behind `examProfiles`. Palette beside the question on wide
screens and in a sheet on phones, with a section summary. Drift v11 queues marks and visits.

## Limits

- Exam-day candidates use an on-screen keyboard; the app uses the device's.
- Matching answers keep their own save button, then Save & Next.
- Not tried on a device or against a real full-length paper: no verified format with enough questions
  exists yet. Tests cover a generated short paper.
- Questions in other languages show only where a translation is linked.
- Scores from different attempts compare different random questions, so history and percentile are a
  rough guide.
- The NTA screen's arrows to the top and bottom of a question aren't copied: phones scroll.
