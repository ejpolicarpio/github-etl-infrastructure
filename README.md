# Platform Infrastructure

## Goal

This repository serves as a centralized Infrastructure as Code (IaC) platform for managing multiple microservices and applications. It provides reusable deployment patterns, GitOps workflows, and environment management using Kubernetes, Helm, ArgoCD, and GitHub CI/CD.

**Current Applications:**
- [GitHub ETL](https://github.com/yourusername/github-etl) - FastAPI service for extracting and loading GitHub repository data

**Local Development**: Minikube with Docker driver to mimic production Kubernetes cluster

## Architecture Philosophy

This infrastructure follows a **mono-infrastructure, multi-application** approach:

### ✅ Benefits
- **Centralized management**: Single source of truth for all infrastructure configs
- **Consistency**: Shared patterns and standards across all applications
- **Resource efficiency**: Shared cluster resources (PostgreSQL, Redis, etc.)
- **Simplified GitOps**: One ArgoCD instance managing all apps
- **Easier maintenance**: Update scripts, charts, and configs in one place
- **Environment parity**: Same infrastructure patterns across dev/prod

### 📋 Best Practices for Scaling
1. **Namespace isolation**: Each application gets its own namespace
2. **Separate Helm charts**: Each app has its own chart in `helm/<app-name>/`
3. **Shared services**: Common services (monitoring, logging) deployed once
4. **Independent ArgoCD apps**: Each application has its own ArgoCD manifest
5. **Environment-based values**: Use `values-dev.yaml` and `values-prod.yaml` per app

### 🔄 Adding New Applications
To add a new application to this infrastructure:
```bash
# 1. Create Helm chart structure
mkdir -p helm/<new-app-name>/templates

# 2. Create ArgoCD manifests
touch argocd/<new-app-name>-dev.yaml
touch argocd/<new-app-name>-prod.yaml

# 3. Deploy using existing scripts
./scripts/deploy.sh <new-app-name> dev
```

## Application Stack

The GitHub ETL application is a FastAPI-based service that extracts, transforms, and loads GitHub repository data:
- **Runtime**: Python 3.12 with UV package manager
- **Framework**: FastAPI with SQLAlchemy ORM
- **Database**: PostgreSQL 15
- **Port**: 8000
- **Dependencies**: Alembic (migrations), asyncpg, Pydantic, Loguru

## Infrastructure Components

### 1. Helm Chart (`helm/github-etl/`)
Complete Kubernetes packaging with:
- **Chart.yaml**: Helm chart metadata and versioning
- **values.yaml**: Default configuration values
- **values-dev.yaml**: Development environment overrides
- **values-prod.yaml**: Production environment overrides
- **templates/**:
  - Application deployment, service, ingress
  - ConfigMaps and Secrets management
  - PostgreSQL StatefulSet with persistent storage
  - Namespace configuration

### 2. ArgoCD GitOps (`argocd/`)
Automated deployment manifests:
- **application-dev.yaml**: Development environment GitOps config
- **application-prod.yaml**: Production environment GitOps config
- Auto-sync and self-healing capabilities

### 3. Automation Scripts (`scripts/`)
- **setup-minikube.sh**: Initialize local Kubernetes cluster with Docker driver
- **install-argocd.sh**: Deploy ArgoCD to the cluster
- **deploy.sh**: Deploy/update application using Helm or ArgoCD

### 4. CI/CD Pipeline (`.github/workflows/`)
GitHub Actions workflow for:
- Building Docker images
- Pushing to container registry
- Triggering ArgoCD deployments
- Environment-specific deployments

## Implementation Plan

### Phase 1: Helm Chart Setup
- [x] Analyze application requirements
- [ ] Create Chart.yaml with proper metadata
- [ ] Define comprehensive values.yaml
- [ ] Create environment-specific value overrides
- [ ] Build Helm templates (deployment, service, configmap, secret, ingress)
- [ ] Configure PostgreSQL StatefulSet with PVC

### Phase 2: Local Development Setup
- [ ] Create setup-minikube.sh for cluster initialization
- [ ] Create install-argocd.sh for ArgoCD deployment
- [ ] Create deploy.sh for application deployment
- [ ] Test full local deployment flow

### Phase 3: GitOps Configuration
- [ ] Create ArgoCD application manifests
- [ ] Configure auto-sync policies
- [ ] Set up environment-specific configurations

### Phase 4: CI/CD Pipeline
- [ ] Create GitHub Actions workflow
- [ ] Configure Docker image building
- [ ] Set up container registry integration
- [ ] Implement automated deployments

## Directory Structure

```
.
├── argocd/
│   ├── application-dev.yaml      # Dev environment ArgoCD config
│   └── application-prod.yaml     # Prod environment ArgoCD config
├── helm/
│   └── github-etl/
│       ├── Chart.yaml            # Helm chart metadata
│       ├── values.yaml           # Default values
│       ├── values-dev.yaml       # Dev overrides
│       ├── values-prod.yaml      # Prod overrides
│       └── templates/
│           ├── deployment.yaml   # App deployment
│           ├── service.yaml      # K8s service
│           ├── ingress.yaml      # Ingress rules
│           ├── configmap.yaml    # Configuration
│           ├── secret.yaml       # Sensitive data
│           ├── namespace.yaml    # Namespace definition
│           └── postgres/
│               ├── statefulset.yaml  # PostgreSQL deployment
│               ├── service.yaml      # PostgreSQL service
│               └── pvc.yaml          # Persistent volume claim
├── scripts/
│   ├── setup-minikube.sh         # Initialize Minikube cluster
│   ├── install-argocd.sh         # Deploy ArgoCD
│   └── deploy.sh                 # Deploy application
└── .github/
    └── workflows/
        └── deploy.yaml           # CI/CD pipeline
```

## Prerequisites

- **Docker**: For Minikube driver
- **Minikube**: Local Kubernetes cluster
- **kubectl**: Kubernetes CLI
- **Helm 3.x**: Package manager for Kubernetes
- **ArgoCD CLI** (optional): For ArgoCD management

## Quick Start

### 🚀 First Time Setup

1. **Start Minikube cluster:**
   ```bash
   ./scripts/setup-minikube.sh
   ```
   This starts a local Kubernetes cluster with Docker driver (4 CPUs, 8GB RAM).

2. **Install ArgoCD:**
   ```bash
   ./scripts/install-argocd.sh
   ```
   Installs ArgoCD for GitOps automation.

3. **Deploy ArgoCD Application:**
   ```bash
   kubectl apply -f argocd/application-dev.yaml
   ```
   Creates the ArgoCD application that watches this repo.

4. **Load Docker Image (Minikube workaround):**
   ```bash
   # Get the current image tag
   TAG=$(grep "tag:" helm/github-etl/values-dev.yaml | awk '{print $2}')

   # Pull and load into Minikube
   docker pull ghcr.io/ejpolicarpio/github-etl:$TAG
   minikube image load ghcr.io/ejpolicarpio/github-etl:$TAG
   ```
   Note: Minikube can't pull from GHCR directly, so we load images manually. See [DEPLOYMENT-GUIDE.md](./DEPLOYMENT-GUIDE.md) for details.

5. **Wait for ArgoCD to sync (1-3 minutes):**
   ```bash
   kubectl get pods -n github-etl -w
   ```
   Wait until you see: `github-etl-xxx 1/1 Running`

### 🔄 After Restarting Your Laptop

When you restart your laptop, Minikube stops. Here's how to start everything again:

1. **Start Minikube:**
   ```bash
   minikube start
   ```

2. **Verify cluster is running:**
   ```bash
   kubectl get nodes
   ```

3. **Check if pods are running:**
   ```bash
   kubectl get pods -n github-etl
   kubectl get pods -n argocd
   ```

   If pods are running, you're good! If not, continue below.

4. **If pods aren't running, reload the image:**
   ```bash
   TAG=$(grep "tag:" helm/github-etl/values-dev.yaml | awk '{print $2}')
   minikube image load ghcr.io/ejpolicarpio/github-etl:$TAG
   kubectl rollout restart deployment github-etl -n github-etl
   ```

### 🌐 Accessing the Application

**Option 1: NodePort (Minikube IP)**
```bash
echo "http://$(minikube ip):30080/docs"
```
Open the URL in your browser to see FastAPI Swagger docs.

**Option 2: Port Forward (localhost)**
```bash
kubectl port-forward -n github-etl svc/github-etl 8000:8000
```
Then open: http://localhost:8000/docs

### 🎛️ Accessing ArgoCD Dashboard

```bash
# Start port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Then open: https://localhost:8080
- Username: `admin`
- Password: (from command above)

### 📝 After CI/CD Deploys New Version

When GitHub Actions builds a new image:

1. **Get the new image tag:**
   ```bash
   TAG=$(curl -s https://raw.githubusercontent.com/ejpolicarpio/github-etl-infrastructure/main/helm/github-etl/values-dev.yaml | grep "tag:" | awk '{print $2}')
   echo "New tag: $TAG"
   ```

2. **Pull and load the new image:**
   ```bash
   docker pull ghcr.io/ejpolicarpio/github-etl:$TAG
   minikube image load ghcr.io/ejpolicarpio/github-etl:$TAG
   ```

3. **Restart deployment:**
   ```bash
   kubectl rollout restart deployment github-etl -n github-etl
   ```

4. **Watch deployment:**
   ```bash
   kubectl get pods -n github-etl -w
   ```

### 🛠️ Common Commands

```bash
# View application logs
kubectl logs -f -n github-etl -l app=github-etl

# View database logs
kubectl logs -f github-etl-postgres-0 -n github-etl

# Check pod status
kubectl get pods -n github-etl

# Restart application
kubectl rollout restart deployment github-etl -n github-etl

# Access PostgreSQL
kubectl exec -it github-etl-postgres-0 -n github-etl -- psql -U postgres -d github_etl

# Delete everything
helm uninstall github-etl -n github-etl
kubectl delete namespace github-etl
```

### Production Deployment

Production deployments are managed via ArgoCD GitOps:
1. Push changes to this repository
2. ArgoCD automatically syncs and deploys
3. Monitor via ArgoCD dashboard

## Environment Configuration

### Development
- Single replica
- Lower resource limits
- Debug logging enabled
- NodePort service type for easy access

### Production
- Multiple replicas for HA
- Higher resource limits
- Production logging levels
- LoadBalancer/Ingress for external access
- Persistent storage for PostgreSQL

## Related Repositories

- **[GitHub ETL Application](../github-etl)** - Main application codebase