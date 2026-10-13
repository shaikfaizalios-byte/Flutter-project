# Document ingestion (Phase 4)

Learners upload PDFs: previous-year papers, scanned or born-digital, and study material. The API
validates each upload, stores the original, and a worker extracts text **page by page**. It uses the PDF's
text layer when that is trustworthy and falls back to OCR when it isn't. Pages the system can't read
reliably are **flagged for review, never "fixed"**.

> Question segmentation (sections, numbering, options, answer keys) is Phase 5. This phase produces
> per-page text with provenance (document ID and page number) and review flags.

## Pipeline

```
upload ─▶ guard: rate limit, declared size ─▶ stream to tmp (size cap + SHA-256)
       ─▶ magic bytes "%PDF-" ─▶ open with PDFium (encrypted? damaged? 0 pages? too many?)
       ─▶ move into storage as documents/<uuid>.pdf ─▶ row in `documents` (status=queued)

worker ─▶ claim oldest queued document (row lock, SKIP LOCKED, lease)
       ─▶ for each page (one at a time):
            text layer ──acceptable?──▶ method=text
                 │ no: too little text / U+FFFD / Hindi page without Devanagari
                 ▼
            render at 300 dpi ─▶ Tesseract (eng, or hin+eng) ─▶ method=ocr
                 │ confidence < 70 or little text ─▶ needs_review
                 │ OCR unavailable / failed / empty ─▶ keep the text layer as-is
                 │                                     (method=text, or none if it was empty)
                 │                                     and set needs_review
            commit page row + progress
       ─▶ status=completed (summary text|ocr|mixed|none), or failed with an error_code
```

| Rule | Why |
|---|---|
| The file type is decided by content (`%PDF-` in the first 1 KB), never by filename or MIME type | Clients can lie about both |
| The user's filename is sanitised, display-only metadata, and is never used in a path | Prevents path traversal and filename-based tricks |
| Rejected uploads leave no file and no row behind | No orphans and no partial state |
| Pages are processed and committed one at a time | Memory stays bounded, progress is visible, and a crash loses at most one page |
| Text is stored exactly as extracted (only whitespace and NFC normalisation) | Uncertain output is never silently "corrected" |
| Hindi pages whose text layer contains almost no Devanagari get OCR | Papers set in legacy fonts such as Kruti Dev extract as Latin gibberish |

### Review reasons (`document_pages.review_reasons`)

| Code | Meaning |
|---|---|
| `little_text` | Fewer than `text_layer_min_chars` meaningful characters |
| `replacement_characters` | The text layer contains more than 1% U+FFFD (broken encoding) |
| `no_devanagari_in_hindi_page` | Hindi document, but less than 5% of the page's letters are Devanagari |
| `low_ocr_confidence` | Mean Tesseract word confidence is below `ocr_min_confidence` |
| `ocr_found_no_text` | OCR ran but recognised nothing |
| `ocr_failed` | Tesseract crashed or timed out on the page |
| `ocr_unavailable` | Tesseract, or the language data it needs, is not installed |

### Document failure codes (`documents.error_code`)

`processing_timeout` (the whole-document budget ran out; finished pages are kept),
`source_file_missing`, `processing_error` (unexpected; details are only in server logs), and
`too_many_attempts` (a worker died three times on the same document).

## Worker

- **Local development:** the API starts a background thread (`PREPLOOP_DOCUMENT_WORKER_IN_PROCESS=true`).
- **Production:** set that to `false` and run one or more workers:

  ```powershell
  cd services/api
  .\.venv\Scripts\python.exe -m app.workers.document_worker
  ```

  Workers claim documents with `SELECT … FOR UPDATE SKIP LOCKED`, so several can run at once. Each
  claim carries a lease of the processing timeout plus 2 minutes. If a worker dies, another
  re-claims the document after the lease expires and starts again from page 1 (at most 3 attempts).

## Configuration (`services/api/.env`)

