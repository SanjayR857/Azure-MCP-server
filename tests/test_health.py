from starlette.testclient import TestClient

from azure_mcp_server.core.config import Settings
from azure_mcp_server.mcp.server import create_mcp_server


def test_health_endpoint_unauthenticated():
    settings = Settings(
        app_name="azure-test-server",
        entra_tenant_id=None,
        entra_client_id=None,
    )
    server = create_mcp_server(custom_settings=settings)
    app = server.streamable_http_app()
    client = TestClient(app)

    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_health_endpoint_with_auth_enabled():
    settings = Settings(
        app_name="azure-test-server",
        entra_tenant_id="mock-tenant-id",
        entra_client_id="mock-client-id",
    )
    server = create_mcp_server(custom_settings=settings)
    app = server.streamable_http_app()
    client = TestClient(app)

    # Health endpoint should be publicly accessible even when auth is enabled
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}

