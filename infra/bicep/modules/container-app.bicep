param containerAppName string
param location string
param environmentId string
param image string
param targetPort int = 8000

resource app 'Microsoft.App/containerApps@2024-03-01' = {

  name: containerAppName

  location: location

  identity: {
    type: 'SystemAssigned'
  }

  properties: {

    managedEnvironmentId: environmentId

    configuration: {

      activeRevisionsMode: 'Single'

      ingress: {
        external: true
        targetPort: targetPort
        transport: 'auto'
      }

      registries: [
        {
          server: replace(image, '/.*\\/.*/', '')
          identity: 'system'
        }
      ]
    }

    template: {

      containers: [
        {
          name: 'azure-mcp-server'

          image: image

          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }

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
          ]
        }
      ]

      scale: {
        minReplicas: 1
        maxReplicas: 10

        rules: [
          {
            name: 'http-scale'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
}

output fqdn string = app.properties.configuration.ingress.fqdn
output principalId string = app.identity.principalId