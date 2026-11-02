from sqlalchemy import CheckConstraint, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class LanguageRow(Base):
    """A supported content language (global Phase 10). The same list as
    ``app/domain/languages.py`` (``tests/test_languages.py`` compares them); content tables'
    ``language`` columns reference ``code``, so an unknown code can't be stored."""

    __tablename__ = "languages"
    __table_args__ = (
        CheckConstraint("code ~ '^[a-z]{2,3}$'", name="code_iso"),
        CheckConstraint("script ~ '^[A-Z][a-z]{3}$'", name="script_iso"),
        CheckConstraint("direction IN ('ltr', 'rtl')", name="direction_known"),
    )

    code: Mapped[str] = mapped_column(String(8), primary_key=True)
    english_name: Mapped[str] = mapped_column(String(60))
    native_name: Mapped[str] = mapped_column(String(60))
    script: Mapped[str] = mapped_column(String(4))
    direction: Mapped[str] = mapped_column(String(3))
