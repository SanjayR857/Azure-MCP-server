param acrName string
param location string

resource acr 'Microsoft.containerRegistry/registries@2023-07-01' = {
    name: acrName
    location: location

    sku: {
        name: 'Basic'
    }

    properties: {
        adminUserEnabled: true   
    }
}

output acrId string = acr.id
output acrLoginServer string = acr.properties.loginServer