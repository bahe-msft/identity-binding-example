#!/bin/bash

# Azure AD Pod Identity Installation Script
# This script installs Azure AD Pod Identity in your AKS cluster

set -e

echo "Azure AD Pod Identity Installation"
echo "=================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "Error: helm is not installed or not in PATH"
    echo "Please install Helm 3.x: https://helm.sh/docs/intro/install/"
    exit 1
fi

# Check if connected to a cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Unable to connect to Kubernetes cluster"
    echo "Please ensure kubectl is configured correctly"
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Get cluster info
CLUSTER_NAME=$(kubectl config current-context)
echo "Installing Pod Identity on cluster: $CLUSTER_NAME"
echo ""

# Ask for confirmation
read -p "Do you want to proceed with the installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled"
    exit 0
fi

echo "Adding Azure AAD Pod Identity Helm repository..."
helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts

echo "Updating Helm repositories..."
helm repo update

echo "Installing Azure AD Pod Identity..."
helm install aad-pod-identity aad-pod-identity/aad-pod-identity --namespace kube-system --create-namespace

echo ""
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=aad-pod-identity" -n kube-system --timeout=300s

echo ""
echo "✅ Installation completed successfully!"
echo ""

# Show the running pods
echo "Pod Identity components running:"
kubectl get pods -n kube-system -l "app.kubernetes.io/name=aad-pod-identity"

echo ""
echo "Installation Summary:"
echo "- MIC (Managed Identity Controller): Manages identity assignments"
echo "- NMI (Node Managed Identity): Handles token requests on each node"
echo ""
echo "Next steps:"
echo "1. Deploy your infrastructure using the Bicep templates"
echo "2. Configure your applications to use Pod Identity"
echo "3. Test the setup with the demo applications"
echo ""
echo "For troubleshooting, check the logs with:"
echo "  kubectl logs -n kube-system -l \"app.kubernetes.io/component=mic\""
echo "  kubectl logs -n kube-system -l \"app.kubernetes.io/component=nmi\""