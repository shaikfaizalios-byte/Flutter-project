"""Application settings loaded from environment variables (and an optional .env file)."""

from decimal import Decimal
from enum import StrEnum
from functools import lru_cache
from pathlib import Path
from typing import Annotated, Literal, Self

from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

from app.domain.razorpay import environment_of as razorpay_environment_of


class Environment(StrEnum):
    DEVELOPMENT = "development"
    TEST = "test"
    STAGING = "staging"
    PRODUCTION = "production"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="PREPLOOP_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "PrepLoop API"
    app_version: str = "0.1.0"
    environment: Environment = Environment.DEVELOPMENT
    log_level: str = "INFO"
    api_v1_prefix: str = "/api/v1"

    # Comma-separated list of exact allowed origins, e.g. "https://app.example.com".
    # Interactive docs (/docs, OpenAPI) outside production. Turn off when a development server
    # is reachable from the internet (e.g. through a tunnel).
    expose_docs: bool = True
    # The content team's review page at /review-tool. It holds no data and needs a sign-in, but
    # stays off in production unless turned on.
    expose_review_tool: bool = False
    cors_origins: Annotated[list[str], NoDecode] = Field(default_factory=list)
    # Optional regex for allowed origins. Intended for local development only, where the
    # Flutter web dev server picks a random localhost port.
    cors_origin_regex: str | None = None

    # SQLAlchemy URL, e.g. postgresql+psycopg://user:pass@host:5432/db. When unset, the API
    # still starts (liveness works) but database-backed endpoints return 503.
    database_url: SecretStr | None = None
    database_pool_size: int = Field(default=5, ge=1, le=50)
    database_connect_timeout_seconds: int = Field(default=5, ge=1, le=60)

    # --- Document ingestion (Phase 4) ---
    # Uploaded originals are stored here under generated names (never the user's filename).
    upload_dir: Path = Path("var/uploads")
    max_upload_bytes: int = Field(default=25 * 1024 * 1024, ge=1024)
    max_pdf_pages: int = Field(default=300, ge=1, le=5000)
    # Uploads per client address per window (in-process limiter; see docs/security.md).
    upload_rate_limit: int = Field(default=10, ge=1)
    upload_rate_window_seconds: int = Field(default=3600, ge=1)
    # Whole-document processing budget; remaining pages are not processed after it.
    processing_timeout_seconds: int = Field(default=900, ge=10)
    # A text layer with fewer meaningful characters than this triggers OCR for the page.
    text_layer_min_chars: int = Field(default=25, ge=1)
    # For Hindi documents, a text layer whose letters are less than this share Devanagari is
    # treated as suspect (legacy-font encodings) and OCR is attempted.
    hindi_min_devanagari_ratio: float = Field(default=0.05, ge=0, le=1)
    # OCR (Tesseract). tesseract_cmd may be a full path; tessdata_dir overrides language data.
    tesseract_cmd: str = "tesseract"
    tessdata_dir: Path | None = None
    ocr_dpi: int = Field(default=300, ge=72, le=600)
    ocr_page_timeout_seconds: int = Field(default=120, ge=5)
    # Pages whose mean OCR word confidence is below this are flagged for review.
    ocr_min_confidence: float = Field(default=70.0, ge=0, le=100)
    # Run the document worker inside the API process (convenient locally). In production,
    # run `python -m app.workers.document_worker` as a separate process instead.
    document_worker_in_process: bool = True
    document_worker_poll_seconds: float = Field(default=2.0, gt=0)
    # Optional AI assistance (Anthropic Claude). Off unless an API key is configured; the key
    # stays on the server and is never logged or returned.
    ai_api_key: SecretStr | None = None
    ai_model: str = "claude-haiku-5-5"
    ai_timeout_seconds: float = Field(default=60.0, gt=0, le=600)
    ai_max_output_tokens: int = Field(default=4000, ge=256, le=32000)
    ai_rate_limit: int = Field(default=30, ge=1)
    ai_rate_window_seconds: int = Field(default=3600, ge=1)
    # Reading a paper with AI: the most pages sent (cost), and the page image size.
    ai_read_max_pages: int = Field(default=60, ge=1, le=300)
    ai_read_image_edge: int = Field(default=1500, ge=600, le=2400)
    # PrepLoop Plus. Successful AI requests allowed per account per calendar month (UTC), and a
    # development-only test mode that lets a learner start a free test subscription from the
    # app (refused in staging/production).
    plus_ai_monthly_allowance: int = Field(default=300, ge=1)
    plus_test_mode: bool = False
    # AI features need an active subscription and stop at the allowance. Off only for
    # development setups that want AI without Plus (refused in staging/production).
    plus_required_for_ai: bool = True
    # Challenge Ladders a learner without Plus may start per day (UTC), one round each.
    # 0 = none. With Plus the normal monthly AI allowance applies instead.
    ladder_free_per_day: int = Field(default=1, ge=0, le=10)
    # Google Play Billing (docs/plus.md "Google Play"). Purchases are verified only on the server
    # with the Play Developer API, using a service account with access to the app in Play
    # Console. All three are needed to sell Plus; without them purchases stay unavailable.
    play_package_name: str | None = None
    play_subscription_ids: Annotated[list[str], NoDecode] = Field(default_factory=list)
    play_service_account_file: Path | None = None
    # Real-time developer notifications (Pub/Sub push to /api/v1/billing/play/rtdn): the
    # audience and service account the push subscription signs its OIDC token with.
    play_rtdn_audience: str | None = None
    play_rtdn_service_account: str | None = None
    # Paytm Payment Gateway: Plus bought on the website (docs/plus.md "Paytm"). Off unless the
    # merchant id and key, price, days, callback and return URLs are all set. A production
    # server must use Paytm's production environment, and any other server its staging one.
    paytm_environment: Literal["staging", "production"] = "staging"
    paytm_mid: str | None = None
    paytm_merchant_key: SecretStr | None = None
    paytm_website_name: str | None = None  # default: WEBSTAGING / DEFAULT
    paytm_plus_price: Decimal | None = Field(default=None, gt=0, max_digits=8, decimal_places=2)
    paytm_plus_days: int | None = Field(default=None, ge=1, le=366)
    # This API's /api/v1/billing/paytm/callback as Paytm can reach it.
    paytm_callback_url: str | None = None
    # The web app's page Paytm's callback sends the browser back to; "{order}" is replaced.
    paytm_return_url: str | None = None
    # Razorpay: Plus bought on the website (docs/plus.md "Razorpay"). Off unless the key id and
    # secret, webhook secret, price, days, callback and return URLs are all set. Test keys
    # (rzp_test_) on any server but production; live keys (rzp_live_) on production only. Only
    # one website payment provider may be configured.
    razorpay_key_id: str | None = None
    razorpay_key_secret: SecretStr | None = None
    razorpay_webhook_secret: SecretStr | None = None
    razorpay_plus_price: Decimal | None = Field(default=None, gt=0, max_digits=8, decimal_places=2)
    razorpay_plus_days: int | None = Field(default=None, ge=1, le=366)
    # This API's /api/v1/billing/razorpay/callback as the learner's browser can reach it.
    razorpay_callback_url: str | None = None
    # The web app's page the browser goes back to after paying; "{order}" is replaced.
    razorpay_return_url: str | None = None
    # Accounts. The signing secret is required outside development/test; locally a random
    # one is generated per process (tokens then stop working after a restart).
    auth_secret: SecretStr | None = None
    access_token_minutes: int = Field(default=15, ge=1, le=60)
    refresh_token_days: int = Field(default=30, ge=1, le=90)
    # Sign-in/registration attempts per client and email within the window (brute force).
    auth_rate_limit: int = Field(default=10, ge=1)
    auth_rate_window_seconds: int = Field(default=900, ge=1)
    # Rate-limit store: "memory" (one process) or "postgres" (shared; required in staging/prod).
    rate_limit_backend: Literal["memory", "postgres"] = "memory"
    # Email (password reset, verification). "file" writes .eml files to email_outbox_dir
    # (development); "smtp" sends via any SMTP provider (required in staging/prod).
    email_backend: Literal["file", "smtp", "disabled"] = "file"
    email_outbox_dir: Path = Path("var/outbox")
    smtp_host: str | None = None
    smtp_port: int = Field(default=587, ge=1, le=65535)
    smtp_username: str | None = None
    smtp_password: SecretStr | None = None
    smtp_from: str | None = None  # e.g. "PrepLoop <no-reply@example.com>"
    # "none" is only for a local test server (e.g. Mailpit); refused in staging/production.
    smtp_security: Literal["starttls", "ssl", "none"] = "starttls"
    # One-time codes for password reset and email verification.
    account_code_minutes: int = Field(default=15, ge=5, le=60)
    account_code_max_attempts: int = Field(default=5, ge=1, le=10)
    # Figures every learner may see get signed links a CDN can cache. The base is the CDN's
    # address in front of this API (empty: links are relative to the API).
    media_base_url: str | None = None
    media_url_hours: int = Field(default=24, ge=1, le=168)
    # Prometheus-format metrics at /api/v1/metrics, only with this bearer token.
    metrics_token: SecretStr | None = None

    @model_validator(mode="before")
    @classmethod
    def _split_origins(cls, data: object) -> object:
        if isinstance(data, dict):
            for key in ("cors_origins", "play_subscription_ids"):
                raw = data.get(key)
                if isinstance(raw, str):
                    data[key] = [o.strip() for o in raw.split(",") if o.strip()]
        return data

    @model_validator(mode="after")
    def _check_production_safety(self) -> Self:
        if self.environment is Environment.PRODUCTION:
            if "*" in self.cors_origins:
                raise ValueError("Wildcard CORS origin is not allowed in production.")
            if self.cors_origin_regex:
                raise ValueError("cors_origin_regex is not allowed in production.")
        if self.environment in (Environment.PRODUCTION, Environment.STAGING):
            if self.auth_secret is None or len(self.auth_secret.get_secret_value()) < 32:
                raise ValueError("PREPLOOP_AUTH_SECRET (32+ characters) is required here.")
            if self.rate_limit_backend != "postgres":
                raise ValueError("PREPLOOP_RATE_LIMIT_BACKEND=postgres is required here.")
            if self.email_backend != "smtp" or not self.smtp_host or not self.smtp_from:
                raise ValueError("SMTP email (PREPLOOP_SMTP_HOST, _FROM) is required here.")
            if self.smtp_security == "none":
                raise ValueError("Unencrypted SMTP is not allowed here.")
            if self.plus_test_mode:
                raise ValueError("PREPLOOP_PLUS_TEST_MODE is for development only.")
            if not self.plus_required_for_ai:
                raise ValueError("PREPLOOP_PLUS_REQUIRED_FOR_AI=false is for development only.")
        if self.paytm_configured:
            production = self.environment is Environment.PRODUCTION
            if production != (self.paytm_environment == "production"):
                raise ValueError(
                    "PREPLOOP_PAYTM_ENVIRONMENT must be production on a production server only."
                )
            key = self.paytm_merchant_key.get_secret_value() if self.paytm_merchant_key else ""
            if len(key.encode()) not in (16, 24, 32):
                raise ValueError("PREPLOOP_PAYTM_MERCHANT_KEY must be 16, 24 or 32 characters.")
            if self.environment in (Environment.PRODUCTION, Environment.STAGING) and not str(
                self.paytm_callback_url
            ).startswith("https://"):
                raise ValueError("PREPLOOP_PAYTM_CALLBACK_URL must be https here.")
        if self.razorpay_configured:
            if self.paytm_configured:
                raise ValueError("Configure Paytm or Razorpay for website payments, not both.")
            environment = razorpay_environment_of(self.razorpay_key_id or "")
            if environment is None:
                raise ValueError("PREPLOOP_RAZORPAY_KEY_ID must start with rzp_test_ or rzp_live_.")
            if (self.environment is Environment.PRODUCTION) != (environment == "production"):
                raise ValueError("Razorpay live keys are for a production server only.")
            if self.environment in (Environment.PRODUCTION, Environment.STAGING) and not str(
                self.razorpay_callback_url
            ).startswith("https://"):
                raise ValueError("PREPLOOP_RAZORPAY_CALLBACK_URL must be https here.")
        if self.email_backend == "smtp" and (not self.smtp_host or not self.smtp_from):
            raise ValueError("PREPLOOP_SMTP_HOST and PREPLOOP_SMTP_FROM are required for SMTP.")
        return self

    @property
    def play_billing_configured(self) -> bool:
        return bool(
            self.play_package_name and self.play_subscription_ids and self.play_service_account_file
        )

    @property
    def razorpay_configured(self) -> bool:
        return bool(
            self.razorpay_key_id
            and self.razorpay_key_secret
            and self.razorpay_webhook_secret
            and self.razorpay_plus_price
            and self.razorpay_plus_days
            and self.razorpay_callback_url
            and self.razorpay_return_url
        )

    @property
    def paytm_configured(self) -> bool:
        return bool(
            self.paytm_mid
            and self.paytm_merchant_key
            and self.paytm_plus_price
            and self.paytm_plus_days
            and self.paytm_callback_url
            and self.paytm_return_url
        )

    @property
    def review_tool_enabled(self) -> bool:
        return self.expose_review_tool or self.environment is not Environment.PRODUCTION

    @property
    def docs_enabled(self) -> bool:
        if self.environment is Environment.PRODUCTION:
            return False  # never in production, whatever the setting says
        return self.expose_docs


@lru_cache
def get_settings() -> Settings:
    return Settings()
