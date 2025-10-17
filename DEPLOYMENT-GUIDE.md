# GitHub ETL Platform - Deployment Guide

## 📋 Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Initial Setup](#initial-setup)
4. [CI/CD Pipeline](#cicd-pipeline)
5. [Minikube Image Loading (Important!)](#minikube-image-loading)
6. [Common Operations](#common-operations)
7. [Troubleshooting](#troubleshooting)
8. [Security Notes](#security-notes)

---

## Architecture Overview

### Stack
- **Kubernetes**: Minikube (local cluster)
- **Container Registry**: GitHub Container Registry (GHCR)
- **GitOps**: ArgoCD
- **Package Manager**: Helm
- **CI/CD**: GitHub Actions
- **Application**: FastAPI + PostgreSQL

### GitOps Flow
```
Developer pushes code → GitHub Actions builds image →
Pushes to GHCR → Updates infrastructure repo →
ArgoCD syncs → Kubernetes deploys
```

---

## Prerequisites

**Required Tools:**
- Docker Desktop
- Minikube
- kubectl
- Helm 3.x
- Git

**Installation (macOS):**
```bash
brew install docker minikube kubectl helm
```

---

## Initial Setup

### 1. Start Minikube
```bash
./scripts/setup-minikube.sh
```

**What it does:**
- Starts Minikube with Docker driver (4 CPUs, 8GB RAM)
- Enables Ingress and Metrics addons
- Verifies cluster is ready

### 2. Install ArgoCD
```bash
./scripts/install-argocd.sh
```

**Access ArgoCD UI:**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Then: https://localhost:8080

**Credentials:**
- Username: `admin`
- Password:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```

### 3. Deploy Application
```bash
./scripts/deploy.sh dev
```

**Access Application:**
```bash
echo "http://$(minikube ip):30080/docs"
```

Or port-forward:
```bash
kubectl port-forward -n github-etl svc/github-etl 8000:8000
```
Then: http://localhost:8000/docs

---

## CI/CD Pipeline

### How It Works

**Trigger:** Push to `main` branch in `github-etl` app repo

**Pipeline Steps:**
1. Checkout code
2. Login to GHCR
3. Build Docker image
4. Tag with `main-<commit-sha>` (e.g., `main-abc1234`)
5. Push to GHCR
6. Clone infrastructure repo
7. Update `helm/github-etl/values-dev.yaml` with new tag
8. Commit and push infrastructure repo
9. ArgoCD detects change (1-3 minutes)
10. ArgoCD deploys new version

**Workflow File:** `.github/workflows/deploy.yaml` (in app repo)

### Required Secrets

**In `github-etl` app repository:**

1. **INFRA_REPO_TOKEN**
   - Purpose: Allow GitHub Actions to push to infrastructure repo
   - Scope: `repo` (Full control)
   - Created at: https://github.com/settings/tokens

**Repository Settings:**

1. **Actions Permissions**
   - Path: Settings → Actions → General → Workflow permissions
   - Set to: "Read and write permissions"

2. **Package Access**
   - Path: https://github.com/USER?tab=packages → Package settings
   - Add `github-etl` repo with **Write** access

---

## Minikube Image Loading

### ⚠️ Important Issue

**Problem:** Minikube cannot pull images from GHCR due to network/DNS restrictions.

**Error:** `ImagePullBackOff` with "unauthorized" or timeout errors

**Why This Happens:**
- Minikube runs in isolated Docker container
- May not have proper internet access or DNS resolution
- GitHub Container Registry requires authentication

### Solution: Manual Image Loading

**After every CI/CD pipeline run, you must load the new image into Minikube:**

#### Step 1: Get the New Image Tag
```bash
curl -s https://raw.githubusercontent.com/ejpolicarpio/github-etl-infrastructure/main/helm/github-etl/values-dev.yaml | grep "tag:"
```

Example output: `tag: main-3b56681`

#### Step 2: Pull Image Locally
```bash
docker pull ghcr.io/ejpolicarpio/github-etl:main-3b56681
```

#### Step 3: Load Into Minikube
```bash
minikube image load ghcr.io/ejpolicarpio/github-etl:main-3b56681
```

#### Step 4: Restart Deployment
```bash
kubectl rollout restart deployment github-etl -n github-etl
```

#### Step 5: Verify
```bash
kubectl get pods -n github-etl
```

Should show: `github-etl-xxx   1/1     Running`

### Alternative Solutions

**Option 1: Set imagePullPolicy to Never (Dev Only)**

In `helm/github-etl/values-dev.yaml`:
```yaml
image:
  tag: latest
  pullPolicy: Never  # Always use local images
```

**Option 2: Fix Minikube Network**
- Restart Minikube: `minikube delete && minikube start`
- Check DNS: `minikube ssh -- nslookup ghcr.io`
- Check proxy settings if behind corporate firewall

**Option 3: Use Minikube Docker Daemon (Advanced)**
```bash
eval $(minikube docker-env)
docker build -t ghcr.io/ejpolicarpio/github-etl:latest .
# Images built directly in Minikube's Docker
```

---

## Common Operations

### View Application Logs
```bash
kubectl logs -f -n github-etl -l app=github-etl
```

### View Database Logs
```bash
kubectl logs -f github-etl-postgres-0 -n github-etl
```

### Access PostgreSQL Database
```bash
kubectl exec -it github-etl-postgres-0 -n github-etl -- psql -U postgres -d github_etl
```

### Check Pod Status
```bash
kubectl get pods -n github-etl
kubectl describe pod <pod-name> -n github-etl
```

### Check ArgoCD Application Status
```bash
kubectl get application -n argocd
```

### Force ArgoCD Sync
```bash
kubectl patch application github-etl-dev -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' --type merge
```

Or in ArgoCD UI: Click "Sync" button

### Restart Deployment
```bash
kubectl rollout restart deployment github-etl -n github-etl
```

### Check Deployment History
```bash
kubectl rollout history deployment github-etl -n github-etl
```

### Rollback to Previous Version
```bash
kubectl rollout undo deployment github-etl -n github-etl
```

### Delete Everything
```bash
helm uninstall github-etl -n github-etl
kubectl delete namespace github-etl
```

---

## Troubleshooting

### Pod Status: ImagePullBackOff

**Cause:** Minikube can't pull image from GHCR

**Solution:** [See Minikube Image Loading section](#minikube-image-loading)

### Pod Status: CrashLoopBackOff

**Check logs:**
```bash
kubectl logs <pod-name> -n github-etl
```

**Common causes:**
- Database connection failed (check credentials)
- Missing environment variables
- Application startup error

**Check environment variables:**
```bash
kubectl exec <pod-name> -n github-etl -- env | grep -i database
```

### Database Connection Failed

**Error:** `password authentication failed for user "xxx"`

**Solution:** Verify environment variable names match application config

**App expects (src/configuration.py):**
```python
database_username: str = "user"
database_password: str = "password"
database_host: str = "localhost"
database_port: int = 5432
database_name: str = "github_etl"
```

**Kubernetes must provide:**
```yaml
env:
  - name: database_username  # Exact name!
    valueFrom:
      secretKeyRef:
        name: github-etl-secret
        key: DATABASE_USER
```

### ArgoCD Not Syncing

**Check application status:**
```bash
kubectl get application github-etl-dev -n argocd -o yaml
```

**Force sync:**
```bash
kubectl patch application github-etl-dev -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' --type merge
```

**Check ArgoCD logs:**
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### GitHub Actions Workflow Failed

**Common errors:**

1. **"permission_denied: write_package"**
   - Fix: Enable write permissions in repo settings
   - Path: Settings → Actions → Workflow permissions → Read and write

2. **"Failed to push image: unauthorized"**
   - Fix: Add repo to package access list
   - Path: GitHub Packages → Package settings → Manage Actions access

3. **"nothing to commit, working tree clean"**
   - Cause: sed command didn't find/update the tag
   - Fix: Ensure `values-dev.yaml` has `image.tag:` field

---

## Security Notes

### ⚠️ Current Security Issues (Dev Only!)

**1. Hardcoded Database Credentials**

Current setup in `values.yaml`:
```yaml
database:
  user: postgres
  password: postgres  # ⚠️ INSECURE!
```

**For Production:**
- Use HashiCorp Vault
- Use Sealed Secrets
- Use cloud provider secret managers (AWS Secrets Manager, GCP Secret Manager)
- **NEVER commit real passwords to Git!**

**2. Public Container Images**

Images are public on GHCR. For production:
- Make packages private
- Use image pull secrets in Kubernetes
- Implement image scanning (Trivy, Snyk)

**3. ArgoCD Admin Password**

Change the default admin password:
```bash
argocd account update-password --account admin --new-password <new-password>
```

**4. Minikube is Local Only**

Minikube is for development only. For production:
- Use managed Kubernetes (EKS, GKE, AKS)
- Implement proper network policies
- Use service mesh (Istio, Linkerd) for mTLS
- Implement RBAC and pod security policies

---

## GitOps Workflow

### Making Changes

**To Update Application Code:**

1. Make changes in `github-etl` app repo
2. Commit and push to `main`
3. GitHub Actions builds and pushes image
4. Infrastructure repo gets updated automatically
5. Load image into Minikube (see above)
6. ArgoCD deploys automatically

**To Update Infrastructure:**

1. Make changes in `github-etl-infrastructure` repo
2. Commit and push to `main`
3. ArgoCD detects and deploys (1-3 minutes)

### Environment Promotion

**Current setup:** Only dev environment

**To add staging/production:**

1. Create `values-staging.yaml` and `values-prod.yaml`
2. Create `argocd/application-staging.yaml` and `application-prod.yaml`
3. Apply ArgoCD applications:
   ```bash
   kubectl apply -f argocd/application-staging.yaml
   kubectl apply -f argocd/application-prod.yaml
   ```
4. Update CI/CD workflow to update appropriate environment

---

## Best Practices

### Development Workflow

1. **Test locally first:**
   ```bash
   docker build -t test-image .
   docker run -p 8000:8000 test-image
   ```

2. **Use feature branches:**
   - Create branch: `git checkout -b feature/new-feature`
   - Push and test
   - Merge to `main` when ready

3. **Monitor deployments:**
   - Watch ArgoCD UI for sync status
   - Check pod logs after deployment
   - Test application endpoints

### Kubernetes Best Practices

1. **Always set resource limits:**
   ```yaml
   resources:
     limits:
       cpu: 500m
       memory: 512Mi
     requests:
       cpu: 250m
       memory: 256Mi
   ```

2. **Use health checks (TODO):**
   - Add liveness and readiness probes
   - Implement `/health` endpoint in FastAPI

3. **Use proper labels:**
   - Makes troubleshooting easier
   - Enables better monitoring

---

## Next Steps

### Improvements to Consider

1. **Fix Minikube Image Pulling**
   - Configure imagePullSecrets
   - Or use Minikube Docker daemon directly

2. **Add Monitoring**
   - Prometheus for metrics
   - Grafana for dashboards
   - Alert manager for notifications

3. **Add Logging**
   - ELK stack (Elasticsearch, Logstash, Kibana)
   - Or Loki + Grafana

4. **Add Health Checks**
   - Liveness probe: Is app running?
   - Readiness probe: Is app ready for traffic?

5. **Implement Production Environment**
   - Separate namespace
   - Manual sync policy
   - Higher resources
   - Multiple replicas

6. **Add Database Migrations**
   - Alembic init container
   - Run migrations before app starts

7. **Implement Secrets Management**
   - External Secrets Operator
   - HashiCorp Vault integration

---

## Useful Links

- **Minikube Docs:** https://minikube.sigs.k8s.io/docs/
- **ArgoCD Docs:** https://argo-cd.readthedocs.io/
- **Helm Docs:** https://helm.sh/docs/
- **Kubernetes Docs:** https://kubernetes.io/docs/

---

## Quick Reference

### Most Common Commands

```bash
# Start Minikube
minikube start

# Deploy app
./scripts/deploy.sh dev

# Watch pods
kubectl get pods -n github-etl -w

# View logs
kubectl logs -f -n github-etl -l app=github-etl

# Access ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access App
echo "http://$(minikube ip):30080/docs"

# Load new image (after CI/CD)
TAG=$(curl -s https://raw.githubusercontent.com/ejpolicarpio/github-etl-infrastructure/main/helm/github-etl/values-dev.yaml | grep "tag:" | awk '{print $2}')
docker pull ghcr.io/ejpolicarpio/github-etl:$TAG
minikube image load ghcr.io/ejpolicarpio/github-etl:$TAG
kubectl rollout restart deployment github-etl -n github-etl

# Restart deployment
kubectl rollout restart deployment github-etl -n github-etl

# Delete everything
helm uninstall github-etl -n github-etl
kubectl delete namespace github-etl
```

---

**Last Updated:** October 2025
**Maintained By:** Erald Policarpio