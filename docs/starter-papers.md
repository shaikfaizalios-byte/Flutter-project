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
