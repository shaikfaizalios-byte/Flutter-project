from dataclasses import dataclass, field

from PIL import Image

from app.integrations.ocr import OcrFailedError, OcrResult, OcrUnavailableError


@dataclass
class FakeOcrEngine:
    """Returns scripted results so OCR behaviour is tested without Tesseract."""

    text: str = "Recognised question text from a scanned page."
    confidence: float | None = 91.0
    mode: str = "ok"  # "ok" | "unavailable" | "failed"
    calls: list[tuple[tuple[int, int], str]] = field(default_factory=list)

    def recognize(self, image: Image.Image, *, languages: str, timeout_seconds: float) -> OcrResult:
        self.calls.append((image.size, languages))
        if self.mode == "unavailable":
            raise OcrUnavailableError("not installed")
        if self.mode == "failed":
            raise OcrFailedError("crashed")
        return OcrResult(
            text=self.text, mean_confidence=self.confidence, word_count=len(self.text.split())
        )
