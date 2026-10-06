from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from azure_mcp_server.auth.entra import EntraTokenVerifier


@pytest.fixture(scope="module")
def rsa_keys():
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_key = private_key.public_key()
    return private_key, public_key


@pytest.fixture
def mock_jwks_client(rsa_keys):
    _, public_key = rsa_keys
    mock_key = MagicMock()
    mock_key.key = public_key
    client = MagicMock()
    client.get_signing_key_from_jwt.return_value = mock_key
    return client


@pytest.mark.asyncio
async def test_verify_valid_token(rsa_keys, mock_jwks_client):
    private_key, _ = rsa_keys
    tenant_id = "test-tenant-123"
    client_id = "test-app-id"

    verifier = EntraTokenVerifier(
        tenant_id=tenant_id,
        client_id=client_id,
        required_scope="mcp:read",
        jwks_client=mock_jwks_client,
    )

    claims = {
        "sub": "user-456",
        "aud": client_id,
        "iss": f"https://login.microsoftonline.com/{tenant_id}/v2.0",
        "scp": "mcp:read user.read",
        "exp": int((datetime.now(UTC) + timedelta(hours=1)).timestamp()),
    }
    token = jwt.encode(claims, private_key, algorithm="RS256")

    access_token = await verifier.verify_token(token)

    assert access_token is not None
    assert access_token.subject == "user-456"
    assert access_token.client_id == client_id
    assert "mcp:read" in access_token.scopes


@pytest.mark.asyncio
async def test_verify_token_missing_required_scope(rsa_keys, mock_jwks_client):
    private_key, _ = rsa_keys
    tenant_id = "test-tenant-123"
    client_id = "test-app-id"

    verifier = EntraTokenVerifier(
        tenant_id=tenant_id,
        client_id=client_id,
        required_scope="mcp:admin",
        jwks_client=mock_jwks_client,
    )

    claims = {
        "sub": "user-456",
        "aud": client_id,
        "iss": f"https://login.microsoftonline.com/{tenant_id}/v2.0",
        "scp": "mcp:read",
        "exp": int((datetime.now(UTC) + timedelta(hours=1)).timestamp()),
    }
    token = jwt.encode(claims, private_key, algorithm="RS256")

    access_token = await verifier.verify_token(token)
    assert access_token is None


@pytest.mark.asyncio
async def test_verify_expired_token(rsa_keys, mock_jwks_client):
    private_key, _ = rsa_keys
    tenant_id = "test-tenant-123"
    client_id = "test-app-id"

    verifier = EntraTokenVerifier(
        tenant_id=tenant_id,
        client_id=client_id,
        required_scope="mcp:read",
        jwks_client=mock_jwks_client,
    )

    claims = {
        "sub": "user-456",
        "aud": client_id,
        "iss": f"https://login.microsoftonline.com/{tenant_id}/v2.0",
        "scp": "mcp:read",
        "exp": int((datetime.now(UTC) - timedelta(hours=1)).timestamp()),
    }
    token = jwt.encode(claims, private_key, algorithm="RS256")

    access_token = await verifier.verify_token(token)
    assert access_token is None


@pytest.mark.asyncio
async def test_verify_token_with_app_roles(rsa_keys, mock_jwks_client):
    private_key, _ = rsa_keys
    tenant_id = "test-tenant-123"
    client_id = "test-app-id"

    verifier = EntraTokenVerifier(
        tenant_id=tenant_id,
        client_id=client_id,
        required_scope="mcp:read",
        jwks_client=mock_jwks_client,
    )

    claims = {
        "sub": "service-principal-01",
        "aud": f"api://{client_id}",
        "iss": f"https://login.microsoftonline.com/{tenant_id}/v2.0",
        "roles": ["mcp:read"],
        "exp": int((datetime.now(UTC) + timedelta(hours=1)).timestamp()),
    }
    token = jwt.encode(claims, private_key, algorithm="RS256")

    access_token = await verifier.verify_token(token)
    assert access_token is not None
    assert "mcp:read" in access_token.scopes
