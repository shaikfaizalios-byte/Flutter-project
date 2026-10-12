from datetime import datetime

from sqlalchemy import Boolean, DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class Exam(Base):
    """An examination the app supports. Exams are reference data, not code: adding one is
    a data migration. Patterns, sections and marking schemes are added as separate
    configuration in later phases and are never invented."""

    __tablename__ = "exams"

    code: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
