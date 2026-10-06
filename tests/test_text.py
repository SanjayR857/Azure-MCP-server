import json

import pytest
from mcp.server.mcpserver.exceptions import ToolError


def test_text_tool_registered(mcp_server):
    assert mcp_server is not None


@pytest.mark.asyncio
async def test_analyze_text(mcp_server):
    sample = "Hello world. Azure MCP server is great."
    result = await mcp_server.call_tool("analyze_text", {"text": sample})
    assert result.is_error is False

    stats = json.loads(result.content[0].text)
    assert stats["word_count"] == 7
    assert stats["sentence_count"] == 2
    assert stats["character_count"] == len(sample)


@pytest.mark.asyncio
async def test_analyze_text_exceeds_max_length(mcp_server):
    huge_sample = "a" * 100_001
    with pytest.raises(ToolError, match="Text too large"):
        await mcp_server.call_tool("analyze_text", {"text": huge_sample})