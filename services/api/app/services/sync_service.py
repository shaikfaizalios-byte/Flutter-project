"""Device-data sync (rules in docs/database.md, "Sync rules").

- Push applies a device's changes in order. Last writer wins per record: each accepted
  change gets a new server sequence number. Deleted records are tombstones and win over any
  later edit. Replaying the same push is harmless (same data, same outcome).
- Pull returns the account's changes after a cursor (sequence number), oldest first.
- Pushes for one account are serialised with an advisory lock, so sequence order equals
  commit order for that account and a cursor can never skip a change.
"""

import uuid
from typing import Any

from pydantic import ValidationError
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.models.sync import SYNC_SEQ, SyncItem
from app.schemas.sync import (
    ENTITY_SCHEMAS,
    FIXED_IDS,
    Change,
    PullResult,
    PushResult,
    ServerChange,
)

MAX_PULL = 500


class SyncService:
    def __init__(self, session: Session, owner_id: uuid.UUID) -> None:
        self._session = session
        self._owner_id = owner_id

    def push(self, changes: list[Change]) -> PushResult:
        self._session.execute(
            text("SELECT pg_advisory_xact_lock(hashtextextended(:owner, 0))"),
            {"owner": str(self._owner_id)},
        )
        accepted = 0
        ignored: list[str] = []
        rejected: dict[str, str] = {}
        for change in changes:
            key = f"{change.entity}:{change.id}"
            problem, data = self._validate(change)
            if problem:
                rejected[key] = problem
                continue
            row = self._session.get(SyncItem, (self._owner_id, change.entity, change.id))
            if row is not None and row.deleted:
                ignored.append(key)  # tombstones win over concurrent or later edits
                continue
            if row is None:
                row = SyncItem(owner_id=self._owner_id, entity=change.entity, item_id=change.id)
                self._session.add(row)
                # Flush so a second change to the same record in this push finds this row.
                self._session.flush()
            row.deleted = change.deleted
            row.data = None if change.deleted else data
            row.seq = int(self._session.execute(select(SYNC_SEQ.next_value())).scalar_one())
            row.updated_at = func.now()
            accepted += 1
        self._session.commit()
        return PushResult(accepted=accepted, ignored_deleted=ignored, rejected=rejected)

    def pull(self, cursor: int, limit: int = MAX_PULL) -> PullResult:
        rows = self._session.scalars(
            select(SyncItem)
            .where(SyncItem.owner_id == self._owner_id, SyncItem.seq > cursor)
            .order_by(SyncItem.seq)
            .limit(limit + 1)
        ).all()
        page = rows[:limit]
        return PullResult(
            changes=[
                ServerChange(
                    entity=r.entity,
                    id=r.item_id,
                    deleted=r.deleted,
                    data=r.data,
                    seq=r.seq,
                    updated_at=r.updated_at,
                )
                for r in page
            ],
            cursor=page[-1].seq if page else cursor,
            has_more=len(rows) > limit,
        )

    @staticmethod
    def _validate(change: Change) -> tuple[str | None, dict[str, Any] | None]:
        fixed = FIXED_IDS.get(change.entity)
        if fixed is not None and change.id not in fixed:
            return f"Unknown id for {change.entity}.", None
        if change.deleted:
            return None, None
        if change.data is None:
            return "Missing data.", None
        try:
            model = ENTITY_SCHEMAS[change.entity].model_validate(change.data)
        except ValidationError as exc:
            first = exc.errors()[0]
            where = ".".join(str(p) for p in first["loc"])
            return f"{where}: {first['msg']}"[:200], None
        return None, model.model_dump(mode="json")
