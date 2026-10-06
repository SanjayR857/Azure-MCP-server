import structlog
from mcp.server.auth.settings import AuthSettings
from mcp.server.mcpserver import MCPServer
from starlette.requests import Request
from starlette.responses import JSONResponse

from azure_mcp_server.auth.entra import EntraTokenVerifier
from azure_mcp_server.core.config import Settings, get_settings
from azure_mcp_server.mcp.tools.azure_resources import (
    register_azure_tools,
)
from azure_mcp_server.mcp.tools.calculator import (
    register_calculator_tools,
)
from azure_mcp_server.mcp.tools.text import (
    register_text_tools,
)

logger = structlog.get_logger(__name__)


def create_mcp_server(custom_settings: Settings | None = None) -> MCPServer:
    settings = custom_settings or get_settings()

    token_verifier = None
    auth_settings = None

    if settings.entra_tenant_id and settings.entra_client_id:
        logger.debug(
            "configuring_entra_authentication",
            tenant_id=settings.entra_tenant_id,
            client_id=settings.entra_client_id,
        )
        token_verifier = EntraTokenVerifier(
            tenant_id=settings.entra_tenant_id,
            client_id=settings.entra_client_id,
            required_scope=settings.required_scope,
        )
        auth_settings = AuthSettings(
            issuer_url=f"https://login.microsoftonline.com/{settings.entra_tenant_id}/v2.0",
            resource_server_url=settings.mcp_resource_url,
            required_scopes=[settings.required_scope] if settings.required_scope else None,
            # Disabled because Entra ID tokens use audience (aud) matching client_id/api://client_id
            # rather than RFC 8707 resource indicators; full audience validation is handled in EntraTokenVerifier.
            validate_token_resource=False,
        )
    else:
        logger.warning("authentication_disabled_running_in_unauthenticated_mode")

    mcp = MCPServer(
        name=settings.app_name,
        token_verifier=token_verifier,
        auth=auth_settings,
    )

    # Health check endpoint for container probes & monitoring
    @mcp.custom_route("/health", methods=["GET"])
    async def health_check(request: Request) -> JSONResponse:
        return JSONResponse({"status": "healthy"})

    register_calculator_tools(mcp)
    register_text_tools(mcp)

    if settings.azure_subscription_id:
        register_azure_tools(
            mcp,
            settings.azure_subscription_id,
        )

    return mcp