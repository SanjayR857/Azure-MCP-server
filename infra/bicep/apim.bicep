@description('The name of the API Management service')
param apimName string

@description('The publisher email address')
param publisherEmail string = 'admin@example.com'

@description('The publisher organization name')
param publisherName string = 'Azure MCP Organization'

@description('The Azure location for the resources')
param location string = resourceGroup().location

@description('The backend Container App FQDN')
param backendFqdn string

@description('The Entra ID Tenant ID for token validation')
param tenantId string = subscription().tenantId

@description('The Expected API Audience')
param apiAudience string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

resource mcpApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: 'azure-mcp'
  properties: {
    displayName: 'Azure MCP Server API'
    path: 'azure-mcp'
    protocols: [
      'https'
    ]
    serviceUrl: 'https://${backendFqdn}/mcp'
    subscriptionRequired: false
  }
}

resource mcpOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpApi
  name: 'mcp-all-operations'
  properties: {
    displayName: 'MCP Wildcard Gateway Operation'
    method: '*'
    urlTemplate: '/*'
  }
}

var policyXml = '''<policies>
  <inbound>
    <base />
    <validate-azure-ad-token tenant-id="${tenantId}">
      <audiences>
        <audience>${apiAudience}</audience>
      </audiences>
    </validate-azure-ad-token>
    <rate-limit calls="60" renewal-period="60" />
    <authentication-managed-identity resource="${apiAudience}" />
    <set-header name="Host" exists-action="override">
      <value>${backendFqdn}</value>
    </set-header>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>'''

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  parent: mcpApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(policyXml, '${tenantId}', tenantId), '${apiAudience}', apiAudience), '${backendFqdn}', backendFqdn)
  }
}

output apimId string = apim.id
output apimName string = apim.name
output apimGatewayUrl string = apim.properties.gatewayUrl
output apimPrincipalId string = apim.identity.principalId
output mcpGatewayEndpoint string = '${apim.properties.gatewayUrl}/azure-mcp/mcp'
