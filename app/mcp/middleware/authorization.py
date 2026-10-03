from mcp.server.auth.middleware.auth_context import get_access_token


def require_scope(required_scope: str) -> None:
    """Ensure the current caller has the required scope."""

    token = get_access_token()

    if token is None:
        raise PermissionError("Authentication required.")

    if required_scope not in token.scopes:
        raise PermissionError(
            f"Missing required scope: {required_scope}"
        )
