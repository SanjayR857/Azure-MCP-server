# Production-Grade Azure MCP Server: Comprehensive Architectural & Implementation Guide

## Executive Overview
This document provides the definitive, end-to-end architectural and implementation record for the **Azure Model Context Protocol (MCP) Server**. It details every phase, decision, configuration, and verification step across the 16 executed project steps.

The infrastructure is built strictly on **Standard, Free, and Serverless Consumption tiers**, ensuring $0 ongoing fixed infrastructure costs while implementing enterprise-grade security (OAuth 2.0 / Entra ID, dual-perimeter gateway inspection, Workload Managed Identities, Key Vault secret references, and zero-secret GitHub Actions CI/CD via OpenID Connect).

---

## Architecture Diagram: Dual-Perimeter Production Flow

```text
               MCP Client (Claude / ChatGPT / Agent)
                                │
                                │ 1. Inbound Bearer Token (aud: MCP App)
                                ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   Azure API Management (APIM)                          │
│                                                                        │
│ • Tier: Serverless Consumption (1,000,000 free calls / month)          │
│ • Inbound Policy: <validate-azure-ad-token> (verifies client JWT)      │
│ • Inbound Policy: <rate-limit calls="60" renewal-period="60" />        │
│ • Inbound Policy: <authentication-managed-identity> (System Identity)  │
│ • Diagnostic Logging: GatewayLogs & Metrics forwarded to App Insights  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    │ 2. Backend Entra Bearer Token (APIM Managed ID)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   Azure Container Apps (ACA)                           │
│                                                                        │
│ • Tier: Serverless Consumption (Scaled to active replicas)             │
│ • Easy Auth: Rejects direct unauthenticated calls with HTTP 401        │
│ • Revision Mode: Multiple (Blue / Green zero-downtime deployment)      │
│ • Probes: Startup (/health/live), Readiness (/health/ready)            │
│ • Secrets: Key Vault SecretRef dynamically injected via Managed ID     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    │ Internal Runtime Execution
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   FastMCP Python Runtime (Port 8000)                   │
│                                                                        │
│ • Transport: streamable-http (Server-Sent Events streaming)            │
│ • Tools Registered: add (calculator), search (docs), greet (strings)   │
│ • Validation: Pydantic v2 strict input schemas                         │
│ • Structured Logging: JSON formatted stdout with request_id & latency  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Step-by-Step Breakdown

### Phase 1: Local MCP Runtime & Validation (Steps 1–5)

#### Step 1: Local Server Architecture & FastMCP Core
- **Implementation**: Created standard modular Python project with `FastMCP`/`MCPServer` runtime in `app/mcp/server.py` and entrypoint `app/main.py`.
- **Protocol**: Configured `transport="streamable-http"` listening on `http://127.0.0.1:8000/mcp`.
- **Verification**: Local server initialized, registered default session managers, and supported JSON-RPC 2.0 streaming via SSE.

#### Step 2: Tool Schemas & Input Validation
- **Implementation**: Authored strict Pydantic v2 models in `app/mcp/schemas/tool_schemas.py`:
  - `CalculatorInput`: Validates integer arithmetic with min/max boundaries (`-1,000,000` to `1,000,000`).
  - `SearchInput`: Validates query length (`min_length=1`, `max_length=200`).
  - `GreetInput`: Validates string inputs.
- **Verification**: Rejected out-of-bound inputs with structured `-32602 Invalid params` JSON-RPC errors.

#### Step 3: Local Authentication & Authorization Middleware
- **Implementation**: Built `StaticTokenVerifier(TokenVerifier)` in `app/mcp/middleware/authentication.py` and `require_scope()` in `authorization.py`.
- **Verification**: Unauthenticated requests received `401 Unauthorized`. Valid bearer tokens successfully resolved `client_id` and assigned `tools:read` scopes.

#### Step 4: Production Structured Logging & Config
- **Implementation**: Created `app/config/settings.py` leveraging `pydantic-settings` to parse configuration and secrets from environment variables.
- **Structured Logging**: Created `JsonFormatter` in `app/mcp/middleware/logging.py` outputting structured JSON (`timestamp`, `level`, `request_id`, `method`, `duration_ms`, `status`).

#### Step 5: Unit & Integration Test Suite
- **Implementation**: Authored 14 automated test cases covering authentication, tool validation, error paths, and health probes using `pytest` and `anyio`.
- **Verification**: `pytest -v` executed with 14/14 passing tests.

---

### Phase 2: Containerization & Azure Container Registry (Steps 6–7)

#### Step 6: Docker Containerization
- **Base Image**: `python:3.12-slim`
- **Security**: Multi-stage/layered build, dependencies isolated, running as non-root user `mcpuser` (UID 10001).
- **Optimization**: `.dockerignore` excludes `.git`, `.venv`, `__pycache__`, and secrets.

