# JEE and NEET work: Phase A report (exam templates)

Built on `claude/any-exam-phase-7`, on branch `claude/jee-neet-phase-a`. Data only, apart from one new field. All templates are
drafts: nothing is live until a named reviewer publishes it.

## What was read

Every value comes from an official document I opened. None comes from a coaching site.

| Exam | Stored | Read from |
| --- | --- | --- |
| JEE Main Paper 1, 2027 | 75 questions, 300 marks, 3 hours. Mathematics, Physics and Chemistry: Section A 20 MCQs, Section B 5 numerical. +4, -1, 0 in both. Two sessions (20-24 and 28 January, 2-7 April), two shifts, 13 languages, computer-based | NTA Information Bulletin 2027, Chapter 2 |
| JEE Advanced 2026 Paper 1 | 48 questions, 180 marks. Per subject: 4 single correct (+3, -1), 4 multiple correct (+4, partial, -1), 4 numerical (+4, 0), 4 matching (+4, -1) | The paper's own section instructions |
| JEE Advanced 2026 Paper 2 | 54 questions, 180 marks. Per subject: 4 single correct (+3, -1), 5 multiple correct (+4, partial, -1), 5 numerical (+4, 0), 4 numerical on 2 stems (+2, 0) | The paper's own section instructions |
| NEET UG 2026, 3 May | 180 questions, 720 marks, 180 minutes, pen and paper, one shift, 13 languages, +4, -1, 0 | NTA Information Bulletin 2026, Chapter 4 |
| NEET UG 2026 re-exam, 21 June | Same pattern, window of 195 minutes (2:00 to 5:15 PM) including formalities | NTA notices of 15 May and 12 June, and press release of 19 June |

All three exams count by session, as you asked. That is recorded as a product choice, not an exam fact.

The NEET template used to cite a third-party copy of the bulletin. It now cites NTA's own link.

## What changed

- `exam_formats.conduct` (migration 0053) keeps each year's mode, sessions, shifts, languages and references, plus a list of what the
  sources leave open.
- Each section records its own page reference. Numerical sections record their rounding rule.
- New files: `jee_main_2027_paper1`, `jee_advanced_2026_paper1`, `jee_advanced_2026_paper2`, `neet_ug_2026_re`, and the `jee_advanced`
  template. `jee_main`, `neet_ug` and `neet_ug_2026` were rewritten.

**Delivery without an app release:** a new year is a new format file, applied and published on the server with the existing
operator tool. `GET /me/exams/{code}/stages` returns it, including `conduct`. A test covers this. No client-side remote config was
needed.

**The partial rule fits exactly.** JEE Advanced's +3, +2 and +1 rules work out as one mark per correct option chosen with no wrong one,
which is the rule Phase 6 built. A test runs the paper's cases through the real scoring code.

## Migrations

| Migration | Change |
| --- | --- |
| 0053 | `exam_formats.conduct`, null for every existing row. Reversible |

## Tests added

`tests/test_jee_neet_templates.py`: totals against the official figures, marks per section, the partial cases, sources on official
hosts only, sessions and shifts, drafts importing, and delivery through the API.

## What I couldn't source, or that differs from your brief

- **NEET moving to computer-based in 2027: no official source found.** Your brief says CBT from 2027. I found only a news headline,
  and nothing on the NTA, NEET or NMC pages I could reach. Nothing is stored for NEET 2027.
- **NEET Botany and Zoology aren't separate in the bulletin.** It gives one Biology row of 90 questions, so that's what is stored.
- **The re-exam's writing time isn't stated.** NTA gives a 195-minute window including formalities, and calls the extra 15 minutes time
  for formalities. I stored 195 as stated and did not infer 180. Its question counts and marking are the bulletin's, carried over by
  the 15 May notice, not restated.
- **JEE Main's option count isn't in the bulletin.** Four is read from an official 2026 paper, and the template says so.
- **Which JEE Main dates carry Paper 1** isn't stated: the bulletin lists dates for all papers together.
- **JEE Advanced 2027:** no date or pattern found, so 2026 is the latest year. Marking appears only in each paper's instructions, so
  a new year has to be read from that year's paper.
- **Earlier years aren't stored.** JEE Main 2026 and before, JEE Advanced 2025 and before, and NEET 2025 and before. Phase D will need
  them for importing past papers.
- **Publication date** of the NEET bulletin comes from news reports, as before. The JEE Main one comes from the file name and notice.

## Limits

- **JEE formats can't be published yet.** Their sections repeat a subject (Section A and B of Mathematics), and mocks keep marks by
  subject, so they would mix them up. I added a check that refuses publishing rather than letting that happen. NEET can be published.
  Fixing this belongs with the mock work in Phase H, or earlier if you want JEE formats live sooner.
- **JEE Advanced's two papers look like stages to the Challenge Ladder,** which would treat Paper 2 as harder than Paper 1. Your Phase G
  anchors should replace that.
- **The matching sections are stored as single correct,** because that's how they're answered. Phase C adds their List-I/List-II display.
- The scanned NTA notices were read with OCR. I checked the two that set the re-exam's date, mode, languages and window against the page images.

## Open questions

1. Do you have an official source for NEET going computer-based in 2027? If so, send it and I'll add it.
2. Should the re-exam's duration stay at 195, or would you rather store 180 with the window as a note? It only affects mock timers and
   ladder times.
3. Who is the named reviewer for publishing? I can't publish these myself.
4. Which earlier years do you want for Phase D?
