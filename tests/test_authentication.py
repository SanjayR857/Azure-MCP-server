import pytest

from app.mcp.middleware.authentication import (
    StaticTokenVerifier,
)


@pytest.fixture
def verifier():
    return StaticTokenVerifier()


@pytest.mark.anyio
async def test_valid_token(verifier):
    token = await verifier.verify_token("local-read-token")

    assert token is not None
    assert token.client_id == "local-client"
    assert "tools:read" in token.scopes


@pytest.mark.anyio
async def test_invalid_token(verifier):
    token = await verifier.verify_token("invalid-token")

    assert token is None
