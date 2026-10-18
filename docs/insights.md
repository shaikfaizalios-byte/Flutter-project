# Repeated models across papers

The point of PrepLoop: from several years of previous papers, show which topics and which kinds of
question (**patterns**, or "models") keep coming back, so a learner doesn't skip them.

## Where the numbers come from

Only from papers **this account imported**. PrepLoop ships no papers. Every number states its basis
("Based on 12 of your papers (2019–2024)"), and:

| Rule | Why |
|---|---|
| Only source questions, never AI-generated ones; rejected questions excluded | Counts describe real papers |
| Headline counts use **reviewed** classifications: topic confirmed (and pattern confirmed, for pattern counts) | Suggestions are never presented as facts |
| Unreviewed suggestions are shown separately ("+3 not yet reviewed") | The learner sees what is still unchecked |
| Year breakdowns use **confirmed** paper dates only; undated papers are counted overall and listed as undated | No guessed years in trends |
| "Seen in most papers" = present in at least 50 % of the papers, once there are 3 or more (`RepeatRules`, shown in the app) | A named product rule, not research |

`GET /api/v1/insights/repeats?exam=SSC_CHSL` (`app/services/insights_service.py`) returns papers basis, per
topic and per pattern: questions, distinct papers and per-year counts (confirmed), unreviewed counts, and
confirmed questions without a pattern. Sorted by papers, then questions.

## Patterns (question types)

`question_patterns` (topic, name, keywords) is taxonomy data under topics, seeded in migration 0010 with a
starter list (e.g. Venn diagrams → *Relationship between classes*, *Reading a given diagram*; Percentage →
*Income, expenditure and savings*, …). Topics whose questions can't be told apart by wording (Syllogism,
Reading Comprehension, most of General Awareness) have none. Edit the list with migrations or SQL.

- **Suggested** by the same keyword scoring as topics (`suggest_pattern`), only within the question's
  topic; ties and no match leave it empty. The reason is stored (`pattern_suggestion_reason`). Matching
  ignores spaces around hyphens, because PDF text often reads "letter -cluster".
- Re-suggested when the topic or stem changes, after the AI topic step, and on re-parse (reviewed
  questions only gain a suggestion; a confirmed pattern is never touched).
- **Confirmed** by approving the question, by choosing it in review (`PATCH pattern_id`, must belong to
  the topic; also confirms a suggested topic), or with the paper's *Accept all suggestions*.
- Practice can be limited to a pattern (`pattern_id`); the report has a *Practise* button per pattern.
  Practice uses reviewed (verified) questions only, as everywhere else.

## Worded-alike groups

`app/domain/similarity.py` compares stems within a topic (or subject when there is no topic): case and
Unicode folded, **numbers masked**, punctuation dropped, cosine similarity of word unigrams + bigrams.
Pairs at 0.8 or more in **different papers** are linked into groups (union-find). This finds "the same
question with new numbers". Groups are labelled in the app as a wording-based hint, never counted in the
reviewed numbers, and never change a question. Names and pronouns are not masked, so the same model with
different names can fall below the threshold.

## Paper dates

`documents.exam_year / exam_date / exam_shift / paper_date_status (unknown | suggested | confirmed)`.

- Suggested after segmentation from the file name and the start of the first page
  (`app/domain/paper_date.py`): dates like `2 July 2019`, `02/07/2019` (day first), `2019-07-02`,
  `July 2, 2019`; shifts only next to the word "shift". Several different dates, or a file name and page
  that disagree, give no suggestion for that part (the reason says so). A confirmed date is never
  overwritten by a re-parse.
- Confirmed in the paper's review screen (`PUT /documents/{id}/paper-date`; all null = "date unknown").

## Repeat Radar (all learners)

The same question, pooled across learners who opted in, so a new learner sees what repeats before
importing anything. `app/domain/radar.py` (pure) + `app/services/radar_service.py`;
`GET /api/v1/radar?exam=`, `GET/PUT /api/v1/radar/settings` (`users.radar_opt_in`, migration 0011).

| Rule | Why |
|---|---|
| **Opt-in**, off by default (Profile, or the *All learners* view); the switch says exactly what is shared | New use of the learner's data; privacy policy updated |
| Only papers with a **confirmed date and shift** contribute; a shift = exam + date + shift | Identifies the same paper across accounts without sharing files |
| Counts are **read live** from confirmed topics/patterns of non-rejected source questions | Nothing copied: opting out or deleting the account removes them at once |
| Each account counts once per shift (largest contribution) | Re-importing can't double-count |
| A shift is published only with **at least 2 accounts**; a count only when at least 2 accounts report the **same** number (a missing topic counts as 0; ties withheld) | One account alone can never publish or skew a number |
| Output has no account, paper or question ids, filenames or text; withheld counts are reported as a number | Privacy; transparency about gaps |

The app shows the basis ("Based on 6 exam shifts reviewed by learners (2019–2024)"), how shifts are
counted, how many counts were withheld, and "In most shifts" (same 50 % / 3 rule as for own papers).

Not done yet: the **response-sheet score checker** (import a candidate's official response sheet, exact
score with the verified marking scheme, questions added to practice) is waiting for a real response-sheet
sample to build and test the importer against; it will also feed the Radar.

## Limits

- Results depend on how many papers are imported and reviewed; with one paper nothing "repeats".
- Pattern suggestions cover only listed patterns (41 of 100 questions of the sample CHSL paper got one);
  the rest stay without a type until a reviewer picks one.
- Similarity is wording-only and per topic; it is not a semantic match.
- The Radar needs at least two opted-in learners per shift with confirmed dates and shifts; until then it
  shows nothing. Agreement is on exact counts, so partial reviews withhold numbers rather than guess.
