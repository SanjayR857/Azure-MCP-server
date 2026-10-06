$ErrorActionPreference = "Stop"

$ACR_NAME = $env:ACR_NAME
$IMAGE_NAME = if ($env:IMAGE_NAME) { $env:IMAGE_NAME } else { "azure-mcp-server" }
$IMAGE_TAG = if ($env:IMAGE_TAG) { $env:IMAGE_TAG } else { (git rev-parse --short HEAD) }

if (-not $ACR_NAME) {
    Write-Error "Environment variable ACR_NAME is not set. Example: `$env:ACR_NAME = 'myacrname'"
    exit 1
}

Write-Host "Building Docker image ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}..."

docker build `
    -t "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}" `
    .

Write-Host "Build complete."

docker images "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"