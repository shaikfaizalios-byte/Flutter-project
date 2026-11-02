import uuid
from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base

CUSTOM_EXAM_PREFIX = "MY_"


class Exam(Base):
    """An examination learners prepare for. Exams are reference data, not code.

    Catalog exams (``owner_id`` NULL) are added by data migrations and visible to everyone;
    only their names and grouping are stored. A learner can also create a private exam of
    their own (``owner_id`` set, code ``MY_...``). Patterns, sections and marking schemes are
    separate, verified configuration (``exam_formats``) and are never invented.
    """

    __tablename__ = "exams"
    __table_args__ = (
        CheckConstraint(
            "country_code IS NULL OR country_code ~ '^[A-Z]{2}$'", name="country_code_iso"
        ),
    )

    code: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    # Short display name for catalog exams ("SSC CGL"); own exams show ``name``.
    short_name: Mapped[str | None] = mapped_column(String(40))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    owner_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    # Catalog grouping, e.g. "Staff Selection", "Banking" (custom exams: NULL).
    category: Mapped[str | None] = mapped_column(String(40))
    featured: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    sort_order: Mapped[int] = mapped_column(Integer, default=100, server_default="100")
    # Global exam catalog (set by the operator, never guessed): ISO 3166-1 alpha-2 country, the
    # body that runs the exam, and other names learners search for.
    country_code: Mapped[str | None] = mapped_column(String(2))
    authority: Mapped[str | None] = mapped_column(String(120))
    aliases: Mapped[list[str]] = mapped_column(ARRAY(String(60)), default=list, server_default="{}")
    # Languages the exam's question paper is offered in, from its official notice (codes of
    # app/domain/languages.py, checked by the operator tool). Empty = not recorded yet; it is
    # never filled in by guess (global Phase 10).
    languages: Mapped[list[str]] = mapped_column(
        ARRAY(String(8)), default=list, server_default="{}"
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
