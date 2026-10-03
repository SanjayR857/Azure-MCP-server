import pytest
from starlette.testclient import TestClient

from app.mcp.server import mcp


@pytest.fixture
def client():
    app = mcp.streamable_http_app()
    return TestClient(app)


def test_liveness_probe(client):
    response = client.get("/health/live")
    assert response.status_code == 200
    assert response.json() == {"status": "alive"}


def test_readiness_probe(client):
    response = client.get("/health/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}
