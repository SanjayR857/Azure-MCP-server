<#
.SYNOPSIS
    Provisions Azure Key Vault and synchronizes secrets for Azure Remote MCP Server.
.DESCRIPTION
    Creates or updates the Key Vault with RBAC authorization, assigns the Container App
    System-Assigned Managed Identity the 'Key Vault Secrets User' role, and synchronizes secrets.
#>
param(
    [string]$ResourceGroup = "azure-mcp-server",
    [string]$KeyVaultName = "kv-azure-mcp-2026",
    [string]$ContainerAppName = "azure-mcp-server",
    [string]$Location = "centralindia"
)

$ErrorActionPreference = "Stop"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host " AZURE KEY VAULT SETUP & CONTAINER APP SECRET INJECTION" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Verify Authentication
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Error "Not authenticated to Azure. Run 'az login' first."
}
Write-Host "Authenticated as: $($account.user.name) on subscription: $($account.name)" -ForegroundColor Gray

# 2. Ensure Key Vault exists
Write-Host "`n[1/4] Ensuring Key Vault '$KeyVaultName' exists in '$ResourceGroup'..." -ForegroundColor Yellow
$kvCheck = az keyvault show --name $KeyVaultName --resource-group $ResourceGroup -o json 2>$null
if (-not $kvCheck) {
    Write-Host "Creating Key Vault '$KeyVaultName' with RBAC..." -ForegroundColor Yellow
    az keyvault create `
        --name $KeyVaultName `
        --resource-group $ResourceGroup `
        --location $Location `
        --enable-rbac-authorization true `
        --output none
    Write-Host "Key Vault created successfully." -ForegroundColor Green
} else {
    Write-Host "Key Vault already exists." -ForegroundColor Green
}

# 3. Grant Container App Managed Identity permission
Write-Host "`n[2/4] Granting Container App Managed Identity access..." -ForegroundColor Yellow
$principalId = az containerapp show --name $ContainerAppName --resource-group $ResourceGroup --query "identity.principalId" -o tsv
if ($principalId) {
    $kvId = az keyvault show --name $KeyVaultName --resource-group $ResourceGroup --query "id" -o tsv
    az role assignment create `
        --role "Key Vault Secrets User" `
        --assignee-object-id $principalId `
        --assignee-principal-type "ServicePrincipal" `
        --scope $kvId `
        --output none 2>$null
    Write-Host "Granted 'Key Vault Secrets User' to Managed Identity ($principalId)." -ForegroundColor Green
} else {
    Write-Warning "Could not find Container App Managed Identity principalId."
}

# 4. Inject Key Vault secret references into Container App
Write-Host "`n[3/4] Binding Key Vault secret references to Container App..." -ForegroundColor Yellow
$vaultUri = "https://${KeyVaultName}.vault.azure.net"
az containerapp secret set `
    --name $ContainerAppName `
    --resource-group $ResourceGroup `
    --secrets `
        "appinsights-cs=keyvaultref:${vaultUri}/secrets/appinsights-connection-string,identityref:system" `
        "azure-sub-id=keyvaultref:${vaultUri}/secrets/azure-subscription-id,identityref:system" `
        "entra-tenant-id=keyvaultref:${vaultUri}/secrets/entra-tenant-id,identityref:system" `
        "entra-client-id=keyvaultref:${vaultUri}/secrets/entra-client-id,identityref:system" `
    --output none

Write-Host "Binding environment variables to secret references..." -ForegroundColor Yellow
az containerapp update `
    --name $ContainerAppName `
    --resource-group $ResourceGroup `
    --set-env-vars `
        "APPLICATIONINSIGHTS_CONNECTION_STRING=secretref:appinsights-cs" `
        "AZURE_SUBSCRIPTION_ID=secretref:azure-sub-id" `
        "ENTRA_TENANT_ID=secretref:entra-tenant-id" `
        "ENTRA_CLIENT_ID=secretref:entra-client-id" `
    --output none

Write-Host "`n[4/4] Verification:" -ForegroundColor Yellow
$appEnv = az containerapp show --name $ContainerAppName --resource-group $ResourceGroup --query "properties.template.containers[0].env" -o json | ConvertFrom-Json
$appEnv | Where-Object { $_.secretRef } | ForEach-Object {
    Write-Host "  * Env: $($_.name) -> secretRef: $($_.secretRef)" -ForegroundColor Green
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host " Azure Key Vault injection completed successfully!" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor Cyan
