from mcp.server import MCPServer
from starlette.requests import Request
from starlette.responses import JSONResponse

from app.mcp.middleware.logging import request_logging_middleware
from app.mcp.tools.calculator import register_calculator_tools
from app.mcp.tools.custom import register_custom_tools
from app.mcp.tools.search import register_search_tools


mcp = MCPServer("Azure MCP Server")

mcp.middleware.append(request_logging_middleware)

register_calculator_tools(mcp)
register_search_tools(mcp)
register_custom_tools(mcp)


@mcp.custom_route("/health/live", methods=["GET"])
async def liveness(request: Request) -> JSONResponse:
    """Lightweight liveness probe checking whether the process is alive."""
    return JSONResponse({"status": "alive"})


@mcp.custom_route("/health/ready", methods=["GET"])
async def readiness(request: Request) -> JSONResponse:
    """Readiness probe checking whether the server is ready to accept traffic."""
    return JSONResponse({"status": "ready"})