# Azure Remote MCP Server

A production-grade **Model Context Protocol (MCP)** server deployed remotely on **Azure Container Apps** with **Azure Key Vault** secret management, **Microsoft Entra ID** authentication, **OpenTelemetry distributed tracing** to Application Insights, and seamless integration with **LangChain** and local/cloud LLMs.

---

## 🚀 Features

- **MCP Standard Compliance**: Implements the official Model Context Protocol (HTTP Streamable transport) over `/mcp`.
- **Azure Key Vault Secret Injection**: Container App references secrets directly from Azure Key Vault using System-Assigned Managed Identity (`Key Vault Secrets User` RBAC).
- **Microsoft Entra ID Authentication**: Validates Bearer JWTs against Microsoft Entra ID JWKS, checking audience, issuer, expiration, and required scopes (`access_as_user` / `mcp:read`).
- **OpenTelemetry & Azure Monitor APM**: Automated distributed tracing for every MCP tool call (`mcp.tool.*`) with latency, parameter tracking, and error reporting in Application Insights.
- **Dynamic LangChain Integration**: Compatible with LangChain's `MultiServerMCPClient`—automatically discovers and invokes tools on Azure without manual code recreation.
- **Azure Container Apps Ready**: Production deployment with health probes (`/health`), container metrics, and Log Analytics streaming.
- **Built-in Tools**:
  - `add`, `subtract`, `multiply`, `divide`: Safe mathematical operations.
  - `analyze_text`: Word, character, and sentence analytics.
  - `list_resource_groups`: Queries Azure Resource Management via Managed Identity (`DefaultAzureCredential`).
- **Infrastructure as Code (IaC)**: Modular Azure Bicep templates for ACR, Container Apps, Key Vault, Application Insights, Log Analytics, and Metric Alerts.
- **Automated CI/CD**: GitHub Actions workflow that gates deployments behind unit testing (pytest) and linting (ruff).

---

## 🏛️ Architecture

```mermaid
graph TD
    Client["Client / LangChain Agent (Ollama / Mistral / OpenAI)"] -->|POST /mcp (Streamable HTTP)| ACA["Azure Container App (azure-mcp-server)"]
    ACA -->|Managed Identity (RBAC)| KV["Azure Key Vault (kv-azure-mcp-2026)"]
    ACA -->|Bearer Token Validation| Entra["Microsoft Entra ID"]
    ACA -->|Spans & Custom Metrics| AppInsights["Application Insights (azure-mcp-insights)"]
    ACA -->|Console & HTTP Logs| LAW["Log Analytics (azure-mcp-law)"]
    ACA -->|Azure Resource Tools| ARM["Azure Resource Manager"]
```

---

## 🛠️ Configuration & Secrets

Configuration uses Pydantic Settings with environment variables and Key Vault references:

| Variable | Description | Source | Default |
| :--- | :--- | :--- | :--- |
| `APP_NAME` | MCP server name | Environment | `azure-remote-mcp-server` |
| `HOST` | Bind host address | Environment | `0.0.0.0` |
| `PORT` | Bind port number | Environment | `8000` |
| `LOG_LEVEL` | Log level (`DEBUG`, `INFO`, `WARNING`, `ERROR`) | Environment | `INFO` |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | App Insights OpenTelemetry connection string | Key Vault (`appinsights-cs`) | `None` |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID for ARM tools | Key Vault (`azure-sub-id`) | `None` |
| `ENTRA_TENANT_ID` | Microsoft Entra Tenant ID (empty = unauthenticated mode) | Key Vault (`entra-tenant-id`) | `None` |
| `ENTRA_CLIENT_ID` | Microsoft Entra Application (Client) ID | Key Vault (`entra-client-id`) | `None` |
| `REQUIRED_SCOPE` | Required OAuth2 scope for MCP requests | Environment | `access_as_user` |
| `MCP_RESOURCE_URL` | Public MCP endpoint URL | Environment | `https://<app>.azurecontainerapps.io/mcp` |

---

## 🔐 Azure Key Vault Secret Management

To securely manage connection strings and credentials, secrets are stored in Azure Key Vault and injected into Azure Container Apps using Managed Identity:

### Automate Key Vault & Secret Setup
Run the automated PowerShell script:

```powershell
.\scripts\deploy-keyvault.ps1 `
    -ResourceGroup "azure-mcp-server" `
    -KeyVaultName "kv-azure-mcp-2026" `
    -ContainerAppName "azure-mcp-server"
