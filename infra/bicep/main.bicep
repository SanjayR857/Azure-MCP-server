param location string = resourceGroup().location

param acrName string
param logAnalyticsName string
param containerEnvironmentName string
param containerAppName string

param imageName string = 'azure-mcp-server'
param imageTag string = 'v1'

param azureSubscriptionId string = subscription().subscriptionId
param entraTenantId string = ''
param entraClientId string = ''
param requiredScope string = 'mcp:read'
param assignSubscriptionReaderRole bool = false
param appInsightsName string = 'azure-mcp-insights'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location

  sku: {
    name: 'Basic'
  }

  properties: {
    adminUserEnabled: false
  }
}

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

      registries: [
        {
          server: acr.properties.loginServer
          identity: 'system'
        }
      ]
    }

    template: {
      containers: [
        {
          name: 'azure-mcp-server'

          image: '${acr.properties.loginServer}/${imageName}:${imageTag}'

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
              initialDelaySeconds: 5
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
              initialDelaySeconds: 5
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
              name: 'AZURE_SUBSCRIPTION_ID'
              value: azureSubscriptionId
            }
            {
              name: 'ENTRA_TENANT_ID'
              value: entraTenantId
            }
            {
              name: 'ENTRA_CLIENT_ID'
              value: entraClientId
            }
            {
              name: 'REQUIRED_SCOPE'
              value: requiredScope
            }
            {
              name: 'MCP_RESOURCE_URL'
              value: 'https://${containerAppName}.${environment.properties.defaultDomain}/mcp'
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
        maxReplicas: 10
      }
    }
  }
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    acr.id,
    containerApp.id,
    'acrpull'
  )

  scope: acr

  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )

    principalId: containerApp.identity.principalId

    principalType: 'ServicePrincipal'
  }
}

resource rgReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    resourceGroup().id,
    containerApp.id,
    'rgreader'
  )

  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'acdd72a7-3385-48ef-bd42-f606fba81ae7'
    )

    principalId: containerApp.identity.principalId

    principalType: 'ServicePrincipal'
  }
}

module subReaderRole 'modules/subscription-role.bicep' = if (assignSubscriptionReaderRole) {
  name: 'subReaderRoleAssignment'
  scope: subscription()
  params: {
    principalId: containerApp.identity.principalId
    roleDefinitionId: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
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

output acrLoginServer string = acr.properties.loginServer

output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn

output mcpEndpoint string = 'https://${containerApp.properties.configuration.ingress.fqdn}/mcp'

output healthEndpoint string = 'https://${containerApp.properties.configuration.ingress.fqdn}/health'

output appInsightsConnectionString string = appInsights.outputs.connectionString

output workbookId string = workbook.outputs.workbookId