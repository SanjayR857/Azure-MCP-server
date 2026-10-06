param location string = 'centralindia'
param logAnalyticsName string = 'azure-mcp-law'
param containerEnvironmentName string = 'azure-mcp-env'
param containerAppName string = 'azure-mcp-server'
param acrName string = 'azurecontainerregistry2026'
param imageName string = 'azure-mcp-server'
param imageTag string = 'latest'

@secure()
param acrPassword string

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

param appInsightsName string = 'azure-mcp-insights'

module appInsights 'modules/app-insights.bicep' = {
  name: 'appInsightsDeploy'
  params: {
    appInsightsName: appInsightsName
    location: location
    workspaceId: workspace.id
  }
}

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerEnvironmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspace.properties.customerId
        sharedKey: workspace.listKeys().primarySharedKey
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8000
        transport: 'auto'
      }
      secrets: [
        {
          name: 'acr-password'
          value: acrPassword
        }
      ]
      registries: [
        {
          server: '${acrName}.azurecr.io'
          username: acrName
          passwordSecretRef: 'acr-password'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'azure-mcp-server'
          image: '${acrName}.azurecr.io/${imageName}:${imageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8000
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8000
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              failureThreshold: 3
            }
          ]
          env: [
            {
              name: 'HOST'
              value: '0.0.0.0'
            }
            {
              name: 'PORT'
              value: '8000'
            }
            {
              name: 'LOG_LEVEL'
              value: 'INFO'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.outputs.connectionString
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 5
      }
    }
  }
}

module diagnosticSettings 'modules/diagnostic-settings.bicep' = {
  name: 'diagnosticSettingsDeploy'
  params: {
    containerAppName: containerAppName
    environmentName: containerEnvironmentName
    workspaceId: workspace.id
  }
}

module alerts 'modules/alerts.bicep' = {
  name: 'alertsDeploy'
  params: {
    containerAppName: containerAppName
  }
}

module workbook 'modules/workbook.bicep' = {
  name: 'workbookDeploy'
  params: {
    workbookDisplayName: 'Azure MCP Server - Inspection & Observability'
    location: location
    workspaceId: workspace.id
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
output healthEndpoint string = 'https://${containerApp.properties.configuration.ingress.fqdn}/health'
output mcpEndpoint string = 'https://${containerApp.properties.configuration.ingress.fqdn}/mcp'
output appInsightsConnectionString string = appInsights.outputs.connectionString
output workbookId string = workbook.outputs.workbookId
