param acrName string
param location string = resourceGroup().location

resource acr 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: acrName
  location: location

  sku: {
    name: 'Premium'
  }

  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

output registryName string = acr.name
output loginServer string = acr.properties.loginServer