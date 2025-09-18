# AKS Identity Binding Demo Project

This project demonstrates three different identity management approaches in Azure Kubernetes Service (AKS):

1. **Pod Identity** (Legacy approach) - deployed in `demo-app-pi` namespace
2. **Workload Identity** (Current recommended approach) - deployed in `demo-app-wi` namespace
3. **Identity Binding** (Newer simplified approach) - deployed in `demo-app-ib` namespace

All three approaches are demonstrated using the same Go application that fetches a secret from Azure Key Vault. Each demo runs in its own namespace to avoid conflicts and provide clear separation. **Each application demonstrates using multiple managed identities in a single pod**, which is a common real-world scenario.

## Project Structure

```
├── infra/
│   ├── bicep/                    # Infrastructure as Code
│   │   ├── main.bicep           # Main deployment template
│   │   ├── aks-cluster.bicep    # AKS cluster with workload identity
│   │   ├── identity-resources.bicep # Managed identities and Key Vault
│   │   └── main.parameters.json # Deployment parameters
│   └── podidentity/             # Pod Identity installation
│       ├── README.md            # Installation guide
│       └── install-pod-identity.sh # Installation script
├── apps/
│   ├── demo-app-go/             # Go application source code
│   │   ├── main.go              # Main application
│   │   ├── go.mod               # Go modules
│   │   ├── Dockerfile           # Container image
│   │   └── build-and-push.sh    # Build script for GHCR
│   ├── demo-app-pi/             # Pod Identity deployment (demo-app-pi namespace)
│   │   ├── deployment.yaml      # Kubernetes manifests with namespace
│   │   └── configure-and-deploy.sh # Configuration script
│   ├── demo-app-wi/             # Workload Identity deployment (demo-app-wi namespace)
│   │   ├── deployment.yaml      # Kubernetes manifests with namespace
│   │   └── configure-and-deploy.sh # Configuration script
│   └── demo-app-ib/             # Identity Binding deployment (demo-app-ib namespace)
│       ├── deployment.yaml      # Kubernetes manifests with namespace
│       └── configure-and-deploy.sh # Configuration script
└── README.md                    # This file
```

## Namespace Architecture

Each identity approach runs in its own dedicated namespace:

- **`demo-app-pi`**: Pod Identity demo with AAD Pod Identity components
- **`demo-app-wi`**: Workload Identity demo with service account annotations
- **`demo-app-ib`**: Identity Binding demo with IdentityBinding CRD

This separation provides:
- ✅ **Isolation**: No resource conflicts between different approaches
- ✅ **Clarity**: Easy to understand which resources belong to which demo
- ✅ **Concurrent Testing**: Run all three demos simultaneously
- ✅ **Clean Separation**: Independent cleanup and troubleshooting

## Prerequisites

- Azure CLI logged in and configured
- kubectl configured for your AKS cluster
- Helm 3.x installed
- Docker installed (for building the demo app)
- GitHub account (for container registry)

## Quick Start

### Step 1: Deploy Infrastructure

1. Navigate to the `infra/bicep` directory
2. Update parameters in `main.parameters.json` if needed
3. Deploy the infrastructure:

```bash
cd infra/bicep

# Create resource group
az group create --name ib-demo-rg --location "westus3"

# Deploy infrastructure
az deployment group create \
  --resource-group ib-demo-rg \
  --template-file main.bicep \
  --parameters @main.parameters.json
```

### Step 2: Build and Push Demo Application

1. Navigate to the `apps/demo-app-go` directory
2. Set your GitHub username:

```bash
export GITHUB_USERNAME="your-github-username"
```

3. Build and push the container:

```bash
cd apps/demo-app-go
./build-and-push.sh
```

### Step 3: Get Deployment Values

After infrastructure deployment, get the required values:

```bash
# Get resource group outputs
az deployment group show \
  --resource-group aks-identity-demo-rg \
  --name main \
  --query properties.outputs

# Get AKS credentials
az aks get-credentials \
  --resource-group aks-identity-demo-rg \
  --name <your-aks-cluster-name>
```

### Step 4: Deploy Demo Applications

