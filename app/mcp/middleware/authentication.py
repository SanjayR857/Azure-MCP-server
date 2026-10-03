from mcp.server.auth.provider import AccessToken, TokenVerifier

from app.config.settings import settings

RESOURCE = settings.mcp_resource_url


class StaticTokenVerifier(TokenVerifier):
    """Temporary local verifier.

    Production authentication will later be replaced with
    Microsoft Entra ID token validation.
    """

    async def verify_token(self, token: str) -> AccessToken | None:
        if not settings.local_auth_token:
            return None

        if token != settings.local_auth_token:
            return None

        return AccessToken(
            token=token,
            client_id="local-client",
            scopes=["tools:read"],
            resource=RESOURCE,
        )