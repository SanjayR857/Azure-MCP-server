import structlog
from azure.core.exceptions import AzureError
from azure.identity import DefaultAzureCredential

try:
    from azure.mgmt.resource import ResourceManagementClient
except ImportError:
    from azure.mgmt.resource.resources import ResourceManagementClient

logger = structlog.get_logger(__name__)


class AzureResourceService:
    def __init__(self, subscription_id: str, credential=None, client=None):
        self.subscription_id = subscription_id
        self.credential = credential or DefaultAzureCredential()
        self.client = client or ResourceManagementClient(
            self.credential,
            subscription_id,
        )

    def list_resource_groups(self) -> list[dict]:
        """Fetch Azure resource groups with structured logging and error handling."""
        try:
            logger.info("listing_resource_groups", subscription_id=self.subscription_id)
            result = []
            for group in self.client.resource_groups.list():
                result.append(
                    {
                        "name": group.name,
                        "location": group.location,
                        "id": group.id,
                    }
                )
            logger.info("resource_groups_listed", count=len(result))
            return result
        except AzureError as e:
            logger.exception("azure_resource_group_error", error=str(e))
            raise RuntimeError(f"Azure error querying resource groups: {e}") from e
        except Exception as e:
            logger.exception("unexpected_resource_group_error", error=str(e))
            raise