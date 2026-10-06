import pytest

from azure_mcp_server.core.config import Settings
from azure_mcp_server.mcp.server import create_mcp_server


@pytest.fixture
def default_settings():
    """Settings with auth disabled for unit tests."""
    return Settings(
        app_name="azure-test-server",
        entra_tenant_id=None,
        entra_client_id=None,
    )


@pytest.fixture
def mcp_server(default_settings):
    """Pre-configured MCP server instance for tool tests."""
    return create_mcp_server(custom_settings=default_settings)
