import pytest
from mcp.server.mcpserver.exceptions import ToolError


def test_server_creation(mcp_server):
    assert mcp_server is not None


@pytest.mark.asyncio
async def test_calculator_add(mcp_server):
    result = await mcp_server.call_tool("add", {"a": 10, "b": 5})
    assert result.structured_content["result"] == 15.0


@pytest.mark.asyncio
async def test_calculator_subtract(mcp_server):
    result = await mcp_server.call_tool("subtract", {"a": 10, "b": 4})
    assert result.structured_content["result"] == 6.0


@pytest.mark.asyncio
async def test_calculator_multiply(mcp_server):
    result = await mcp_server.call_tool("multiply", {"a": 3, "b": 7})
    assert result.structured_content["result"] == 21.0


@pytest.mark.asyncio
async def test_calculator_divide(mcp_server):
    result = await mcp_server.call_tool("divide", {"a": 20, "b": 4})
    assert result.structured_content["result"] == 5.0


@pytest.mark.asyncio
async def test_calculator_divide_by_zero(mcp_server):
    with pytest.raises(ToolError, match="Cannot divide by zero."):
        await mcp_server.call_tool("divide", {"a": 10, "b": 0})

