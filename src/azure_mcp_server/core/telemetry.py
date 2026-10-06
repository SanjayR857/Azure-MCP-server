import functools
import inspect
import os
from collections.abc import Callable
from contextlib import contextmanager
from typing import Any

import structlog
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode

logger = structlog.get_logger(__name__)

TRACER_NAME = "azure_mcp_server"


def setup_telemetry(connection_string: str | None = None) -> bool:
    """Configure Azure Monitor OpenTelemetry exporter if connection string is provided.

    Args:
        connection_string: Azure Application Insights connection string. If omitted,
            the APPLICATIONINSIGHTS_CONNECTION_STRING environment variable is checked.

    Returns:
        True if Azure Monitor telemetry was configured, False otherwise.
    """
    cs = connection_string or os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING")
    if not cs:
        logger.debug("azure_monitor_skipped_no_connection_string")
        return False

    try:
        from azure.monitor.opentelemetry import configure_azure_monitor

        configure_azure_monitor(
            connection_string=cs,
            logger_name="azure_mcp_server",
        )
        logger.info("azure_monitor_telemetry_configured")
        return True
    except Exception as exc:  # noqa: BLE001
        logger.warning("azure_monitor_configuration_failed", error=str(exc))
        return False


def get_tracer() -> trace.Tracer:
    """Return an OpenTelemetry tracer for Azure MCP server."""
    return trace.get_tracer(TRACER_NAME)


@contextmanager
def trace_tool_execution(tool_name: str, **attributes: Any):
    """Context manager for tracing an MCP tool execution.

    Creates an OpenTelemetry span with MCP metadata, records any exceptions,
    and sets status codes accordingly.
    """
    tracer = get_tracer()
    with tracer.start_as_current_span(f"mcp.tool.{tool_name}") as span:
        span.set_attribute("mcp.tool.name", tool_name)
        for key, value in attributes.items():
            if value is not None:
                span.set_attribute(f"mcp.tool.param.{key}", str(value))

        try:
            yield span
            span.set_status(Status(StatusCode.OK))
        except Exception as exc:
            span.record_exception(exc)
            span.set_status(Status(StatusCode.ERROR, str(exc)))
            raise


def instrument_tool(tool_name: str) -> Callable:
    """Decorator to automatically trace MCP tool executions in Application Insights."""
    def decorator(fn: Callable) -> Callable:
        if inspect.iscoroutinefunction(fn):
            @functools.wraps(fn)
            async def async_wrapper(*args: Any, **kwargs: Any) -> Any:
                with trace_tool_execution(tool_name, **kwargs):
                    return await fn(*args, **kwargs)
            return async_wrapper
        else:
            @functools.wraps(fn)
            def sync_wrapper(*args: Any, **kwargs: Any) -> Any:
                with trace_tool_execution(tool_name, **kwargs):
                    return fn(*args, **kwargs)
            return sync_wrapper

    return decorator
