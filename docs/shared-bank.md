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
