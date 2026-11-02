# Question segmentation and question bank (Phase 5)

After a document's text is extracted (see [document-ingestion.md](document-ingestion.md)), the same
worker **segments** the pages into questions and stores them in the question bank with full
provenance. A human reviewer then approves, fixes or rejects each question. Nothing the segmenter is
unsure about is silently "corrected". Every uncertainty becomes an **issue** with a reason code.

## Segmenter (`app/domain/segmentation.py`)

A pure, deterministic module. Its input is per-page text; its output is questions, passages and issues. It has no database
access and is unit-tested on synthetic text (`tests/test_segmentation.py`).

| Element | Rule |
|---|---|
| Question start | **Strong markers** `Q.12`, `Question 12`, `प्रश्न 12`. Plain `12.` / `12)` lines start a question only when the paper uses no strong markers *and* the number is the expected next one. While option *N* is expected, an `N.` line is an option. |
| Options | Parsed separately from question boundaries: inline `(1)…(4)`, `(a)…(d)`, `(A)…(D)`, several per line, or `a.` / `A)` / `1.` at the start of a line. Labels that restart (e.g. the same options repeated in Hindi) keep the first set and raise `repeated_option_labels`, with the dropped text in the issue detail. |
| Sections | Known subject headings (English and Hindi) or `Section/Part/खंड/भाग` + label. Sentences that merely start with "Part" are not headings (length limit). |
| Shared passages | `Directions/Read/निर्देश` lines that name a range ("Questions 21 to 25"). The passage is linked to every question in that range, **not copied** into each stem. |
| Answers | Inline (`Ans: 2`, `उत्तर: (2)`) or an **answer-key section** (`1-(3) 2-(b)`), joined **by question number, never by position**. Keys using letters for numbered options are mapped by position (a→1). Disagreeing answers are not guessed: `conflicting_answers`, and the answer is left unset. |
| Explanations | A `Solutions`/`Explanations`/`हल` section joined by number, or inline `Sol:` lines. |
| Section-restarted numbering | If numbers restart in each section (`Q.1–25` per section), the key cannot be matched by number. It is not applied, and the document gets `answer_key_ambiguous_numbering`. |
| Inline answers (CAT style) | "Correct Answer: Option 2" / "Option (4)" set the answer; an "Explanation:" or "Solution:" right after a question's answer line explains that question (an end-of-paper "Solutions" section still works). An answer that names no option ("Sentence 5", or a number for a question without options, i.e. a typed-in answer) is kept as found in `unrecognised_answer`, never mapped to an option. In a paper answering inline, "5." before the current question's answer line that continues its options is a fifth item, not the next question. |
| Numbering details | A number alone on its line ("4.") starts a question; "47:" counts like "47."; two options on one line ("1. a 2. b") are split (decimals like "10.0" are not); a row of labels like "Q1 Q2 Q3 Q4" is never a question marker, and a stray "Q1 ..." line doesn't switch a plainly numbered paper; numbered lines inside directions don't start questions (after directions only the next number, or the first number the directions name). |
| Image-dependent | Stems mentioning figures, mirror or water images, cubes, dice, charts and similar (EN/HI keywords, also when a ligature like "fi" was lost from the text), or questions with no options and a very short stem. They are flagged, with the source page kept. When the figure is found on the page it is cropped and stored (see below). Missing visual content is never redrawn or reconstructed. |
| Provenance | Every question keeps the source document, page(s) and printed question number. Questions spanning pages record both pages. |

### Issue codes

Question level: `missing_answer`, `incomplete_options`, `empty_option`, `duplicate_number`,
`ambiguous_boundary`, `image_dependent`, `repeated_option_labels`, `answer_not_in_options`,
`conflicting_answers`, `source_page_needs_review` (a source page was flagged during extraction or OCR),
`unreadable_text` (characters lost from the PDF text, or a formula drawn as graphics; the question
carries an image of itself as printed).

Document level: `no_questions_found`, `numbering_gaps`, `answer_key_unmatched`,
`answer_key_ambiguous_numbering`, `count_mismatch`, `section_count_mismatch`,
`figures_not_extracted` (pages whose layout could not be analysed for figures).

