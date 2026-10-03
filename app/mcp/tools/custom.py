from app.mcp.schemas.tool_schemas import GreetInput


def register_custom_tools(mcp):

    @mcp.tool()
    def greet(data: GreetInput) -> str:
        """Return a greeting for a person."""

        return f"Hello, {data.name}!"