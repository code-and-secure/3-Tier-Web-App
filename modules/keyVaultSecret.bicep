// modules/keyVaultSecret.bicep
// Writes a single secret into an existing Key Vault. Kept generic/reusable
// rather than hardcoding to the SQL password, in case more secrets are
// added later (see README learning path).

param keyVaultName string
param secretName string

@secure()
param secretValue string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: secretName
  properties: {
    value: secretValue
  }
}

output secretUri string = secret.properties.secretUri
