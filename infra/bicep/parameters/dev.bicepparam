using '../main.bicep'

param acrName = 'azuremcpacr'

param logAnalyticsName = 'azure-mcp-law'

param containerEnvironmentName = 'azuremcp-env'

param containerAppName = 'azure-mcp-server'

param imageName = 'azure-mcp-server'

param imageTag = 'v1'

// Note: azureSubscriptionId and entraTenantId are automatically resolved dynamically in main.bicep
// Provide entraClientId at deploy time (e.g. via CLI parameter or CI/CD pipeline)
param entraClientId = ''

param requiredScope = 'access_as_user'