You can deploy one, two, or all three demos. Each runs in its own namespace.

#### Option A: Pod Identity Demo (Legacy)

```bash
# Install Pod Identity first
cd infra/podidentity
./install-pod-identity.sh

# Configure and deploy the app in demo-app-pi namespace
cd ../../apps/demo-app-pi
export MANAGED_IDENTITY_1_RESOURCE_ID="..."
export MANAGED_IDENTITY_1_CLIENT_ID="..."
export KEYVAULT_URL="..."
export YOUR_GITHUB_USERNAME="..."
./configure-and-deploy.sh
```

#### Option B: Workload Identity Demo (Recommended)

```bash
# Deploy in demo-app-wi namespace
cd apps/demo-app-wi
export MANAGED_IDENTITY_2_CLIENT_ID="..."
export AZURE_TENANT_ID="..."
export KEYVAULT_URL="..."
export YOUR_GITHUB_USERNAME="..."
./configure-and-deploy.sh
```

#### Option C: Identity Binding Demo (Newest)

```bash
# Deploy in demo-app-ib namespace
cd apps/demo-app-ib
export MANAGED_IDENTITY_2_CLIENT_ID="..."
export MANAGED_IDENTITY_2_RESOURCE_ID="..."
export AKS_OIDC_ISSUER_URL="..."
export KEYVAULT_URL="..."
export YOUR_GITHUB_USERNAME="..."
./configure-and-deploy.sh
```

## Testing the Applications

Each application runs in its own namespace. You can test them by port-forwarding and accessing the endpoints:

### Pod Identity Demo (demo-app-pi namespace)
```bash
# Check deployment status
kubectl get pods -n demo-app-pi -l app=demo-app-pi

# Port forward to the service
kubectl port-forward service/demo-app-pi-service 8080:80 -n demo-app-pi

# Test endpoints (in another terminal)
curl http://localhost:8080/health              # Health check
curl http://localhost:8080/secret              # Fetch secret using first available identity
curl http://localhost:8080/secret?identity=identity-1  # Use first managed identity
curl http://localhost:8080/secret?identity=identity-2  # Use second managed identity
curl http://localhost:8080/identities          # List all available identities
curl http://localhost:8080/                    # Application info
```

### Workload Identity Demo (demo-app-wi namespace)
```bash
# Check deployment status
kubectl get pods -n demo-app-wi -l app=demo-app-wi

# Port forward to the service
kubectl port-forward service/demo-app-wi-service 8080:80 -n demo-app-wi

# Test endpoints (in another terminal)
curl http://localhost:8080/health              # Health check
curl http://localhost:8080/secret              # Fetch secret using first available identity
curl http://localhost:8080/secret?identity=identity-1  # Use first managed identity
curl http://localhost:8080/secret?identity=identity-2  # Use second managed identity
curl http://localhost:8080/identities          # List all available identities
curl http://localhost:8080/                    # Application info
```

### Identity Binding Demo (demo-app-ib namespace)
```bash
# Check deployment status
kubectl get pods -n demo-app-ib -l app=demo-app-ib

# Check identity binding
kubectl get identitybinding -n demo-app-ib

# Port forward to the service
kubectl port-forward service/demo-app-ib-service 8080:80 -n demo-app-ib

# Test endpoints (in another terminal)
curl http://localhost:8080/health              # Health check
curl http://localhost:8080/secret              # Fetch secret using first available identity
curl http://localhost:8080/secret?identity=identity-1  # Use first managed identity
curl http://localhost:8080/secret?identity=identity-2  # Use second managed identity
curl http://localhost:8080/identities          # List all available identities
curl http://localhost:8080/                    # Application info
```

## Key Differences

### Pod Identity (demo-app-pi namespace)
- **Status**: Legacy approach (deprecated)
- **Components**: Requires additional components (MIC/NMI)
- **Configuration**: Uses `AzureIdentity` and `AzureIdentityBinding` CRDs
- **Permissions**: Requires cluster-level permissions
- **Setup Complexity**: Most complex setup
- **Use Case**: Legacy applications, migration scenarios

