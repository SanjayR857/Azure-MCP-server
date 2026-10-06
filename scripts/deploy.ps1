$ErrorActionPreference = "Stop"

$RESOURCE_GROUP = if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { "rg-azure-mcp" }
$ACR_NAME = $env:ACR_NAME
$CONTAINER_APP_NAME = if ($env:CONTAINER_APP_NAME) { $env:CONTAINER_APP_NAME } else { "azure-mcp-server" }
$IMAGE_NAME = if ($env:IMAGE_NAME) { $env:IMAGE_NAME } else { "azure-mcp-server" }
$IMAGE_TAG = if ($env:IMAGE_TAG) { $env:IMAGE_TAG } else { (git rev-parse --short HEAD) }

if (-not $ACR_NAME) {
    Write-Error "Environment variable ACR_NAME is not set. Example: `$env:ACR_NAME = 'myacrname'"
    exit 1
}

# Only login if not already logged in
$account = az account show --output json 2>$null
if (-not $account) {
    Write-Host "Logging into Azure..."
    az login
} else {
    Write-Host "Already authenticated to Azure."
}

Write-Host "Logging into ACR: $ACR_NAME..."
az acr login --name $ACR_NAME

Write-Host "Building image ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}..."
docker build -t "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}" .

Write-Host "Pushing image to ACR..."
docker push "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

Write-Host "Deploying Container App: $CONTAINER_APP_NAME in $RESOURCE_GROUP..."
az containerapp update `
    --name $CONTAINER_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --image "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

Write-Host "Deployment completed successfully."