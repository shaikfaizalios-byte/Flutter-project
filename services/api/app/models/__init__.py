"""Import every model here so Alembic autogenerate sees the full metadata."""

from app.models.concept import Concept
from app.models.exam import Exam

__all__ = ["Concept", "Exam"]
