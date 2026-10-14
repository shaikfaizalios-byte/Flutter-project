"""Device data synchronised between a learner's devices (Phase 10)."""

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Sequence,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base

# One server-wide, ever-increasing change number; a device's cursor is the last one it saw.
SYNC_SEQ = Sequence("sync_seq")


class SyncItem(Base):
    """The latest server copy of one device record (concept, study profile, revision card,
    card review, setting). ``deleted`` rows are tombstones: they win over later edits."""

    __tablename__ = "sync_items"
    __table_args__ = (Index("ix_sync_items_owner_seq", "owner_id", "seq"),)

    owner_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    entity: Mapped[str] = mapped_column(String(32), primary_key=True)
    # Client-generated id (UUID for most entities; fixed keys for singletons/settings).
    item_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    data: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
    deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    seq: Mapped[int] = mapped_column(BigInteger, SYNC_SEQ, server_default=SYNC_SEQ.next_value())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