## Q&A notes (`app/domain/qa_notes.py`)

Interview questions and revision notes have a written answer instead of options. When the
segmenter finds mostly option-less questions (at most 30 % with two or more options), the paper is
read as Q&A notes instead, and stored as `answer_type = "written"` with `model_answer`:

- **"Answer:" layout:** each `Answer:` / `Ans:` line closes the question written just above it
  (up to 5 lines, stopping at a line that ends a sentence; title-like lines above the first
  question are dropped). Unnumbered questions are numbered in order.
- **Numbered layout:** `Q.3 What is …?` / `3. Why …?` starts a question; the answer follows. A
  numbered line only starts a question when it has a "?" or a "Q" prefix, so numbered lists in
  answers stay in the answer. A question asked in two short sentences stays whole.
- Lines printed on many pages (author, title) are page furniture and dropped.
- Where the split is a guess, the question gets `ambiguous_boundary`; text is kept as found.
- Written questions are never practised or used in mocks; verified ones become flashcards from the
  paper's review screen (front: question, back: the written answer). The AI reader returns
  `written_answer` for such papers too.

## Figures (`app/domain/figures.py`, `app/services/page_layout.py`)

A PDF's text layer has no pictures, so Venn diagrams, figure series, charts and formulas drawn as
vector paths would be lost. After segmentation the worker reads each page's **layout** with PDFium
(text lines with positions, image objects, vector paths) and decides, from geometry only:

