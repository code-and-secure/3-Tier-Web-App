// main.bicep
// Deploys a small learning stack: VNet, App Service (Free F1), Storage, Key Vault,
// a free-tier SQL Database, and Log Analytics + App Insights for monitoring.
// Deploy at subscription scope so this file can create the resource group too.

targetScope = 'subscription'

@description('Short project name used as a prefix for all resources')
param projectName string = 'bicepprac'

@description('Azure region for all resources')
param location string = 'eastus'

@description('Environment tag, e.g. dev, test')
param environment string = 'dev'

@secure()
@description('Admin password for the SQL logical server')
param sqlAdminPassword string

@description('Admin login for the SQL logical server')
param sqlAdminLogin string = 'sqladminuser'

var uniqueSuffix = uniqueString(subscription().subscriptionId, projectName, environment)
var resourceGroupName = 'rg-${projectName}-${environment}'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module network 'modules/network.bicep' = {
  name: 'networkDeploy'
  scope: rg
  params: {
    location: location
    projectName: projectName
  }
}

module logAnalytics 'modules/logAnalytics.bicep' = {
  name: 'logAnalyticsDeploy'
  scope: rg
  params: {
    location: location
    projectName: projectName
    uniqueSuffix: uniqueSuffix
  }
}

module storage 'modules/storageAccount.bicep' = {
  name: 'storageDeploy'
  scope: rg
  params: {
    location: location
    projectName: projectName
    uniqueSuffix: uniqueSuffix
  }
}

module keyVault 'modules/keyVault.bicep' = {
  name: 'keyVaultDeploy'
  scope: rg
  params: {
    location: location
    projectName: projectName
    uniqueSuffix: uniqueSuffix
  }
}

module sqlDb 'modules/sqlDatabase.bicep' = {
  name: 'sqlDbDeploy'
  scope: rg
  params: {
    location: location
    projectName: projectName
    uniqueSuffix: uniqueSuffix
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
  }
}

module appService 'modules/appService.bicep' = {
  name: 'appServiceDeploy'
  scope: rg
  params: {
    location: location
    projectName: projectName
    uniqueSuffix: uniqueSuffix
    appInsightsConnectionString: logAnalytics.outputs.appInsightsConnectionString
    keyVaultUri: keyVault.outputs.keyVaultUri
    subnetId: network.outputs.appSubnetId
  }
}

output webAppUrl string = appService.outputs.defaultHostName
output resourceGroup string = resourceGroupName
