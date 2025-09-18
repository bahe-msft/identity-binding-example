@description('The location for all resources')
param location string

@description('The name prefix for all resources')
param namePrefix string

@description('The AKS cluster name')
param aksClusterName string

@description('The OIDC issuer URL from the AKS cluster')
param aksOidcIssuerUrl string

// Create the first managed identity for pod identity demo
resource managedIdentity1 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${namePrefix}-mi-podidentity'
  location: location
}

// Create the second managed identity for workload identity and identity binding demos
resource managedIdentity2 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${namePrefix}-mi-workloadidentity'
  location: location
}

// Create Azure Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'akv${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
  }
}

// Create a sample secret in the Key Vault
resource sampleSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'demo-secret'
  properties: {
    value: 'Hello from Azure Key Vault! This is a demo secret.'
    contentType: 'text/plain'
  }
}

// Grant Key Vault Secrets User role to both managed identities
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: keyVault
  name: '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
}

resource managedIdentity1KeyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, managedIdentity1.id, keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: managedIdentity1.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource managedIdentity2KeyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, managedIdentity2.id, keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: managedIdentity2.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Pod Identity setup module
module podIdentitySetup 'identity-pi.bicep' = {
  name: 'pod-identity-setup'
  params: {
    location: location
    aksClusterName: aksClusterName
    managedIdentity1Id: managedIdentity1.id
    managedIdentity2Id: managedIdentity2.id
  }
}

// Workload Identity setup module
module workloadIdentitySetup 'identity-wi.bicep' = {
  name: 'workload-identity-setup'
  params: {
    aksOidcIssuerUrl: aksOidcIssuerUrl
    managedIdentity1Id: managedIdentity1.id
    managedIdentity2Id: managedIdentity2.id
  }
}

// Identity Binding setup module
module identityBindingSetup 'identity-ib.bicep' = {
  name: 'identity-binding-setup'
  params: {
    aksClusterName: aksClusterName
    managedIdentity1Id: managedIdentity1.id
    managedIdentity2Id: managedIdentity2.id
  }
}

// Outputs
output keyVaultName string = keyVault.name
output keyVaultUrl string = keyVault.properties.vaultUri
output keyVaultId string = keyVault.id
output managedIdentity1Name string = managedIdentity1.name
output managedIdentity1ClientId string = managedIdentity1.properties.clientId
output managedIdentity1PrincipalId string = managedIdentity1.properties.principalId
output managedIdentity1ResourceId string = managedIdentity1.id
output managedIdentity2Name string = managedIdentity2.name
output managedIdentity2ClientId string = managedIdentity2.properties.clientId
output managedIdentity2PrincipalId string = managedIdentity2.properties.principalId
output managedIdentity2ResourceId string = managedIdentity2.id
output sampleSecretName string = sampleSecret.name
