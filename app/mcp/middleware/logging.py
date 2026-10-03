import json
import logging
import time
from datetime import datetime, timezone
from typing import Any

from mcp.server.context import CallNext, HandlerResult
from mcp.server import ServerRequestContext


logger = logging.getLogger("azure_mcp")


class JsonFormatter(logging.Formatter):
    """Format logs as JSON for local and cloud log collection."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        if hasattr(record, "request_id"):
            payload["request_id"] = record.request_id

        if hasattr(record, "method"):
            payload["method"] = record.method

        if hasattr(record, "duration_ms"):
            payload["duration_ms"] = record.duration_ms

        if hasattr(record, "status"):
            payload["status"] = record.status

        return json.dumps(payload)


def configure_logging(log_level: str) -> None:
    """Configure application logging."""

    root_logger = logging.getLogger()

    root_logger.setLevel(log_level.upper())

    # Avoid duplicate handlers when development servers reload.
    if root_logger.handlers:
        return

    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())

    root_logger.addHandler(handler)


async def request_logging_middleware(
    ctx: ServerRequestContext,
    call_next: CallNext,
) -> HandlerResult:
    """Log every inbound MCP request and its execution time."""

    start = time.perf_counter()

    request_id = str(ctx.request_id) if ctx.request_id is not None else None

    try:
        result = await call_next(ctx)

        duration_ms = round(
            (time.perf_counter() - start) * 1000,
            2,
        )

        logger.info(
            "MCP request completed",
            extra={
                "request_id": request_id,
                "method": ctx.method,
                "duration_ms": duration_ms,
                "status": "success",
            },
        )

        return result

    except Exception:
        duration_ms = round(
            (time.perf_counter() - start) * 1000,
            2,
        )

        logger.exception(
            "MCP request failed",
            extra={
                "request_id": request_id,
                "method": ctx.method,
                "duration_ms": duration_ms,
                "status": "error",
            },
        )

        raise
