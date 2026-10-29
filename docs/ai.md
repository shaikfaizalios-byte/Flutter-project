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
| Topic lesson | `POST /ai/topic-lesson` | `{exam_code, topic: 2-100, subject?, language: en\|hi}`. For a learner new to a topic: overview, 3–8 key points, one worked example (or none) and up to 5 common mistakes (`LESSON_SCHEMA`, pure `validate_lesson`: any malformed part rejects the whole lesson, 502). Own system prompt `TOPIC_SYSTEM` (any MCQ exam; no claims of official papers, no invented patterns, weightage or statistics). **Nothing stored**; `ai_generations` task `topic_lesson` (migration 0027) without text. The app shows it as "AI-generated · not checked" with the model, a warning when `confident` is false, *Test my knowledge* and *Save as a concept* (the lesson as editable notes). |
| Topic quiz | `POST /ai/topic-quiz` | Same body plus `count` 3–5 (default 5). For a learner who says they know a topic: questions easy → hard, each checked with `validate_generated` (invalid ones dropped and counted; none valid → 502). **Not stored**: they never enter the question bank, practice, analytics or mastery. Task `topic_quiz` (outcome `partial` when some were dropped). The app marks them on the device one at a time with the explanation, then gives a verdict by `QuizRules` (≥ 80 % know it, ≥ 50 % partly; shown in the UI) and offers the lesson or new questions. |
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
- **Review:** AI questions appear in the question bank (filter: AI-generated) and go through the normal review: edit, approve or reject.

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
