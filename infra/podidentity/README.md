# Pod Identity Installation Guide

This directory contains instructions and scripts for installing Azure AD Pod Identity in your AKS cluster.

## Prerequisites

- AKS cluster with RBAC enabled
- kubectl configured to access your cluster
- Helm 3.x installed

## Installation Methods

### Method 1: Using Helm (Recommended)

```bash
# Add the Azure AAD Pod Identity helm repository
helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts

# Update helm repositories
helm repo update

# Install AAD Pod Identity
helm install aad-pod-identity aad-pod-identity/aad-pod-identity --namespace kube-system
```

### Method 2: Using kubectl

```bash
# Apply the AAD Pod Identity deployment
kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
```

### Method 3: Using the provided script

Run the installation script in this directory:

```bash
./install-pod-identity.sh
```

## Verification

After installation, verify that the pods are running:

```bash
# Check that the pods are running
kubectl get pods -n kube-system | grep aad-pod-identity

# You should see output similar to:
# aad-pod-identity-mic-xxx   1/1     Running   0          2m
# aad-pod-identity-nmi-xxx   1/1     Running   0          2m
```

## Components

Pod Identity consists of two main components:

1. **MIC (Managed Identity Controller)**: Watches for pod/identity binding changes and updates Azure
2. **NMI (Node Managed Identity)**: Intercepts token requests and provides the appropriate identity

## Important Notes

- Pod Identity is considered legacy and Microsoft recommends using Workload Identity for new deployments
- Pod Identity requires the cluster to have the Azure VMSS (Virtual Machine Scale Set) identity configured
- Each node in the cluster will have an NMI pod running as a DaemonSet

## Next Steps

After installing Pod Identity:

1. Deploy your managed identities using the Bicep templates in `../bicep/`
2. Configure your applications using the deployment specs in `../apps/demo-app-pi/`

## Troubleshooting

If you encounter issues:

1. Check the MIC logs: `kubectl logs -n kube-system -l "app.kubernetes.io/component=mic"`
2. Check the NMI logs: `kubectl logs -n kube-system -l "app.kubernetes.io/component=nmi"`
3. Ensure your AKS cluster has the proper permissions to manage identities

## Uninstallation

To remove Pod Identity:

```bash
# If installed with Helm
helm uninstall aad-pod-identity --namespace kube-system

# If installed with kubectl
kubectl delete -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
```