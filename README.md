# AKS Identity Binding Demo

This project demonstrates five different identity management approaches in Azure Kubernetes Service (AKS):

1. **Pod Identity** (Legacy approach) - deployed in `demo-app-pi` namespace
2. **Workload Identity** (Current recommended approach) - deployed in `demo-app-wi` namespace
3. **Workload Identity with Proxy Mode** (Migration approach) - deployed in `demo-app-wi` namespace
4. **Identity Binding** (Newer simplified approach) - deployed in `demo-app-ib` namespace
5. **Identity Binding with Proxy Mode** (Migration approach) - deployed in `demo-app-ib` namespace

The workload identity demos share the same namespace since they both use the same underlying workload identity technology. Similarly, the identity binding demos share their namespace since they both use the same underlying identity binding RBAC. The proxy mode variants simply add a migration sidecar for backward compatibility. **Each application demonstrates using multiple managed identities in a single pod**, which is a common real-world scenario.

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

#### Option C: Workload Identity with Proxy Mode (Migration)

```bash
cd apps/demo-app-wi-proxy
./configure-and-deploy.sh ib-demo-rg
```

**Note**: This demonstrates the migration sidecar for applications that still rely on IMDS. The sidecar is not supported for production use and is meant as a temporary migration solution.

#### Option D: Identity Binding Demo (Newest)

```bash
cd apps/demo-app-ib
./configure-and-deploy.sh ib-demo-rg
```

#### Option E: Identity Binding with Proxy Mode (Migration)

```bash
cd apps/demo-app-ib-proxy
./configure-and-deploy.sh ib-demo-rg
```

**Note**: This demonstrates the migration sidecar with identity binding for applications that still rely on IMDS. The sidecar is not supported for production use and is meant as a temporary migration solution.

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

### Workload Identity with Proxy Mode Demo (demo-app-wi namespace)
```bash
# Check deployment status
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl get pods -n demo-app-wi -l app=demo-app-wi-proxy

# Check that the proxy sidecar was injected
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl describe pod -l app=demo-app-wi-proxy -n demo-app-wi

# View application logs
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl logs -f -l app=demo-app-wi-proxy -n demo-app-wi -c demo-app

# View proxy sidecar logs
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl logs -f -l app=demo-app-wi-proxy -n demo-app-wi -c azure-workload-identity-proxy

# Expected output (main container):
# === Iteration at 2024-01-15 10:30:00 ===
# [workload-identity-proxy] retrieved secret content "Hello from Azure Key Vault! This is a demo secret." from akv using mi client id "abc123..."
# [workload-identity-proxy] retrieved secret content "Hello from Azure Key Vault! This is a demo secret." from akv using mi client id "def456..."
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

### Identity Binding with Proxy Mode Demo (demo-app-ib namespace)
```bash
# Check deployment status
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl get pods -n demo-app-ib -l app=demo-app-ib-proxy

# Check ClusterRole and ClusterRoleBinding status (shared with regular identity binding)
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl get clusterrole identity-binding-role
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl get clusterrolebinding identity-binding-role-binding

# Check that the proxy sidecar was injected
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl describe pod -l app=demo-app-ib-proxy -n demo-app-ib

# View application logs
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl logs -f -l app=demo-app-ib-proxy -n demo-app-ib -c demo-app

# View proxy sidecar logs
KUBECONFIG=./kubeconfig-ib-demo-rg-<cluster-name> kubectl logs -f -l app=demo-app-ib-proxy -n demo-app-ib -c azure-workload-identity-proxy

# Expected output (main container):
# === Iteration at 2025-10-06 10:30:00 ===
# [identity-binding-proxy] retrieved secret content "Hello from Azure Key Vault! This is a demo secret." from akv using mi client id "abc123..."
# [identity-binding-proxy] retrieved secret content "Hello from Azure Key Vault! This is a demo secret." from akv using mi client id "def456..."
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

### Workload Identity with Proxy Mode (demo-app-wi namespace)
- **Status**: Migration approach (not for production use)
- **Components**: Built into AKS with migration sidecar injected by webhook
- **Configuration**: Same as workload identity plus sidecar annotations
- **RBAC Requirements**: Same FICs as workload identity
- **Security**: Provides backward compatibility for IMDS-dependent applications
- **Setup Complexity**: Same as workload identity with additional sidecar configuration
- **Use Case**: Migration scenarios for legacy applications using IMDS, temporary solution only
- **Limitations**: Linux containers only, not supported for production

### Identity Binding (demo-app-ib namespace)
- **Status**: Newest approach using standard Kubernetes RBAC
- **Components**: Uses ClusterRole and ClusterRoleBinding (no custom controllers)
- **Configuration**: Standard Kubernetes RBAC with `use-managed-identity` verb
- **RBAC Requirements**: ClusterRole grants access to both managed identity client IDs
- **Automation**: Simplified approach using native Kubernetes permissions
- **Setup Complexity**: Simplest RBAC-based setup
- **Use Case**: Future applications, simplified management, standard Kubernetes patterns

