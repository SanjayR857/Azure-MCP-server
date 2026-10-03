from mcp.server import MCPServer

from app.mcp.middleware.logging import request_logging_middleware
from app.mcp.tools.calculator import register_calculator_tools
from app.mcp.tools.custom import register_custom_tools
from app.mcp.tools.search import register_search_tools


mcp = MCPServer("Azure MCP Server")

mcp.middleware.append(request_logging_middleware)

register_calculator_tools(mcp)
register_search_tools(mcp)
register_custom_tools(mcp)