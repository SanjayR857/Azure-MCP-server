import structlog
from mcp.server.mcpserver.exceptions import ToolError

from azure_mcp_server.core.telemetry import trace_tool_execution

logger = structlog.get_logger(__name__)


def register_text_tools(mcp):

    @mcp.tool()
    def analyze_text(text: str) -> dict:
        """
        Analyze text.

        Returns word count, character count and sentence count.
        """
        with trace_tool_execution("analyze_text", text_length=len(text)):
            logger.debug("text_analyze", length=len(text))

            if len(text) > 100_000:
                raise ToolError("Text too large. Maximum 100,000 characters allowed.")

            words = text.split()

            sentences = [
                sentence.strip()
                for sentence in text.replace("!", ".").replace("?", ".").split(".")
                if sentence.strip()
            ]

            return {
                "word_count": len(words),
                "character_count": len(text),
                "sentence_count": len(sentences),
            }