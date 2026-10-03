import sys
from pathlib import Path

# Add project root directory to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config.settings import settings
from app.mcp.middleware.logging import configure_logging
from app.mcp.server import mcp


def main() -> None:
    configure_logging(settings.log_level)

    mcp.run(
        transport="streamable-http",
        host=settings.host,
        port=settings.port,
    )


if __name__ == "__main__":
    main()