"""Accounts: registration, sign-in, rotating refresh tokens, sign-out, export, deletion."""

import logging
import uuid
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import func, select, text, update
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.security import (
    TokenSigner,
    hash_password,
    hash_refresh_token,
    needs_rehash,
    new_refresh_token,
    verify_password,
)
from app.domain.errors import EmailTakenError, InvalidCredentialsError, UnauthorizedError
from app.integrations.storage import DocumentStorage
from app.models.ai import AIGeneration
from app.models.concept import Concept
from app.models.document import Document
from app.models.practice import PracticeSession
from app.models.question import Question
from app.models.sync import SyncItem
from app.models.user import RefreshToken, User
from app.schemas.auth import AccountExport, TokenPair, UserRead

logger = logging.getLogger(__name__)

# Tables whose rows belong to an account (owner_id). Rows created before accounts existed
# (owner_id NULL) are claimed by the first account (single-tenant → multi-user migration).
OWNED_MODELS: tuple[type[Any], ...] = (Concept, Document, Question, PracticeSession, AIGeneration)

# Serialises "first account" claims (arbitrary constant for pg_advisory_xact_lock).
_CLAIM_LOCK = 724_310_010


class AuthService:
    def __init__(
        self,
        session: Session,
        signer: TokenSigner,
        settings: Settings,
        *,
        now: Callable[[], datetime] | None = None,
    ) -> None:
        self._session = session
        self._signer = signer
        self._settings = settings
        self._now = now or (lambda: datetime.now(UTC))

    # --- accounts -------------------------------------------------------------------------

    def register(self, email: str, password: str, display_name: str | None) -> TokenPair:
        if password.strip().lower() == email:
            raise InvalidCredentialsError("Choose a password that is not your email address.")
        self._session.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": _CLAIM_LOCK})
        if self._session.scalar(select(User.id).where(User.email == email)) is not None:
            raise EmailTakenError("An account with this email already exists.")
        first_account = (self._session.scalar(select(func.count(User.id))) or 0) == 0
        user = User(email=email, password_hash=hash_password(password), display_name=display_name)
        self._session.add(user)
        self._session.flush()
        if first_account:
            claimed = 0
            for model in OWNED_MODELS:
                result = self._session.execute(
                    update(model).where(model.owner_id.is_(None)).values(owner_id=user.id)
                )
                claimed += result.rowcount  # type: ignore[attr-defined]
            if claimed:
                logger.info("First account claimed %d existing rows", claimed)
        pair = self._issue(user, family_id=uuid.uuid4())
        self._session.commit()
        return pair

    def login(self, email: str, password: str) -> TokenPair:
        user = self._session.scalars(select(User).where(User.email == email)).first()
        if not verify_password(user.password_hash if user else None, password) or user is None:
            raise InvalidCredentialsError("Email or password is not correct.")
        if needs_rehash(user.password_hash):
            user.password_hash = hash_password(password)
        user.last_login_at = self._now()
        pair = self._issue(user, family_id=uuid.uuid4())
        self._session.commit()
        return pair

    def user(self, user_id: uuid.UUID) -> User:
        user = self._session.get(User, user_id)
        if user is None:
            raise UnauthorizedError("This account no longer exists.")
        return user

    # --- refresh tokens -------------------------------------------------------------------

    def refresh(self, token: str) -> TokenPair:
        """Rotates a refresh token. Reusing a replaced token revokes its whole family."""
        row = self._session.scalars(
            select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(token))
        ).first()
        now = self._now()
        if row is None:
            raise UnauthorizedError("Please sign in again.")
        if row.revoked_at is not None or row.used_at is not None:
            self._revoke_family(row.family_id, now)
            self._session.commit()
            logger.warning("Refresh token reuse detected; family revoked")
            raise UnauthorizedError("Please sign in again.")
        if row.expires_at <= now:
            raise UnauthorizedError("Your session has expired. Please sign in again.")
        row.used_at = now
        pair = self._issue(self.user(row.user_id), family_id=row.family_id)
        self._session.commit()
        return pair

    def logout(self, token: str) -> None:
        row = self._session.scalars(
            select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(token))
        ).first()
        if row is not None:
            self._revoke_family(row.family_id, self._now())
            self._session.commit()

    # --- privacy --------------------------------------------------------------------------

    def export(self, user: User) -> AccountExport:
        data: dict[str, list[dict[str, Any]]] = {}
        for model in OWNED_MODELS:
            rows = self._session.scalars(select(model).where(model.owner_id == user.id)).all()
            data[model.__tablename__] = [_row_dict(r) for r in rows]
        # Children that belong to owned rows.
        question_ids = [q["id"] for q in data.get("questions", [])]
        if question_ids:
            from app.models.question import QuestionOption

            options = self._session.scalars(
                select(QuestionOption).where(QuestionOption.question_id.in_(question_ids))
            ).all()
            data["question_options"] = [_row_dict(o) for o in options]
        synced = self._session.scalars(select(SyncItem).where(SyncItem.owner_id == user.id)).all()
        data["sync_items"] = [_row_dict(s) for s in synced]
        session_ids = [s["id"] for s in data.get("practice_sessions", [])]
        if session_ids:
            from app.models.practice import SessionAnswer

            answers = self._session.scalars(
                select(SessionAnswer).where(SessionAnswer.session_id.in_(session_ids))
            ).all()
            data["session_answers"] = [_row_dict(a) for a in answers]
        return AccountExport(exported_at=self._now(), user=UserRead.model_validate(user), data=data)

    def delete_account(self, user: User, password: str, storage: DocumentStorage) -> None:
        """Deletes the account and everything it owns, including stored PDF files."""
        if not verify_password(user.password_hash, password):
            raise InvalidCredentialsError("Password is not correct.")
        keys = self._session.scalars(
            select(Document.storage_key).where(Document.owner_id == user.id)
        ).all()
        self._session.delete(user)  # owned rows cascade (owner_id ON DELETE CASCADE)
        self._session.commit()
        for key in keys:
            try:
                storage.delete(key)
            except OSError:
                logger.warning("Could not delete a stored file during account deletion")

    # --- helpers --------------------------------------------------------------------------

    def _issue(self, user: User, *, family_id: uuid.UUID) -> TokenPair:
        token = new_refresh_token()
        self._session.add(
            RefreshToken(
                user_id=user.id,
                family_id=family_id,
                token_hash=hash_refresh_token(token),
                expires_at=self._now() + timedelta(days=self._settings.refresh_token_days),
            )
        )
        return TokenPair(
            access_token=self._signer.access_token(user.id, now=self._now()),
            refresh_token=token,
            expires_in=self._signer.access_minutes * 60,
            user=UserRead.model_validate(user),
        )

    def _revoke_family(self, family_id: uuid.UUID, now: datetime) -> None:
        self._session.execute(
            update(RefreshToken)
            .where(RefreshToken.family_id == family_id, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=now)
        )


def _row_dict(row: Any) -> dict[str, Any]:
    return {attr.key: getattr(row, attr.key) for attr in row.__mapper__.column_attrs}