### Workload Identity (demo-app-wi namespace)
- **Status**: Current recommended approach
- **Components**: Built into AKS, no additional components needed
- **Configuration**: Uses service account annotations and federated identity credentials
- **Security**: More secure and lightweight
- **Setup Complexity**: Moderate setup
- **Use Case**: New applications, production workloads

### Identity Binding (demo-app-ib namespace)
- **Status**: Newest approach (Preview/Experimental)
- **Components**: Uses IdentityBinding CRD controller
- **Configuration**: Completely automated - no FICs, no service account annotations, no volume mounts
- **Automation**: Automatically creates and manages federated credentials, environment variables, and token volumes
- **Setup Complexity**: Simplest setup (just create IdentityBinding CRD)
- **Use Case**: Future applications, simplified management, maximum automation

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    AKS Cluster                                  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  demo-app-pi    │  │  demo-app-wi    │  │  demo-app-ib    │ │
│  │   namespace     │  │   namespace     │  │   namespace     │ │
│  │                 │  │                 │  │                 │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │ Pod Identity│ │  │ │  Workload   │ │  │ │  Identity   │ │ │
│  │ │    Demo     │ │  │ │  Identity   │ │  │ │  Binding    │ │ │
│  │ │    App      │ │  │ │    Demo     │ │  │ │    Demo     │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │   Managed Identities    │
                    │                         │
                    │  • MI 1 (Pod Identity)  │
                    │  • MI 2 (WI + IB)      │
                    └─────────────────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │    Azure Key Vault      │
                    │                         │
                    │   • demo-secret         │
                    │   • RBAC permissions    │
                    └─────────────────────────┘
```

### Managed Identity Usage

- **MI 1 (`${namePrefix}-mi-podidentity`)**: Used by all three demos to demonstrate multiple identity scenarios
  - **Pod Identity**: Assigned to VMSS (no FICs needed)
  - **Workload Identity**: Has FIC for `demo-app-wi:workload-identity-sa`
  - **Identity Binding**: No manual FICs (managed automatically by Identity Binding controller)

- **MI 2 (`${namePrefix}-mi-workloadidentity`)**: Used by all three demos to demonstrate multiple identity scenarios
  - **Pod Identity**: Assigned to VMSS (no FICs needed)
  - **Workload Identity**: Has FIC for `demo-app-wi:workload-identity-sa` (primary identity)
  - **Identity Binding**: No manual FICs (managed automatically by Identity Binding controller, primary identity)

### Infrastructure Setup

#### **For Pod Identity**:
- ✅ **VMSS Assignment**: Both managed identities are automatically assigned to the AKS node pool VMSS
- ✅ **Pod Identity Components**: MIC (Managed Identity Controller) and NMI (Node Managed Identity)
- ❌ **No FICs**: Pod Identity uses its own authentication mechanism

#### **For Workload Identity**:
- ✅ **Federated Identity Credentials**: 2 FICs total (1 per managed identity)
- ✅ **OIDC Integration**: Uses AKS OIDC issuer for token exchange
- ✅ **Manual Configuration**: Service account annotations and volume mounts
- ❌ **No VMSS Assignment**: Not needed for workload identity

#### **For Identity Binding**:
- ✅ **Automatic FIC Management**: Identity Binding controller creates and manages FICs automatically
- ✅ **OIDC Integration**: Uses AKS OIDC issuer for token exchange (same as workload identity)
- ✅ **Simplified Configuration**: Just the IdentityBinding CRD, no manual setup
- ❌ **No VMSS Assignment**: Not needed for identity binding

**Key Feature**: Each demo demonstrates the real-world scenario of using multiple managed identities within a single pod, allowing applications to access different Azure resources with different identities as needed.

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure managed identities have proper Key Vault permissions
2. **Token Exchange Errors**: Verify OIDC issuer URL and federated identity credentials
3. **Pod Startup Issues**: Check image availability and environment variables
4. **Namespace Issues**: Ensure you're using the correct namespace in kubectl commands

### Useful Commands

```bash
# Check all demo namespaces
kubectl get namespaces | grep demo-app

