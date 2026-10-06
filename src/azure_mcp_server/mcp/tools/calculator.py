import structlog
from mcp.server.mcpserver.exceptions import ToolError

from azure_mcp_server.core.telemetry import trace_tool_execution

logger = structlog.get_logger(__name__)


def register_calculator_tools(mcp):

    @mcp.tool()
    def add(a: float, b: float) -> float:
        """Add two numbers."""
        with trace_tool_execution("add", a=a, b=b):
            logger.debug("calculator_add", a=a, b=b)
            return a + b

    @mcp.tool()
    def subtract(a: float, b: float) -> float:
        """Subtract b from a."""
        with trace_tool_execution("subtract", a=a, b=b):
            logger.debug("calculator_subtract", a=a, b=b)
            return a - b

    @mcp.tool()
    def multiply(a: float, b: float) -> float:
        """Multiply two numbers."""
        with trace_tool_execution("multiply", a=a, b=b):
            logger.debug("calculator_multiply", a=a, b=b)
            return a * b

    @mcp.tool()
    def divide(a: float, b: float) -> float:
        """Divide a by b."""
        with trace_tool_execution("divide", a=a, b=b):
            logger.debug("calculator_divide", a=a, b=b)
            if b == 0:
                raise ToolError("Cannot divide by zero.")

            return a / b