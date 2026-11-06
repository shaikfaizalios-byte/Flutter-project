# Any-exam work: Phase 2 report (syllabus tree and topics)

Built on Phase 1, on branch `claude/any-exam-phase-2`. New screens are behind the `examProfiles` flag, which is off.

## What changed

**Structural (results unchanged)**
- `syllabus_versions` and `syllabus_nodes`: versions by effective year, and trees of any depth with level labels, keywords
  and aliases.
- Trees sit over `topics`. A leaf points to the topic questions already use, so no question moved and an exam with one
  version behaves exactly as before.
- Today's shared topics became one version per catalog exam, as subject → topic nodes.
- The built-in lists are now data files too: `data/syllabi/shared_aptitude.json` (10 exams, 60 topics) and `rrb_ntpc.json`
  (85). A test keeps them equal to the database.

**Behaviour**
- Not repeated uses the syllabus in force for the counted papers. Topics since removed show "Dropped from the current
  syllabus", and topics added after those papers are left out.
- Topic suggestions use only the syllabus in force today.
- A new version reuses topics with the same subject and name, so history carries over.
- Learners can add their own syllabus (`/exams/{code}/syllabus-versions`), by hand in the app or through the API.
- Operators add shared versions with `python -m app.cli.syllabus import FILE --reviewer NAME`. It refuses a file with no
  official source or effective year, so the built-in lists can't be re-imported as if they were official.
- `GET /analytics/canonical`: answers on topics that mean the same across exams, per exam and combined. Only confirmed links
  count. The syllabus screen shows it when a learner has two or more exams.
- App: syllabus screen with versions, tree, "In force", and an outline builder (one item per line, indent to nest).

## Migrations

| Migration | Change |
| --- | --- |
| 0044 | Adds both tables and the backfill. Reversible; topics and questions aren't touched |

## Tests added

| File | Covers |
| --- | --- |
| `tests/test_syllabus_tree.py` | Version rules, backfill, data files equal to the database, trees of any depth, topic reuse, limits, privacy, delete rules, Not repeated by version and Dropped, suggestions, operator refusals, combined stats |
| `test/features/exams/syllabus_tree_test.dart` | Outline parsing, Dropped flag, versions and tree on screen, building by hand |

## Verification

- Full backend and app suites pass (492 app tests). `tests/test_ssc_characterization.py` passes with its golden files
  untouched.
- All migrations go down to 0040 and back up, and `alembic check` shows no drift.
- Real papers: 13 of 13 unchanged, compared inside a transaction that was rolled back. The first comparison showed 4
  differences. They came from the new `dropped` field changing the report's hash: with it set aside everything matched, and
  it was false on all 101 topic references. `app.cli.characterize` now ignores `dropped: false`, and a true value still
  counts as a difference.

## Decisions worth checking

- **No effective year on the built-in syllabus.** None was ever recorded, so it's left empty and means "from the start".
- **The built-in list is PrepLoop's own.** The files say so: it isn't marked as an official syllabus, because no source was
  recorded for it.
- **The audit said the canonical tables needed relaxing. They didn't.** Only leaves link to canonical topics, so their two
  levels are enough.

## Limits

- **PDF syllabi still read two levels.** The parser finds headings and topics, then saves through the existing screen.
  Deeper trees come from the outline builder or an operator file, and a PDF syllabus doesn't create a version yet. This
  matters for JEE/NEET only if learners import those PDFs: the official trees will be operator files.
- **Suggestions use today's syllabus, even for an old paper**, because the paper's year isn't known when it's parsed. A
  reviewer can still pick any topic by hand.
- **Keywords.** A leaf linked to an existing topic shows the topic's keywords unless the node states its own, but suggestions
  read only the topic's. New keywords on a reused topic don't reach suggestions yet.
- **Same name, same topic.** Two chapters with an identically named leaf under one subject share a topic.
- The "AI suggests, you confirm" step is the existing one and wasn't changed.
- Hindi strings have had no native-speaker review.

## Open questions

Nothing blocks Phase 3. Still open from earlier: the official documents, IBPS's option count, the university exam and the
ladder times.
