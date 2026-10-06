import pytest

from azure_mcp_server.core.telemetry import (
    get_tracer,
    instrument_tool,
    setup_telemetry,
    trace_tool_execution,
)


def test_setup_telemetry_without_connection_string(monkeypatch):
    monkeypatch.delenv("APPLICATIONINSIGHTS_CONNECTION_STRING", raising=False)
    assert setup_telemetry(None) is False


def test_get_tracer():
    tracer = get_tracer()
    assert tracer is not None


def test_trace_tool_execution_success():
    with trace_tool_execution("test_tool", param1="value1") as span:
        assert span is not None


def test_trace_tool_execution_exception():
    with pytest.raises(ValueError, match="test error"), trace_tool_execution("test_tool_error"):
        raise ValueError("test error")


def test_instrument_tool_sync():
    @instrument_tool("custom_sync_tool")
    def sync_tool(x: int) -> int:
        return x * 2

    assert sync_tool(5) == 10


@pytest.mark.asyncio
async def test_instrument_tool_async():
    @instrument_tool("custom_async_tool")
    async def async_tool(x: int) -> int:
        return x + 10

    assert await async_tool(5) == 15
