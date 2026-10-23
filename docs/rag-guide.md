# RAG in PrepLoop: how it works, and how to keep learning

PrepLoop's Study search answers from the learner's own material with **retrieval-augmented
generation (RAG)**. This walks through the real code in the order a request flows, then gives
exercises to deepen it yourself.

```
query ─▶ query_terms ─▶ RagRetriever (SQL full-text, 3 kinds) ─▶ best_window snippets
                                                                       │ S1..S6
app ◀─ SearchAnswerPanel ◀─ /ai/search-answer ◀─ validate_rag ◀─ Claude ◀─ rag_prompt
```

## 1. Retrieval words: `app/domain/rag.py` → `query_terms`, `ts_query`

- Lower-case, NFC, drop stop words ("what", "is", "the"…), de-duplicate, max 10.
- The regex keeps only word characters plus the Devanagari block (Hindi vowel signs are not `\w`).
  Side effect: no PostgreSQL query syntax (`& | ! ' :`) can come from user text.
- `ts_query` joins terms with `|` (OR) and `:*` (prefix). **OR = recall**: a page needs only some
  words; ranking then puts the best first.

Try: `query_terms("What is the difference between struct and class in Swift?")`.

## 2. Retrieval: `app/services/rag_service.py` → `RagRetriever.retrieve`

Three searches, each limited to **one account and one exam before ranking** (access control
lives inside retrieval, so other learners' text can never reach a prompt):

| Kind | Text searched | Filter | `verified` |
|---|---|---|---|
| page | `document_pages.text` | own documents | no (extracted / OCR) |
| question | stem + options + explanation (+ passage in the snippet) | `visible_question` (own + shared bank), `origin='source'`, not rejected | if reviewed |
| concept | title, subject, topic, notes in `sync_items.data` | own, not deleted/archived | yes (own notes) |

SQL ideas used: `to_tsvector('simple', text)` (words; `simple` = no stemming, works for Hindi),
`to_tsquery`, `@@` (matches), `ts_rank_cd` (score: more words, closer together). The three lists
are merged by score and the best 6 become **S1..S6**. Each question becomes one text block
(`_question_text`): choosing that unit is **chunking**.

Try in psql: the query in exercise A below, then `EXPLAIN ANALYZE` it.

## 3. Snippets: `best_window`

A page can be 4,000 characters; the model gets the ~1,200 around the densest hits. Fewer
tokens, less distraction, lower cost.

## 4. Prompt: `rag_prompt`, `RAG_SYSTEM`, `RAG_SCHEMA`

- Sources first, numbered and labelled, unchecked ones marked; the question last.
- Rules: only these sources, `[S#]` after every statement, `found: false` if they don't answer,
  watch for OCR mistakes, no invented exam facts.
- Structured output (`RAG_SCHEMA`) so we never parse free text.

## 5. Generation + trust: `AIService.search_answer` (`app/services/ai_service.py`)

1. Retrieve. **No sources → `found: false` without calling the AI** (free and honest).
2. Call Claude (`_call`, task `rag_answer`).
3. `validate_rag`: the answer must contain `[S#]` markers, and every marker must be a source we
   sent. `[S9]` when we sent S1–S3 → the whole answer is rejected (502), logged as `invalid`.
   Never "clean up" bad citations: that would hide a hallucination.
4. Log the call **without text** (`_record`), return the answer + sources with a `cited` flag.

## 6. The app: `SearchAnswerPanel` (`lib/features/ai/presentation/search_answer_panel.dart`)

- Nothing is sent until the learner taps "Ask AI" once (`quickAnswersOnProvider`).
- `searchAnswerProvider` waits ~0.8 s after typing stops (no AI call per keystroke).
- Found → answer, then the **cited** sources: page → the paper, question → the question,
  concept → the concept; unchecked sources say so. Not found → general `QuickAnswerPanel`,
  then Google.

## 7. Tests that teach

- `services/api/tests/test_rag.py`: pure parts; retrieval ranking; **another account's and
  another exam's pages never returned**; AI-made and rejected questions never sources; no
  material → no AI call; invented citation → 502.
- `apps/mobile/test/features/concepts/paper_search_test.dart`: sources shown and tappable,
  fallback to the general answer, nothing sent before "Ask AI".

---

## Exercises (do them in order)

**A. Look at retrieval with your own eyes.** In psql:

```sql
SELECT d.original_filename, p.page_number,
       ts_rank_cd(to_tsvector('simple', p.text), q) AS rank,
       left(p.text, 120) AS start
FROM document_pages p JOIN documents d ON d.id = p.document_id,
     to_tsquery('simple', 'struct:* | value:*') q
WHERE to_tsvector('simple', p.text) @@ q
ORDER BY rank DESC LIMIT 5;
```

Change OR to AND (`&`), remove `:*`, and see what changes.

**B. Build an evaluation set.** Write 20 queries about your own material and the source you
expect (`query → document + page or question`). Write a script that calls
`RagRetriever.retrieve` and prints recall@3 (how often the expected source is in the top 3).
Every later change must be judged by this number.

**C. Make it faster.** With many pages, add GIN expression indexes in a migration:
`CREATE INDEX ix_pages_fts ON document_pages USING gin (to_tsvector('simple', text));` (same
expression as the query), then compare `EXPLAIN ANALYZE` before and after.

**D. Better keyword ranking.** Try `setweight` to rank stems above explanations, or the
`'english'` configuration for English-only material (stemming). Measure with B.

**E. Meaning search (embeddings).** Add a multilingual embedding model, store vectors in
pgvector, retrieve top-N by cosine similarity, and merge with the keyword list using
reciprocal rank fusion (`score = Σ 1 / (60 + rank)`). Measure with B.

**F. Re-ranking.** Take the top 30 hybrid results and re-score each (query, snippet) pair with
a cross-encoder; keep the best 6. Measure with B.

**G. Answer quality.** For 10 queries, check by hand: is every statement supported by its cited
source? Count unsupported statements. This is "faithfulness", the second RAG metric after recall.

Ask Claude to review any exercise: paste your code or results.
