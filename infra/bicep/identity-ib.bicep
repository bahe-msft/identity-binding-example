@description('The AKS cluster name')
param aksClusterName string

@description('The resource ID of the first managed identity')
param managedIdentity1Id string

@description('The resource ID of the second managed identity')
param managedIdentity2Id string

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-01-01' existing = {
  name: aksClusterName
}

resource identityBindingMI1 'Microsoft.ContainerService/managedClusters/identityBindings@2025-06-02-preview' = {
  parent: aksCluster

  name: 'mi1-identity-binding'
  properties: {
    managedIdentity: {
      resourceId: managedIdentity1Id
    }
  }
}

resource identityBindingMI2 'Microsoft.ContainerService/managedClusters/identityBindings@2025-06-02-preview' = {
  parent: aksCluster

  name: 'mi2-identity-binding'
  properties: {
    managedIdentity: {
      resourceId: managedIdentity2Id
    }
  }
}

// Outputs
output identityBinding1ResourceId string = identityBindingMI1.id
output identityBinding2ResourceId string = identityBindingMI2.id
