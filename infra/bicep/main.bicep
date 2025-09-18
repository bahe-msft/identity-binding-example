@description('The location for all resources')
param location string = resourceGroup().location

@description('The name prefix for all resources')
param namePrefix string = 'aks-identity-demo'

@description('The AKS cluster name')
param aksClusterName string = '${namePrefix}-aks'

@description('The node count for the AKS cluster')
param nodeCount int = 2

@description('The VM size for the AKS cluster nodes')
param vmSize string = 'Standard_D4ds_v5'

@description('The Kubernetes version')
param kubernetesVersion string = '1.32.0'

// Create the AKS cluster with workload identity enabled
module aksCluster 'aks-cluster.bicep' = {
  name: 'aks-cluster-deployment'
  params: {
    clusterName: aksClusterName
    location: location
    nodeCount: nodeCount
    vmSize: vmSize
    kubernetesVersion: kubernetesVersion
  }
}

// Create managed identities and Key Vault
module identityResources 'identity-resources.bicep' = {
  name: 'identity-resources-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    aksClusterName: aksClusterName
    aksOidcIssuerUrl: aksCluster.outputs.oidcIssuerUrl
  }
}

// Outputs
output aksClusterName string = aksCluster.outputs.clusterName
output aksClusterFqdn string = aksCluster.outputs.clusterFqdn
output aksOidcIssuerUrl string = aksCluster.outputs.oidcIssuerUrl
output keyVaultName string = identityResources.outputs.keyVaultName
output keyVaultUrl string = identityResources.outputs.keyVaultUrl
output managedIdentity1Name string = identityResources.outputs.managedIdentity1Name
output managedIdentity1ClientId string = identityResources.outputs.managedIdentity1ClientId
output managedIdentity1ResourceId string = identityResources.outputs.managedIdentity1ResourceId
output managedIdentity2Name string = identityResources.outputs.managedIdentity2Name
output managedIdentity2ClientId string = identityResources.outputs.managedIdentity2ClientId
output managedIdentity2ResourceId string = identityResources.outputs.managedIdentity2ResourceId