| Variable | Default | Purpose |
|---|---|---|
| `PREPLOOP_UPLOAD_DIR` | `var/uploads` | Original files (gitignored) |
| `PREPLOOP_MAX_UPLOAD_BYTES` | 25 MB | Upload size limit |
| `PREPLOOP_MAX_PDF_PAGES` | 300 | Page limit |
| `PREPLOOP_UPLOAD_RATE_LIMIT` / `_WINDOW_SECONDS` | 10 / 3600 | Uploads per client address per window |
| `PREPLOOP_PROCESSING_TIMEOUT_SECONDS` | 900 | Whole-document budget |
| `PREPLOOP_TEXT_LAYER_MIN_CHARS` | 25 | Below this, a page's text layer is not trusted |
| `PREPLOOP_HINDI_MIN_DEVANAGARI_RATIO` | 0.05 | Legacy-font detection for Hindi documents |
| `PREPLOOP_TESSERACT_CMD` | `tesseract` | Executable (a full path on Windows) |
| `PREPLOOP_TESSDATA_DIR` | (Tesseract's default) | Folder with `eng.traineddata` and `hin.traineddata` |
| `PREPLOOP_OCR_DPI` | 300 | Render resolution for OCR |
| `PREPLOOP_OCR_PAGE_TIMEOUT_SECONDS` | 120 | Per-page OCR limit |
| `PREPLOOP_OCR_MIN_CONFIDENCE` | 70 | Below this mean confidence, the page is flagged for review |
| `PREPLOOP_DOCUMENT_WORKER_IN_PROCESS` | `true` | See Worker above |

## Installing Tesseract (with Hindi)

The pipeline works without Tesseract: scanned pages are stored empty and flagged `ocr_unavailable`.
Real OCR needs Tesseract 5 with the `eng` and `hin` language data.

### Windows (what this dev machine uses)

```powershell
winget install --id UB-Mannheim.TesseractOCR -e
```

The installer ships `eng` only. Writing to `Program Files` needs admin rights, so keep a user-level
tessdata folder instead:

```powershell
$td = "$env:USERPROFILE\.preploop\tessdata"
New-Item -ItemType Directory -Force $td | Out-Null
Copy-Item 'C:\Program Files\Tesseract-OCR\tessdata\eng.traineddata', 'C:\Program Files\Tesseract-OCR\tessdata\osd.traineddata' $td
Invoke-WebRequest https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/hin.traineddata -OutFile "$td\hin.traineddata"
```

Then add to `services/api/.env`:

```
PREPLOOP_TESSERACT_CMD=C:/Program Files/Tesseract-OCR/tesseract.exe
PREPLOOP_TESSDATA_DIR=C:/Users/<you>/.preploop/tessdata
```

Verified copy used here: `hin.traineddata` from `tesseract-ocr/tessdata_fast` (Apache-2.0), git blob
`a8f0aaec09378115b12a2c6287c57695d082aea2`, SHA-256
`4c73ffc59d497c186b19d1e90f5d721d678ea6b2e277b719bee4e2af12271825`.

### Linux (Debian/Ubuntu, e.g. a server or CI)

```bash
sudo apt-get install -y tesseract-ocr tesseract-ocr-eng tesseract-ocr-hin
```

The defaults (`tesseract` on PATH, the system tessdata folder) then work without extra settings.

Check an installation with `tesseract --list-langs`. It should list `eng` and `hin`.

## Retention and deletion

- Originals and extracted pages are kept until the user deletes the document. They are never
  deleted automatically.
- `DELETE /api/v1/documents/{id}` permanently removes the database row, every page row (cascade) and
  the original file. A worker processing that document stops cleanly.
- Rejected uploads are never stored. Temporary upload files are always removed.
- Until accounts exist (Phase 10), documents are single-tenant. See docs/security.md.

## Library choice (ADR-23)

PyMuPDF, named in the brief, is AGPL-3.0 or commercially licensed. Using it in a network service can
require publishing the server's source. **pypdfium2** (PDFium, Apache-2.0 and BSD-3) was chosen instead.
It provides everything this pipeline needs (text layer and page rendering) with no copyleft obligations.
Tesseract (Apache-2.0) is called as a subprocess (`stdin` → TSV on `stdout`, no shell), so no Python
wrapper is needed.
