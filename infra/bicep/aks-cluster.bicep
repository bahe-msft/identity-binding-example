@description('The name of the AKS cluster')
param clusterName string

@description('The location for the AKS cluster')
param location string

@description('The number of nodes in the cluster')
param nodeCount int = 2

@description('The size of the Virtual Machine')
param vmSize string = 'Standard_D4ds_v5'

@description('The version of Kubernetes')
param kubernetesVersion string = '1.32.0'

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-09-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    enableRBAC: true
    dnsPrefix: '${clusterName}-dns'

    // Enable workload identity and OIDC issuer (required for workload identity)
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }

    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: nodeCount
        vmSize: vmSize
        osType: 'Linux'
        mode: 'System'
        enableAutoScaling: true
        minCount: 1
        maxCount: 5
        maxPods: 30
        type: 'VirtualMachineScaleSets'
        upgradeSettings: {
          maxSurge: '1'
        }
      }
    ]

    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
    }

    // Auto upgrade
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
    }
  }
}

// Output the important values
output clusterName string = aksCluster.name
output clusterFqdn string = aksCluster.properties.fqdn
output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL
output clusterIdentityPrincipalId string = aksCluster.identity.principalId
