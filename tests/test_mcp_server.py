import pytest

from mcp import Client

from app.mcp.server import mcp


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.fixture
async def client():
    async with Client(mcp, raise_exceptions=True) as client:
        yield client


@pytest.mark.anyio
async def test_server_is_reachable(client: Client):
    assert client.server_info is not None
    assert client.server_info.name == "Azure MCP Server"


@pytest.mark.anyio
async def test_tools_are_registered(client: Client):
    result = await client.list_tools()

    tool_names = {tool.name for tool in result.tools}

    assert "add" in tool_names
    assert "search" in tool_names
    assert "greet" in tool_names


@pytest.mark.anyio
async def test_add_tool(client: Client):
    result = await client.call_tool(
        "add",
        {
            "a": 10,
            "b": 20,
        },
    )

    assert result.is_error is False
    assert result.structured_content is not None
