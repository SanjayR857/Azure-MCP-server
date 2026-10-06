"""MCP Server tool modules."""

from azure_mcp_server.mcp.tools.azure_resources import register_azure_tools
from azure_mcp_server.mcp.tools.calculator import register_calculator_tools
from azure_mcp_server.mcp.tools.text import register_text_tools

__all__ = [
    "register_azure_tools",
    "register_calculator_tools",
    "register_text_tools",
]
