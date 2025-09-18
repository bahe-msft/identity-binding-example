#!/bin/bash

# Pod Identity Deployment Configuration Script
# This script helps configure the pod identity deployment with the correct values

set -e

echo "Pod Identity Deployment Configuration"
echo "====================================="

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
MANAGED_IDENTITY_1_RESOURCE_ID=$(echo "$MANAGED_IDENTITIES" | jq -r 'sort_by(.name)[0].resourceId')
MANAGED_IDENTITY_2_CLIENT_ID=$(echo "$MANAGED_IDENTITIES" | jq -r 'sort_by(.name)[1].clientId')
MANAGED_IDENTITY_2_RESOURCE_ID=$(echo "$MANAGED_IDENTITIES" | jq -r 'sort_by(.name)[1].resourceId')

# Get Key Vault
echo "- Finding Key Vault..."
KEYVAULT_NAME=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)

if [ -z "$KEYVAULT_NAME" ]; then
    echo "Error: No Key Vault found in resource group '$RESOURCE_GROUP'"
    exit 1
fi

KEYVAULT_URL=$(az keyvault show --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP" --query "properties.vaultUri" -o tsv)

echo ""
echo "Configuration values:"
echo "- Managed Identity 1 Resource ID: $MANAGED_IDENTITY_1_RESOURCE_ID"
echo "- Managed Identity 1 Client ID: $MANAGED_IDENTITY_1_CLIENT_ID"
echo "- Managed Identity 2 Resource ID: $MANAGED_IDENTITY_2_RESOURCE_ID"
echo "- Managed Identity 2 Client ID: $MANAGED_IDENTITY_2_CLIENT_ID"
echo "- Key Vault URL: $KEYVAULT_URL"
echo ""

# Create configured deployment file
echo "Generating configured deployment file..."

sed -e "s|\${MANAGED_IDENTITY_1_RESOURCE_ID}|$MANAGED_IDENTITY_1_RESOURCE_ID|g" \
    -e "s|\${MANAGED_IDENTITY_1_CLIENT_ID}|$MANAGED_IDENTITY_1_CLIENT_ID|g" \
    -e "s|\${MANAGED_IDENTITY_2_RESOURCE_ID}|$MANAGED_IDENTITY_2_RESOURCE_ID|g" \
    -e "s|\${MANAGED_IDENTITY_2_CLIENT_ID}|$MANAGED_IDENTITY_2_CLIENT_ID|g" \
    -e "s|\${KEYVAULT_URL}|$KEYVAULT_URL|g" \
    deployment.yaml > deployment-configured.yaml

echo "✅ Configured deployment file created: deployment-configured.yaml"
echo ""

# Get AKS cluster for kubeconfig
echo "Getting AKS cluster credentials..."
AKS_CLUSTER_NAME=$(az aks list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)

if [ -z "$AKS_CLUSTER_NAME" ]; then
    echo "Error: No AKS cluster found in resource group '$RESOURCE_GROUP'"
    exit 1
fi

# Get kubeconfig to local file
KUBECONFIG_FILE="./kubeconfig-${RESOURCE_GROUP}-${AKS_CLUSTER_NAME}"
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER_NAME" --file "$KUBECONFIG_FILE" --overwrite-existing

echo "✅ Kubeconfig saved to: $KUBECONFIG_FILE"
echo ""

# Deploy the application
echo "Deploying Pod Identity demo application..."
export KUBECONFIG="$KUBECONFIG_FILE"

kubectl apply -f deployment-configured.yaml

echo ""
echo "✅ Pod Identity demo deployed successfully!"
echo ""
echo "To monitor the deployment:"
echo "1. Check status: KUBECONFIG=$KUBECONFIG_FILE kubectl get pods -l app=demo-app-pi -n demo-app-pi"
echo "2. View logs: KUBECONFIG=$KUBECONFIG_FILE kubectl logs -f -l app=demo-app-pi -n demo-app-pi"
echo ""
echo "Note: Make sure pod identity is installed in your cluster before the pods will start successfully."