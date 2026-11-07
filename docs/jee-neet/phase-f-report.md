# Phase F: repeat analysis by shift

`/insights/repeats` is untouched, so the SSC output stays pinned. Everything here is new.

## Counted papers

Rejected questions, translations and duplicate papers are out. A shift is the exam's counting unit
(`app/domain/counting.py`): papers of one confirmed date, shift and session count once for exams
counting sessions. Reviewed means a confirmed topic. Curated papers are the shared bank plus approved
`official_pyq` library questions (`counted_curated()`); original library questions were never in a paper.

## `GET /insights/chapters?exam=&scope=`

Raw counts for "appeared in X of Y shifts", by year and session, per chapter and topic. `basis` gives the
shifts and reviewed questions per year; a chapter's weightage in a year is its questions over the year's,
worked out in the app (`weightPercent`). Questions without a confirmed topic are counted in
`basis.unreviewed` and in no chapter. A chapter is the syllabus Unit (`chapter_map.py`); a topic outside
any syllabus stands as its own chapter. Default scope `all`: the learner's papers and curated ones.

## Starter models

`python -m app.cli.library propose EXAM`, or "Rebuild proposals" in the review tool, clusters alike
questions of curated papers only, within a topic, in at least `MIN_PAPERS_TO_NAME` (3) shifts. Clusters
use wording with numbers masked (`app/domain/similarity.py`), on the transcript where a question is a
picture. A proposal changes nothing. A reviewer names it, can untick questions, and approves: the model
joins the shared list, confirmed on the kept questions. Rejected clusters aren't proposed again, unless
new questions change the cluster.

## Concept hints

`python -m app.cli.library hints EXAM --limit 20` asks the AI, one request per topic (up to 80 questions),
to group questions by concept. Curated questions only: learners' private papers are never sent. Answers
are validated (`app/domain/concept_hints.py`); a group needs questions from two shifts. Hints live in
`concept_hints`, which no count reads, and are labelled as unchecked AI. A transcript is never shown to
learners, so pictured questions appear as a number.

Why not embeddings: the brief asks for meaning, Anthropic offers no embeddings API, and a second provider
or a local model is a new dependency and a privacy decision. Grouping with the existing AI needs neither.
It costs one request per topic and has to be re-run when papers are added.

## Cross-exam view

`GET /insights/shared-chapters?exam=A&exam=B`: canonical chapters at least two exams have, through
confirmed links only and topics named for the exam. Empty until a reviewer runs
`python -m app.cli.syllabus link`. In the app it shows when the learner has two or more exams.

## App

`ChaptersScreen` (`/practice/chapters`), opened from the Repeated models card, behind `examProfiles`.
Says it isn't a prediction, what was left out, and when the sample is small (`reliable_papers`).

## Limits

- The hint prompt has never been run on the real model, so its quality and cost are unmeasured.
- Clusters are wording-based: "same model, different wording" reaches reviewers only through hints.
- Topic-level counts don't split by year in the app, though chapters do.
- Pictured questions need a transcript to cluster at all (`app.cli.official_papers transcribe`).
