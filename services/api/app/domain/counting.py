"""What counts as one in repeat analysis. Pure.

Most exams count papers. A multi-shift exam can count sessions instead: papers of the same
confirmed date, shift and session are one sitting. A paper without those facts counts on its
own, because nothing says it belongs with another.
"""

import uuid
from collections.abc import Hashable
from datetime import date

# Worded alike in at least this many papers, with no model yet: worth naming.
MIN_PAPERS_TO_NAME = 3


def unit_key(
    counting_unit: str,
    document_id: uuid.UUID,
    *,
    confirmed: bool,
    exam_date: date | None,
    exam_shift: int | None,
    session_label: str | None,
) -> Hashable:
    if counting_unit != "session" or not confirmed or exam_date is None:
        return document_id
    return (exam_date, exam_shift, session_label)
