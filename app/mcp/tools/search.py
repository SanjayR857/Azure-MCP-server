from typing import Annotated

from pydantic import Field


def register_search_tools(mcp):

    @mcp.tool()
    def search(
        query: Annotated[
            str,
            Field(min_length=1, max_length=500),
        ],
    ) -> str:
        """Search for information using a search query."""
        return f"Search requested for: {query}"