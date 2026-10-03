from mcp.server.mcpserver.exceptions import ToolError


def tool_error(message: str) -> None:
    """Raise a safe tool-level error."""
    raise ToolError(message)