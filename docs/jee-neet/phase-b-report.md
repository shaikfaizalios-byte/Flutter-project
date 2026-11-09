# JEE and NEET work: Phase B report (syllabus trees)

Built on Phase A, on branch `claude/jee-neet-phase-b`. The syllabi are data files and don't reach learners until a named reviewer
imports them. The new Progress card is behind the `examProfiles` flag, which is off.

## What changed

**Three versioned trees from official lists** (`data/syllabi/official`)

| Exam | Year | Units | Topics | Source |
| --- | --- | --- | --- | --- |
| JEE Main Paper 1 | 2027 | Mathematics 14, Physics 20, Chemistry 20 in 3 sections | 362 | NTA, Syllabus for JEE (Main) 2027 |
| JEE Advanced | 2026 | Chemistry 33, Mathematics 9, Physics 7 | 427 | Information Brochure 2026, Annexure-I |
| NEET UG | 2026 | Physics 20, Chemistry 20 in 3 sections, Biology 10 | 514 | NMC letter of 22-12-2025, published by NTA |

- Topics are the official phrases, split at semicolons and sentence ends. I checked each against the source text. A handful aren't
  word for word: long bracketed lists moved into keywords, and formula symbols didn't survive extraction.
- Each topic keeps its own keywords, drawn from its official wording.
- The existing versioning does the rest: a new year is a new file, and topics carry over, so history stays.

**Links across exams** (`canonical_jee_neet.json`)
- 40 canonical topics for Physics and Chemistry. JEE Main and NEET have the same 20 units in each, so they pair directly.
- JEE Advanced's chemistry headings map to those units. Its physics has only 7 broad headings, so each physics topic is placed
  individually.
- 9 items have no equivalent and are listed in the file for a person to place, such as Solid State and Surface Chemistry.
- This file is my proposal, not an official mapping. Nothing counts until a named reviewer runs
  `python -m app.cli.syllabus link FILE --reviewer NAME`.

**Stats per exam or combined**
- The server could already count this. A new Progress card, "Across your exams", shows each shared topic combined and per exam. It
  appears only with two or more exams and shared answers, and shows raw counts only.

**AI for gaps**
- Nothing here uses AI. The existing topic draft already saves nothing until a person accepts it.

## Migrations

None.

## Tests added

| File | Covers |
| --- | --- |
| `tests/test_jee_neet_syllabi.py` | Official unit counts, clean topics, sources, imports needing a reviewer, a second year reusing topics, links joining exams |
| `test/features/analytics/combined_topics_test.dart` | The card with two exams, one exam, no shared answers and flag off |

## Where this differs from your brief

- **There is no Chapter level.** The official syllabi go Subject, Unit, then running text. I didn't invent chapters. Chemistry has an
  official extra level (Physical, Inorganic, Organic), stored as Section.
- **No class 11/12 references.** Those sources don't give them, and they'd need the NCERT chapter list. You marked this optional. The
  field can be added once there's a source.
- **Biology isn't split into Botany and Zoology,** matching NMC's list.
- **The NEET syllabus linked on NTA's documents page is headed 2025.** I used NMC's letter titled for 2026 instead.
- **Maths and Biology have no links.** You asked for Physics and Chemistry. JEE Main and Advanced maths could be linked later.

## Limits

- **Topics were split by a script and spot-checked, not read one by one.** Sampling looked sound, but the reviewer should expect some
  awkward breaks, especially in long sentences.
- **Formula symbols may be imperfect** where the PDFs store them as special characters. The differential equation form in JEE Main's
  Unit 9 was dropped from its topic name.
- **Official spelling was corrected in two unit names** ("Calculas", "Diffrential").
- **A phrase listed under two units of one exam** becomes one topic, and takes the first unit's link.
- **Many topics.** About 400 per exam is a long list on the topics screen, which was built for shorter ones. The tree screen handles it
  better. Worth seeing on a phone.
- **JEE Advanced physics placement is rule-based** on words in each topic, and is the part most likely to need correcting.

## Open questions

1. Are you happy with no Chapter level? If you want one, it needs a source, or your own grouping.
2. Do you want class 11/12 references? If so, which list should I use?
3. Should JEE Main and Advanced maths be linked too?
4. Who reviews and imports the syllabi and links? It's the same reviewer question as Phase A.
