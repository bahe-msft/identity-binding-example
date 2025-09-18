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
// MANUAL STEPS REQUIRED: Configure Pod Identity Prerequisites
// =====================================================================================
//
// Pod Identity requires three manual configuration steps after deployment:
//
// 1. MANAGED IDENTITY OPERATOR ROLE (REQUIRED FOR POD IDENTITY):
//    The AKS cluster's kubelet identity must have "Managed Identity Operator" role
//    over the node resource group. This allows Pod Identity components to manage
//    identity assignments on the VMSS.
//
//    This should be configured automatically if you're using the aks-cluster.bicep
//    template, which includes the pod-identity-rbac.bicep module. If not, run:
//
//    az role assignment create \
//      --assignee {clusterKubeletIdentityPrincipalId} \
//      --role "Managed Identity Operator" \
//      --scope "/subscriptions/{subscriptionId}/resourceGroups/{nodeResourceGroupName}"
//
// 2. READER ROLE (REQUIRED FOR POD IDENTITY):
//    The AKS cluster's kubelet identity must have "Reader" role over the resource
//    group containing the managed identities. This allows Pod Identity to read
//    managed identity metadata and validate identity assignments.
//
//    az role assignment create \
//      --assignee {clusterKubeletIdentityPrincipalId} \
//      --role "Reader" \
//      --scope "/subscriptions/{subscriptionId}/resourceGroups/{managedIdentityResourceGroupName}"
//
// 3. ASSIGN MANAGED IDENTITIES TO VMSS (REQUIRED FOR POD IDENTITY):
//    Pod Identity requires the managed identities to be assigned to the node pool VMSS.
//    This cannot be automated via Bicep and must be done manually after deployment.
//
//    Run the following Azure CLI commands after the infrastructure deployment completes:
//
//    a. Get the VMSS name in the node resource group:
//       VMSS_NAME=$(az vmss list --resource-group {nodeResourceGroupName} --query "[0].name" -o tsv)
//
//    b. Assign both managed identities to the VMSS:
//       az vmss identity assign \
//         --resource-group {nodeResourceGroupName} \
//         --name $VMSS_NAME \
//         --identities {managedIdentity1Id}
//
//       az vmss identity assign \
//         --resource-group {nodeResourceGroupName} \
//         --name $VMSS_NAME \
//         --identities {managedIdentity2Id}
//
//    c. Verify the assignment:
//       az vmss identity show \
//         --resource-group {nodeResourceGroupName} \
//         --name $VMSS_NAME
//
// Replace the placeholders with actual values:
// - {clusterKubeletIdentityPrincipalId}: Use the clusterIdentityPrincipalId output from aks-cluster deployment
// - {subscriptionId}: Your Azure subscription ID
// - {nodeResourceGroupName}: Use the nodeResourceGroupName output from aks-cluster deployment
// - {managedIdentityResourceGroupName}: The resource group where managed identities are deployed (usually same as main resource group)
// - {managedIdentity1Id}: Use the managedIdentity1ResourceId output from the main deployment
// - {managedIdentity2Id}: Use the managedIdentity2ResourceId output from the main deployment
//
// Note: If Pod Identity fails with permission errors, verify all three steps above are completed.
// =====================================================================================

// Outputs
output nodeResourceGroupName string = nodeResourceGroupName
output podIdentitySetupStatus string = 'MANUAL STEPS REQUIRED: 1) Verify kubelet identity has Managed Identity Operator role, 2) Verify kubelet identity has Reader role, 3) Assign managed identities to VMSS (see comments above)'
