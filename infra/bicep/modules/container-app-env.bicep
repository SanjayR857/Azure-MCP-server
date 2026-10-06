param environmentName string
param location string
param workspaceCustomerId string

@secure()
param workspaceSharedKey string

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location

  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'

      logAnalyticsConfiguration: {
        customerId: workspaceCustomerId
        sharedKey: workspaceSharedKey
      }
    }
  }
}

output environmentId string = environment.id