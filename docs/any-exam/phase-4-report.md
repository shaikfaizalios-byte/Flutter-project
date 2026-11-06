# Any-exam work: Phase 4 report (models and repeat analysis)

Built on Phase 3, on branch `claude/any-exam-phase-4`. New screens are behind the `examProfiles` flag, which is off.

One item of the brief is deliberately left out: the meaning-based similarity hint. It needs your decision first (see the end).

## What changed

**Models**
- Models now have an owner. NULL is the shared list; otherwise a model is private to that learner, even on a shared topic.
  Before this, a learner's model on a shared topic would have shown to everyone, so creating one was blocked.
- Learners can create models on any topic they can see, rename and delete their own, and merge their own into another model of
  the same topic. The shared list can't be changed from the app: to a learner it looks missing.
- One rule, `visible_pattern`, decides what an account sees. It is used by suggestions, the repeats report, the ladder, the
  model list and review.
- Private models never reach Radar's pooled report, and the shared bank refuses to publish a paper that uses one. Both have
  tests.

**Starter lists as data**
- `data/model_lists/shared_aptitude.json` holds today's 91 models, and a test keeps it equal to the database. They apply to the
  same 11 exams as before, through the topics they sit on. SSC's list is unchanged.
- `data/model_lists/descriptive_defaults.json` holds the eight answer formats: define, short note, explain with a diagram,
  compare, derive, case study, essay, letter. A learner adds them to a topic with one tap, as private models. Their keywords only
  suggest; a person confirms.

**"These look alike. Name this type?"**
- Questions worded alike in three or more papers, with a confirmed topic and no confirmed model, are offered for naming. Your own
  papers only. Nothing is created until someone names them, and naming confirms those questions under the new model.

**Counting**
- Thresholds come from the exam profile (done in Phase 1).
- `counting_unit: session` treats papers of the same confirmed date, shift and session as one sitting. A paper without those
  facts counts on its own, because nothing says it belongs with another. Counts by year stay per question.
- Counts carry marks where questions state them. Where marks differ, a "Rank by marks" option appears. Topics with no marks go
  last rather than counting as zero.

## Migrations

| Migration | Change |
| --- | --- |
| 0047 | `question_patterns.owner_id`; models under a learner's own topics take that owner; the unique name rule becomes per owner |

Reversible, checked by a round trip. Downgrading removes private models on shared topics, and their questions go back to having
no model, because the older schema can't hold them.

## Tests added

| File | Covers |
| --- | --- |
| `tests/test_models_and_repeats.py` | Data file equal to the database, privacy, rename, merge, naming, answer formats, session counting, marks |
| `tests/test_radar.py` (added to) | A private model never reaches the pooled report |
| `tests/test_shared_bank.py` (added to) | A private model stops publishing |
| `test/features/insights/models_and_counting_test.dart` | Reading reports, ranking by marks, the models screen |

## Worth knowing

- **Sessions count sittings, not shifts.** Two shifts on one day are two sessions. "In X of Y shifts" for JEE works as it is, if
  each shift's paper has a confirmed date and shift.
- **Worded-alike groups still count files**, not sittings, in their "in N papers" line. Only the topic and model counts follow
  the counting unit.
- **The naming prompt needs a confirmed topic.** Alike questions whose topic is only suggested wait until it's reviewed.
- **"3 papers" for naming is a product rule** in `app/domain/counting.py`, not an exam fact.
- **A mistake of mine:** one commit went in with a failing test, because the command didn't stop on the failure. The test had a
  missing import. It was fixed straight after, before anything was pushed, and commits now run only after the tests pass.

## Limits

- Models can't be reassigned to another topic, and merging works only within a topic.
- Syllabus versions don't carry their own model lists: a model belongs to a topic, and the topic can sit in several versions.
- Hindi strings have had no native-speaker review.

## Your decision: the meaning-based hint

The brief asks for an embedding-based hint across papers, labelled a hint and kept out of reviewed counts. Nothing is built,
because it needs a choice:

| Option | What it means |
| --- | --- |
| Hosted embeddings (such as Voyage) | Paper text goes to another company. Needs a privacy policy change, a data agreement and a new cost |
| Local model on the server | Text stays on your server. More memory and setup on the VPS, not measured yet |
| Skip it for now | The numbers-hidden matcher already finds most repeats. Revisit with real JEE/NEET papers |

Recommendation: skip it for now. It only adds a hint, the matcher it would sit beside is unchanged, and real papers would show
whether it's worth a provider.
