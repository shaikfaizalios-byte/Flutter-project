import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, func
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
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
