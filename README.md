# Azure Remote MCP Server

A production-grade Model Context Protocol (MCP) server running remotely on Azure Container Apps with Microsoft Entra ID authentication, structured logging, health probes, and Azure management tools.

---

## 🚀 Features

- **MCP Standard Compliance**: Implements the official Model Context Protocol (HTTP Streamable transport) over `/mcp`.
- **Microsoft Entra ID Authentication**: Validates Bearer JWTs against Microsoft Entra ID JWKS, verifying audience, issuer, expiry, and required scopes.
- **Azure Container Apps Ready**: Includes liveness and readiness health probes via `/health`.
- **Infrastructure as Code (IaC)**: Complete Azure Bicep templates for deploying Azure Container Registry (ACR), Log Analytics, Managed Environment, Container App, and Managed Identity RBAC.
- **Built-in Tools**:
  - `add`, `subtract`, `multiply`, `divide`: Safe mathematical operations.
  - `analyze_text`: Word, character, and sentence analytics.
  - `list_resource_groups`: Queries Azure Resource Management using Azure Managed Identity (`DefaultAzureCredential`).
- **Structured Observability**: End-to-end JSON structured logging using `structlog`.
- **Automated CI/CD**: GitHub Actions workflow that gates deployments behind linting and unit testing.

---

## 🛠️ Configuration

Configure via environment variables or a `.env` file (see `.env.example`):

| Variable | Description | Default |
| :--- | :--- | :--- |
| `APP_NAME` | Name of the MCP server application | `azure-remote-mcp-server` |
| `HOST` | Bind host address | `0.0.0.0` |
| `PORT` | Bind port number | `8000` |
| `LOG_LEVEL` | Log level (`DEBUG`, `INFO`, `WARNING`, `ERROR`) | `INFO` |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID for Azure resource tools | `None` |
| `ENTRA_TENANT_ID` | Microsoft Entra Tenant ID (leave empty for unauthenticated local dev) | `None` |
| `ENTRA_CLIENT_ID` | Microsoft Entra Application (Client) ID | `None` |
| `REQUIRED_SCOPE` | Required OAuth2 scope or App Role for accessing MCP endpoints | `mcp:read` |
| `MCP_RESOURCE_URL` | Public MCP endpoint URL | `http://localhost:8000/mcp` |

---

## 🏃 Local Development

### 1. Install Dependencies
```bash
uv sync --extra dev
```

### 2. Run Tests & Linter
```bash
uv run pytest -v
uv run ruff check .
```

### 3. Start the Server Locally
```bash
uv run python -m azure_mcp_server.main
```

Check the health status:
```bash
curl http://localhost:8000/health
```

---

## 🐳 Docker

### Build and Run with Docker
```bash
docker build -t azure-mcp-server:latest .
docker run -p 8000:8000 --env-file .env azure-mcp-server:latest
```

Or using Docker Compose:
```bash
docker compose up --build
```

---

## ☁️ Azure Deployment

### 1. Deploy Infrastructure (Bicep)
```powershell
az deployment group create `
    --resource-group rg-azure-mcp `
    --template-file infra/bicep/main.bicep `
    --parameters acrName="<your-acr-name>" `
                 logAnalyticsName="azure-mcp-law" `
                 containerEnvironmentName="azure-mcp-env" `
                 containerAppName="azure-mcp-server" `
                 entraTenantId="<your-tenant-id>" `
                 entraClientId="<your-client-id>"
```

### 2. Build & Deploy Container App
```powershell
$env:ACR_NAME = "<your-acr-name>"
.\scripts\build.ps1
.\scripts\deploy.ps1
```

---

## 🔍 Azure Monitor & Live Inspection

The project includes an enterprise-grade monitoring, inspection, and alerting stack in Azure Cloud:

- **Application Insights (`azure-mcp-insights`)**: OpenTelemetry APM for distributed tracing of MCP requests, live metrics, and exception reporting.
- **Diagnostic Settings**: Streams console logs, system logs, HTTP logs, and container metrics directly to Log Analytics (`azure-mcp-law`).
- **Metric Alerts**: Proactive alert rules for High CPU (>80%), High Memory (>80%), Crash Loops/Restarts (>2 in 5m), and High Latency (>2000ms).
- **Inspection Workbook**: Pre-built Azure Monitor Workbook for real-time traffic visualization, latency charts, and interactive log querying.

### Real-Time CLI Inspection Tool
Inspect your live deployment in Azure Cloud directly from PowerShell:

```powershell
# Run full health inspection
.\scripts\inspect.ps1

# Filter Log Analytics for errors only
.\scripts\inspect.ps1 -ErrorsOnly

# Stream live container logs in real time
.\scripts\inspect.ps1 -Tail
```

### Deploying / Updating Monitoring Separately
To provision or refresh the monitoring stack on an existing Azure resource group:

```powershell
.\scripts\deploy-monitoring.ps1 -ResourceGroup "azure-mcp-server"
```

