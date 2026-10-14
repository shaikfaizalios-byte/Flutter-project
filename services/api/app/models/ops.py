"""Operational tables (Phase 11)."""

from datetime import datetime

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class RateLimitCounter(Base):
    """Hits per hashed rate-limit key and fixed time window (shared by all API processes)."""

    __tablename__ = "rate_limit_counters"

    key_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    window_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True)
    hits: Mapped[int] = mapped_column(Integer, default=0)
