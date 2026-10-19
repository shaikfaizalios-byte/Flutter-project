# Privacy policy (draft)

**Draft for legal review — not yet in force.** Replace every [bracketed placeholder] before release.

Operator: [Operator name and address]. Contact for privacy questions: [privacy contact email].

## What PrepLoop stores

**Your account**
- Your email address, an optional display name and whether your email is confirmed.
- Your password is stored only as a one-way hash (Argon2id); nobody can read it.
- Sign-in sessions: refresh tokens are stored only as hashes and expire after 30 days.

**Your study data**
- Concepts and notes you write, your study plan (exams, exam date, daily study time, reminder time),
  flashcards and how you rated them, and your revision schedule. These are kept on your device and
  synced to your account so you can use other devices.
- Question papers you import (the PDF files), the text read from them and the questions found in them.
  These are processed on our server for your account only.
- Your practice and mock-test answers, scores and bookmarks.

**Optional AI assistance** (only when you use it, and only if it is switched on)
- When you ask for an AI explanation or AI practice questions, the question text (or the concept
  title and notes you chose) is sent to our AI provider, [Anthropic PBC], to write the answer.
- We keep a record that an AI request happened (type, model, outcome, size) but not its text.

**Repeat Radar** (only if you turn on "Share my counts with the Repeat Radar"; off by default)
- For your reviewed papers with a confirmed exam date and shift, the Radar reads how many questions
  of each topic and question type they had, together with that exam date and shift.
- These counts are combined with other learners' counts and shown to all learners only when at
  least 2 learners reviewed the same exam shift and their counts agree. Nothing that identifies you,
  your papers or their questions is shown, and no question text is shared.
- Nothing is copied: the Radar reads your counts live, so turning sharing off (or deleting your
  account) removes them at once.

**Technical data**
- Server logs: time, request path, response status and duration, with a random request id. Logs do
  not contain your notes, document text, passwords, codes or tokens.
- To stop abuse, we count requests per network address or account in short time windows. These
  counters store only a scrambled (hashed) key and are deleted within 2 days.

We do **not** sell data, show ads, or use advertising or analytics trackers. The app sends no
usage analytics.

## On your device

- Your study data is stored in the app's database on the device. Your sign-in session is stored in
  the system's secure storage (Android Keystore / iOS Keychain).
- Study reminders are scheduled on the device. They contain no study content.
- Signing out removes your study data from the device (it stays in your account).

## Who processes data for us

- Hosting and database: [hosting provider, region].
- Email delivery (sign-in codes): [email provider].
- AI assistance (only when used): [Anthropic PBC]. See their data-use terms: [link].

They process data only to provide these services to us.

## No tracking

- No analytics, advertising or session-recording tools are used in the app, the web app or the
  website.
- Fonts and the web app's engine are served from our own servers. Nothing is loaded from Google
  Fonts or other third-party content servers, so opening PrepLoop does not send your IP address to
  them.
- Emails are sent only when your account needs one (sign-in, verification and password-reset
  codes). We send no marketing emails.

## How long we keep data

- Account and study data: until you delete your account.
- Deleting your account removes your data and imported files from our live systems immediately.
  Backups are deleted on a rolling basis within [N] days.
- One-time codes expire after 15 minutes. Rate-limit counters are removed within 2 days.

## Your choices and rights

- **Copy your data**: Profile → Copy my data gives you everything we hold for your account.
- **Correct** your profile and notes in the app at any time.
- **Delete** your account and all its data: Profile → Delete account.
- You can turn off reminders, AI features and Repeat Radar sharing. To exercise other rights under applicable law
  (for example India's Digital Personal Data Protection Act, 2023, or the GDPR), contact
  [privacy contact email].

## Children

PrepLoop is for adults: you must be 18 or older to create an account. Sign-up asks you to confirm
this, and we record when you did. We do not knowingly keep data about anyone younger; if we learn
that an account belongs to someone under 18, we delete it. [Legal review: India's DPDP Act treats
everyone under 18 as a child; confirm this minimum age for your markets.]

## Changes

We will announce material changes in the app before they take effect. Last updated: [date].