# Check pod logs (specify namespace)
kubectl logs <pod-name> -n <namespace>

# Check service account annotations
kubectl describe serviceaccount <sa-name> -n <namespace>

# Check identity binding status (for identity binding demo)
kubectl get identitybinding -n demo-app-ib

# Test token acquisition
kubectl exec <pod-name> -n <namespace> -- env | grep AZURE

# View all resources in a namespace
kubectl get all -n demo-app-pi
kubectl get all -n demo-app-wi
kubectl get all -n demo-app-ib
```

### Debugging by Demo Type

#### Pod Identity Issues
```bash
# Check MIC and NMI pods
kubectl get pods -n kube-system | grep aad-pod-identity

# Check MIC logs
kubectl logs -n kube-system -l "app.kubernetes.io/component=mic"

# Check NMI logs
kubectl logs -n kube-system -l "app.kubernetes.io/component=nmi"

# Check Azure Identity and Binding
kubectl get azureidentity -n demo-app-pi
kubectl get azureidentitybinding -n demo-app-pi
```

#### Workload Identity Issues
```bash
# Check service account annotations
kubectl describe sa workload-identity-sa -n demo-app-wi

# Check federated identity credentials in Azure
az identity federated-credential list --identity-name <identity-name> --resource-group <rg-name>

# Verify OIDC issuer
kubectl get --raw /.well-known/openid_configuration | jq .
```

#### Identity Binding Issues
```bash
# Check identity binding resource
kubectl describe identitybinding demo-app-identity-binding -n demo-app-ib

# Check if Identity Binding controller is running
kubectl get pods -A | grep identity-binding
```

## Cleanup

### Clean Up Individual Demos

```bash
# Clean up Pod Identity demo
kubectl delete namespace demo-app-pi

# Clean up Workload Identity demo
kubectl delete namespace demo-app-wi

# Clean up Identity Binding demo
kubectl delete namespace demo-app-ib
```

### Clean Up Everything

```bash
# Delete all demo namespaces
kubectl delete namespace demo-app-pi demo-app-wi demo-app-ib

# Uninstall Pod Identity (if installed)
helm uninstall aad-pod-identity --namespace kube-system

# Delete Azure resources
az group delete --name aks-identity-demo-rg --yes --no-wait
```

## Environment Variables Reference

### Pod Identity Demo
- `MANAGED_IDENTITY_1_RESOURCE_ID`: Resource ID of the first managed identity (MI 1)
- `MANAGED_IDENTITY_1_CLIENT_ID`: Client ID of the first managed identity (MI 1)
- `MANAGED_IDENTITY_2_CLIENT_ID`: Client ID of the second managed identity (MI 2)
- `KEYVAULT_URL`: Azure Key Vault URL
- `YOUR_GITHUB_USERNAME`: GitHub username for container image

### Workload Identity Demo
- `MANAGED_IDENTITY_1_CLIENT_ID`: Client ID of the first managed identity (MI 1)
- `MANAGED_IDENTITY_2_CLIENT_ID`: Client ID of the second managed identity (MI 2)
- `AZURE_TENANT_ID`: Azure tenant ID
- `KEYVAULT_URL`: Azure Key Vault URL
- `YOUR_GITHUB_USERNAME`: GitHub username for container image

### Identity Binding Demo
- `MANAGED_IDENTITY_1_CLIENT_ID`: Client ID of the first managed identity (MI 1)
- `MANAGED_IDENTITY_2_CLIENT_ID`: Client ID of the second managed identity (MI 2)
- `MANAGED_IDENTITY_2_RESOURCE_ID`: Resource ID of the second managed identity (MI 2 - for IdentityBinding resource)
- `AKS_OIDC_ISSUER_URL`: AKS cluster OIDC issuer URL
- `KEYVAULT_URL`: Azure Key Vault URL
- `YOUR_GITHUB_USERNAME`: GitHub username for container image

> **Note**: All demos use both managed identities to demonstrate multiple identity scenarios. The applications can switch between identities using the `?identity=identity-1` or `?identity=identity-2` query parameters.

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License - see the LICENSE file for details.