#### Step 7: Azure Container Registry (ACR)
- **Service & Tier**: Azure Container Registry, **Basic Tier** (cost-effective, private container registry).
- **Resource Name**: `azuremcpacrsanjay`
- **Azure CLI Commands**:
  ```bash
  az acr create --resource-group rg-azure-mcp --name azuremcpacrsanjay --sku Basic --admin-enabled false
  az acr login --name azuremcpacrsanjay
  docker tag azure-mcp-server:latest azuremcpacrsanjay.azurecr.io/azure-mcp-server:v1
  docker push azuremcpacrsanjay.azurecr.io/azure-mcp-server:v1
  ```
- **Verification**: Verified image catalog with `az acr repository list` and `show-tags`.

---

### Phase 3: Serverless Compute & Secret Management (Steps 8–9)

#### Step 8: Azure Container Apps Deployment
- **Service & Tier**: Azure Container Apps on **Serverless Consumption Tier** ($0 when inactive).
- **Environment**: `azure-mcp-env` in `centralindia`.
- **Container Identity**: Created user-assigned managed identity `azure-mcp-container-identity` and assigned `AcrPull` on `azuremcpacrsanjay`.
- **Azure CLI Commands**:
  ```bash
  az identity create --name azure-mcp-container-identity --resource-group rg-azure-mcp
  az role assignment create --assignee <IDENTITY_PRINCIPAL_ID> --role AcrPull --scope <ACR_RESOURCE_ID>
  az containerapp env create --name azure-mcp-env --resource-group rg-azure-mcp --location centralindia
  az containerapp create --name azure-mcp-server --resource-group rg-azure-mcp \
    --environment azure-mcp-env \
    --image azuremcpacrsanjay.azurecr.io/azure-mcp-server:v1 \
    --target-port 8000 --ingress external \
    --user-assigned <IDENTITY_RESOURCE_ID> \
    --registry-server azuremcpacrsanjay.azurecr.io --registry-identity <IDENTITY_RESOURCE_ID>
  ```
- **Verification**: Container deployed, HTTPS endpoint provisioned at `https://azure-mcp-server.whitesky-8a5d41e8.centralindia.azurecontainerapps.io/mcp`.

#### Step 9: Azure Key Vault & Workload Managed Identity
- **Service & Tier**: Azure Key Vault, **Standard Tier** with Azure RBAC enabled.
- **Resource Name**: `azuremcpkvsanjay`
- **Dynamic Secret Injection**: Created secret `mcp-local-test-token`. Created workload managed identity `azure-mcp-workload-identity` with `Key Vault Secrets User`.
- **Configuration**: Container app secret configured via `keyVaultUrl` and exposed as an environment variable via `secretRef`.
- **Verification**: Application dynamically read secrets from Key Vault via managed identity without plain-text configuration.

---

### Phase 4: Identity, Gateway & Dual-Perimeter Governance (Steps 10–12)

#### Step 10: Microsoft Entra ID Authentication & Easy Auth
- **Entra ID App Registration**: `Azure MCP Server` (`appId: 96aa8318-7994-470d-af80-4c41cd659ecd`, `tenantId: e08a82d9-2069-48b3-8dd2-1d8f5d37a046`).
- **Identifier URI**: `https://azure-mcp-server.whitesky-8a5d41e8.centralindia.azurecontainerapps.io`
- **Exposed Scope**: `tools.execute`
- **Container Apps Easy Auth**: Enabled Microsoft Entra ID provider with `unauthenticatedClientAction: Return401`.
- **Verification**: Unauthenticated requests to Container Apps directly received `HTTP 401 Unauthorized` before application code was executed.

#### Step 11: Azure API Management (APIM) Gateway
- **Service & Tier**: Azure API Management, **Consumption Tier** (1,000,000 free calls per month, $0 fixed hourly fee).
- **Resource Name**: `azure-mcp-apim-sanjay`
- **API Exposed**: `azure-mcp` with wildcard operation `/*` mapping to Container Apps `/mcp`.
- **Rate Limiting**: Enforced `<rate-limit calls="60" renewal-period="60" />` (adapted for serverless Consumption tier).
- **Streaming Passthrough**: Enabled unbuffered transfer to preserve Server-Sent Events (SSE).

#### Step 12: Dual-Perimeter Token Exchange & Security Hardening
- **Concept**:
  - Client sends OAuth2 JWT for `Azure MCP Server` to APIM Gateway.
  - APIM `<validate-azure-ad-token>` inspects signature, tenant, and audience.
  - APIM System-Assigned Managed Identity (`PrincipalId: 72f08837-0d29-43f8-a690-ca4c97769246`) acquires a backend token using `<authentication-managed-identity>` and forwards to Container Apps.
  - Container Apps Easy Auth validates the APIM token.
- **Verification**:
  - Unauthenticated calls rejected at APIM Gateway with 401.
  - Calls with client token successfully traversed APIM and Container Apps to return live results for `add(a=777, b=223) -> 1000`.

