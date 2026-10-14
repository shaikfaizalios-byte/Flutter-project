# PrepLoop API and document worker (same image, different command).
# Build context: services/api.  docker build -t preploop-api services/api
FROM python:3.12.10-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Tesseract OCR with English + Hindi data (Apache-2.0). Nothing else from apt.
RUN apt-get update \
    && apt-get install -y --no-install-recommends tesseract-ocr tesseract-ocr-eng tesseract-ocr-hin \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Runtime pins only (no test or lint tools); --no-deps keeps the set exactly as locked.
COPY requirements.runtime.lock.txt ./
RUN pip install --no-deps -r requirements.runtime.lock.txt

COPY pyproject.toml alembic.ini ./
COPY app ./app
COPY migrations ./migrations
RUN pip install --no-deps .

# Unprivileged user; only the data directory is writable.
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin preploop \
    && mkdir -p /app/var/uploads /app/var/outbox \
    && chown -R preploop /app/var
USER 10001

ENV PREPLOOP_UPLOAD_DIR=/app/var/uploads \
    PREPLOOP_EMAIL_OUTBOX_DIR=/app/var/outbox \
    PREPLOOP_DOCUMENT_WORKER_IN_PROCESS=false

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/v1/health', timeout=4)"

# Behind a TLS-terminating proxy, set FORWARDED_ALLOW_IPS to the proxy's address.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --proxy-headers --forwarded-allow-ips \"${FORWARDED_ALLOW_IPS:-127.0.0.1}\""]
