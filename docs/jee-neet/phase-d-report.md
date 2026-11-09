# JEE and NEET work: Phase D report (paper import at volume)

Built on Phase C, on branch `claude/jee-neet-phase-d`. Nothing changes for learners until papers are imported and reviewed.

## Checked on real files

I ran NTA's own files through a local server. They aren't committed: tests use a generated paper in the same layout.

| Step | Result |
| --- | --- |
| Paper "B Tech 2nd Apr 2026 Shift 1" | 75 questions: 60 MCQ, 15 numerical, the right count in all six sections |
| Crops | Every question and all 240 options have their picture |
| Session 2 final key file (18 shifts, 1,350 entries) | All 75 matched by ID, none missing |
| Import check against the JEE Main template | Passed |
| Review tool | Signed in, showed the question beside its page, and the key's option matched; keyboard moves, selects and verifies |

## What changed

**Papers with official IDs**
- JEE Main papers print each question and option as a picture, with NTA's own IDs in text. PrepLoop recognises this layout and takes each
  question exactly as printed, with stem and option crops. No text is read from the pictures, so nothing can be misread.
- Sections, numbers and question types come from the paper. Multiple-choice and typed questions become their formats.
- Question and option IDs are stored (migration 0055).

**Keys by question ID**
- `POST /documents/{id}/official-key` reads a key file and matches by ID. One file covers a whole session; other shifts are ignored.
- It handles option IDs, numbers, `Dropped`, and `41 or 42`.
- A final key replaces a provisional one and marks attempts again. A plain key file still never overwrites.
- Anything that doesn't fit is reported: an option the paper doesn't have, a question the key doesn't cover, or a non-whole typed answer.

**Language versions**
- The same official ID in another language links as a translation, so it counts once. The ID is the paper's own statement, so this
  doesn't wait for a person.

**Maths-aware reading**
- `python -m app.cli.official_papers transcribe DOC --limit N` has the AI read pictured questions, with maths as TeX and chemistry as
  `\ce{}`. It costs one AI request per question, so it's never automatic.
- **The reading goes only into hidden search text.** Learners always see the printed picture, so a misread formula can't reach a question
  or its marking.

**Import checks**
- `GET /documents/{id}/import-check` compares a paper with a format: counts per section, a key for every question, and formats that
  fit their section. It reports and changes nothing.

**Internal review tool**
- A separate page at `/review-tool`, not part of the student app. It needs a sign-in and holds no data of its own. It's off in production
  unless `PREPLOOP_EXPOSE_REVIEW_TOOL` is set.
- It shows the question beside its source page, bulk-assigns topic and model, verifies or rejects, runs the import check and uploads key
  files.
- Keys: `j`/`k` move, `x` select, `v` verify, `r` reject, `t` topic, `m` model, `a` apply.

## Migrations

| Migration | Change |
| --- | --- |
| 0055 | `external_id` on questions and options, and `transcript` on questions. Reversible |

## Tests added

`tests/test_official_papers.py`: the reader (page breaks, labels above images, typed questions), every key state, final over provisional,
language links, checks, bulk assign, hidden search text, the tool.

## Limits

- **Only one real paper and one key file were tried.** Other shifts should match, but only a batch run will show it. A paper with several
  images per option should work and hasn't been seen.
- **Provisional key files weren't tried.** The stage is read from the words "PROVISIONAL ANSWER KEY", which I assumed from the final key's
  wording. A file without either word is refused.
- **Pictured questions can't be used offline, and the AI ladder doesn't use them as examples,** because they have no text.
- **Numeric answers with decimals in key files are refused for now,** because JEE Main's are whole numbers.
- **JEE Advanced and NEET papers aren't in this layout.** They use the existing text reader, keys by number, and existing figure detection.
  Their Hindi versions have no IDs, so linking stays a person's job. NEET's papers weren't available to test.
- **Scanned papers** still go through OCR and the existing "Read with AI". The new prompt rules cover pictured questions only.
- **Bulk import** isn't a new command. The existing starter papers tool imports folders, but doesn't take session or key files yet. The
  review tool handles one paper at a time.
- **The tool assigns topics, not chapters,** as Phase B has no chapter level. Its topic list can be long.
- **The tool's account owns the papers.** Content staff need the operator account, so there are no separate team logins yet.
- **Rights.** These are NTA's papers. The shared bank needs a rights decision before learners see them, which is your Phase E.

## Open questions

1. Which years and shifts should be imported first? A full 2026 batch is a good test of this.
2. Do you want the starter papers tool extended so a folder of shift papers and key files imports in one go? I'd do that next.
3. Should the content team get their own logins and roles?
