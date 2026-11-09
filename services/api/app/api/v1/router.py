from fastapi import APIRouter, Depends

from app.api.deps import get_current_user
from app.api.v1.endpoints import (
    ai,
    analytics,
    auth,
    billing,
    concepts,
    content,
    descriptive,
    documents,
    exam_topics,
    exams,
    feedback,
    health,
    insights,
    ladder,
    library,
    media,
    ops,
    plus,
    practice,
    questions,
    radar,
    sync,
)

# Every learner-data route requires a signed-in account. Services additionally scope every
# query to that account (ownership is enforced at the service/repository boundary).
_signed_in = [Depends(get_current_user)]

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(ops.router)
api_router.include_router(exams.router, tags=["exams"])
api_router.include_router(auth.router)
# Older server-side concept store for API clients; the app syncs concepts via /sync instead.
api_router.include_router(
    concepts.router, tags=["concepts"], dependencies=_signed_in, deprecated=True
)
api_router.include_router(documents.router, tags=["documents"], dependencies=_signed_in)
api_router.include_router(questions.router, dependencies=_signed_in)
api_router.include_router(exam_topics.router, dependencies=_signed_in)
api_router.include_router(practice.router, dependencies=_signed_in)
api_router.include_router(analytics.router, dependencies=_signed_in)
api_router.include_router(insights.router, dependencies=_signed_in)
api_router.include_router(radar.router, dependencies=_signed_in)
api_router.include_router(ai.router, dependencies=_signed_in)
api_router.include_router(ladder.router, dependencies=_signed_in)
api_router.include_router(library.router, dependencies=_signed_in)
api_router.include_router(descriptive.router, dependencies=_signed_in)
api_router.include_router(sync.router, dependencies=_signed_in)
api_router.include_router(feedback.router, dependencies=_signed_in)
api_router.include_router(content.router, dependencies=_signed_in)
api_router.include_router(plus.router, dependencies=_signed_in)
# Not signed in as a whole: Google's notifications carry their own token (verify needs a user).
api_router.include_router(billing.router)
api_router.include_router(media.router)
