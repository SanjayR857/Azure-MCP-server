# Azure Remote MCP Server

![Python](https://img.shields.io/badge/Python-3.11%20%7C%203.12-blue.svg)
![Model Context Protocol](https://img.shields.io/badge/MCP-2.0+-purple.svg)
![Azure Container Apps](https://img.shields.io/badge/Azure-Container%20Apps-0078D4.svg)
![Azure Key Vault](https://img.shields.io/badge/Azure-Key%20Vault-0078D4.svg)
![Azure Monitor](https://img.shields.io/badge/Azure-Monitor%20%26%20OpenTelemetry-orange.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

A production-grade **Model Context Protocol (MCP)** server deployed remotely on **Azure Container Apps** with **Azure Key Vault** secret management, **Microsoft Entra ID** authentication, **OpenTelemetry distributed tracing** to Application Insights, and seamless integration with **LangChain**, local LLMs (**Ollama**), and cloud agents.

---

## 🏛️ Architecture

```mermaid
graph TD
    Client["Client / LangChain Agent / Cursor"] -->|POST /mcp (Streamable HTTP)| ACA["Azure Container App (<your-container-app>)"]
    ACA -->|Managed Identity (RBAC)| KV["Azure Key Vault (<your-keyvault-name>)"]
    ACA -->|Bearer Token Validation| Entra["Microsoft Entra ID"]
    ACA -->|Spans & Custom Metrics| AppInsights["Application Insights (<your-appinsights-name>)"]
    ACA -->|Console & HTTP Logs| LAW["Log Analytics (<your-law-name>)"]
    ACA -->|Azure Resource Tools| ARM["Azure Resource Manager"]
```

---

## 🚀 Key Features

- **MCP Standard Compliance**: Implements the official Model Context Protocol (HTTP Streamable transport) over `/mcp`.
- **Zero-Trust Security**: Validates Microsoft Entra ID Bearer JWTs against JWKS endpoints (audience, issuer, expiration, and `mcp:read` scope / roles).
- **Dual Authentication Modes**: Supports unauthenticated mode for local development, and strict Entra ID JWT validation in production.
- **Azure Key Vault Secret Injection**: Secrets are mounted into the Container App via System-Assigned Managed Identity (`Key Vault Secrets User` RBAC).
- **OpenTelemetry & Azure Monitor APM**: Automated distributed tracing for every tool execution (`mcp.tool.*`) with latency, parameters, and error reporting in Application Insights.
- **Live Health & Inspection CLI**: Built-in `/health` probe and PowerShell inspector (`inspect.ps1`) for real-time latency, logs, and alert diagnostics.
- **Dynamic LangChain Integration**: Compatible with LangChain's `MultiServerMCPClient` for dynamic tool discovery with Ollama, Mistral, Llama, and cloud models.
- **Infrastructure as Code (IaC)**: Modular Bicep templates for ACR, Container Apps, Key Vault, Application Insights, Log Analytics, and Metric Alerts.
- **Automated CI/CD**: GitHub Actions workflow with unit testing (`pytest`), linting (`ruff`), OIDC login, and ACR container publishing.

---

## 🧰 Available MCP Tools

| Tool Name | Parameters | Return Type | Description |
| :--- | :--- | :--- | :--- |
| `add` | `a: float`, `b: float` | `float` | Adds two numbers. |
| `subtract` | `a: float`, `b: float` | `float` | Subtracts `b` from `a`. |
| `multiply` | `a: float`, `b: float` | `float` | Multiplies two numbers. |
| `divide` | `a: float`, `b: float` | `float` | Divides `a` by `b` (with zero division check). |
| `analyze_text` | `text: str` | `dict` | Returns word, character, and sentence counts (up to 100k chars). |
| `list_resource_groups` | *None* | `list[dict]` | Queries Azure Resource Groups via `DefaultAzureCredential`. |

---

## ⚙️ Configuration & Environment Variables

Configuration uses Pydantic Settings ([`src/azure_mcp_server/core/config.py`](file:///c:/Users/User/Projects/Gen%20AI/azure-mcp-server/src/azure_mcp_server/core/config.py)):

| Variable | Description | Source / Key Vault Secret | Default |
| :--- | :--- | :--- | :--- |
| `APP_NAME` | MCP server identifier | Environment | `azure-remote-mcp-server` |
| `HOST` | Bind host address | Environment | `0.0.0.0` |
| `PORT` | Bind port number | Environment | `8000` |
| `LOG_LEVEL` | Logging level (`DEBUG`, `INFO`, `WARNING`, `ERROR`) | Environment | `INFO` |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | App Insights connection string | Key Vault (`appinsights-connection-string`) | `None` |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID for ARM tools | Key Vault (`azure-subscription-id`) | `None` |
| `ENTRA_TENANT_ID` | Microsoft Entra Tenant ID (empty = unauthenticated) | Key Vault (`entra-tenant-id`) | `None` |
| `ENTRA_CLIENT_ID` | Microsoft Entra Application (Client) ID | Key Vault (`entra-client-id`) | `None` |
| `REQUIRED_SCOPE` | Required OAuth2 scope | Environment | `mcp:read` |
| `MCP_RESOURCE_URL` | Public MCP endpoint URL | Environment | `http://localhost:8000/mcp` |

---

## 🏃 Local Development

### 1. Installation

```bash
# Clone the repository
git clone https://github.com/<your-org>/<your-repo>.git
cd <your-repo>

# Install dependencies using uv (or: pip install -e ".[dev]")
uv sync --extra dev

# Copy environment template
cp .env.example .env
```

### 2. Run Tests & Linting

```powershell
uv run pytest -v
uv run ruff check .
```

### 3. Start Local Server

```bash
uv run python -m azure_mcp_server.main
```

Check health probe:
```bash
curl http://localhost:8000/health
# {"status":"healthy"}
```

---

## 🐳 Docker

```bash
# Build and run locally
docker build -t azure-mcp-server:latest .
docker run -p 8000:8000 --env-file .env azure-mcp-server:latest

# Or with Docker Compose
docker compose up -d
```

---

## ☁️ Azure Cloud Deployment

### 1. Provision Infrastructure via Bicep

```powershell
az deployment group create `
    --resource-group "<your-resource-group>" `
    --template-file infra/bicep/main.bicep `
    --parameters acrName="<your-acr-name>" `
                 logAnalyticsName="<your-log-analytics-name>" `
                 containerEnvironmentName="<your-env-name>" `
                 containerAppName="<your-container-app-name>" `
                 assignSubscriptionReaderRole=true
```

### 2. Build & Deploy Container Image

```powershell
$env:ACR_NAME = "<your-acr-name>"
$env:RESOURCE_GROUP = "<your-resource-group>"
$env:CONTAINER_APP_NAME = "<your-container-app-name>"

.\scripts\build.ps1
.\scripts\deploy.ps1
```

### 3. Configure Key Vault Secrets & Managed Identity

```powershell
.\scripts\deploy-keyvault.ps1 `
    -ResourceGroup "<your-resource-group>" `
    -KeyVaultName "<your-keyvault-name>" `
    -ContainerAppName "<your-container-app-name>" `
    -Location "<your-region>"
```

### 4. Deploy Monitoring Stack & Alerts

```powershell
.\scripts\deploy-monitoring.ps1 `
    -ResourceGroup "<your-resource-group>" `
    -ContainerAppName "<your-container-app-name>" `
    -AppInsightsName "<your-appinsights-name>"
```

---

## 🔍 Observability & Live Inspection

Inspect the live deployment from PowerShell using [`scripts/inspect.ps1`](file:///c:/Users/User/Projects/Gen%20AI/azure-mcp-server/scripts/inspect.ps1):

```powershell
# Run full deployment health inspection (status, latency, replicas)
.\scripts\inspect.ps1

# Query Log Analytics for errors only
.\scripts\inspect.ps1 -ErrorsOnly

# Stream live container logs in real time
.\scripts\inspect.ps1 -Tail
```

Configured Azure Monitor alerts:
- **CPU > 80%**
- **Memory > 80%**
- **Container Restarts > 2**
- **HTTP Latency > 2000ms**

---

## 🔌 Client Integration

### LangChain with Ollama (`client.py`)

```python
import asyncio
from azure.identity import AzureCliCredential
from langchain_ollama import ChatOllama
from langchain_mcp_adapters.client import MultiServerMCPClient

MCP_URL = "https://<your-container-app>.<your-region>.azurecontainerapps.io/mcp"
ENTRA_CLIENT_ID = "<your-client-id>"

def get_auth_headers():
    try:
        credential = AzureCliCredential()
        token = credential.get_token(f"api://{ENTRA_CLIENT_ID}/.default")
        return {"Authorization": f"Bearer {token.token}"}
    except Exception:
        return {}

async def main():
    client = MultiServerMCPClient({
        "azure_mcp": {
            "url": MCP_URL,
            "transport": "http",
            "headers": get_auth_headers(),
        }
    })

    tools = await client.get_tools()
    print("Discovered tools:", [t.name for t in tools])

    llm = ChatOllama(model="mistral:latest", temperature=0).bind_tools(tools)
    response = await llm.ainvoke([
        ("system", "Use available tools to calculate results."),
        ("human", "Calculate 4856 multiplied by 1246565656.")
    ])

    if response.tool_calls:
        tools_map = {t.name: t for t in tools}
        for call in response.tool_calls:
            result = await tools_map[call["name"]].ainvoke(call["args"])
            print(f"Tool {call['name']} result: {result}")
    else:
        print(response.content)

if __name__ == "__main__":
    asyncio.run(main())
```

### Claude Desktop / Cursor Config

```json
{
  "mcpServers": {
    "azure-mcp-server": {
      "url": "https://<your-container-app>.<your-region>.azurecontainerapps.io/mcp",
      "transport": "http",
      "headers": {
        "Authorization": "Bearer <YOUR_ENTRA_ACCESS_TOKEN>"
      }
    }
  }
}
```

---

## 🔄 CI/CD Secrets (GitHub Actions)

Configure these secrets in GitHub (**Settings** &rarr; **Secrets and variables** &rarr; **Actions**):

| Secret Name | Description | Example Placeholder |
| :--- | :--- | :--- |
| `AZURE_CLIENT_ID` | App Registration Client ID (OIDC) | `<your-client-id>` |
| `AZURE_TENANT_ID` | Azure Entra Tenant ID | `<your-tenant-id>` |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID | `<your-subscription-id>` |
| `ACR_NAME` | Azure Container Registry Name | `<your-acr-name>` |
| `RESOURCE_GROUP` | Target Azure Resource Group | `<your-resource-group>` |
| `CONTAINER_APP_NAME` | Target Azure Container App Name | `<your-container-app-name>` |

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
