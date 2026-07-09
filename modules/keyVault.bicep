// modules/keyVault.bicep
// Standard Key Vault with RBAC authorization (no access policies needed).
// Used to practice storing and referencing secrets from the web app.

param location string
param projectName string
param uniqueSuffix string

var keyVaultName = toLower('kv-${projectName}-${uniqueSuffix}')

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: take(keyVaultName, 24)
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