```

This script:
1. Provisions Azure Key Vault with RBAC authorization enabled.
2. Assigns the Container App's System-Assigned Managed Identity the **Key Vault Secrets User** role.
3. Sets up secret references:
   - `appinsights-cs` &rarr; `keyvaultref:.../secrets/appinsights-connection-string,identityref:system`
   - `azure-sub-id` &rarr; `keyvaultref:.../secrets/azure-subscription-id,identityref:system`
   - `entra-tenant-id` &rarr; `keyvaultref:.../secrets/entra-tenant-id,identityref:system`
   - `entra-client-id` &rarr; `keyvaultref:.../secrets/entra-client-id,identityref:system`

---

## 🦜 Using with LangChain & Ollama

LangChain connects to the remote MCP server using `MultiServerMCPClient`. Tools are dynamically fetched and bound to the LLM:

### 1. Install Dependencies
```powershell
uv pip install langchain-ollama langchain-mcp-adapters azure-identity
```

### 2. Python Client (`test.py`)

```python
import asyncio
from azure.identity import AzureCliCredential
from langchain_ollama import ChatOllama
from langchain_mcp_adapters.client import MultiServerMCPClient

MCP_URL = "https://azure-mcp-server.lemonforest-dbf13967.centralindia.azurecontainerapps.io/mcp"

# Retrieve Azure Entra ID Bearer token if authentication is enabled
def get_auth_headers():
    try:
        credential = AzureCliCredential()
        # Scope matches your Entra App ID URI or client ID
        token = credential.get_token("api://a8f23ec3-b349-478e-b03a-320e0b7696ce/.default")
        return {"Authorization": f"Bearer {token.token}"}
    except Exception:
        return {}

async def main():
    # 1. Connect to the Azure MCP server
    headers = get_auth_headers()
    client = MultiServerMCPClient({
        "azure_mcp": {
            "url": MCP_URL,
            "transport": "http",
            "headers": headers,
        }
    })

    # 2. Dynamically fetch all tools from Azure
    tools = await client.get_tools()
    print("Fetched MCP Tools:", [t.name for t in tools])

    # 3. Bind tools to a tool-capable model (e.g. mistral:latest or llama3.1)
    llm = ChatOllama(model="mistral:latest", temperature=0).bind_tools(tools)

    # 4. Invoke LLM with System Prompt & User Query
    messages = [
        ("system", "You are an expert AI assistant. Always invoke available tools for calculations."),
        ("human", "Calculate 4856 multiplied by 1246565656.")
    ]
    response = await llm.ainvoke(messages)

    # 5. Execute requested tools
    if response.tool_calls:
        tools_map = {t.name: t for t in tools}
        for tc in response.tool_calls:
            print(f"-> Calling tool: {tc['name']} with args {tc['args']}")
            result = await tools_map[tc["name"]].ainvoke(tc["args"])
            print(f"-> Result from Azure: {result}")
    else:
        print(f"AI: {response.content}")

if __name__ == "__main__":
    asyncio.run(main())
```

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

Check health status:
```bash
curl http://localhost:8000/health
```

---

## 🐳 Docker Deployment

### Build & Run Locally
```bash
docker build -t azure-mcp-server:latest .
docker run -p 8000:8000 --env-file .env azure-mcp-server:latest
```

---

## ☁️ Azure Cloud Deployment

### 1. Deploy Infrastructure via Bicep
```powershell
az deployment group create `
    --resource-group azure-mcp-server `
    --template-file infra/bicep/main.bicep `
    --parameters acrName="azurecontainerregistry2026" `
                 logAnalyticsName="azure-mcp-law" `
                 containerEnvironmentName="azure-mcp-env" `
                 containerAppName="azure-mcp-server"
```

### 2. Build & Deploy Container Image
```powershell
$env:ACR_NAME = "azurecontainerregistry2026"
.\scripts\build.ps1
.\scripts\deploy.ps1
```

---

## 🔍 Azure Monitor & Live Inspection

The solution includes an end-to-end observability stack:

- **Application Insights (`azure-mcp-insights`)**: OpenTelemetry APM for distributed tracing of MCP tool executions (`mcp.tool.add`, `mcp.tool.multiply`, etc.).
- **Diagnostic Settings**: Streams console logs, system logs, and HTTP logs to Log Analytics (`azure-mcp-law`).
- **Metric Alerts**: Proactive alert rules for CPU (>80%), Memory (>80%), Restarts (>2), and Latency (>2000ms).
- **Inspection Workbook**: Azure Monitor Workbook for latency and tool volume visualization.

### Real-Time Inspection CLI
Inspect the deployment from PowerShell:

```powershell
# Run full deployment health inspection
.\scripts\inspect.ps1

# Filter Log Analytics for errors only
.\scripts\inspect.ps1 -ErrorsOnly

# Stream live container logs in real time
.\scripts\inspect.ps1 -Tail
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
