"""Microsoft Entra ID JWT Bearer Token verification for MCP Server."""

import anyio
import jwt
import structlog
from jwt import PyJWKClient
from mcp.server.auth.provider import AccessToken, TokenVerifier

logger = structlog.get_logger(__name__)


class EntraTokenVerifier(TokenVerifier):
    """Verifies OAuth2 Bearer tokens issued by Microsoft Entra ID."""

    def __init__(
        self,
        tenant_id: str,
        client_id: str,
        required_scope: str | None = None,
        jwks_uri: str | None = None,
        jwks_client: PyJWKClient | None = None,
    ):
        self.tenant_id = tenant_id
        self.client_id = client_id
        self.required_scope = required_scope

        self.issuer = f"https://login.microsoftonline.com/{tenant_id}/v2.0"
        self.sts_issuer = f"https://sts.windows.net/{tenant_id}/"

        if jwks_client is not None:
            self.jwks_client = jwks_client
        else:
            uri = jwks_uri or f"https://login.microsoftonline.com/{tenant_id}/discovery/v2.0/keys"
            self.jwks_client = PyJWKClient(uri, cache_keys=True, cache_jwk_set=True, lifespan=300)

    async def verify_token(self, token: str) -> AccessToken | None:
        """Verify token against Entra ID keys and return AccessToken if valid."""
        try:
            # 1. Fetch signing key from JWKS asynchronously
            signing_key = await anyio.to_thread.run_sync(
                self.jwks_client.get_signing_key_from_jwt,
                token,
            )

            # 2. Decode and validate claims
            accepted_audiences = [self.client_id, f"api://{self.client_id}"]

            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=["RS256"],
                audience=accepted_audiences,
                issuer=[self.issuer, self.sts_issuer],
                options={
                    "verify_exp": True,
                    "verify_aud": True,
                    "verify_iss": True,
                },
            )

            # 3. Extract scopes and app roles
            scp_claim = payload.get("scp", "")
            if isinstance(scp_claim, str):
                scopes = scp_claim.split()
            elif isinstance(scp_claim, list):
                scopes = scp_claim
            else:
                scopes = []

            roles = payload.get("roles", [])
            if isinstance(roles, list):
                scopes.extend(roles)

            # 4. Verify required scope / role if specified
            if self.required_scope and self.required_scope not in scopes:
                logger.warning(
                    "token_missing_required_scope",
                    required=self.required_scope,
                    found=scopes,
                )
                return None

            client_id = (
                payload.get("azp")
                or payload.get("appid")
                or self.client_id
            )

            logger.info("token_verified_successfully", client_id=client_id, subject=payload.get("sub"))

            return AccessToken(
                token=token,
                client_id=client_id,
                scopes=scopes,
                expires_at=payload.get("exp"),
                subject=payload.get("sub"),
                claims=payload,
            )

        except jwt.ExpiredSignatureError:
            logger.warning("token_expired")
            return None
        except jwt.InvalidTokenError as e:
            logger.warning("invalid_token", error=str(e))
            return None
        except Exception as e:
            logger.exception("token_verification_failed", error=str(e))
            return None
