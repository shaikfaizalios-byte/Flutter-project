# Progress analytics and the daily study plan (Phase 8)

Code:
- Backend: `services/api/app/services/analytics_service.py` and `GET /api/v1/analytics/overview`
- Mobile:
  - `apps/mobile/lib/features/analytics/` (pure rules in `domain/`)
  - `RevisionRepository.watchStats` for device flashcard data

## Data sources (nothing else)

| Source | Where | What counts |
|---|---|---|
| Practice and mock answers | Server: `session_answers` + `session_items` (section/subject/topic snapshot) | **Attempted** answers in practice sessions, and in mock tests **once submitted**. An active mock gives no feedback, so its answers aren't results yet. Unanswered questions are never counted as wrong. |
| Mock results | Server: submitted `practice_sessions` (mode `mock`) | Score, max score, format, marking note, and whether time ran out (the last 20) |
| Flashcard recall | Device: `card_reviews` joined to the card and its concept | Reviews and "Forgot" ratings per subject/topic and per local day, over the last 30 days |

No sample data, ratios or charts are shown without recorded data. A topic with no answers has no accuracy (`null`), never 0 %.

## API

`GET /api/v1/analytics/overview?timezone=<IANA>&days=30&recent_days=14`

- `timezone` is **required** and checked against the IANA database (`422 invalid_timezone` otherwise).
  PostgreSQL buckets days with `timezone(zone, answered_at)`, so an answer at 19:00 UTC counts on the next day in India.
- `days` is 1–365 (daily history). `recent_days` is 1–90 (the window for the `recent_*` counts used for trends).
- Responses contain **raw counts only**:
  - totals
  - per subject (the snapshot subject, or the section)
  - per topic (with id, name and subject)
  - per local day
  - mocks

  Accuracy and every judgement are computed on the device from these counts, using the rules below.

## Rules (`AnalyticsRules`, shown in the app)

| Rule | Value |
|---|---|
| Answers needed before a topic's or subject's accuracy is judged | 10 |
| Weak when accuracy is below | 60 % |
| Flashcard reviews needed before recall is judged | 5 |
| Weak when "Forgot" is at least | 40 % of reviews |
| Trend: answers needed in the last 14 days **and** before them | 5 each |
| Improving or declining when the accuracy change is at least | 10 points |
| Analysis window (daily charts, flashcard recall) | 30 days |

- A topic is **weak** if either rule applies. The reasons are listed, with the evidence: "40% correct over 20 answers · forgotten in 3 of 5 flashcard reviews".
- Server topics (from question topics) and device topics (concept or question cards) are matched by subject and name, ignoring case.
- Topics that don't have enough data yet are counted ("2 more topics need more data before they are judged"), not judged.
- Weakest first: lowest accuracy, then highest forget rate.

## Mastery levels (`MasteryRules`, shown in the app)

Each syllabus topic of the current exam (and each topic of the learner's concepts) gets one level, from the
same data as the weak-topic rules (30-day window) plus the topic's "revised" mark:

| Level | When |
|---|---|
| Not started | No answers, no flashcard reviews, not marked revised |
| Learning | Fewer than 10 practice answers |
| Practising | 10+ answers but under 60 % correct, or the topic's flashcards are often forgotten |
| Strong | 10+ answers at 60 % or more |
| Mastered | 25+ answers at 85 % or more, not often forgotten, and marked revised |

The Study tab shows the levels per subject (a bar of topics per level, "x of y strong") and per topic, with the
evidence and the next step ("Answer 4 more questions to see your level."). Offline, practice answers are missing,
so levels use flashcards and revised marks only, and the card says so. Product choices, not validated research.

## Daily plan (`buildStudyPlan`, deterministic, no AI)

Candidates, in priority order. Each one says why it is in the plan and roughly how long it takes:

1. **Revise due flashcards.** About 1 minute per card, at least 5 minutes. Reason: "12 due today, 3 overdue".
2. **Practise each weak topic** (at most 2, and only topics with a server topic id). This is a 10-question practice
   session on that topic (about 15 min). Reason: the evidence and "below 60%".
3. **Otherwise, practise mixed questions** (about 15 min). Reason: there are no practice answers yet, or no weak
   topic was found ("a topic is judged after 10 answers").
4. **Take a mock test**, if a verified, available format exists for the learner's exams and it is due:
   - weekly when the exam is within 60 days, otherwise every 14 days
   - "never taken" also counts as due

   The reason gives the days since the last mock and the days to the exam. The button opens the Practice tab, where the mock's rules
   are shown and confirmed.

- **Daily goal.** If a daily study goal is set, candidates are kept in order while they fit, and the first item always stays.
  The plan says "About 35 min planned for your 60-minute daily goal". Without a goal it suggests setting one.
- **Offline.** Practice statistics need the server. Without them the plan contains only device revision and says why.
- **Past exam date.** A past exam date counts as no exam date.

## Screens

- **Home → "What should I study today?"**: the plan, with a Start button on each item.
- **Home → "Which topics am I weak in?"**: up to 3 weak topics with their evidence. Otherwise it explains which case applies:
  - no data
  - not enough data
  - nothing weak (with the threshold)
  - offline
- **Progress tab:**
  - practice overview (answers, accuracy, sessions, a bar chart of answers per day)
  - per subject (accuracy, or "Not enough answers yet (8 of 10)")
  - topics (judged topics with evidence, trend and a "Weak" badge)
  - mock history (score / max, date, marking note, time-up)
  - flashcard recall (reviews and forgets, a daily chart)
  - the rules text

  If the server is unreachable, a retry card replaces the practice sections and the device data still shows.
- **Charts** are plain Flutter widgets (`DailyBars`), with one screen-reader summary per chart and a tooltip per day. No chart
  package was added (no licence or size cost; the needs are simple).

## Not covered yet

- Analytics are single-learner and unauthenticated until Phase 10 (accounts).
- No per-section trends or time-per-question analysis yet. `time_spent_ms` is recorded for later.
- Topic stats come only from questions that have a topic, whether suggested or confirmed.
