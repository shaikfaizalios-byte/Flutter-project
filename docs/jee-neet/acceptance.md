# JEE and NEET: acceptance

Where each criterion of the brief stands. "Done" means built and tested; "needs you" means it needs real
papers, a decision or a sign-off only you can give.

| Criterion | Status | Evidence | What's left |
| --- | --- | --- | --- |
| One full JEE Main shift imports end to end: sections match the template, maths and diagrams render, answer keys match | Done for one shift | Phase D: "B Tech 2nd Apr 2026 Shift 1", 75 questions in six sections, all 240 option crops, 75 of 75 matched the final key by ID, import check passed | More shifts in a batch run |
| One JEE Advanced paper pair imports end to end | Needs you | Templates, syllabus and partial marking exist (Phases A-C); the text reader handles the layout in tests | Import a real Paper 1 and Paper 2 with their keys, then review |
| One NEET paper imports end to end | Needs you | Template and syllabus exist; no NEET paper was available | Import a real paper with its key |
| Scoring matches official marking on sample responses, including partial marking and dropped questions | Done in tests | `tests/test_answer_key_states.py`, `tests/test_mock_marking.py`, Phase A's check against JEE Advanced partial rules | Check against official scores for real responses, if you have any |
| Repeat analysis counts by shift and by year | Done | Phase F, `tests/test_repeat_analysis.py` | Real counts need reviewed papers |
| The ladder uses each exam's formats | Done | Phase G, `data/ladder_rules`, `tests/test_ladder_strict.py` | |
| Every generated question shown has passed verification | Done | Phase G: working recalculated, solves by level, any disagreement discards; failures give way to library or own questions | Hard levels stay off until the benchmark passes |
| The benchmark accuracy report exists | Built, not run | `python -m app.cli.ladder_benchmark run` | Your benchmark file and threshold |
| CBT mocks reproduce the palette states and scoring rules stored in the template | Done | Phase H, rules with page references in the formats, `tests/test_cbt_mocks.py`, `test/features/practice/cbt_test.dart` | NEET uses JEE Main's instructions until NTA publishes NEET's |
| No library question is visible to students unless its rights are licensed or owned | Done | Phase E, `library_question()`, `tests/test_library.py` (pending and withdrawn stay hidden) | Record rights decisions |

## Before students see any of it

- A named reviewer publishes the JEE and NEET formats and syllabi, and confirms the cross-exam links.
- Editors are set up (`python -m app.cli.library role EMAIL editor`): at least two, since nobody reviews their
  own work.
- Real papers are imported and reviewed, with rights recorded.
- The `examProfiles` flag is turned on in a release.
- A load test runs on a staging server sized like production.
