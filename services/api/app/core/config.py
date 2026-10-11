"""Application settings loaded from environment variables (and an optional .env file)."""

from enum import StrEnum
from functools import lru_cache
from typing import Annotated, Self

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


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
    cors_origins: Annotated[list[str], NoDecode] = Field(default_factory=list)
    # Optional regex for allowed origins. Intended for local development only, where the
    # Flutter web dev server picks a random localhost port.
    cors_origin_regex: str | None = None

    @model_validator(mode="before")
    @classmethod
    def _split_origins(cls, data: object) -> object:
        if isinstance(data, dict):
            raw = data.get("cors_origins")
            if isinstance(raw, str):
                data["cors_origins"] = [o.strip() for o in raw.split(",") if o.strip()]
        return data

    @model_validator(mode="after")
    def _check_production_safety(self) -> Self:
        if self.environment is Environment.PRODUCTION:
            if "*" in self.cors_origins:
                raise ValueError("Wildcard CORS origin is not allowed in production.")
            if self.cors_origin_regex:
                raise ValueError("cors_origin_regex is not allowed in production.")
        return self

    @property
    def docs_enabled(self) -> bool:
        return self.environment is not Environment.PRODUCTION


@lru_cache
def get_settings() -> Settings:
    return Settings()
