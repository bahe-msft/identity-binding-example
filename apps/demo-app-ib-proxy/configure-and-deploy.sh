#!/bin/bash

# Identity Binding Proxy Mode Deployment Configuration Script
# This script helps configure the identity binding proxy deployment with the correct values
# The proxy mode demonstrates the migration sidecar for applications using IMDS with identity binding

set -e

echo "Identity Binding Proxy Mode Deployment Configuration"
echo "=================================================="

# Check if resource group is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <resource-group-name>"
    echo "Example: $0 ib-demo-rg"
    exit 1
fi

RESOURCE_GROUP="$1"

echo "Resource Group: $RESOURCE_GROUP"
echo ""
echo "Retrieving Azure resources..."

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo "Error: Resource group '$RESOURCE_GROUP' not found"
    exit 1
fi

# Get managed identities
echo "- Finding managed identities..."
MANAGED_IDENTITIES=$(az identity list --resource-group "$RESOURCE_GROUP" --query "[].{name:name,clientId:clientId,resourceId:id}" -o json)

if [ "$(echo "$MANAGED_IDENTITIES" | jq length)" -lt 2 ]; then
    echo "Error: Expected at least 2 managed identities in resource group '$RESOURCE_GROUP'"
    echo "Found: $(echo "$MANAGED_IDENTITIES" | jq length)"
    exit 1
fi

# Get the first two managed identities (sorted by name)
MANAGED_IDENTITY_1_CLIENT_ID=$(echo "$MANAGED_IDENTITIES" | jq -r 'sort_by(.name)[0].clientId')
MANAGED_IDENTITY_2_CLIENT_ID=$(echo "$MANAGED_IDENTITIES" | jq -r 'sort_by(.name)[1].clientId')

# Get Key Vault
echo "- Finding Key Vault..."
KEYVAULT_NAME=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)

if [ -z "$KEYVAULT_NAME" ]; then
    echo "Error: No Key Vault found in resource group '$RESOURCE_GROUP'"
    exit 1
fi

KEYVAULT_URL=$(az keyvault show --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP" --query "properties.vaultUri" -o tsv)

# Get AKS cluster and OIDC issuer URL
echo "- Finding AKS cluster..."
AKS_CLUSTER_NAME=$(az aks list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)

if [ -z "$AKS_CLUSTER_NAME" ]; then
    echo "Error: No AKS cluster found in resource group '$RESOURCE_GROUP'"
    exit 1
fi

AKS_OIDC_ISSUER_URL=$(az aks show --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --query "oidcIssuerProfile.issuerUrl" -o tsv)

if [ -z "$AKS_OIDC_ISSUER_URL" ]; then
    echo "Error: AKS cluster '$AKS_CLUSTER_NAME' does not have OIDC issuer enabled"
    exit 1
fi

echo ""
echo "Configuration values:"
echo "- Managed Identity 1 Client ID: $MANAGED_IDENTITY_1_CLIENT_ID"
echo "- Managed Identity 2 Client ID: $MANAGED_IDENTITY_2_CLIENT_ID"
echo "- AKS OIDC Issuer URL: $AKS_OIDC_ISSUER_URL"
echo "- Key Vault URL: $KEYVAULT_URL"
echo ""

# Create configured deployment file
echo "Generating configured deployment file..."

sed -e "s|\${MANAGED_IDENTITY_1_CLIENT_ID}|$MANAGED_IDENTITY_1_CLIENT_ID|g" \
    -e "s|\${MANAGED_IDENTITY_2_CLIENT_ID}|$MANAGED_IDENTITY_2_CLIENT_ID|g" \
    -e "s|\${AKS_OIDC_ISSUER_URL}|$AKS_OIDC_ISSUER_URL|g" \
    -e "s|\${KEYVAULT_URL}|$KEYVAULT_URL|g" \
    deployment.yaml > deployment-configured.yaml

echo "✅ Configured deployment file created: deployment-configured.yaml"
echo ""

# Get kubeconfig to local file (AKS_CLUSTER_NAME already retrieved above)
KUBECONFIG_FILE="./kubeconfig-${RESOURCE_GROUP}-${AKS_CLUSTER_NAME}"
echo "Getting AKS cluster credentials..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER_NAME" --file "$KUBECONFIG_FILE" --overwrite-existing

echo "✅ Kubeconfig saved to: $KUBECONFIG_FILE"
echo ""

# Deploy the application
echo "Deploying Identity Binding Proxy Mode demo application..."
export KUBECONFIG="$KUBECONFIG_FILE"

kubectl apply -f deployment-configured.yaml

echo ""
echo "✅ Identity Binding Proxy Mode demo deployed successfully!"
echo ""
echo "📋 Important Notes:"
echo "- This deployment uses the migration sidecar with identity binding"
echo "- The sidecar provides backward compatibility while using identity binding RBAC"
echo "- For production use, migrate your application to use Azure Identity SDKs with client assertion"
echo "- The migration sidecar is only supported on Linux containers"
echo ""
echo "To monitor the deployment:"
echo "1. Check status: KUBECONFIG=$KUBECONFIG_FILE kubectl get pods -l app=demo-app-ib-proxy -n demo-app-ib"
echo "2. Check cluster role: KUBECONFIG=$KUBECONFIG_FILE kubectl get clusterrole identity-binding-role"
echo "3. Check cluster role binding: KUBECONFIG=$KUBECONFIG_FILE kubectl get clusterrolebinding identity-binding-role-binding"
echo "4. View logs: KUBECONFIG=$KUBECONFIG_FILE kubectl logs -f -l app=demo-app-ib-proxy -n demo-app-ib"
echo "5. Check sidecar injection: KUBECONFIG=$KUBECONFIG_FILE kubectl describe pod -l app=demo-app-ib-proxy -n demo-app-ib"
echo ""
echo "Note: Identity Binding with proxy mode uses ClusterRole and ClusterRoleBinding"
echo "to grant the service account permission to use the specified managed identity"
echo "while providing IMDS compatibility through the migration sidecar."