// modules/storageAccount.bicep
// Standard_LRS storage account with a blob container, for practicing
// blob storage integration from the web app.

param location string
param projectName string
param uniqueSuffix string

// Storage account names must be lowercase alphanumeric only (no hyphens),
// so strip any hyphens from projectName before using it here.
var sanitizedProjectName = replace(projectName, '-', '')
var storageAccountName = toLower('st${sanitizedProjectName}${uniqueSuffix}')

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: take(storageAccountName, 24)
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'app-data'
  properties: {
    publicAccess: 'None'
  }
}

output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
