import structlog
from mcp.server.mcpserver.exceptions import ToolError

logger = structlog.get_logger(__name__)


def register_calculator_tools(mcp):

    @mcp.tool()
    def add(a: float, b: float) -> float:
        """Add two numbers."""
        logger.debug("calculator_add", a=a, b=b)
        return a + b

    @mcp.tool()
    def subtract(a: float, b: float) -> float:
        """Subtract b from a."""
        logger.debug("calculator_subtract", a=a, b=b)
        return a - b

    @mcp.tool()
    def multiply(a: float, b: float) -> float:
        """Multiply two numbers."""
        logger.debug("calculator_multiply", a=a, b=b)
        return a * b

    @mcp.tool()
    def divide(a: float, b: float) -> float:
        """Divide a by b."""
        logger.debug("calculator_divide", a=a, b=b)
        if b == 0:
            raise ToolError("Cannot divide by zero.")

        return a / b