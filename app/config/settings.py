from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = Field(default="Azure MCP Server")
    app_version: str = Field(default="0.1.0")

    host: str = Field(default="127.0.0.1")
    port: int = Field(default=8000)

    log_level: str = Field(default="INFO")

    environment: str = Field(default="local")

    mcp_resource_url: str = Field(default="http://127.0.0.1:8000/mcp")
    local_auth_token: str = Field(
        default="",
        validation_alias="MCP_LOCAL_TEST_TOKEN",
    )

    model_config = SettingsConfigDict(
        env_file=(".env", "app/.env"),
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()