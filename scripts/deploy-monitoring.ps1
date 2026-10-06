<#
.SYNOPSIS
    Deploys Azure Monitor, Application Insights, Diagnostic Settings, Metric Alerts,
    and the Inspection Workbook for the Azure Remote MCP Server.
.PARAMETER ResourceGroup
    The resource group where the MCP server is deployed (default: 'azure-mcp-server').
.PARAMETER ContainerAppName
    The name of the Container App (default: 'azure-mcp-server').
.PARAMETER AppInsightsName
    The name of the Application Insights component to create (default: 'azure-mcp-insights').
#>
param(
    [string]$ResourceGroup = "azure-mcp-server",
    [string]$ContainerAppName = "azure-mcp-server",
    [string]$AppInsightsName = "azure-mcp-insights"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Deploying Azure Monitor & Inspection to Azure Cloud" -ForegroundColor Cyan
Write-Host " Resource Group: $ResourceGroup" -ForegroundColor Cyan
Write-Host " Container App:  $ContainerAppName" -ForegroundColor Cyan
Write-Host " App Insights:   $AppInsightsName" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify Azure CLI Authentication
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Authenticating to Azure..." -ForegroundColor Yellow
    az login
} else {
    Write-Host "[OK] Authenticated to subscription: $($account.name) ($($account.id))" -ForegroundColor Green
}

# 2. Deploy Monitoring Infrastructure via Bicep
Write-Host "`n[1/3] Deploying Bicep monitoring template..." -ForegroundColor Yellow
$deployResultJson = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file infra/bicep/deploy-monitoring.bicep `
    --parameters containerAppName=$ContainerAppName `
                 appInsightsName=$AppInsightsName `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to deploy monitoring infrastructure."
    exit 1
}

$deployResult = $deployResultJson | ConvertFrom-Json
$connectionString = $deployResult.properties.outputs.appInsightsConnectionString.value
$workbookId = $deployResult.properties.outputs.workbookId.value

Write-Host "[OK] Application Insights deployed successfully." -ForegroundColor Green
Write-Host "[OK] Diagnostic Settings configured for Log Analytics." -ForegroundColor Green
Write-Host "[OK] Azure Monitor Metric Alerts configured (CPU, Memory, Restarts, Latency)." -ForegroundColor Green
Write-Host "[OK] Inspection Workbook deployed (ID: $workbookId)" -ForegroundColor Green

# 3. Update Container App Environment Variables with AppInsights Connection String
Write-Host "`n[2/3] Updating Container App with Application Insights connection string..." -ForegroundColor Yellow
az containerapp update `
    --name $ContainerAppName `
    --resource-group $ResourceGroup `
    --set-env-vars APPLICATIONINSIGHTS_CONNECTION_STRING="$connectionString" `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Container App updated with APPLICATIONINSIGHTS_CONNECTION_STRING." -ForegroundColor Green
} else {
    Write-Warning "Could not update container app environment variables automatically."
}

# 4. Verification & Inspection Links
Write-Host "`n[3/3] Fetching server status..." -ForegroundColor Yellow
$appDetails = az containerapp show `
    --name $ContainerAppName `
    --resource-group $ResourceGroup `
    --output json | ConvertFrom-Json

$fqdn = $appDetails.properties.configuration.ingress.fqdn
$healthUrl = "https://$fqdn/health"

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Monitoring & Inspection Setup Complete!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Health Endpoint:      $healthUrl" -ForegroundColor White
Write-Host "MCP Endpoint:         https://$fqdn/mcp" -ForegroundColor White
Write-Host "Application Insights: $AppInsightsName" -ForegroundColor White
Write-Host "Azure Portal Links:" -ForegroundColor Cyan
Write-Host " - Live Metrics:       https://portal.azure.com/#@/resource/subscriptions/$($account.id)/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/components/$AppInsightsName/quickPulse" -ForegroundColor Yellow
Write-Host " - Failures & Traces:  https://portal.azure.com/#@/resource/subscriptions/$($account.id)/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/components/$AppInsightsName/failures" -ForegroundColor Yellow
Write-Host " - Log Analytics:      https://portal.azure.com/#@/resource/subscriptions/$($account.id)/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/azure-mcp-law/logs" -ForegroundColor Yellow
Write-Host " - Inspection Workbook:https://portal.azure.com/#@/resource$workbookId" -ForegroundColor Yellow
Write-Host "`nRun .\scripts\inspect.ps1 anytime to inspect your live deployment!" -ForegroundColor Cyan
