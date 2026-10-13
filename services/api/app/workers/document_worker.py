"""Document processing worker.

Run standalone (recommended outside local development):
    python -m app.workers.document_worker

or inside the API process when ``PREPLOOP_DOCUMENT_WORKER_IN_PROCESS=true`` (the default
for local development). Several workers may run at once; claims use row locks.
"""

import logging
import signal
import threading
from types import FrameType

from sqlalchemy.orm import Session, sessionmaker

from app.core.config import Settings, get_settings
from app.core.logging import configure_logging
from app.database.session import build_engine, build_sessionmaker
from app.integrations.ocr import TesseractOcrEngine
from app.integrations.storage import LocalDocumentStorage
from app.services.processing_service import DocumentProcessor

logger = logging.getLogger("app.worker")


def build_processor(settings: Settings) -> DocumentProcessor:
    return DocumentProcessor(
        storage=LocalDocumentStorage(settings.upload_dir),
        ocr=TesseractOcrEngine(settings.tesseract_cmd, settings.tessdata_dir),
        settings=settings,
    )


def run_once(factory: sessionmaker[Session], processor: DocumentProcessor) -> bool:
    """Process at most one document. Returns True if one was processed."""
    with factory() as session:
        document_id = processor.claim_next(session)
        if document_id is None:
            return False
        processor.process(session, document_id)
        return True


def run_forever(
    factory: sessionmaker[Session],
    processor: DocumentProcessor,
    stop: threading.Event,
    poll_seconds: float,
) -> None:
    logger.info("document worker started")
    while not stop.is_set():
        try:
            if run_once(factory, processor):
                continue  # more work may be waiting
        except Exception:
            # Keep the worker alive (e.g. the database restarted); retry after a pause.
            logger.exception("document worker iteration failed")
        stop.wait(poll_seconds)
    logger.info("document worker stopped")


def start_background_worker(
    factory: sessionmaker[Session], settings: Settings
) -> tuple[threading.Thread, threading.Event]:
    stop = threading.Event()
    thread = threading.Thread(
        target=run_forever,
        args=(factory, build_processor(settings), stop, settings.document_worker_poll_seconds),
        name="document-worker",
        daemon=True,
    )
    thread.start()
    return thread, stop


def main() -> None:
    settings = get_settings()
    configure_logging(settings.log_level)
    engine = build_engine(settings)
    if engine is None:
        raise SystemExit("PREPLOOP_DATABASE_URL is not set.")
    stop = threading.Event()

    def _stop(signum: int, _frame: FrameType | None) -> None:
        logger.info("stop requested", extra={"fields": {"signal": signum}})
        stop.set()

    signal.signal(signal.SIGINT, _stop)
    signal.signal(signal.SIGTERM, _stop)
    try:
        run_forever(
            build_sessionmaker(engine),
            build_processor(settings),
            stop,
            settings.document_worker_poll_seconds,
        )
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
