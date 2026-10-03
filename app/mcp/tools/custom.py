from typing import Annotated

from pydantic import Field


def register_custom_tools(mcp):

    @mcp.tool()
    def greet(
        name: Annotated[
            str,
            Field(min_length=1, max_length=100),
        ],
    ) -> str:
        """Return a greeting for a person."""
        return f"Hello, {name}!"