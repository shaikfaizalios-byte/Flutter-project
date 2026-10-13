"""FastAPI application factory."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import Engine

from app.api.v1.endpoints.health import build_health
from app.api.v1.router import api_router
from app.core.config import Settings, get_settings
from app.core.errors import register_exception_handlers
from app.core.logging import configure_logging
from app.core.middleware import REQUEST_ID_HEADER, RequestContextMiddleware
from app.core.rate_limit import SlidingWindowRateLimiter
from app.database.session import build_engine, build_sessionmaker
from app.integrations.storage import DocumentStorage, LocalDocumentStorage
from app.schemas.health import HealthResponse
from app.workers.document_worker import start_background_worker


def create_app(
    settings: Settings | None = None,
    *,
    engine: Engine | None = None,
    storage: DocumentStorage | None = None,
) -> FastAPI:
    """Build the app. ``engine`` and ``storage`` let tests inject dependencies; by default
    they are created from settings (no engine if ``database_url`` is unset)."""
    settings = settings or get_settings()
    configure_logging(settings.log_level)
    owns_engine = engine is None
    engine = engine if engine is not None else build_engine(settings)
    session_factory = build_sessionmaker(engine) if engine is not None else None

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        worker = None
        if settings.document_worker_in_process and session_factory is not None:
            worker = start_background_worker(session_factory, settings)
        yield
        if worker is not None:
            thread, stop = worker
            stop.set()
            thread.join(timeout=10)
        if owns_engine and engine is not None:
            engine.dispose()

    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        openapi_url=f"{settings.api_v1_prefix}/openapi.json" if settings.docs_enabled else None,
        docs_url="/docs" if settings.docs_enabled else None,
        redoc_url=None,
        lifespan=lifespan,
    )
    app.state.engine = engine
    app.state.sessionmaker = session_factory
    app.state.document_storage = storage or LocalDocumentStorage(settings.upload_dir)
    app.state.upload_rate_limiter = SlidingWindowRateLimiter(
        settings.upload_rate_limit, settings.upload_rate_window_seconds
    )
    # Use the injected settings everywhere, including Depends(get_settings).
    app.dependency_overrides[get_settings] = lambda: settings

    # Middleware order: the last added is the outermost. CORS sits inside the request
    # context so that every response, including CORS rejections, carries a request ID.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_origin_regex=settings.cors_origin_regex,
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
        allow_headers=["Authorization", "Content-Type", REQUEST_ID_HEADER],
        expose_headers=[REQUEST_ID_HEADER],
    )
    app.add_middleware(RequestContextMiddleware)

    register_exception_handlers(app)

    @app.get("/health", response_model=HealthResponse, tags=["health"], summary="Root liveness")
    def root_health() -> HealthResponse:
        return build_health(settings)

    app.include_router(api_router, prefix=settings.api_v1_prefix)
    return app


app = create_app()
