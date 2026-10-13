"""Storage, rate limiter and OCR adapters. Real-Tesseract tests skip when it isn't installed."""

import os
from pathlib import Path

import pytest

from app.core.rate_limit import SlidingWindowRateLimiter
from app.domain.errors import RateLimitedError
from app.integrations.ocr import OcrUnavailableError, TesseractOcrEngine, parse_tesseract_tsv
from app.integrations.storage import LocalDocumentStorage, StorageKeyError
from tests.pdf_factory import text_image

# --- storage ---------------------------------------------------------------------------


def test_storage_round_trip(tmp_path: Path) -> None:
    storage = LocalDocumentStorage(tmp_path)
    source = storage.temp_dir() / "upload.part"
    source.write_bytes(b"%PDF-1.4 test")
    key = storage.new_key()

    storage.save(key, source)

    assert storage.path_for(key).read_bytes() == b"%PDF-1.4 test"
    assert not source.exists()
    storage.delete(key)
    storage.delete(key)  # idempotent
    assert not storage.path_for(key).exists()


@pytest.mark.parametrize(
    "key",
    [
        "../outside.pdf",
        "documents/../../outside.pdf",
        "tmp/x.pdf",
        "documents/x.txt",
        "/etc/passwd",
        "C:\\Windows\\win.ini",
    ],
)
def test_storage_rejects_keys_outside_documents(tmp_path: Path, key: str) -> None:
    with pytest.raises(StorageKeyError):
        LocalDocumentStorage(tmp_path / "root").path_for(key)


# --- rate limiter ----------------------------------------------------------------------


def test_rate_limiter_window() -> None:
    now = [0.0]
    limiter = SlidingWindowRateLimiter(limit=2, window_seconds=60, clock=lambda: now[0])

    limiter.check("a")
    limiter.check("a")
    limiter.check("b")  # separate key
    with pytest.raises(RateLimitedError) as exc:
        limiter.check("a")
    assert exc.value.retry_after_seconds == 60

    now[0] = 61.0
    limiter.check("a")  # window passed


# --- Tesseract adapter -----------------------------------------------------------------


def test_parse_tesseract_tsv_rebuilds_lines_and_confidence() -> None:
    header = "\t".join(
        [
            *("level", "page_num", "block_num", "par_num", "line_num", "word_num"),
            *("left", "top", "width", "height", "conf", "text"),
        ]
    )
    rows = [
        "1\t1\t0\t0\t0\t0\t0\t0\t100\t100\t-1\t",
        "5\t1\t1\t1\t1\t1\t0\t0\t10\t10\t90\tQ.1",
        "5\t1\t1\t1\t1\t2\t0\t0\t10\t10\t80\tWhat?",
        "5\t1\t1\t1\t2\t1\t0\t0\t10\t10\t70\t(1)",
        "5\t1\t1\t1\t2\t2\t0\t0\t10\t10\t-1\t",
    ]
    result = parse_tesseract_tsv("\n".join([header, *rows]))

    assert result.text == "Q.1 What?\n(1)"
    assert result.mean_confidence == pytest.approx(80.0)
    assert result.word_count == 3


def test_parse_empty_tsv() -> None:
    result = parse_tesseract_tsv("")
    assert (result.text, result.mean_confidence, result.word_count) == ("", None, 0)


def test_missing_tesseract_is_reported_as_unavailable() -> None:
    engine = TesseractOcrEngine(command="definitely-not-tesseract-xyz")
    assert engine.is_available() is False
    with pytest.raises(OcrUnavailableError):
        engine.recognize(text_image(["x"]), languages="eng", timeout_seconds=5)


def _engine() -> TesseractOcrEngine:
    tessdata = os.environ.get("PREPLOOP_TESSDATA_DIR")
    command = os.environ.get("PREPLOOP_TESSERACT_CMD", "tesseract")
    default_windows = Path("C:/Program Files/Tesseract-OCR/tesseract.exe")
    if command == "tesseract" and default_windows.is_file():
        command = str(default_windows)
    user_tessdata = Path.home() / ".preploop" / "tessdata"
    if tessdata is None and user_tessdata.is_dir():
        tessdata = str(user_tessdata)
    return TesseractOcrEngine(command, Path(tessdata) if tessdata else None)


def _devanagari_font() -> Path | None:
    candidates = [
        Path("C:/Windows/Fonts/Nirmala.ttc"),
        Path("C:/Windows/Fonts/Nirmala.ttf"),
        Path("C:/Windows/Fonts/mangal.ttf"),
        Path("/usr/share/fonts/truetype/noto/NotoSansDevanagari-Regular.ttf"),
        Path("/usr/share/fonts/opentype/noto/NotoSansDevanagari-Regular.ttf"),
    ]
    return next((p for p in candidates if p.is_file()), None)


@pytest.mark.skipif(not _engine().is_available("eng"), reason="Tesseract (eng) not installed")
def test_real_tesseract_reads_english() -> None:
    image = text_image(["Q.1 What is 20% of 150?", "(1) 20 (2) 30 (3) 40 (4) 50"], size=48)

    result = _engine().recognize(image, languages="eng", timeout_seconds=60)

    assert "150" in result.text
    assert "What" in result.text
    assert result.mean_confidence is not None and result.mean_confidence > 70


@pytest.mark.skipif(
    not _engine().is_available("hin+eng") or _devanagari_font() is None,
    reason="Tesseract Hindi data or a Devanagari font is not installed",
)
def test_real_tesseract_reads_hindi() -> None:
    image = text_image(["प्रश्न सामान्य ज्ञान"], font_path=_devanagari_font(), size=64)

    result = _engine().recognize(image, languages="hin+eng", timeout_seconds=60)

    assert "प्रश्न" in result.text
    assert result.mean_confidence is not None
