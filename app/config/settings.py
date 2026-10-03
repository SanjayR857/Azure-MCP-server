from dataclasses import dataclass


@dataclass
class Settings:
    app_name: str = "Azure MCP Server"
    host: str = "127.0.0.1"
    port: int = 8000


settings = Settings()