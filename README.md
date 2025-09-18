# AKS Identity Binding Demo

This project demonstrates three different identity management approaches in Azure Kubernetes Service (AKS):

1. **Pod Identity** (Legacy approach) - deployed in `demo-app-pi` namespace
2. **Workload Identity** (Current recommended approach) - deployed in `demo-app-wi` namespace
3. **Identity Binding** (Newer simplified approach) - deployed in `demo-app-ib` namespace

All three approaches are demonstrated using the same Go application that fetches a secret from Azure Key Vault. Each demo runs in its own namespace to avoid conflicts and provide clear separation. **Each application demonstrates using multiple managed identities in a single pod**, which is a common real-world scenario.

## Prerequisites

- Azure CLI logged in and configured
- kubectl configured for your AKS cluster
- Helm 3.x installed
- jq installed (for parsing JSON in scripts)

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

### Step 2: Install Pod Identity (Optional)

Only needed if you want to test the Pod Identity demo:

```bash
cd infra/podidentity
./install-pod-identity.sh ib-demo-rg
```

### Step 3: Deploy Demo Applications

Each demo uses automated scripts that discover Azure resources from the resource group. Simply provide the resource group name:

#### Option A: Pod Identity Demo (Legacy)

```bash
cd apps/demo-app-pi
./configure-and-deploy.sh ib-demo-rg
```

**Important**: Pod Identity requires manual VMSS assignment. The script will provide the exact commands needed.

#### Option B: Workload Identity Demo (Recommended)

```bash
cd apps/demo-app-wi
./configure-and-deploy.sh ib-demo-rg
```

#### Option C: Identity Binding Demo (Newest)

```bash
cd apps/demo-app-ib
./configure-and-deploy.sh ib-demo-rg
```

## Testing the Applications

Each application runs as a background polling service that fetches secrets from Azure Key Vault every 30 seconds using multiple managed identities. You can test them by checking the logs:

### Pod Identity Demo (demo-app-pi namespace)
```bash
# Check deployment status
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl get pods -n demo-app-pi -l app=demo-app-pi

# View application logs
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl logs -f -l app=demo-app-pi -n demo-app-pi

# Expected output:
# === Iteration at 2024-01-15 10:30:00 ===
# [pod-identity] retrieved secret content "Hello from Azure Key Vault! This is a demo secret." from akv using mi client id "abc123..."
# [pod-identity] retrieved secret content "Hello from Azure Key Vault! This is a demo secret." from akv using mi client id "def456..."
```

### Workload Identity Demo (demo-app-wi namespace)
```bash
# Check deployment status
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl get pods -n demo-app-wi -l app=demo-app-wi

# View application logs
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl logs -f -l app=demo-app-wi -n demo-app-wi

# Expected output:
# === Iteration at 2024-01-15 10:30:00 ===
# [workload-identity] retrieved secret content "Hello from Azure Key Vault! This is a demo secret." from akv using mi client id "abc123..."
# [workload-identity] retrieved secret content "Hello from Azure Key Vault! This is a demo secret." from akv using mi client id "def456..."
```

### Identity Binding Demo (demo-app-ib namespace)
```bash
# Check deployment status
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl get pods -n demo-app-ib -l app=demo-app-ib

# Check ClusterRole and ClusterRoleBinding status
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl get clusterrole identity-binding-role
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl get clusterrolebinding identity-binding-role-binding

# View application logs
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl logs -f -l app=demo-app-ib -n demo-app-ib

# Expected output:
# === Iteration at 2024-01-15 10:30:00 ===
# [identity-binding] retrieved secret content "Hello from Azure Key Vault! This is a demo secret." from akv using mi client id "abc123..."
# [identity-binding] retrieved secret content "Hello from Azure Key Vault! This is a demo secret." from akv using mi client id "def456..."
```
## Key Differences

### Pod Identity (demo-app-pi namespace)
- **Status**: Legacy approach (deprecated)
- **Components**: Requires additional components (MIC/NMI) via Helm installation
- **Configuration**: Uses `AzureIdentity` and `AzureIdentityBinding` CRDs (2 of each for dual identity support)
- **RBAC Requirements**:
  - Managed Identity Operator role over node resource group
  - Reader role over managed identity resource group
  - Manual VMSS identity assignment
- **Setup Complexity**: Most complex setup with manual RBAC and VMSS steps
- **Use Case**: Legacy applications, migration scenarios

### Workload Identity (demo-app-wi namespace)
- **Status**: Current recommended approach
- **Components**: Built into AKS, no additional components needed
- **Configuration**: Uses service account annotations and federated identity credentials
- **RBAC Requirements**: Federated Identity Credentials (FICs) automatically created by Bicep
- **Security**: More secure and lightweight than Pod Identity
- **Setup Complexity**: Moderate setup with automated FIC management
- **Use Case**: New applications, production workloads

### Identity Binding (demo-app-ib namespace)
- **Status**: Newest approach using standard Kubernetes RBAC
- **Components**: Uses ClusterRole and ClusterRoleBinding (no custom controllers)
- **Configuration**: Standard Kubernetes RBAC with `use-managed-identity` verb
- **RBAC Requirements**: ClusterRole grants access to both managed identity client IDs
- **Automation**: Simplified approach using native Kubernetes permissions
- **Setup Complexity**: Simplest RBAC-based setup
- **Use Case**: Future applications, simplified management, standard Kubernetes patterns

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
                    │  • mi-1 (All demos)     │
                    │  • mi-2 (All demos)     │
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

- **MI 1 (`${namePrefix}-mi-1`)**: Used by all three demos to demonstrate multiple identity scenarios
  - **Pod Identity**: Assigned to VMSS (manual step required)
  - **Workload Identity**: Has FIC for `demo-app-wi:workload-identity-sa`
  - **Identity Binding**: Uses ClusterRole permissions

- **MI 2 (`${namePrefix}-mi-2`)**: Used by all three demos to demonstrate multiple identity scenarios
  - **Pod Identity**: Assigned to VMSS (manual step required)
  - **Workload Identity**: Has FIC for `demo-app-wi:workload-identity-sa` (primary identity)
  - **Identity Binding**: Uses ClusterRole permissions (primary identity)

### Infrastructure Setup

#### **For Pod Identity**:
- ✅ **RBAC Setup**: Kubelet identity automatically granted Managed Identity Operator role (via Bicep)
- ⚠️ **Manual VMSS Assignment**: Both managed identities must be manually assigned to AKS node pool VMSS
- ✅ **Pod Identity Components**: MIC and NMI installed via Helm
- ✅ **Dual AzureIdentity Resources**: Creates 2 AzureIdentity and 2 AzureIdentityBinding resources
- ❌ **No FICs**: Pod Identity uses its own authentication mechanism

#### **For Workload Identity**:
- ✅ **Federated Identity Credentials**: 2 FICs total (1 per managed identity) automatically created via Bicep
- ✅ **OIDC Integration**: Uses AKS OIDC issuer for token exchange
- ✅ **Service Account Configuration**: Automatic annotation and volume mount setup
- ❌ **No VMSS Assignment**: Not needed for workload identity

#### **For Identity Binding**:
- ✅ **ClusterRole RBAC**: ClusterRole grants `use-managed-identity` verb for both MI client IDs
- ✅ **Standard Kubernetes**: Uses native ClusterRole and ClusterRoleBinding resources
- ✅ **Simplified Setup**: No custom controllers or FIC management needed
- ❌ **No VMSS Assignment**: Not needed for identity binding

**Key Feature**: Each demo demonstrates the real-world scenario of using multiple managed identities within a single pod, allowing applications to access different Azure resources with different identities as needed.