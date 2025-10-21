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
- **Observability**: OpenTelemetry auto-instrumentation (traces, metrics)

## Infrastructure Components

### 1. Helm Chart (`helm/github-etl/`)
Complete Kubernetes packaging with:
- **Chart.yaml**: Helm chart metadata and versioning
- **values.yaml**: Default configuration values
- **values-dev.yaml**: Development environment overrides (uses `latest` tag for auto-updates)
- **values-prod.yaml**: Production environment overrides (uses specific commit tags)
- **templates/**:
  - Application deployment with OpenTelemetry auto-instrumentation
  - Service, ingress, ConfigMaps and Secrets
  - PostgreSQL StatefulSet with persistent storage
  - Namespace configuration
  - Image pull secrets for GitHub Container Registry

### 2. Observability Stack (`helm/observability/`)
Complete LGTM (Loki, Grafana, Tempo, Metrics) stack using Grafana open-source tools:
- **Grafana**: Unified observability dashboard (NodePort 30300)
- **Prometheus**: Metrics collection and storage (via kube-prometheus-stack)
- **Loki**: Log aggregation and querying
- **Tempo**: Distributed tracing backend
- **Grafana Alloy**: Modern telemetry collector (replaces Grafana Agent)
  - Collects logs from Kubernetes pods
  - Receives OTLP traces and metrics (ports 4317/4318)
  - Routes data to appropriate backends (Loki, Tempo, Prometheus)
- **OpenTelemetry Operator**: Auto-instrumentation for Python/FastAPI
  - Zero-code instrumentation via annotations
  - Automatic trace and metrics collection

### 3. OpenTelemetry Configuration (`k8s/dev/instrumentation.yaml`)
Auto-instrumentation resource for Python applications:
- Injects OpenTelemetry SDK into Python pods
- Configures OTLP exporters to Alloy
- Enables distributed tracing and metrics without code changes
- Applied via annotation: `instrumentation.opentelemetry.io/inject-python: "true"`

### 4. ArgoCD GitOps (`argocd/`)
Automated deployment manifests:
- **application-dev.yaml**: Development environment GitOps config
- **application-prod.yaml**: Production environment GitOps config
- Auto-sync and self-healing capabilities
- Watches this repository for changes

### 5. Makefile Automation
Complete automation for infrastructure setup and management:
- **setup-minikube**: Start Minikube cluster
- **install-cert-manager**: Install cert-manager (required for OpenTelemetry Operator)
- **create-ghcr-secret**: Create GitHub Container Registry pull secret (supports `.env` file)
- **install-argocd**: Install ArgoCD for GitOps
- **deploy-app**: Deploy application via ArgoCD (GitOps approach)
- **deploy-helm**: Deploy directly via Helm (bypasses ArgoCD for local testing)
- **install-observability**: Install complete observability stack
- **apply-instrumentation**: Apply OpenTelemetry Instrumentation resource
- **setup-observability**: Complete observability setup (stack + instrumentation)
- **upgrade-observability**: Upgrade observability stack
- **access-grafana**: Open Grafana in browser
- **access-argocd**: Port-forward to ArgoCD dashboard
- **status**: Show status of all components
- **clean**: Delete everything
- **full-setup**: Complete setup from scratch (all components in correct order)

### 6. Automation Scripts (`scripts/`)
- **setup-minikube.sh**: Initialize local Kubernetes cluster with Docker driver
- **install-argocd.sh**: Deploy ArgoCD to the cluster
- **deploy.sh**: Deploy/update application using Helm (legacy, use Makefile instead)

### 7. CI/CD Pipeline (`.github/workflows/`)
GitHub Actions workflow for:
- Building Docker images
- Pushing to GitHub Container Registry
- Triggering ArgoCD deployments
- Environment-specific deployments
- Automatic tagging (dev uses `latest`, prod uses commit hashes)

## Implementation Status

### Phase 1: Helm Chart Setup ✅
- [x] Analyze application requirements
- [x] Create Chart.yaml with proper metadata
- [x] Define comprehensive values.yaml
- [x] Create environment-specific value overrides (dev/prod)
- [x] Build Helm templates (deployment, service, configmap, secret, ingress)
- [x] Configure PostgreSQL StatefulSet with PVC
- [x] Add OpenTelemetry auto-instrumentation annotations
- [x] Configure image pull secrets for GHCR

### Phase 2: Local Development Setup ✅
- [x] Create setup-minikube.sh for cluster initialization
- [x] Create install-argocd.sh for ArgoCD deployment
- [x] Create deploy.sh for application deployment
- [x] Test full local deployment flow
- [x] Create comprehensive Makefile for automation
- [x] Add `.env` support for credentials

### Phase 3: GitOps Configuration ✅
- [x] Create ArgoCD application manifests (dev/prod)
- [x] Configure auto-sync policies
- [x] Set up environment-specific configurations
- [x] Integrate with Makefile automation

### Phase 4: CI/CD Pipeline ✅
- [x] Create GitHub Actions workflow
- [x] Configure Docker image building
- [x] Set up GHCR container registry integration
- [x] Implement automated deployments
- [x] Configure environment-specific tagging (latest for dev, commit hash for prod)

### Phase 5: Observability Stack ✅
- [x] Design observability architecture (LGTM stack)
- [x] Create observability Helm chart with dependencies
- [x] Configure Grafana for unified dashboard
- [x] Set up Prometheus for metrics collection
- [x] Configure Loki for log aggregation
- [x] Set up Tempo for distributed tracing
- [x] Deploy Grafana Alloy as telemetry collector
- [x] Install OpenTelemetry Operator
- [x] Configure Python auto-instrumentation
- [x] Integrate observability into Makefile automation

## Directory Structure

```
.
├── Makefile                       # Complete automation (RECOMMENDED)
├── .env                           # GitHub credentials (gitignored)
├── argocd/
│   ├── application-dev.yaml       # Dev environment ArgoCD config
│   └── application-prod.yaml      # Prod environment ArgoCD config
├── helm/
│   ├── github-etl/                # Application Helm chart
│   │   ├── Chart.yaml             # Chart metadata
│   │   ├── values.yaml            # Default values
│   │   ├── values-dev.yaml        # Dev overrides (latest tag)
│   │   ├── values-prod.yaml       # Prod overrides (commit tags)
│   │   └── templates/
│   │       ├── deployment.yaml    # App deployment (with OTel annotation)
│   │       ├── service.yaml       # K8s service
│   │       ├── ingress.yaml       # Ingress rules
│   │       ├── configmap.yaml     # Configuration
│   │       ├── secret.yaml        # Sensitive data
│   │       ├── namespace.yaml     # Namespace definition
│   │       └── postgres/
│   │           ├── statefulset.yaml  # PostgreSQL deployment
│   │           ├── service.yaml      # PostgreSQL service
│   │           └── pvc.yaml          # Persistent volume claim
│   └── observability/             # Observability Helm chart
│       ├── Chart.yaml             # Chart with LGTM stack dependencies
│       ├── values.yaml            # Observability configuration
│       └── values-dev.yaml        # Dev overrides (lower resources)
├── k8s/
│   └── dev/
│       └── instrumentation.yaml   # OpenTelemetry auto-instrumentation
├── scripts/
│   ├── setup-minikube.sh          # Initialize Minikube cluster
│   ├── install-argocd.sh          # Deploy ArgoCD
│   └── deploy.sh                  # Deploy application (legacy)
└── .github/
    └── workflows/
        └── deploy.yaml            # CI/CD pipeline
```

## Prerequisites

- **Docker**: For Minikube driver
- **Minikube**: Local Kubernetes cluster
- **kubectl**: Kubernetes CLI
- **Helm 3.x**: Package manager for Kubernetes
- **ArgoCD CLI** (optional): For ArgoCD management

## Quick Start

### 🚀 First Time Setup (Automated with Makefile)

**Prerequisites:** Docker, Minikube, kubectl, Helm 3.x installed on your system.

1. **Create `.env` file with GitHub credentials:**
   ```bash
   cat > .env << EOF
   GITHUB_USERNAME=your-github-username
   GITHUB_EMAIL=your-github-email
   GITHUB_PAT=ghp_your_personal_access_token
   EOF
   ```
   The PAT needs `read:packages` scope to pull images from GitHub Container Registry.

2. **Run complete setup (one command):**
   ```bash
   make full-setup
   ```
   This single command will:
   - Start Minikube cluster (4 CPUs, 8GB RAM)
   - Install cert-manager (required for OpenTelemetry Operator)
   - Create GHCR pull secret from `.env`
   - Install ArgoCD for GitOps
   - Deploy github-etl application via ArgoCD
   - Install complete observability stack (Grafana, Prometheus, Loki, Tempo, Alloy)
   - Apply OpenTelemetry auto-instrumentation

   Wait 5-10 minutes for all components to be ready.

3. **Check status:**
   ```bash
   make status
   ```
   Verify all pods are running in `github-etl`, `argocd`, and `observability` namespaces.

### 🔄 After Restarting Your Laptop

When you restart your laptop, Minikube stops. Simply restart it:

```bash
minikube start
make status  # Check if everything is running
```

All your deployments and data persist across restarts! The development environment uses `latest` tag with `pullPolicy: Always`, so ArgoCD will automatically pull new images when they're pushed to GHCR.

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
make access-argocd
```

Then open: https://localhost:8080
- Username: `admin`
- Password: (displayed in terminal from command above)

### 📊 Accessing Grafana (Observability)

```bash
make access-grafana
```

This opens Grafana in your browser automatically:
- Username: `admin`
- Password: `admin`

**What you can monitor:**
- **Logs**: View application and infrastructure logs via Loki
- **Metrics**: Monitor CPU, memory, request rates via Prometheus
- **Traces**: Distributed tracing via Tempo (OpenTelemetry auto-instrumentation)
- **Dashboards**: Pre-configured dashboards for Kubernetes monitoring

The github-etl application is automatically instrumented with OpenTelemetry, sending traces and metrics to Grafana Alloy, which forwards them to Tempo and Prometheus.

### 📝 After CI/CD Deploys New Version

When GitHub Actions builds a new image and pushes to GHCR:

**Development Environment:**
- ArgoCD automatically detects the `latest` tag update
- Pods restart automatically with `pullPolicy: Always`
- Check deployment status: `make status`

**Production Environment:**
- CI/CD updates the image tag in `values-prod.yaml` with commit hash
- ArgoCD syncs and deploys the specific version
- Manual approval required for production deployments

### 🛠️ Makefile Commands Reference

```bash
# Status and monitoring
make status              # Show status of all components (app, ArgoCD, observability)

# Access services
make access-grafana      # Open Grafana dashboard in browser
make access-argocd       # Port-forward to ArgoCD and show credentials

# Deployment
make deploy-app          # Deploy/update app via ArgoCD (GitOps)
make deploy-helm         # Deploy directly via Helm (bypasses ArgoCD, for testing)

# Observability
make setup-observability        # Install observability + instrumentation
make install-observability      # Install observability stack only
make upgrade-observability      # Upgrade observability stack
make apply-instrumentation      # Apply OpenTelemetry instrumentation

# Credentials
make create-ghcr-secret  # Create GitHub Container Registry secret (uses .env)

# Infrastructure
make setup-minikube      # Start Minikube cluster
make install-argocd      # Install ArgoCD
make install-cert-manager # Install cert-manager

# Complete workflows
make full-setup          # Complete setup from scratch
make clean               # Delete everything and Minikube cluster

# View help
make help                # Show all available commands
```

### 🛠️ Kubectl Commands Reference

```bash
# View application logs
kubectl logs -f -n github-etl -l app=github-etl

# View database logs
kubectl logs -f github-etl-postgres-0 -n github-etl

# View observability logs
kubectl logs -f -n observability -l app.kubernetes.io/name=alloy

# Check pod status
kubectl get pods -n github-etl
kubectl get pods -n observability
kubectl get pods -n argocd

# Restart application
kubectl rollout restart deployment github-etl -n github-etl

# Access PostgreSQL
kubectl exec -it github-etl-postgres-0 -n github-etl -- psql -U postgres -d github_etl

# Check ArgoCD applications
kubectl get application -n argocd
kubectl describe application github-etl-dev -n argocd
```

### Production Deployment

Production deployments are managed via ArgoCD GitOps:
1. Push changes to this repository
2. ArgoCD automatically syncs and deploys
3. Monitor via ArgoCD dashboard

## Environment Configuration

### Development (`values-dev.yaml`)
**Application:**
- Single replica (cost-effective)
- Lower resource limits (500m CPU, 512Mi memory)
- Debug logging enabled (`LOG_LEVEL: DEBUG`)
- NodePort service (port 30080 for easy local access)
- Image tag: `latest` with `pullPolicy: Always` (auto-updates on push)

**Observability:**
- Smaller storage for Prometheus (10Gi)
- Lower resource limits for Loki, Tempo, Alloy
- Grafana exposed via NodePort (30300)
- Single replica deployments

**Database:**
- PostgreSQL with 500Mi storage
- Lower resource limits (250m CPU, 256Mi memory)

### Production (`values-prod.yaml`)
**Application:**
- Multiple replicas for HA (3+)
- Higher resource limits (2 CPU, 2Gi memory)
- Production logging levels (`LOG_LEVEL: INFO` or `WARNING`)
- LoadBalancer/Ingress for external access with TLS
- Image tag: Specific commit hashes (e.g., `main-abc1234`)
- Manual approval required for deployments

**Observability:**
- Larger storage for Prometheus (100Gi+)
- Higher resource limits for all components
- Grafana behind Ingress with authentication
- Multi-replica deployments for HA

**Database:**
- PostgreSQL with persistent storage (10Gi+)
- Higher resource limits
- Automated backups configured

### `.env` Configuration

Create a `.env` file in the repository root for GitHub Container Registry authentication:

```bash
GITHUB_USERNAME=your-github-username
GITHUB_EMAIL=your-github-email@example.com
GITHUB_PAT=ghp_your_personal_access_token
```

**Requirements:**
- PAT must have `read:packages` scope
- Used by `make create-ghcr-secret` and `make full-setup`
- File is gitignored for security

**Alternative:** Without `.env`, Makefile will prompt for credentials interactively.

## Related Repositories

- **[GitHub ETL Application](../github-etl)** - Main application codebase