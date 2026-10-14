from dataclasses import dataclass, field
from typing import Any

from PIL import Image

from app.integrations.ai import AIProviderError, AIResult
from app.integrations.email import OutgoingEmail
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


@dataclass
class AICall:
    system: str
    prompt: str
    schema: dict[str, Any]
    max_tokens: int


@dataclass
class FakeAIProvider:
    """Deterministic AI provider: returns scripted JSON (or raises scripted errors) in order,
    and records every call so prompts can be checked. No network."""

    responses: list[dict[str, Any] | AIProviderError] = field(default_factory=list)
    calls: list[AICall] = field(default_factory=list)
    name: str = "fake"
    model: str = "fake-model-1"

    def complete_json(
        self, *, system: str, prompt: str, schema: dict[str, Any], max_tokens: int
    ) -> AIResult:
        self.calls.append(AICall(system, prompt, schema, max_tokens))
        if not self.responses:
            raise AssertionError("FakeAIProvider: no scripted response left")
        response = self.responses.pop(0)
        if isinstance(response, AIProviderError):
            raise response
        return AIResult(data=response, input_tokens=120, output_tokens=80)


@dataclass
class FakeEmailSender:
    """Captures outgoing emails instead of sending them."""

    sent: list[OutgoingEmail] = field(default_factory=list)

    def send(self, email: OutgoingEmail) -> None:
        self.sent.append(email)

    def last_code(self) -> str:
        import re

        match = re.search(r"\b(\d{6})\b", self.sent[-1].text)
        assert match is not None
        return match.group(1)
