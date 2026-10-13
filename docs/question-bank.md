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
| Image-dependent | Stems mentioning figures, mirror or water images, cubes, dice, charts and similar (EN/HI keywords), or questions with no options and a very short stem. They are flagged, with the source page kept. Missing visual content is never reconstructed. |
| Provenance | Every question keeps the source document, page(s) and printed question number. Questions spanning pages record both pages. |

### Issue codes

Question level: `missing_answer`, `incomplete_options`, `empty_option`, `duplicate_number`,
`ambiguous_boundary`, `image_dependent`, `repeated_option_labels`, `answer_not_in_options`,
`conflicting_answers`, `source_page_needs_review` (a source page was flagged during extraction or OCR).

Document level: `no_questions_found`, `numbering_gaps`, `answer_key_unmatched`,
`answer_key_ambiguous_numbering`, `count_mismatch`, `section_count_mismatch`.

## Exam formats: verified only

`exam_formats` rows are created **only** after checking an official SSC document. Each row records the
source title, URL, reference (file number and paragraph), publication date and verification date.
Unknown formats simply have no row, and count checks are skipped for them.

| Code | Source | Content |
|---|---|---|
| `SSC_CHSL_2026_TIER1` | SSC notice "Combined Higher Secondary (10+2) Level Examination, 2026", F. No. HQ-C1102/5/2026-C-1, published 07-09-2026, para 13.8 and 13.8.2. Verified 2026-10-13 against the PDF on ssc.gov.in. | 4 parts × 25 questions / 50 marks: English Language (Basic Knowledge), General Intelligence, Quantitative Aptitude (Basic Arithmetic Skill), General Awareness. 60 minutes. 0.50 negative marks per wrong answer. **Parts "Not in sequence".** |

Because the notice says the parts are not in a fixed order, section counts are compared **by section
name**, never by position. **SSC CGL has no verified format yet.** Add one only after checking the
current official notice, and record its source in a migration.

A document is linked to a format at upload (`exam_format_code`) or later
(`PUT /documents/{id}/exam-format`). Re-run segmentation to apply a newly linked format.

## Topics (taxonomy as data)

`topics` (subject, name, keywords) is seeded with a small starter set of general subjects and topics.
Edit it with migrations or SQL; no code changes are needed. Keywords only produce **suggestions**
(`topic_status = suggested`). There is no suggestion on ties or without a match, and a suggestion becomes
`confirmed` only when a reviewer approves the question or picks a topic.

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

## Known limitations

- Passages without a stated question range ("Read the passage and answer the questions that follow")
  are not detected; their text stays with the preceding question's stem.
- Table-style answer keys (rows of numbers and rows of answers) are not parsed. Use `1-(3)` style or
  set answers during review.
- Bilingual papers keep only the first language's options per question (the other set is in the issue detail).
- Issue *details* are generated by the server in English. Issue *labels* are localised in the app.
