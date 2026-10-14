"""AI provider access (server only).

``AIProvider`` is the seam: services ask for JSON that matches a schema and get a parsed
dict back. ``AnthropicProvider`` calls Claude with structured outputs; tests use the
deterministic fake in ``tests/fakes.py``. Prompts and document text are never logged.
"""

import json
import logging
from dataclasses import dataclass
from typing import Any, Protocol

from app.core.config import Settings

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class AIResult:
    data: dict[str, Any]
    input_tokens: int = 0
    output_tokens: int = 0


class AIProviderError(Exception):
    """The provider failed (network, timeout, rate limit, refusal or unusable output).
    ``reason`` is a short code safe to log and store; it never contains prompt text."""

    def __init__(self, reason: str, *, retryable: bool = True) -> None:
        super().__init__(reason)
        self.reason = reason
        self.retryable = retryable


class AIProvider(Protocol):
    @property
    def name(self) -> str: ...

    @property
    def model(self) -> str: ...

    def complete_json(
        self, *, system: str, prompt: str, schema: dict[str, Any], max_tokens: int
    ) -> AIResult:
        """Returns output that matches ``schema`` or raises ``AIProviderError``."""
        ...


class AnthropicProvider:
    """Claude via the official SDK, with JSON-schema structured output."""

    name = "anthropic"

    def __init__(self, api_key: str, model: str, timeout_seconds: float) -> None:
        import anthropic  # imported lazily: only needed when AI is configured

        self._anthropic = anthropic
        self._client = anthropic.Anthropic(api_key=api_key, timeout=timeout_seconds, max_retries=2)
        self._model = model

    @property
    def model(self) -> str:
        return self._model

    def complete_json(
        self, *, system: str, prompt: str, schema: dict[str, Any], max_tokens: int
    ) -> AIResult:
        errors = self._anthropic
        try:
            message = self._client.messages.create(
                model=self._model,
                max_tokens=max_tokens,
                system=system,
                messages=[{"role": "user", "content": prompt}],
                output_config={"format": {"type": "json_schema", "schema": schema}},
            )
        except errors.APITimeoutError as exc:
            raise AIProviderError("timeout") from exc
        except errors.RateLimitError as exc:
            raise AIProviderError("provider_rate_limited") from exc
        except errors.AuthenticationError as exc:
            logger.error("AI provider rejected the API key (check PREPLOOP_AI_API_KEY)")
            raise AIProviderError("provider_auth", retryable=False) from exc
        except errors.APIStatusError as exc:
            logger.warning("AI provider error status=%s", exc.status_code)
            raise AIProviderError(f"provider_status_{exc.status_code}") from exc
        except errors.APIConnectionError as exc:
            raise AIProviderError("connection") from exc

        if message.stop_reason == "refusal":
            raise AIProviderError("refused", retryable=False)
        if message.stop_reason == "max_tokens":
            raise AIProviderError("truncated")
        text = "".join(block.text for block in message.content if block.type == "text")
        try:
            data = json.loads(text)
        except json.JSONDecodeError as exc:
            raise AIProviderError("invalid_json") from exc
        if not isinstance(data, dict):
            raise AIProviderError("invalid_json")
        return AIResult(
            data=data,
            input_tokens=message.usage.input_tokens,
            output_tokens=message.usage.output_tokens,
        )


def provider_from_settings(settings: Settings) -> AIProvider | None:
    """The configured provider, or None when AI is switched off (no API key)."""
    if settings.ai_api_key is None or not settings.ai_api_key.get_secret_value().strip():
        return None
    return AnthropicProvider(
        settings.ai_api_key.get_secret_value(), settings.ai_model, settings.ai_timeout_seconds
    )
