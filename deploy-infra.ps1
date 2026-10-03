<#
.SYNOPSIS
    Automated Azure Infrastructure Provisioning Script for Azure MCP Server.
.DESCRIPTION
    Deploys all Azure resources (ACR, Key Vault, Container Apps, APIM, App Insights)
    using modular Bicep templates strictly on standard, free, and consumption tiers.
#>

param(
    [string]$ResourceGroupName = "rg-azure-mcp",
    [string]$Location = "centralindia",
    [string]$Prefix = "azuremcp"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Azure MCP Server: Automated Infrastructure Deployment   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check Azure Login
Write-Host "`n[1/4] Checking Azure CLI authentication..." -ForegroundColor Yellow
$account = az account show --output json | ConvertFrom-Json
if (-not $account) {
    Write-Error "Please run 'az login' before running this deployment script."
    exit 1
}
Write-Host "Authenticated as: $($account.user.name) on subscription: $($account.name) ($($account.id))" -ForegroundColor Green

# 2. Create Resource Group
Write-Host "`n[2/4] Ensuring resource group '$ResourceGroupName' exists in '$Location'..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --output table

# 3. Deploy Bicep Infrastructure
Write-Host "`n[3/4] Deploying Bicep templates from infra/bicep/main.bicep..." -ForegroundColor Yellow
$deployment = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "infra/bicep/main.bicep" `
    --parameters prefix=$Prefix location=$Location `
    --output json | ConvertFrom-Json

# 4. Display Outputs
Write-Host "`n[4/4] Infrastructure Deployment Successful!" -ForegroundColor Green
Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Container Registry  : $($deployment.properties.outputs.acrLoginServer.value)" -ForegroundColor White
Write-Host "Container App FQDN  : $($deployment.properties.outputs.containerAppFqdn.value)" -ForegroundColor White
Write-Host "APIM Gateway URL    : $($deployment.properties.outputs.apimGatewayUrl.value)" -ForegroundColor White
Write-Host "MCP Public Endpoint : $($deployment.properties.outputs.mcpPublicEndpoint.value)" -ForegroundColor Green
Write-Host "Key Vault URI       : $($deployment.properties.outputs.keyVaultUri.value)" -ForegroundColor White
Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Done." -ForegroundColor Green
