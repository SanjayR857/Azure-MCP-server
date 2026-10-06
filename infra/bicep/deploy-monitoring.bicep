param location string = resourceGroup().location
param logAnalyticsName string = 'azure-mcp-law'
param containerEnvironmentName string = 'azure-mcp-env'
param containerAppName string = 'azure-mcp-server'
param appInsightsName string = 'azure-mcp-insights'
param workbookDisplayName string = 'Azure MCP Server - Inspection & Observability'

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsName
}

module appInsights 'modules/app-insights.bicep' = {
  name: 'appInsightsDeployment'
  params: {
    appInsightsName: appInsightsName
    location: location
    workspaceId: workspace.id
  }
}

module diagnosticSettings 'modules/diagnostic-settings.bicep' = {
  name: 'diagnosticSettingsDeployment'
  params: {
    containerAppName: containerAppName
    environmentName: containerEnvironmentName
    workspaceId: workspace.id
  }
}

module alerts 'modules/alerts.bicep' = {
  name: 'alertsDeployment'
  params: {
    containerAppName: containerAppName
  }
}

module workbook 'modules/workbook.bicep' = {
  name: 'workbookDeployment'
  params: {
    workbookDisplayName: workbookDisplayName
    location: location
    workspaceId: workspace.id
  }
}

output appInsightsId string = appInsights.outputs.appInsightsId
output appInsightsConnectionString string = appInsights.outputs.connectionString
output appInsightsInstrumentationKey string = appInsights.outputs.instrumentationKey
output workbookId string = workbook.outputs.workbookId