- which graphics are page decoration (logos, rules repeated on most pages) and are ignored;
- which touching objects form one figure (a minimum visible size, so underlines and table rules don't count);
- which text lines are labels *inside* a figure (chart values, axis labels), which are moved out of the stem;
- which question, and which option of it, each figure belongs to.

Each figure is rendered at 2× (144 dpi; very wide crops are scaled down, at most ~1 MB) and stored as PNG in
`question_figures` (kind `stem`, `option` with its position, or `original` = the whole question as printed
when its text could not be read in full), with page number and box. The app fetches them from
`GET /questions/{id}/figures/{figure_id}` (owner only, cached privately) and shows them **as printed**
in review and practice. An option that is a picture counts as option content (no `empty_option`).

Questions with a stored figure are eligible for practice (image-dependent questions without one are
still excluded). Pages with several text columns, rotated pages or too many objects are skipped and
reported with `figures_not_extracted`; those questions keep the text-only checks.

## Exam formats: verified only

`exam_formats` rows are created **only** after checking an official SSC document. Each row records the
source title, URL, reference (file number and paragraph), publication date and verification date.
Unknown formats simply have no row, and count checks are skipped for them.

| Code | Source | Content |
|---|---|---|
| `SSC_CHSL_2026_TIER1` | SSC notice "Combined Higher Secondary (10+2) Level Examination, 2026", F. No. HQ-C1102/5/2026-C-1, published 07-09-2026, para 13.8 and 13.8.2. Verified 2026-10-13 against the PDF on ssc.gov.in. | 4 parts × 25 questions / 50 marks: English Language (Basic Knowledge), General Intelligence, Quantitative Aptitude (Basic Arithmetic Skill), General Awareness. 60 minutes. 0.50 negative marks per wrong answer. **Parts "Not in sequence".** |

Because the notice says the parts are not in a fixed order, section counts are compared **by section
name**, never by position. SSC CGL 2026 Tier-I was added in migration 0018 (its sections have 15-minute
timers and a fixed order).

### Versions, review and the catalog (global Phase 5, migration 0032)

A format is a **version**: `status` draft | verified | retired, `effective_from`/`effective_to`,
`supersedes_id`, `question_types` (choice, typed), `sectional_timing`, `reviewed_by`, `review_notes`.
Published formats are never edited; a new notice becomes a new row, so past attempts (which keep
`exam_format_id` and per-item marks) stay reproducible. The two recorded formats became `verified`
(CGL `sectional_timing` = true because every section records a timer).

- New mocks use only `verified` formats in effect today (`app/services/exam_formats.py`,
  pure `in_effect`); `GET /exam-formats` and linking a paper show verified and retired formats,
  never drafts.
- Operator tool `python -m app.cli.exam_formats`: `import FILE.json` (creates a draft; unknown keys
  refused; facts the notice doesn't give stay null), `check CODE`, `publish CODE --reviewer NAME`
  (refused while `format_problems` + `config_problems` find anything: missing marks/counts/duration/
  negative marking, timers that don't add up, sectional timing without a fixed order, unsupported
  answer types, dates, a source without title/https URL/reference; ends the superseded format the day
  before the new one starts), `retire CODE --on DATE`, `list`.
- Catalog exams by configuration: `exam CODE --name --short-name --category --country --authority
  --alias`. `exams.country_code` (ISO alpha-2, CHECK), `authority`, `aliases`; returned by `/exams`.
  The 0012 catalog exams got country IN (all Indian exams); authorities are left for the operator to
  set from official sources. `--languages en,hi,...` records the languages the paper is offered in
  (`exams.languages`, any ISO 639 code as the notice states, not only PrepLoop's content languages).
- `section_counts_indicative` (migration 0038): the notice gives its section-wise counts as only
  indicative. Mocks still use those counts, and say so on the mock card and in the marking note.

### RRB NTPC (global Phase 10, CEN 06/2026 and 07/2026)

From the official Centralised Employment Notices CEN No. 06/2026 (NTPC Graduate) and 07/2026 (NTPC
Under Graduate), Railway Recruitment Boards (indicative notice in Employment News 26.09.2026):

| Format (draft file in `services/api/data/exam_formats/`) | Duration | Questions (GA / Maths / GI&R) | Source |
|---|---|---|---|
| `RRB_NTPC_G_2026_CBT1`, `RRB_NTPC_UG_2026_CBT1` | 90 min | 100 (40 / 30 / 30) | para 13.1 |
| `RRB_NTPC_G_2026_CBT2`, `RRB_NTPC_UG_2026_CBT2` | 90 min | 120 (50 / 35 / 35) | para 13.2.1 |

Each question is 1 mark; 1/3 mark is deducted per wrong answer; the section split is "only
indicative"; no sectional timers; no section order stated (`sections_in_fixed_order` false). The
120-minute duration applies only to eligible PwBD candidates with a scribe (mocks use 90). The files
are **drafts**: the operator imports each (`import`), checks it against the notice and publishes it
under their own name (`publish --reviewer`); until then no RRB mock is offered.

Migration 0038 also records RRB NTPC's authority and its 15 languages (para 14.3 d), adds
"Mathematics" as an alias of the canonical subject "Quantitative Aptitude" (mock sections named
"Mathematics" find those questions; "General Intelligence and Reasoning" already matches "General
Intelligence" by name), and adds the 25 syllabus items of para 13.1 that no shared topic covered
(e.g. Elementary Statistics, Data Sufficiency, Flagship Government Programs) as shared topics for
RRB_NTPC only, each with its own confirmed canonical topic. RRB Group D has no notice yet: nothing
is recorded for it.

A document is linked to a format at upload (`exam_format_code`) or later
(`PUT /documents/{id}/exam-format`). Re-run segmentation to apply a newly linked format.

## Canonical topics (global Phase 6, migration 0034)

One id per subject or topic, whatever an exam or a learner calls it: `taxonomy_nodes` (`key` such as
`quantitative-aptitude/percentage`, kind subject|topic, parent), `taxonomy_labels` (language, label,
alias) and `topic_taxonomy_links` (exam topic → canonical topic; status suggested|confirmed|rejected,
source migration|rules|learner|operator; at most one confirmed per topic).

- Seeded from the shared topics (4 subjects, 60 topics, used by the SSC, banking and railway exams):
  one node each with the existing English name, and each shared topic linked to its own node
  (`confirmed`, source `migration`). No Hindi labels were added (none were reviewed).
- A learner's own topic gets a **suggested** link only when its name matches exactly one canonical
  topic (pure `app/domain/taxonomy.py`: case, spacing, punctuation, "&"/"and", simple plurals);
  two candidates → no suggestion. Renaming drops old suggestions; a rejection is never suggested
  again. `OwnTopicRead.canonical` shows it; `PUT /topics/{id}/canonical {node_id, confirmed}` (own
  topics only); `GET /taxonomy` lists the tree. App: "Same as the shared topic …? Yes, same / No" on
  the topics screen, then "Counts as the shared topic …".
- Used where it matters now: a mock section also takes questions whose topic is **confirmed**
  linked to a canonical topic of the section's subject (by id), so a learner's own "Reasoning
  Ability > Analogies" counts toward CGL's "General Intelligence and Reasoning". Suggestions never
  count. Topic wording in papers and syllabuses is never changed.

## Exams and topics for any exam

- `exams`: the **catalog** (names, short names, categories, featured; added by migrations; no patterns or marking)
  plus each learner's **own exams** (private, code `MY_...`). `GET /exams` (public catalog),
  `GET/POST /me/exams`, `PATCH/DELETE /me/exams/{code}` (delete only when no paper, question or note uses it).
- `topics.owner_id` (NULL = shared) and `topics.exam_codes` (NULL = every exam). The shared aptitude taxonomy
  applies to the SSC, banking and railway catalog exams; NEET, CUET, UPSC prelims and own exams start empty.
- Learners add their own subjects/topics (`POST /topics`, `/topics/bulk`; edit/delete their own only; deleting
  sends questions back to "no topic") and question types under their own topics (`POST /patterns`).
- With AI configured, `POST /ai/exams/{code}/topic-draft` proposes subjects/topics (with keywords) from up to 60
  of the learner's own questions of that exam. Bounded, de-duplicated, existing topics dropped; **nothing is
  saved** until the learner keeps topics from it.
- Everywhere topics are used (parsing, suggestions, review, AI, uploads) the same rule applies: shared or own,
  and applying to the question's exam. A paper's section headings also match its exam's subject names.

## Topics (taxonomy as data)

`topics` (subject, name, keywords) holds the SSC subject/topic taxonomy (about 60 topics since migration
0009). Edit it with migrations or SQL; no code changes are needed. Topics are only ever **suggested**
(`topic_status = suggested`) and become `confirmed` when a reviewer approves the question, picks a topic,
or accepts all suggestions of a paper.

1. **Keyword rules** (`app/domain/topics.py`, free, deterministic): a matching keyword scores its number
   of words, three times as much in the question's first sentence (where SSC questions state the task).
   The section heading limits the subject. No suggestion on ties or without a match. The reason is stored
   (`topic_suggestion_reason`, e.g. `Matched "venn diagram"`) and shown in the app.
2. **AI, optional** (`POST /ai/documents/{id}/topic-suggestions`, only with an AI key): the questions the rules
   left unassigned are sent in batches of 20 (stem and options, truncated) and the model must pick from the
   taxonomy; anything else is ignored. Suggestions are labelled as AI. Questions the AI found nothing for
   are not sent again. See [ai.md](ai.md).
3. **Accept all** (`POST /documents/{id}/topics/accept`): confirms every suggested topic of a paper's
   non-rejected questions in one step. Each topic can still be changed afterwards.

On the sample SSC CHSL paper used for tuning, the rules alone suggest a topic for about 83 of 100 questions.
That figure is from one paper and is not a validated accuracy; suggestions still need a reviewer.

Each topic can also have named **patterns** (question types), suggested and confirmed the same way, and
each paper has a suggested/confirmed **exam date and shift**. Both feed the repeated-models report: see
[insights.md](insights.md).

## Review workflow

| Action | Effect |
|---|---|
| Edit stem, options, answer, explanation, topic or image flag | Content issues (`missing_answer`, `incomplete_options`, `empty_option`, `answer_not_in_options`) are recomputed. A manual answer sets `answer_source = manual`. Editing a verified question sends it back to `unverified`. |
| Approve (`verification_status = verified`) | Refused with `cannot_verify` (422) while content issues are open. Otherwise all its issues are resolved and a suggested topic is confirmed. |
| Reject | Kept as a human decision. It is not used later (e.g. in practice). |
| Re-run segmentation (`POST /documents/{id}/segment`) | Replaces unverified questions, passages and document issues. **Verified and rejected questions are kept untouched**, and freshly parsed questions with the same (section, number) are skipped. |
| Delete document | Its questions, passages and issues are deleted too (cascade). |

Questions have `origin`: `source` (from an upload) or `ai` (Phase 9). The app always shows which one,
and AI questions are never presented as official previous-year questions.

## Question history and answer provenance (global Phase 2)

Edits never erase what the paper said. `question_revisions` (migration `0030`) is append-only;
each row is a snapshot of the tracked fields (`stem`, `options`, `answer_type`,
`correct_option_position`, `typed_answer`, `model_answer`, `answer_source`, `explanation`) after
one action:

| action | actor | when |
|---|---|---|
| `extracted` | `rules` / `ai` | the question is read from its paper (segmenter, Q&A notes, AI reading) |
| `generated` | `ai` | an AI practice question is created |
| `baseline` | `migration` | questions that existed before `0030`: their state when history began (earlier edits unknown, so it never counts as the paper's answer) |
| `edited` | `reviewer` | `PATCH /questions/{id}` changed a tracked field (`changed` lists which) |

Status-only changes (approve, reject, verify-clean, reports) add no revision; `verified_at` and
issues record those. Rules are pure in `app/domain/question_history.py`; writing/reading in
`app/services/question_history.py`.

`QuestionRead` adds `answer_origin` — `paper` (`answer_source` answer_key/inline, as read),
`reviewer` (set or changed in review, or with no recorded source), `ai`, `none` — and, for a
reviewer's answer, `paper_answer` taken from the `extracted` snapshot (all null: the paper gave
none; `paper_answer` null: not recorded). `GET /questions/{id}/revisions` lists the history (own
questions only; others → 404). The app shows the origin under the answer ("You set this answer.
The paper said (b) 30."), says approving is not an official answer key, and lists the history
("Edit history") on the review screen. Practice and scoring still read the effective answer
columns, so nothing else changed.

Not built: an "official key matched" state (needs an official answer-key source per paper) and
"independently checked" (needs a second reviewer); the app's "Verified" status still means "checked
by the paper's owner".

## Known limitations

- Passages without a stated question range ("Read the passage and answer the questions that follow")
  are not detected; their text stays with the preceding question's stem.
- Solutions-style papers (question, "Option 1:" lines with the text below, "Correct Answer:" and
  "Solution:" per question, e.g. CAT papers with solutions) are read: a "Solutions" title before
  the first question is ignored; text before a "Question" line becomes the question's passage
  (one passage when the paper repeats it for each question); an answer written as the option's
  text is matched to that option (letters and digits only; a near-identical OCR reading only when
  it clearly stands out, `FUZZY_OPTION_MATCH`), else "The correct answer is 3)" in the solution;
  "key in the number" questions are typed-in; "Option 7:" in a four-option question is used in
  order and flagged `option_label_unclear`. Answers that match no option stay
  `unrecognised_answer` for the reviewer.
- Answer keys are read after an "Answer Key" / "Answers" / "उत्तर कुंजी" heading, as pairs
  (`1-(3)`, `1. b`, `Q1 (c)`) or as tables: a row of question numbers ("Q. No. 1 2 3 4 5") followed
  by a row of answers ("Ans. b c a d b", digits or letters, with or without brackets), rows split
  over several lines, columns read one cell per line ("1", "b", "2", "c"), and "1 | b" / "1 b"
  rows. After a numbers row, a row of digits counts as answers unless it carries on the number
  sequence. A table row whose counts differ is reported as `answer_key_unmatched` and not used:
  answers are never shifted onto the wrong questions. Keys printed as images (scans) need OCR.
- Bilingual papers keep only the first language's options per question (the other set is in the issue detail).
- Issue *details* are generated by the server in English. Issue *labels* are localised in the app.
- Figure detection works on the PDF's vector/image objects. Scanned papers (one image per page) give no
  separate figures: those questions stay flagged and the reviewer uses the source page. Multi-column and
  rotated pages are skipped.
- Figure crops are stored in PostgreSQL (`bytea`), not in object storage.
