@description('The location for all resources')
param location string

@description('The AKS cluster name')
param aksClusterName string

@description('The resource ID of the first managed identity')
param managedIdentity1Id string

@description('The resource ID of the second managed identity')
param managedIdentity2Id string

// Get the AKS cluster to access its node resource group
resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-09-01' existing = {
  name: aksClusterName
}

// Get the node resource group name (where the VMSS is located)
var nodeResourceGroupName = aksCluster.properties.nodeResourceGroup

// =====================================================================================
// MANUAL STEP REQUIRED: Assign managed identities to the AKS node pool VMSS
// =====================================================================================
// 
// Pod Identity requires the managed identities to be assigned to the node pool VMSS.
// This cannot be automated via Bicep and must be done manually after deployment.
//
// Run the following Azure CLI commands after the infrastructure deployment completes:
//
// 1. Get the VMSS name in the node resource group:
//    VMSS_NAME=$(az vmss list --resource-group {nodeResourceGroupName} --query "[0].name" -o tsv)
//
// 2. Assign both managed identities to the VMSS:
//    az vmss identity assign \
//      --resource-group {nodeResourceGroupName} \
//      --name $VMSS_NAME \
//      --identities {managedIdentity1Id}
//
//    az vmss identity assign \
//      --resource-group {nodeResourceGroupName} \
//      --name $VMSS_NAME \
//      --identities {managedIdentity2Id}
//
// 3. Verify the assignment:
//    az vmss identity show \
//      --resource-group {nodeResourceGroupName} \
//      --name $VMSS_NAME
//
// Replace the placeholders with actual values:
// - {nodeResourceGroupName}: Use the nodeResourceGroupName output from this deployment
// - {managedIdentity1Id}: Use the managedIdentity1ResourceId output from the main deployment
// - {managedIdentity2Id}: Use the managedIdentity2ResourceId output from the main deployment
// =====================================================================================

// Outputs
output nodeResourceGroupName string = nodeResourceGroupName
output vmssIdentityAssignmentStatus string = 'MANUAL STEP REQUIRED: Assign managed identities to VMSS for Pod Identity support (see comments above)'