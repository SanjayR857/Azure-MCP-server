FROM python:3.12-slim

# Prevent Python from creating .pyc files
# and ensure logs are written immediately.
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Container networking
ENV HOST=0.0.0.0
ENV PORT=8000
ENV ENVIRONMENT=docker

WORKDIR /app

# Install dependencies first for Docker layer caching.
COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy only the application source.
COPY app ./app

# Run as a non-root user.
RUN useradd --create-home --shell /bin/bash appuser \
    && chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

CMD ["python", "-m", "app.main"]