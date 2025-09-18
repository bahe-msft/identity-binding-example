#!/bin/bash

# Workload Identity Deployment Configuration Script
# This script helps configure the workload identity deployment with the correct values

set -e

echo "Workload Identity Deployment Configuration"
echo "=========================================="

# Check if required environment variables are set
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

if [ -z "$AZURE_TENANT_ID" ]; then
    echo "Error: AZURE_TENANT_ID environment variable is not set"
    echo "Please set it to your Azure tenant ID"
    echo "Example: export AZURE_TENANT_ID='12345678-1234-1234-1234-123456789abc'"
    exit 1
fi

if [ -z "$KEYVAULT_URL" ]; then
    echo "Error: KEYVAULT_URL environment variable is not set"
    echo "Please set it to your Key Vault URL"
    echo "Example: export KEYVAULT_URL='https://your-keyvault.vault.azure.net/'"
    exit 1
fi

echo "Configuration values:"
echo "- Managed Identity 1 Client ID: $MANAGED_IDENTITY_1_CLIENT_ID"
echo "- Managed Identity 2 Client ID: $MANAGED_IDENTITY_2_CLIENT_ID"
echo "- Azure Tenant ID: $AZURE_TENANT_ID"
echo "- Key Vault URL: $KEYVAULT_URL"
echo ""

# Create configured deployment file
echo "Generating configured deployment file..."

sed -e "s|\${MANAGED_IDENTITY_1_CLIENT_ID}|$MANAGED_IDENTITY_1_CLIENT_ID|g" \
    -e "s|\${MANAGED_IDENTITY_2_CLIENT_ID}|$MANAGED_IDENTITY_2_CLIENT_ID|g" \
    -e "s|\${AZURE_TENANT_ID}|$AZURE_TENANT_ID|g" \
    -e "s|\${KEYVAULT_URL}|$KEYVAULT_URL|g" \
    deployment.yaml > deployment-configured.yaml

echo "✅ Configured deployment file created: deployment-configured.yaml"
echo ""
echo "To deploy:"
echo "1. Make sure workload identity is enabled in your AKS cluster"
echo "2. Make sure the federated identity credential is configured for this service account"
echo "3. Run: kubectl apply -f deployment-configured.yaml"
echo "4. Check status: kubectl get pods -l app=demo-app-wi -n demo-app-wi"
echo "5. View logs: kubectl logs -f -l app=demo-app-wi -n demo-app-wi"
echo ""
echo "Note: The federated identity credential should be configured with:"
echo "- Issuer: Your AKS OIDC issuer URL"
echo "- Subject: system:serviceaccount:demo-app-wi:workload-identity-sa"
echo "- Audience: api://AzureADTokenExchange"