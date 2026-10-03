from typing import Annotated

from pydantic import Field


def register_calculator_tools(mcp):

    @mcp.tool()
    def add(
        a: Annotated[int, Field(ge=-1_000_000, le=1_000_000)],
        b: Annotated[int, Field(ge=-1_000_000, le=1_000_000)],
    ) -> int:
        """Add two integers."""
        return a + b