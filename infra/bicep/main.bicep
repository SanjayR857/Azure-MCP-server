@description('Base prefix for all resources to ensure unique naming')
param prefix string = 'azuremcp'

@description('Azure region for resource deployment')
param location string = resourceGroup().location

@description('Container image tag to deploy')
param containerImage string = 'azuremcpacrsanjay.azurecr.io/azure-mcp-server:latest'

@description('Unique suffix for global names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

var acrName = toLower('${prefix}acr${uniqueSuffix}')
var workspaceName = '${prefix}-workspace-${uniqueSuffix}'
var appInsightsName = '${prefix}-appinsights-${uniqueSuffix}'
var identityName = '${prefix}-container-identity'
var keyVaultName = toLower(take('${prefix}kv${uniqueSuffix}', 24))
var environmentName = '${prefix}-env'
var containerAppName = '${prefix}-server'
var apimName = '${prefix}-apim-${uniqueSuffix}'

// 1. Container Registry (Basic Tier)
module acrModule 'acr.bicep' = {
  name: 'acrDeployment'
  params: {
    acrName: acrName
    location: location
  }
}

// 2. Monitoring (Log Analytics + App Insights)
module monitoringModule 'monitoring.bicep' = {
  name: 'monitoringDeployment'
  params: {
    workspaceName: workspaceName
    appInsightsName: appInsightsName
    location: location
  }
}

// 3. User Assigned Managed Identity for ACR Pull
module identityModule 'identity.bicep' = {
  name: 'identityDeployment'
  params: {
    identityName: identityName
    acrId: acrModule.outputs.registryId
    location: location
  }
}

// 4. Key Vault (Standard Tier with RBAC)
module keyVaultModule 'keyvault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    keyVaultName: keyVaultName
    location: location
    workloadPrincipalId: identityModule.outputs.identityPrincipalId
  }
}

// 5. Container Apps Environment and App (Serverless Consumption)
module containerAppModule 'containerapp.bicep' = {
  name: 'containerAppDeployment'
  params: {
    environmentName: environmentName
    containerAppName: containerAppName
    location: location
    workspaceId: monitoringModule.outputs.workspaceId
    appInsightsConnectionString: monitoringModule.outputs.appInsightsConnectionString
    userAssignedIdentityId: identityModule.outputs.identityId
    acrLoginServer: acrModule.outputs.loginServer
    containerImage: containerImage
  }
}

// 6. Azure API Management (Consumption Tier)
module apimModule 'apim.bicep' = {
  name: 'apimDeployment'
  params: {
    apimName: apimName
    location: location
    backendFqdn: containerAppModule.outputs.containerAppFqdn
    apiAudience: 'https://${containerAppModule.outputs.containerAppFqdn}'
  }
}

output acrLoginServer string = acrModule.outputs.loginServer
output containerAppFqdn string = containerAppModule.outputs.containerAppFqdn
output apimGatewayUrl string = apimModule.outputs.apimGatewayUrl
output mcpPublicEndpoint string = apimModule.outputs.mcpGatewayEndpoint
output keyVaultUri string = keyVaultModule.outputs.keyVaultUri
