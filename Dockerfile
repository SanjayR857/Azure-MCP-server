# syntax=docker/dockerfile:1

# -----------------------------------------------------------------------------
# Stage 1: Build dependencies & virtual environment
# -----------------------------------------------------------------------------
FROM python:3.11.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 1. Install dependencies first for optimal Docker layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# 2. Install application package without dependencies (already installed above)
COPY pyproject.toml .
COPY src ./src
RUN pip install --no-cache-dir --no-deps .

# -----------------------------------------------------------------------------
# Stage 2: Minimal runtime image
# -----------------------------------------------------------------------------
FROM python:3.11.11-slim AS runner

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Create non-root application user
RUN useradd --create-home --shell /bin/bash appuser \
    && chown -R appuser:appuser /app

# Copy virtual environment and source code
COPY --from=builder /opt/venv /opt/venv
COPY --chown=appuser:appuser src ./src

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["python", "-m", "azure_mcp_server.main"]
