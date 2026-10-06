from unittest.mock import MagicMock

import pytest
from azure.core.exceptions import HttpResponseError

from azure_mcp_server.services.azure_resource_service import AzureResourceService


def test_list_resource_groups_success():
    mock_client = MagicMock()
    mock_rg_1 = MagicMock()
    mock_rg_1.name = "rg-prod-01"
    mock_rg_1.location = "eastus"
    mock_rg_1.id = "/subscriptions/sub-123/resourceGroups/rg-prod-01"

    mock_rg_2 = MagicMock()
    mock_rg_2.name = "rg-dev-01"
    mock_rg_2.location = "westeurope"
    mock_rg_2.id = "/subscriptions/sub-123/resourceGroups/rg-dev-01"

    mock_client.resource_groups.list.return_value = [mock_rg_1, mock_rg_2]

    service = AzureResourceService(
        subscription_id="sub-123",
        credential=MagicMock(),
        client=mock_client,
    )

    result = service.list_resource_groups()

    assert len(result) == 2
    assert result[0] == {
        "name": "rg-prod-01",
        "location": "eastus",
        "id": "/subscriptions/sub-123/resourceGroups/rg-prod-01",
    }
    assert result[1] == {
        "name": "rg-dev-01",
        "location": "westeurope",
        "id": "/subscriptions/sub-123/resourceGroups/rg-dev-01",
    }


def test_list_resource_groups_azure_error():
    mock_client = MagicMock()
    mock_client.resource_groups.list.side_effect = HttpResponseError(message="Forbidden")

    service = AzureResourceService(
        subscription_id="sub-123",
        credential=MagicMock(),
        client=mock_client,
    )

    with pytest.raises(RuntimeError, match="Azure error querying resource groups"):
        service.list_resource_groups()
