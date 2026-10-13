from fastapi import APIRouter

from app.api.v1.endpoints import concepts, documents, exams, health, practice, questions

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(exams.router, tags=["exams"])
api_router.include_router(concepts.router, tags=["concepts"])
api_router.include_router(documents.router, tags=["documents"])
api_router.include_router(questions.router)
api_router.include_router(practice.router)
