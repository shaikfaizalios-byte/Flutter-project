# AI assistance (Phase 9)

Code:
- Backend:
  - `services/api/app/integrations/ai.py` (provider)
  - `app/domain/ai_content.py` (prompts, schemas, validation; pure)
  - `app/services/ai_service.py`
  - `app/api/v1/endpoints/ai.py`
- Mobile: `apps/mobile/lib/features/ai/`

AI is **optional and off by default**. Every AI result is labelled "AI-generated", stored with its
provenance, and reviewed before learners rely on it. AI never produces previous-year questions and never feeds mock tests.

## Provider, model, cost and data handling

| Item | Choice |
|---|---|
| Provider | Anthropic Claude through the official `anthropic` Python SDK (MIT), called **only from the server** |
| Model | `claude-haiku-5-5` by default (low cost); set with `PREPLOOP_AI_MODEL` |
| Switching on | Set `PREPLOOP_AI_API_KEY` in the gitignored `services/api/.env`. Without a key, `/ai/status` reports `enabled: false`, AI endpoints return `503 ai_disabled`, and the app hides AI actions. |
| Output | JSON-schema structured output (`output_config.format`), parsed and then validated by our own rules |
| Cost control | Rate limit (`PREPLOOP_AI_RATE_LIMIT` per `PREPLOOP_AI_RATE_WINDOW_SECONDS`, default 30 per hour per client), `PREPLOOP_AI_MAX_OUTPUT_TOKENS` (default 4000), and at most 5 questions per request. Every call logs input and output tokens in `ai_generations`, so spend can be computed with the provider's current price list (prices aren't hard-coded here). |
| What is sent | One question's stem, options and known answer (from a **verified** paper question); or, when the learner asks for questions from a concept, that concept's title, notes, subject and topic. The app tells the learner their notes will be sent before it sends them. Nothing else is sent: no account or device data. |
| What is stored | AI output (questions, explanation drafts, topic choice) with provider, model, prompt version and source. `ai_generations` stores the task, model, outcome, reason codes and token counts, but **never prompt or output text**. A concept's notes are not stored on the server. Only `ai_source_note = "Concept: <title>"` is kept. |
| Logging | Only reason codes (e.g. `timeout`, `provider_status_529`). No prompts, document text, notes or keys. The key is a `SecretStr`. |
| Provider's data retention | Governed by Anthropic's API terms. Review these before enabling in production. |
| Untrusted input | Paper text, options, passages, notes, searches, topic names and RAG sources go into the prompt inside one `<material>…</material>` block each (`app/domain/untrusted.py` `material()`; tags inside the text are neutralised so it can't close its block), and every system prompt ends with `UNTRUSTED_RULE`: the block is data, never instructions. Output is still validated as before, so an "obeyed" injection (unknown source, off-list topic, wrong shape) is rejected. `tests/test_prompt_injection.py` covers every prompt builder. The general system prompt names no exam; prompts that need the exam take its catalog name. Prompt version `p10`. This lowers the risk; it does not make injection impossible — never let AI output act without validation. |

## Features

| Feature | Endpoint | Rules |
|---|---|---|
| Explanation draft | `POST /ai/questions/{id}/explanation` | **Verified** source question, with an answer and no figure, that has no explanation of its own. Stored in `ai_explanations` as a `draft`, separate from `questions.explanation`, so source text and AI text never mix. A newer draft replaces older drafts. The model also reports `confident`; when it doubts the given answer, reviewers see a warning. |
| Review the explanation | `PATCH /ai/explanations/{id}` | `approved` (optionally with edited text, recorded as `edited`) or `rejected`. Only one approved explanation per question. Practice feedback then shows it with `explanation_origin = "ai"`, and the app labels it "AI-generated explanation". Drafts are never shown to learners. |
| Practice questions | `POST /ai/questions/generate` | The basis is either a **verified** source question or the learner's concept (`concept: {title, notes ≤ 4000, subject, topic}`). The language (`en`/`hi`) is requested in the prompt. At most 5 per request. See below for validation and storage. |
| Topic suggestion | `POST /ai/questions/{id}/topic-suggestion` | Only for questions without a topic that have a subject. The model must choose **from the existing taxonomy** for that subject; any other answer is ignored (`suggested: false`). Sets `topic_status = suggested`, `topic_suggested_by = ai`, which the app shows as "Suggested by AI". The reviewer confirms it. |
| Paper topics | `POST /ai/documents/{id}/topic-suggestions` | For a paper's questions the keyword rules left without a topic (rejected ones excluded): batches of 20 (stem ≤ 600, options ≤ 120 characters each), a few batches per request; the app repeats while `remaining > 0`. Choices outside the taxonomy, or of another subject than the question's section, are ignored. Suggestions are `topic_suggested_by = ai` with the model as reason; questions with no match are not sent again. The app warns that question text goes to the AI service first. |
| Quick answer | `POST /ai/quick-answer` | `{text: 2-300, exam_code?}`. A short answer (≤ 120 words, in Hindi when the search is in Devanagari) to a Study search that no imported question matched. Own system prompt (exams **and** interviews; no claims of official papers, no invented patterns or statistics). **Nothing is stored**: only the `ai_generations` row (task `quick_answer`, migration 0022), without text. The app sends nothing until the learner taps *Ask AI* once (device setting `quick_answers_on`, told the search text goes to the AI service); after that it asks by itself once the search has stood still for ~1 s, until they choose *Stop automatic AI answers*. Shown as "AI-generated · not checked" with the model, a warning when `confident` is false, and the Google button after it. |
| Read a paper | `POST /ai/documents/{id}/read` (202) | For papers the rules can't read (new layouts, two columns, tables, scans). Queues `documents.ai_read_status`; the **document worker** (`app/services/ai_paper_reader.py`) renders 3 pages per request (+ the next page as context, `ai_read_image_edge` px) and sends the images with their extracted text; pure prompt/schema/checks in `app/domain/ai_reading.py` (copy exactly, never solve, answer only if printed). Every question is compared with its page text: < 85 % of its words on the page → `ai_text_mismatch`; page without text (scan) → `ai_read_unchecked`; both block verification until a reviewer resolves them. Questions keep `origin=source` with `extracted_by=ai` ("Read by AI" in the app); reviewed ones are kept, the rules' unreviewed ones replaced. At most `ai_read_max_pages` (60). Each request logged as task `paper_read` (migration 0025) without text. |
| Search answer (RAG) | `POST /ai/search-answer` | `{text: 2-300, exam_code}`. Answers ONLY from the learner's material: keyword full-text retrieval (`app/services/rag_service.py`) over their own PDF pages, source questions they may see (own + shared bank; never AI-made or rejected) and their synced concepts, one exam, best 6 as S1..S6 snippets; pure prompt/citation check in `app/domain/rag.py`. Nothing retrieved → `found: false` **without an AI call**. Every [S#] must be a sent source, else 502 and outcome `invalid`. Nothing stored; `ai_generations` task `rag_answer` (migration 0024). The app shows the answer, then the cited sources (page/question/concept, unchecked ones marked), and falls back to the general quick answer when not found. See docs/rag-guide.md. |
| Topic lists and summaries | `POST /ai/search-answer` (same endpoint; optional `document_id`, `language`) | The Study search recognises two requests by word lists, no AI (pure `app/domain/study_requests.py`). **Topics** ("10 important topics in iOS across pdfs"; 1-15, default 10): `RagRetriever.retrieve_broad` takes up to 24 excerpts, taking turns between papers so one PDF can't fill the context; no subject, or a subject that is the exam itself, adds an even sample of every paper; no matching material → `found: false` without an AI call. **Summary** ("summarize this pdf", or a paper's "Summarize this paper"): one paper → summarised; several → `kind: choose_paper` lists them (no AI call); words naming a file pick it; words naming no file stay an ordinary search. Every page with text is read, in batches of whole pages (90 000 characters, at most 4; then one merge call); `pages_read`/`pages_total` say so when a paper is longer. Reply: `kind`, `items` (`title`, `text`, `cited`), `requested`, `document_name`; only cited `sources`. Every item must cite sources we sent, else 502 and outcome `invalid`; lists are never padded (fewer items than asked = the material covers fewer). "Important" = covered most by the learner's material, never a prediction (the app says so). Nothing stored; tasks `study_topics`, `paper_summary` (migration 0039), each call logged; a long paper uses up to 5 of the monthly allowance. The whole paper goes to the provider for a summary; the consent text and privacy policy say so. |
| Challenge Ladder | `/ladder/*` (see below) | Five questions on a topic, each harder than the last, written by AI from the patterns in the learner's reviewed papers, with web references as a secondary source. Tasks `ladder_search`, `ladder_question`, `ladder_solve` (migration 0040). |
| Topic lesson | `POST /ai/topic-lesson` | `{exam_code, topic: 2-100, subject?, language: en\|hi}`. For a learner new to a topic: overview, 3–8 key points, one worked example (or none) and up to 5 common mistakes (`LESSON_SCHEMA`, pure `validate_lesson`: any malformed part rejects the whole lesson, 502). Own system prompt `TOPIC_SYSTEM` (any MCQ exam; no claims of official papers, no invented patterns, weightage or statistics). **Nothing stored**; `ai_generations` task `topic_lesson` (migration 0027) without text. The app shows it as "AI-generated · not checked" with the model, a warning when `confident` is false, *Test my knowledge* and, only for confident lessons, *Save as a concept*: the notes start with "[AI-generated · not checked]", the concept is tagged `ai-generated` with an AI source, its page shows the AI badge, and search answers (RAG) treat it as unchecked material. Hidden in the app until `AppFeatures.learnStart` is on. |
| Topic quiz | `POST /ai/topic-quiz` | Same body plus `count` 3–5 (default 5). For a learner who says they know a topic: questions easy → hard, each checked with `validate_generated` (invalid ones dropped and counted; fewer than `MIN_QUIZ_QUESTIONS` = 3 usable → 502, outcome `invalid`). **Not stored**: they never enter the question bank, practice, analytics or mastery. Task `topic_quiz` (outcome `partial` when some were dropped). The app marks them on the device one at a time, each labelled "AI question · not from a paper", with the explanation and a note that the AI chose the answer and no one checked it, then gives a verdict by `QuizRules` (≥ 80 % know it, ≥ 50 % partly, no verdict under 3 questions; shown in the UI) and offers the lesson or new questions. |
| Answer check | `POST /ai/questions/{id}/answer-check` | `{answer: 1-4000}`. Used when solving an imported paper (Imported papers → a paper → *Solve this paper*): written (Q&A) answers, and options or typed answers the paper gives no answer for. The AI works out the answer itself, judges the learner's answer (correct / partly / incorrect, by meaning), writes a short good answer and says whether the paper's printed answer (written answer, typed answer or correct option, sent as "may contain reading errors, or be wrong") agrees or differs (`ANSWER_CHECK_SCHEMA`, pure `validate_answer_check`: a paper answer that isn't compared, or a comparison without one, rejects the check, 502). Own questions only. **Nothing stored**; task `answer_check` (migration 0028). The app shows it as "AI-generated · not checked" with the model, the paper's answer and whether it agrees, and a warning when `confident` is false; without AI or Plus the button is not shown and the paper's answer can still be revealed. |
| Status | `GET /ai/status` | `enabled`, provider, model, features. No secrets. |
| Report | `POST /questions/{id}/report` | Any question, any origin. Adds an open `learner_report` issue (reason + note) and moves a verified question back to **unverified**, so it leaves practice until re-approved. |

### Generated questions: validation and storage

- **Each item is checked** (`validate_generated`). Failing items are **rejected and counted, never repaired**.
  - Stem: 10–2000 characters.
  - Options: exactly 4 non-empty options of up to 500 characters each, all distinct (ignoring case and spacing).
  - Answer: `correct_option` must be 1–4.
  - Explanation: must not be empty.
  - Copies: the item must not repeat the source question or an earlier item in the batch.
  - The response returns `rejected` and `rejection_reasons`.
- **Stored fields:** valid items are saved as `questions` with:
  - `origin = ai` and `verification_status = unverified`
  - `answer_source = ai`
  - `ai_provider`, `ai_model`, `ai_prompt_version` (`p9.1`), and `ai_source_question_id` or `ai_source_note`
  - no document or page

  The `ai_has_provenance` database CHECK guarantees the provenance fields are present.
- **Topic:** inherited from the source question, or matched to the concept's topic by name, always as *suggested by AI*.
- **Hindi:** Hindi output gets an `ai_language_review` issue, so a reviewer checks the language, as with OCR text.
  Which languages get this flag is part of the language reference list (`review_ai_text` in
  `app/domain/languages.py`), as is the name each language has in prompts.
- **Which language:** lessons and knowledge checks use the learner's "AI lessons and checks" language (Settings;
  default = the app's language); generated questions default to their source's language (the learner can change
  it); explanations are always written in their question's language.
- **Review:** AI questions appear in the question bank (filter: AI-generated) and go through the normal review: edit, approve or reject.

## Challenge Ladder

Pure rules in `app/domain/challenge_ladder.py`, prompt in `app/domain/prompts/challenge_ladder_generator.txt`
(the product owner's prompt, asking for one step's question at a time, with the whole step plan as context),
service `app/services/ladder_service.py`, app `lib/features/ladder`.

- **Rounds.** Round 1: easy, easy, medium, hard, extreme hard. Later rounds ("Test me more"): medium-hard twice, hard
  three times, starting from the question types got wrong. `plan_round` uses the repeats report's order: the two most
  repeated types, a different one, a rarer one, then two combined. `POST /ladder/sessions` plans without AI; the app then
  calls `.../steps/{n}/generate` for each step, so the loading ladder fills in and no request runs long.
- **Sources.** Up to 3 of the learner's **own** reviewed questions per type from different papers, worded-alike ones first.
  Shared-bank papers are never sent: their rights cover practice, not an AI service. Web references: Claude's server-side
  `web_search_20250305` through `AIProvider.search_web`, once per session, with URLs checked against the real results;
  a failed search continues with papers only. Under 3 paper questions, web references lead; with none, only the web.
- **Exam facts.** `app/services/ladder_exam.py` reads the first stage: verified formats in effect, or the stage a learner entered.
  The prompt gets the exam, stage, allowed formats, option count, marking and base time; none of it is in the template. Without a
  stage, marks stay unstated. The next stage, if any, sets extreme hard.
- **Formats.** single_correct, statement, assertion_reason, multiple_correct, numeric, match, as the stage allows, and only with
  `include_new_formats`; otherwise single_correct. No format the ladder can write: 409 `ladder_no_format`. Descriptive exams have
  no ladder yet.
- **Time targets** are set by the server: seconds per question in the stage x the level's factor, from `defaults.json` `ladder`.
- **Marks.** Each step snapshots its section's marks and is scored like a mock, with penalties and partial marks. None stated: right
  or wrong only.
- **Checks before a question shows** (`generate`): the schema (an allowed format, the exam's option count, a solution; one retry); not
  a copy (95 % with numbers kept, or found inside a web snippet); unlike the session's questions (the existing 80 %
  numbers-hidden measure); an independent solve that sees only what a learner sees must reach the key: the same option or
  set of options, a number within the tolerance, or exactly the same pairs (up to 2 regenerations). Still failing, or the AI service down: a real reviewed question of the same type, labelled "From your
  papers"; with none left, 502. Options (or a match question's right list) are shuffled and the key follows.
- **Answers stay on the server** until the learner has answered (`LadderStepRead`); the first answer is final.
- **Separate storage.** `ladder_sessions` and `ladder_steps`, never `questions`, so nothing can reach the repeat counts
  (`tests/test_ladder.py`). Attempts (topic, type, difficulty, correct, time) are kept for weak-topic tracking later; they
  don't feed it yet. Both tables are in the account export and deleted with the account.
- **Cost.** A clean step is 2 AI requests, so a round is about 11 with the search; rejected attempts add more. Each counts
  toward the Plus monthly allowance (default 300), and each step counts once toward the hourly AI rate limit.

## Written practice

Pure rules in `app/domain/descriptive.py`, service `app/services/descriptive_service.py`, app `lib/features/descriptive`, settings
in `data/exam_templates/defaults.json`. For exams of kind descriptive or mixed.

- **Levels.** Define or list, short explanation, full explanation, analyse or compare, case study or critical evaluation. Marks are
  a share of the marks of the exam's question; with none stated, the default.
- **Questions.** `.../steps/{n}/generate` writes one with a rubric and a model answer. The rubric must add up to the marks, the
  question must be unlike the others, and the model answer must earn nearly all of its own rubric. Failing that it is rewritten,
  then 502. There is no fallback question: a real one would have no rubric.
- **Marking.** Two separate requests; over the set gap, a third, and the middle one is shown with the range. Agreeing markings are
  averaged point by point. The answer goes into the prompt as `<material>`. A failed marking saves nothing.
- **Photos.** `POST /descriptive/read-photo`: JPEG or PNG up to 10 MB, turned upright and reduced, copied by the AI without
  correcting, never stored. The learner corrects the text before it is marked.
- **Real questions.** With `source: papers` a session uses the learner's own reviewed written questions as printed, never the shared
  bank, up to 5, unanswered ones first. Marks are the question's own, else the exam's. The rubric is drafted by AI from the paper's
  answer if there is one, checked the same way, and reused until the wording, marks or paper's answer change. The paper's answer
  always wins over the AI's. Rubrics are labelled as AI-drafted, not the exam's official scheme.
- **Separate storage.** `descriptive_sessions` and `descriptive_steps`, never `questions`. Tasks `written_question`, `written_mark`,
  `written_read` (migration 0051).
- **Label.** "Estimated marks from AI feedback, not an official grade." wherever marks are shown.

## Where AI content can appear

- **Practice:** only when the learner turns on *Include AI-generated questions* (`include_ai`). Unverified ones also need
  *Include questions not yet reviewed*. Each item keeps `origin = ai` and is labelled.
- **Mock tests:** never. They use verified source questions only.
- **Study search (quick answers):** only when nothing in the papers matches; labelled "AI-generated · not checked",
  never stored, never shown as a question.
- **Lessons and knowledge checks** (Home "How do you want to start?", topic cards): labelled "AI-generated · not
  checked", never stored; quiz answers don't count toward progress.
- **Review screens:** always labelled. Provenance shows the model, the prompt version and the basis.

## Errors

| Code | When |
|---|---|
| `503 ai_disabled` | No provider configured |
| `502 ai_unavailable` | Provider timeout, connection or status error, refusal, truncated or unusable output. Retryable (the message says so). The failure is logged in `ai_generations` with a reason code. |
| `429 rate_limited` | Too many AI calls (`Retry-After` header) |
| `422 not_eligible` | Not a verified source question with an answer and no figure; or no subject or taxonomy for a topic |
| `409 explanation_exists` / `409 topic_already_set` | Already done |
| `422 invalid_reference` | Unknown exam for concept generation |

## Verified and not verified

- **Verified by tests**, using a deterministic `FakeAIProvider` (no network):
  - labelling and provenance
  - storage, validation and rejection
  - drafts never shown to learners; approval shown with the AI label
  - the AI opt-in in practice and source-only mocks
  - topic choices limited to the taxonomy
  - reports
  - rate limits, provider errors and the no-provider state
  - prompts carrying the learner's language
- **The Anthropic adapter** is tested with a stubbed client: request shape, JSON parsing, refusal, truncation and SDK error mapping.
- **Not verified:** no real Claude call has been made yet; that needs a key in `.env`. Answer quality, Hindi quality and real latency
  and cost are unknown until then.
- Rate limits are per process (as for uploads). Use a shared store before scaling out.
