from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "azure-remote-mcp-server"

    host: str = "0.0.0.0"
    port: int = 8000

    log_level: str = "INFO"

    # Azure
    azure_subscription_id: str | None = None
    applicationinsights_connection_string: str | None = None

    # Entra ID
    entra_tenant_id: str | None = None
    entra_client_id: str | None = None

    # Public MCP endpoint
    mcp_resource_url: str = "http://localhost:8000/mcp"

    required_scope: str = "mcp:read"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
