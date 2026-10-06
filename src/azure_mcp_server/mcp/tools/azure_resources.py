import anyio
import structlog

from azure_mcp_server.core.telemetry import trace_tool_execution
from azure_mcp_server.services.azure_resource_service import (
    AzureResourceService,
)

logger = structlog.get_logger(__name__)


def register_azure_tools(mcp, subscription_id: str, service: AzureResourceService | None = None):
    svc = service or AzureResourceService(subscription_id)

    @mcp.tool()
    async def list_resource_groups() -> list[dict]:
        """
        List Azure resource groups available to the MCP server.
        """
        with trace_tool_execution("list_resource_groups", subscription_id=subscription_id):
            logger.info("tool_invoked", tool="list_resource_groups")
            return await anyio.to_thread.run_sync(svc.list_resource_groups)