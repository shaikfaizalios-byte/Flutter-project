"""Outgoing email (password reset and verification codes).

- ``SmtpEmailSender``: any SMTP provider (Amazon SES, Postmark, Mailgun, Brevo, ...) over
  STARTTLS or implicit TLS, using only the standard library.
- ``FileOutboxEmailSender``: development; writes ``.eml`` files to a local, gitignored folder
  instead of sending (open them with any mail client).
- ``DisabledEmailSender``: drops messages (logged without content).

Message bodies (which contain one-time codes) are never logged.
"""

import logging
import smtplib
import ssl
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from email.message import EmailMessage
from pathlib import Path
from typing import Protocol

from app.core.config import Settings

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class OutgoingEmail:
    to: str
    subject: str
    text: str


class EmailSender(Protocol):
    def send(self, email: OutgoingEmail) -> None: ...


def _message(sender: str, email: OutgoingEmail) -> EmailMessage:
    message = EmailMessage()
    message["From"] = sender
    message["To"] = email.to
    message["Subject"] = email.subject
    message["Message-ID"] = f"<{uuid.uuid4().hex}@preploop>"
    message.set_content(email.text)
    return message


class SmtpEmailSender:
    def __init__(
        self,
        host: str,
        port: int,
        sender: str,
        *,
        username: str | None,
        password: str | None,
        security: str,
        timeout_seconds: float = 15,
    ) -> None:
        self._host = host
        self._port = port
        self._sender = sender
        self._username = username
        self._password = password
        self._security = security
        self._timeout = timeout_seconds

    def send(self, email: OutgoingEmail) -> None:
        context = ssl.create_default_context()
        message = _message(self._sender, email)
        try:
            if self._security == "ssl":
                with smtplib.SMTP_SSL(
                    self._host, self._port, timeout=self._timeout, context=context
                ) as smtp:
                    self._deliver(smtp, message)
            else:
                with smtplib.SMTP(self._host, self._port, timeout=self._timeout) as smtp:
                    smtp.starttls(context=context)
                    self._deliver(smtp, message)
        except (smtplib.SMTPException, OSError) as exc:
            # Log the failure type only; never the recipient's code.
            logger.error("Sending email failed: %s", type(exc).__name__)
            raise

    def _deliver(self, smtp: smtplib.SMTP, message: EmailMessage) -> None:
        if self._username:
            smtp.login(self._username, self._password or "")
        smtp.send_message(message)


class FileOutboxEmailSender:
    def __init__(self, directory: Path, sender: str = "PrepLoop <no-reply@localhost>") -> None:
        self._directory = directory
        self._sender = sender

    def send(self, email: OutgoingEmail) -> None:
        self._directory.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%S")
        path = self._directory / f"{stamp}-{uuid.uuid4().hex[:8]}.eml"
        path.write_bytes(bytes(_message(self._sender, email)))
        logger.info("Email written to the development outbox")


class DisabledEmailSender:
    def send(self, email: OutgoingEmail) -> None:
        logger.warning("Email sending is disabled; a message was dropped")


def email_sender_from_settings(settings: Settings) -> EmailSender:
    if settings.email_backend == "smtp":
        assert settings.smtp_host and settings.smtp_from  # noqa: S101 - checked by Settings
        return SmtpEmailSender(
            settings.smtp_host,
            settings.smtp_port,
            settings.smtp_from,
            username=settings.smtp_username,
            password=settings.smtp_password.get_secret_value() if settings.smtp_password else None,
            security=settings.smtp_security,
        )
    if settings.email_backend == "file":
        return FileOutboxEmailSender(settings.email_outbox_dir)
    return DisabledEmailSender()
