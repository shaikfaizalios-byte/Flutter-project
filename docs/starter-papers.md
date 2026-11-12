# Starter papers (operator guide)

A new learner should be able to practise straight away. Starter papers are official previous papers
the operator publishes to the **shared bank**: every learner of that exam then sees their **verified**
questions in practice, mock tests, Repeated models ("Shared bank" view) and the AI search answers. Home
shows a "Starter papers" card while the learner has no papers of their own, and the exam chips say how
many papers each exam has.

## Rules first

- Only real papers, never written or generated ones presented as previous papers.
- Only papers you have the right to share. Official papers published by the exam body (for example on
  its website for candidates) are the safest source; coaching compilations and Telegram PDFs usually are
  not. Government papers are still copyrighted: read each site's terms, keep the link and the date you
  downloaded it, and get legal advice before going public.
- Every published paper records its `source` and `rights` (required by the database).

## Steps

1. **Operator account.** Sign up in the app with a dedicated address (for example `papers@your-domain`).
   Don't use a personal account: deleting it would empty the shared bank.
2. **Folder.** Put the PDFs in one folder with a `manifest.json`:

   ```json
   {
     "operator": "papers@your-domain",
     "papers": [
       {
         "file": "ssc-chsl-2024-07-01-shift-1.pdf",
         "exam": "SSC_CHSL",
         "language": "en",
         "source": "SSC CHSL 2024 Tier-I, 1 July 2024, shift 1 - official paper from <link>, downloaded <date>",
         "rights": "Published by the exam body for candidates; <terms you checked>",
         "exam_date": "2024-07-01",
         "shift": 1
       }
     ]
   }
   ```

   `exam` is the catalog code (`SSC_CGL`, `SSC_CHSL`, ...). `exam_date`/`shift` are optional; when given
   the paper's date counts as confirmed in the year breakdowns.
3. **Import** (on the server, from `services/api`):

   ```powershell
   .\.venv\Scripts\python.exe -m app.cli.starter_papers import D:\papers\chsl --process
   ```

   `--process` reads them right away; without it the worker does. Re-running skips files already
   imported (same content).
4. **Review.** Sign in to the app as the operator, open each paper's review screen, fix what is flagged
   ("need a look"), confirm topics, and verify the questions ("Verify every clean question" helps).
   Check progress with:

   ```powershell
   .\.venv\Scripts\python.exe -m app.cli.starter_papers status D:\papers\chsl
   ```

5. **Publish:**

   ```powershell
   .\.venv\Scripts\python.exe -m app.cli.starter_papers publish D:\papers\chsl
   ```

   Papers without verified questions, or whose verified questions use the operator's private topics,
   are skipped with the reason. Only verified questions become visible. Withdraw a paper with
   `python -m app.cli.shared_bank unpublish DOCUMENT_ID`.

## Suggested first set

Five papers each for SSC CGL, SSC CHSL, RRB NTPC, IBPS PO and UPSC Prelims. Only SSC CGL and CHSL have
verified exam formats, so the others get practice and Repeated models but no timed mocks until their
official formats are added (from the current notice, source recorded in a migration).

## Sample papers (made up, for trying the app)

Different from starter papers: `services/api/data/sample_papers` holds two practice papers **written by
PrepLoop** (not from any exam), so a learner with no papers can try importing, solving, reviewing and repeated
models on day one. Both sets use the same question types with different numbers, so Repeated models has
something to show once the learner reviews them.

- The learner taps **Try sample papers** on the empty Imported papers screen. `POST /documents/samples`
  imports both PDFs into the current exam as the learner's own papers, through the normal pipeline; asking
  again adds nothing (matched by file content).
- They are always labelled ("Sample · made up by PrepLoop, not a real exam paper", `is_sample` on the paper),
  carry a "SAMPLE PAPER" notice on the page, are never pooled into Repeat Radar and can never be published to
  the shared bank. The learner can delete them like any paper.
- To change them, edit `sample_papers.json` and run
  `services/api/.venv/Scripts/python.exe scripts/make_sample_papers.py`; `tests/test_sample_papers.py` checks
  that the import reads every question, option and answer.

## Official paper pages ("Get papers")

`services/api/data/paper_sources/paper_sources.json` lists, per exam code, official pages where learners can
download papers themselves. The app shows **Get papers** on the Imported papers screen when the current exam has
any; each opens in the browser (PrepLoop never fetches or copies them). The learner downloads a paper there and
imports it with Import PDF.

Add a page only after opening it yourself and seeing the papers or keys it offers. Every entry needs a title, an
https url, the publisher, what it offers, `checked_on` and `checked_by`; the server refuses to start a list with a
missing field (`app/domain/paper_sources.py`, `tests/test_paper_sources.py`). Re-check the pages when an exam's
site changes.

Checked on 2026-11-12: JEE (Advanced) lists the latest year's papers and keys on https://jeeadv.ac.in/ (added).
The SSC home page loaded but showed no paper list to an automated reader, the RRB site failed its certificate
check and the NTA sites refused automated access, so none of those are listed yet: open them in a browser,
find the papers page and add it.

