@description('The OIDC issuer URL from the AKS cluster')
param aksOidcIssuerUrl string

@description('The resource ID of the first managed identity')
param managedIdentity1Id string

@description('The resource ID of the second managed identity')
param managedIdentity2Id string

// Get references to the existing managed identities
resource managedIdentity1 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: last(split(managedIdentity1Id, '/'))
}

resource managedIdentity2 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: last(split(managedIdentity2Id, '/'))
}

// Federated Identity Credentials - Only needed for Workload Identity scenarios
// Pod Identity doesn't use FICs, it uses the Azure AD Pod Identity MIC/NMI components
// Identity Binding manages FICs automatically, so we don't create them manually

// Federated Identity Credential for Managed Identity 1 - Workload Identity demo
resource federatedIdentityCredentialMI1_WI 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: managedIdentity1
  name: 'workload-identity-credential'
  properties: {
    issuer: aksOidcIssuerUrl
    subject: 'system:serviceaccount:demo-app-wi:workload-identity-sa'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

// Federated Identity Credential for Managed Identity 2 - Workload Identity demo
resource federatedIdentityCredentialMI2_WI 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: managedIdentity2
  name: 'workload-identity-credential'
  properties: {
    issuer: aksOidcIssuerUrl
    subject: 'system:serviceaccount:demo-app-wi:workload-identity-sa'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

// Outputs
output federatedIdentityCredential1Name string = federatedIdentityCredentialMI1_WI.name
output federatedIdentityCredential2Name string = federatedIdentityCredentialMI2_WI.name