@description('The location for all resources')
param location string

@description('The AKS cluster name')
param aksClusterName string

@description('The resource ID of the first managed identity')
param managedIdentity1Id string

@description('The resource ID of the second managed identity')
param managedIdentity2Id string

// Assign managed identities to the AKS VMSS for Pod Identity
// This is required for Pod Identity to work - the identities must be assigned to the node pool VMSS

// Get the AKS cluster to access its node resource group
resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-09-01' existing = {
  name: aksClusterName
}

// Get the node resource group name (where the VMSS is located)
var nodeResourceGroupName = aksCluster.properties.nodeResourceGroup

// Use a deployment script to assign identities to VMSS since Bicep doesn't directly support VMSS identity assignment
resource vmssIdentityAssignment 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'vmss-identity-assignment'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.50.0'
    timeout: 'PT30M'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'NODE_RESOURCE_GROUP'
        value: nodeResourceGroupName
      }
      {
        name: 'MANAGED_IDENTITY_1_ID'
        value: managedIdentity1Id
      }
      {
        name: 'MANAGED_IDENTITY_2_ID'
        value: managedIdentity2Id
      }
      {
        name: 'AKS_CLUSTER_NAME'
        value: aksClusterName
      }
    ]
    scriptContent: '''
      echo "Starting VMSS identity assignment for Pod Identity..."
      
      # Get the VMSS name in the node resource group
      VMSS_NAME=$(az vmss list --resource-group $NODE_RESOURCE_GROUP --query "[0].name" -o tsv)
      
      if [ -z "$VMSS_NAME" ]; then
        echo "Error: No VMSS found in resource group $NODE_RESOURCE_GROUP"
        exit 1
      fi
      
      echo "Found VMSS: $VMSS_NAME in resource group: $NODE_RESOURCE_GROUP"
      
      # Assign both managed identities to the VMSS
      echo "Assigning managed identity 1 to VMSS..."
      az vmss identity assign \
        --resource-group $NODE_RESOURCE_GROUP \
        --name $VMSS_NAME \
        --identities $MANAGED_IDENTITY_1_ID
      
      echo "Assigning managed identity 2 to VMSS..."
      az vmss identity assign \
        --resource-group $NODE_RESOURCE_GROUP \
        --name $VMSS_NAME \
        --identities $MANAGED_IDENTITY_2_ID
      
      echo "Successfully assigned both managed identities to VMSS $VMSS_NAME"
      
      # Verify the assignment
      echo "Verifying identity assignments..."
      az vmss identity show \
        --resource-group $NODE_RESOURCE_GROUP \
        --name $VMSS_NAME
    '''
  }
}

// Outputs
output nodeResourceGroupName string = nodeResourceGroupName
output vmssIdentityAssignmentStatus string = 'Managed identities assigned to VMSS for Pod Identity support'