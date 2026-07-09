// modules/appService.bicep
// Free tier (F1) App Service plan + a Linux web app, VNet-integrated,
// with a system-assigned identity so it can read secrets from Key Vault
// without storing credentials.

param location string
param projectName string
param uniqueSuffix string
param appInsightsConnectionString string
param keyVaultUri string
param subnetId string

var appServicePlanName = 'plan-${projectName}'
var webAppName = toLower('app-${projectName}-${uniqueSuffix}')

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'F1'
    tier: 'Free'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: subnetId
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'KEY_VAULT_URI'
          value: keyVaultUri
        }
      ]
    }
  }
}

// Grant the web app's managed identity permission to read secrets from Key Vault.
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(webApp.id, 'Key Vault Secrets User')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output defaultHostName string = webApp.properties.defaultHostName
output webAppName string = webApp.name
output principalId string = webApp.identity.principalId
