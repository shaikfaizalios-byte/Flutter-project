# Shared bank

The shared bank lets learners see repeat counts and practise from day one: the operator
publishes reviewed papers, and every learner sees their **verified** questions, read-only and
labelled with where the paper came from. Learners' own papers are never shared.

## Rules (enforced in code)

- **Rights first.** Publishing records a *rights basis* (why the paper may be shared) and a
  *source* (where it came from). The database refuses a shared paper without both
  (`ck_documents_shared_needs_rights`).
- **Verified questions only.** Only questions the publisher verified become visible. A paper
  with no verified question can't be published.
- **Shared topics only.** Publishing is refused while a verified question uses a private
  (own-account) topic or question type, because other learners couldn't see it.
- **One visibility rule.** `app/services/shared_bank.py` `visible_question()` is used by
  practice, mock tests, question reading, figures, question history and repeats.
- **Read-only for others.** Edits, reports and bookmarks stay owner-only (other accounts get
  404). Other learners never see the publisher's file name, review issues or AI drafts; the
  recorded source is shown instead.
- **Counted apart.** Repeats take `scope=mine|shared|all`; the app shows "Your papers",
  "Shared bank" and "All learners" (Radar) separately. Practice includes the shared bank by
  default (`include_shared`, a switch in practice setup). Mock tests draw from it too.

## Publishing (operator)

Use a dedicated operator account (deleting it would delete its papers and empty the bank).

1. Sign in as the operator, import the paper and review it: confirm the date and shift, verify
   the questions ("Verify all clean questions", then the rest by hand), use shared topics.
2. On the server:

```powershell
cd services\api
.\.venv\Scripts\python.exe -m app.cli.shared_bank list
.\.venv\Scripts\python.exe -m app.cli.shared_bank publish <document-id> --rights "Published by SSC on ssc.gov.in; reproduced for study" --source "SSC CHSL 2024 Tier-I, 2 July 2024, shift 1"
.\.venv\Scripts\python.exe -m app.cli.shared_bank unpublish <document-id>
```

With Docker (production): `docker compose exec api python -m app.cli.shared_bank list`.

## Rights, reports and takedown (global Phase 7, migration 0035)

- **Rights record.** Every shared paper has a `content_rights` row: basis (required), rights holder
  (when known), **permitted uses** (`practice`, `diagnostic` = the starter check), territory,
  attribution, review-by date, who decided and when. Uploading a paper never creates one: private
  processing is not permission to share. `python -m app.cli.shared_bank publish ... --by NAME
  [--use practice --use diagnostic] [--holder] [--territory] [--attribution] [--review-by]`;
  starter papers take `"uses"` per paper from `manifest.json` and the manifest's operator as
  decider. Papers shared before 0035 got a record for **practice only** ("territory: not recorded").
- **Reports.** Learners report a shared paper or question (`POST /content-reports`: rights problem,
  error, other; 10–2000 chars; 10 a day; only other accounts' shared papers) and see the status
  (`GET /content-reports`). App: flag button on shared questions (question screen and practice).
- **Operator tool** `python -m app.cli.content`: `reports [--all]`, `resolve ID --uphold|--dismiss
  --note --by`, `takedown DOCUMENT_ID --reason --by` (withdraws the paper at once, upholds its open
  reports; the paper stays in its owner's account), `audit`.
- **Audit log.** `audit_events` records publish, unpublish, takedown, report decisions and exam-format
  publish/retire: who, what, target id and reason; never content. Kept after the target is gone.

## Starter check (cold start)

A learner without papers takes a short check from Home's starter card: `GET /practice/starter-check?exam=`
(how many questions) and `POST /practice/starter-check` → a `diagnostic` session (migration 0035 adds
the mode). Questions: verified shared-bank questions of the exam whose rights include `diagnostic`,
up to 5 per subject and 20 in all, never the learner's own; untimed; answers can change and are
marked after submitting (1 point each). The result shows the subject/topic breakdown, says it is a
starting point and not an exam score, and its answers feed the usual progress and study plan.
**No starter check exists until the operator publishes papers with the `diagnostic` use**: PrepLoop
writes no sample questions of its own.

## What may be shared

Only what you have the right to share: material the exam body itself published for the
public, material whose licence allows redistribution, or content licensed to you. Coaching
institutes' papers and solutions are usually their copyright, even when they reproduce an
exam. When unsure, don't publish; get legal advice. The terms of use describe the shared bank
and the copyright takedown process.

## Limits

- Shared questions can't be bookmarked (bookmarks belong to the question's owner).
- Questions a learner answered stay in their history if the paper is withdrawn later; the
  question itself is no longer shown.
- Unpublishing hides the paper at once; nothing is copied to learners' accounts.