---

### Phase 5: Network Perimeter & Telemetry (Steps 13–14)

#### Step 13: Network Perimeter & Direct Ingress Shielding
- Verified that direct access to Container Apps without valid tokens is rejected by Easy Auth, making APIM the governed gateway.

#### Step 14: Observability & Application Insights
- **Services**: Log Analytics Workspace (`workspace-rgazuremcpy425`) + Application Insights (`azure-mcp-appinsights`).
- **Diagnostics**: APIM diagnostic settings configured for `GatewayLogs` and `AllMetrics`.
- **Container Telemetry**: `APPLICATIONINSIGHTS_CONNECTION_STRING` attached to Container App revision.

---

### Phase 6: DevOps, CI/CD & Blue/Green Deployments (Steps 15–16)

#### Step 15: Zero-Secret Production CI/CD with GitHub Actions OIDC
- **Zero-Secret Architecture**: OpenID Connect (OIDC) between GitHub Actions and Microsoft Entra ID. No permanent passwords stored in GitHub!
- **Entra ID Deployment Identity**: `azure-mcp-github-actions` (`appId: e4c733f8-b7cd-4eae-b327-d30f692b733f`).
- **Federated Credentials**: Configured for repository `SanjayR857/Azure-MCP-server` on `main` branch.
- **RBAC**: Assigned `AcrPush` on ACR and `Contributor` on Container App.
- **Workflow Pipeline**: `.github/workflows/deploy.yml` with dual jobs:
  1. `Run Pytest Suite` (14/14 tests on Ubuntu).
  2. `Build, Push & Deploy Revision`:
     - `azure/login@v2` with OIDC
     - `az acr login`
     - Docker image build tagged with `${{ github.sha }}` and `latest`
     - Docker image push to ACR
     - `az containerapp update` deploying versioned revision

#### Step 16: Blue/Green Deployment, Health Checks & Rollbacks
- **Multiple Revision Mode**: Configured `activeRevisionsMode: Multiple`.
- **Health Endpoints**: Added `@mcp.custom_route("/health/live")` and `@mcp.custom_route("/health/ready")` returning HTTP 200 JSON responses.
- **Revision Naming**: Unique revisions named with commit hash (`azure-mcp-server--<short-sha>`).
- **Traffic Splitting**:
  - Green revision deployed with initial traffic weight `0%` (`blue=100 green=0`).
  - Staging verification performed.
  - Traffic promoted to `100%` (`blue=0 green=100`).
  - Blue revision retained active at `0%` for instantaneous zero-downtime rollback!
- **Verification**: Verified live in Azure:
  - Revision `azure-mcp-server--0000009` (Blue): weight 0%
  - Revision `azure-mcp-server--e89e174` (Green): weight 100%

---

## Complete Resource Inventory

| Resource Name | Type | Tier / SKU | Location | Purpose |
|---|---|---|---|---|
| `rg-azure-mcp` | Resource Group | N/A | centralindia | Core project container |
| `azuremcpacrsanjay` | Container Registry | Basic | centralindia | Docker image storage |
| `azure-mcp-container-identity` | Managed Identity | User-Assigned | centralindia | ACR image pull authentication |
| `azure-mcp-workload-identity` | Managed Identity | User-Assigned | centralindia | Key Vault secret retrieval |
| `azuremcpkvsanjay` | Key Vault | Standard (RBAC) | centralindia | Production secret store |
| `workspace-rgazuremcpy425` | Log Analytics | PerGB2018 | centralindia | Centralized log workspace |
| `azure-mcp-appinsights` | Application Insights | Web (Consumption) | centralindia | Distributed tracing & telemetry |
| `azure-mcp-env` | Managed Environment | Consumption | centralindia | Serverless ACA environment |
| `azure-mcp-server` | Container App | Consumption | centralindia | MCP server execution engine |
| `azure-mcp-apim-sanjay` | API Management | Consumption | centralindia | Enterprise MCP API gateway |
| `Azure MCP Server` | Entra App Registration | Free | Global | OAuth 2.0 API resource & Easy Auth |
| `azure-mcp-github-actions` | Entra App Registration | Free | Global | OIDC deployment principal |

---

## Infrastructure as Code (Bicep)
All infrastructure described above is fully codified in modular Bicep templates located under `infra/bicep/`:
- `main.bicep`: Orchestrates all resources with automated dependency management.
- `acr.bicep`: Basic SKU registry.
- `monitoring.bicep`: Log Analytics and Application Insights.
- `identity.bicep`: User-assigned managed identity and RBAC assignments.
- `keyvault.bicep`: Standard Key Vault with RBAC.
- `containerapp.bicep`: Container Apps environment, probes, and app configuration.
- `apim.bicep`: Consumption APIM with policies and API definitions.
- `deploy-infra.ps1`: One-click PowerShell deployment script.
