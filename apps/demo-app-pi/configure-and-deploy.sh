#!/bin/bash

# Pod Identity Deployment Configuration Script
# This script helps configure the pod identity deployment with the correct values

set -e

echo "Pod Identity Deployment Configuration"
echo "====================================="

# Check if required environment variables are set
if [ -z "$MANAGED_IDENTITY_1_RESOURCE_ID" ]; then
    echo "Error: MANAGED_IDENTITY_1_RESOURCE_ID environment variable is not set"
    echo "Please set it to the resource ID of your first managed identity"
    echo "Example: export MANAGED_IDENTITY_1_RESOURCE_ID='/subscriptions/.../resourceGroups/.../providers/Microsoft.ManagedIdentity/userAssignedIdentities/...'"
    exit 1
fi

if [ -z "$MANAGED_IDENTITY_1_CLIENT_ID" ]; then
    echo "Error: MANAGED_IDENTITY_1_CLIENT_ID environment variable is not set"
    echo "Please set it to the client ID of your first managed identity"
    echo "Example: export MANAGED_IDENTITY_1_CLIENT_ID='12345678-1234-1234-1234-123456789abc'"
    exit 1
fi

if [ -z "$MANAGED_IDENTITY_2_CLIENT_ID" ]; then
    echo "Error: MANAGED_IDENTITY_2_CLIENT_ID environment variable is not set"
    echo "Please set it to the client ID of your second managed identity"
    echo "Example: export MANAGED_IDENTITY_2_CLIENT_ID='12345678-1234-1234-1234-123456789abc'"
    exit 1
fi

if [ -z "$KEYVAULT_URL" ]; then
    echo "Error: KEYVAULT_URL environment variable is not set"
    echo "Please set it to your Key Vault URL"
    echo "Example: export KEYVAULT_URL='https://your-keyvault.vault.azure.net/'"
    exit 1
fi

echo "Configuration values:"
echo "- Managed Identity 1 Resource ID: $MANAGED_IDENTITY_1_RESOURCE_ID"
echo "- Managed Identity 1 Client ID: $MANAGED_IDENTITY_1_CLIENT_ID"
echo "- Managed Identity 2 Client ID: $MANAGED_IDENTITY_2_CLIENT_ID"
echo "- Key Vault URL: $KEYVAULT_URL"
echo ""

# Create configured deployment file
echo "Generating configured deployment file..."

sed -e "s|\${MANAGED_IDENTITY_1_RESOURCE_ID}|$MANAGED_IDENTITY_1_RESOURCE_ID|g" \
    -e "s|\${MANAGED_IDENTITY_1_CLIENT_ID}|$MANAGED_IDENTITY_1_CLIENT_ID|g" \
    -e "s|\${MANAGED_IDENTITY_2_CLIENT_ID}|$MANAGED_IDENTITY_2_CLIENT_ID|g" \
    -e "s|\${KEYVAULT_URL}|$KEYVAULT_URL|g" \
    deployment.yaml > deployment-configured.yaml

echo "✅ Configured deployment file created: deployment-configured.yaml"
echo ""
echo "To deploy:"
echo "1. Make sure pod identity is installed in your cluster"
echo "2. Run: kubectl apply -f deployment-configured.yaml"
echo "3. Check status: kubectl get pods -l app=demo-app-pi -n demo-app-pi"
echo "4. View logs: kubectl logs -f -l app=demo-app-pi -n demo-app-pi"