### Identity Binding with Proxy Mode (demo-app-ib namespace)
- **Status**: Migration approach (not for production use)
- **Components**: Uses ClusterRole and ClusterRoleBinding plus migration sidecar injected by webhook
- **Configuration**: Same as identity binding plus sidecar annotations
- **RBAC Requirements**: Same ClusterRole as identity binding
- **Security**: Provides backward compatibility for IMDS-dependent applications using RBAC
- **Setup Complexity**: Same as identity binding with additional sidecar configuration
- **Use Case**: Migration scenarios for legacy applications using IMDS with identity binding RBAC, temporary solution only
- **Limitations**: Linux containers only, not supported for production

## Architecture Overview

```
┌───────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   AKS Cluster                                                 │
│                                                                                               │
│ ┌─────────────┐ ┌─────────────────────────────────┐ ┌─────────────────────────────────┐       │
│ │demo-app-pi  │ │        demo-app-wi              │ │        demo-app-ib              │       │
│ │ namespace   │ │        namespace                │ │        namespace                │       │
│ │             │ │                                 │ │                                 │       │
│ │┌───────────┐│ │┌───────────┐┌─────────────────┐ │ │┌───────────┐┌─────────────────┐ │       │
│ ││Pod Identity│ │││ Workload ││  Workload       │ │ ││ Identity  ││  Identity       │ │       │
│ ││   Demo    ││ ││ Identity  ││  Identity       │ │ ││ Binding   ││  Binding        │ │       │
│ ││   App     ││ ││   Demo    ││ Proxy Demo      │ │ ││   Demo    ││ Proxy Demo      │ │       │
│ │└───────────┘│ │└───────────┘└─────────────────┘ │ │└───────────┘└─────────────────┘ │       │
│ └─────────────┘ └─────────────────────────────────┘ └─────────────────────────────────┘       │
└───────────────────────────────────────────────────────────────────────────────────────────────┘
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

- **MI 1 (`${namePrefix}-mi-1`)**: Used by all five demos to demonstrate multiple identity scenarios
  - **Pod Identity**: Assigned to VMSS (manual step required)
  - **Workload Identity**: Has FIC for `demo-app-wi:workload-identity-sa`
  - **Workload Identity Proxy**: Uses same FIC as workload identity (`demo-app-wi:workload-identity-sa`)
  - **Identity Binding**: Uses ClusterRole permissions
  - **Identity Binding Proxy**: Uses same ClusterRole permissions as identity binding

- **MI 2 (`${namePrefix}-mi-2`)**: Used by all five demos to demonstrate multiple identity scenarios
  - **Pod Identity**: Assigned to VMSS (manual step required)
  - **Workload Identity**: Has FIC for `demo-app-wi:workload-identity-sa` (primary identity)
  - **Workload Identity Proxy**: Uses same FIC as workload identity (`demo-app-wi:workload-identity-sa`) (primary identity)
  - **Identity Binding**: Uses ClusterRole permissions (primary identity)
  - **Identity Binding Proxy**: Uses same ClusterRole permissions as identity binding (primary identity)

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

#### **For Workload Identity Proxy Mode**:
- ✅ **Federated Identity Credentials**: Uses the same FICs as regular workload identity
- ✅ **Service Account**: Shares `workload-identity-sa` with regular workload identity demo
- ✅ **OIDC Integration**: Uses AKS OIDC issuer for token exchange
- ✅ **Migration Sidecar**: Automatically injected by Azure Workload Identity webhook
- ✅ **IMDS Compatibility**: Provides IMDS endpoint at localhost:8000 for backward compatibility
- ⚠️ **Linux Only**: Migration sidecar only supports Linux containers
- ❌ **Not for Production**: This is a temporary migration solution only

#### **For Identity Binding**:
- ✅ **ClusterRole RBAC**: ClusterRole grants `use-managed-identity` verb for both MI client IDs
- ✅ **Standard Kubernetes**: Uses native ClusterRole and ClusterRoleBinding resources
- ✅ **Simplified Setup**: No custom controllers or FIC management needed
- ❌ **No VMSS Assignment**: Not needed for identity binding

#### **For Identity Binding Proxy Mode**:
- ✅ **ClusterRole RBAC**: Uses the same ClusterRole as regular identity binding
- ✅ **Service Account**: Shares `identity-binding-sa` with regular identity binding demo
- ✅ **Standard Kubernetes**: Uses native ClusterRole and ClusterRoleBinding resources
- ✅ **Migration Sidecar**: Automatically injected by Azure Workload Identity webhook
- ✅ **IMDS Compatibility**: Provides IMDS endpoint at localhost:8000 for backward compatibility
- ⚠️ **Linux Only**: Migration sidecar only supports Linux containers
- ❌ **Not for Production**: This is a temporary migration solution only

**Key Feature**: Each demo demonstrates the real-world scenario of using multiple managed identities within a single pod, allowing applications to access different Azure resources with different identities as needed.