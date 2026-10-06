from azure_mcp_server.core.config import get_settings
from azure_mcp_server.core.logging import configure_logging
from azure_mcp_server.mcp.server import create_mcp_server


def main():

    settings = get_settings()

    configure_logging(settings.log_level)

    mcp = create_mcp_server()

    mcp.run(
        transport="streamable-http",
        host=settings.host,
        port=settings.port,
        json_response=True,
        stateless_http=True,
    )


if __name__ == "__main__":
    main()