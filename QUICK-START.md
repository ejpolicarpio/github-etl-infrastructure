# GitHub ETL - Quick Start Guide

A quick reference for starting the platform and accessing your application.

---

## 🚀 Starting Everything (After Restart)

When you restart your laptop or start fresh, run these commands in order:

### 1. Start Minikube
```bash
minikube start
```
**Wait:** ~30-60 seconds for cluster to be ready.

### 2. Verify Everything is Running
```bash
# Check if Minikube is running
minikube status

# Check if pods are running
kubectl get pods -n github-etl
kubectl get pods -n argocd
```

**Expected output:**
```
NAME                          READY   STATUS    RESTARTS   AGE
github-etl-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
github-etl-postgres-0         1/1     Running   0          2m
```

### 3. If Pods are NOT Running (ImagePullBackOff)

```bash
# Get the current image tag
TAG=$(grep "tag:" helm/github-etl/values-dev.yaml | awk '{print $2}')

# Pull and load image into Minikube
docker pull ghcr.io/ejpolicarpio/github-etl:$TAG
minikube image load ghcr.io/ejpolicarpio/github-etl:$TAG

# Restart the deployment
kubectl rollout restart deployment github-etl -n github-etl

# Wait for pod to be ready
kubectl get pods -n github-etl -w
```

**Wait until:** `github-etl-xxx 1/1 Running`

---

## 🌐 Accessing Your Application

### Method 1: NodePort (Recommended for Minikube)

```bash
# Get the URL
echo "http://$(minikube ip):30080/docs"
```

**Example output:** `http://192.168.49.2:30080/docs`

Copy that URL and open it in your browser!

### Method 2: Port Forward (Alternative)

```bash
# Start port forwarding
kubectl port-forward -n github-etl svc/github-etl 8000:8000
```

Then open: **http://localhost:8000/docs**

**Note:** Port forward must stay running in the terminal. Press `Ctrl+C` to stop.

---

## 📊 Where is the Application Deployed?

### Kubernetes Namespace
```bash
kubectl get all -n github-etl
```

**Your application runs in the `github-etl` namespace with:**

| Resource | Name | Purpose |
|----------|------|---------|
| **Deployment** | `github-etl` | Manages your FastAPI application pods |
| **Pod** | `github-etl-xxxxxxxxxx-xxxxx` | Running instance of your app |
| **Service** | `github-etl` | Network endpoint (NodePort 30080) |
| **StatefulSet** | `github-etl-postgres` | PostgreSQL database |
| **Pod** | `github-etl-postgres-0` | Running PostgreSQL instance |
| **Service** | `github-etl-postgres` | Database endpoint (port 5432) |
| **PVC** | `github-etl-postgres-pvc` | Persistent storage for database data |
| **ConfigMap** | `github-etl-config` | Non-sensitive configuration |
| **Secret** | `github-etl-secret` | Database credentials |

### View All Resources
```bash
# Everything in github-etl namespace
kubectl get all,configmap,secret,pvc -n github-etl

# Just the pods
kubectl get pods -n github-etl

# Pod details
kubectl describe pod <pod-name> -n github-etl
```

### Application Endpoints

**FastAPI Application:**
- **Swagger UI:** `http://$(minikube ip):30080/docs`
- **ReDoc:** `http://$(minikube ip):30080/redoc`
- **OpenAPI JSON:** `http://$(minikube ip):30080/openapi.json`
- **Health Check:** `http://$(minikube ip):30080/` (if implemented)

**Database (Internal Only):**
- **Host:** `github-etl-postgres` (DNS inside cluster)
- **Port:** `5432`
- **Database:** `github_etl`
- **User:** `postgres`

---

## 🎛️ ArgoCD Dashboard

ArgoCD manages your GitOps deployments.

### Access ArgoCD

```bash
# Start port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get password (run in another terminal)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Open:** https://localhost:8080

**Login:**
- Username: `admin`
- Password: (from command above)

### What You'll See

- **Application:** `github-etl-dev`
- **Status:** Synced / Healthy
- **Visual Graph:** Shows all Kubernetes resources
- **Sync Button:** Manually trigger deployment
- **History:** View past deployments

---

## 📝 Common Operations

### View Application Logs
```bash
# Live logs
kubectl logs -f -n github-etl -l app=github-etl

# Last 100 lines
kubectl logs --tail=100 -n github-etl -l app=github-etl
```

### View Database Logs
```bash
kubectl logs -f github-etl-postgres-0 -n github-etl
```

### Restart Application
```bash
kubectl rollout restart deployment github-etl -n github-etl
```

### Check Pod Status
```bash
kubectl get pods -n github-etl

# Detailed info
kubectl describe pod <pod-name> -n github-etl
```

### Access Database Shell
```bash
kubectl exec -it github-etl-postgres-0 -n github-etl -- psql -U postgres -d github_etl
```

**PostgreSQL commands:**
```sql
-- List tables
\dt

-- View table structure
\d repositories

-- Query data
SELECT * FROM repositories LIMIT 10;

-- Exit
\q
```

### Check Application Events
```bash
kubectl get events -n github-etl --sort-by='.lastTimestamp'
```

---

## 🔄 After Code Changes (CI/CD)

When you push code to the `github-etl` app repository:

1. **GitHub Actions builds new image** (~2-3 minutes)
2. **Infrastructure repo gets updated** with new tag
3. **Load the new image:**
   ```bash
   # Get latest tag
   TAG=$(curl -s https://raw.githubusercontent.com/ejpolicarpio/github-etl-infrastructure/main/helm/github-etl/values-dev.yaml | grep "tag:" | awk '{print $2}')

   # Pull and load
   docker pull ghcr.io/ejpolicarpio/github-etl:$TAG
   minikube image load ghcr.io/ejpolicarpio/github-etl:$TAG

   # Restart
   kubectl rollout restart deployment github-etl -n github-etl
   ```

4. **Wait for deployment:**
   ```bash
   kubectl get pods -n github-etl -w
   ```

5. **Verify new version:**
   - Check application logs
   - Test endpoints in browser
   - View ArgoCD dashboard

---

## 🐛 Troubleshooting

### Pod Status: ImagePullBackOff
**Problem:** Minikube can't pull image from GitHub Container Registry

**Solution:**
```bash
TAG=$(grep "tag:" helm/github-etl/values-dev.yaml | awk '{print $2}')
docker pull ghcr.io/ejpolicarpio/github-etl:$TAG
minikube image load ghcr.io/ejpolicarpio/github-etl:$TAG
kubectl rollout restart deployment github-etl -n github-etl
```

### Pod Status: CrashLoopBackOff
**Problem:** Application is crashing on startup

**Check logs:**
```bash
kubectl logs <pod-name> -n github-etl
```

**Common causes:**
- Database connection failed
- Missing environment variables
- Application code error

### Application Not Accessible
**Check if pods are running:**
```bash
kubectl get pods -n github-etl
```

**Check if service exists:**
```bash
kubectl get svc -n github-etl
```

**Get the correct URL:**
```bash
echo "http://$(minikube ip):30080/docs"
```

### Minikube Won't Start
```bash
# Check status
minikube status

# Delete and recreate (last resort)
minikube delete
./scripts/setup-minikube.sh
```

### ArgoCD Not Syncing
**Force sync:**
```bash
kubectl patch application github-etl-dev -n argocd \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' \
  --type merge
```

**Or use the ArgoCD UI:** Click the "Sync" button

---

## 🛑 Stopping Everything

### Stop Minikube (Preserves Data)
```bash
minikube stop
```
**Note:** Everything will be saved. Just run `minikube start` to resume.

### Delete Everything (Clean Slate)
```bash
# Delete the application
helm uninstall github-etl -n github-etl
kubectl delete namespace github-etl

# Delete Minikube cluster
minikube delete
```

---

## 📊 Quick Health Check

Run this to verify everything is working:

```bash
echo "=== Minikube Status ==="
minikube status

echo -e "\n=== Pods Status ==="
kubectl get pods -n github-etl

echo -e "\n=== Services ==="
kubectl get svc -n github-etl

echo -e "\n=== Application URL ==="
echo "http://$(minikube ip):30080/docs"

echo -e "\n=== ArgoCD Applications ==="
kubectl get application -n argocd
```

---

## 📚 More Information

- **Detailed Guide:** [DEPLOYMENT-GUIDE.md](./DEPLOYMENT-GUIDE.md)
- **Full README:** [README.md](./README.md)
- **Kubernetes Docs:** https://kubernetes.io/docs/
- **Helm Docs:** https://helm.sh/docs/
- **ArgoCD Docs:** https://argo-cd.readthedocs.io/

---

## 🎯 TL;DR - Absolute Minimum

```bash
# 1. Start
minikube start

# 2. Check
kubectl get pods -n github-etl

# 3. If not running, load image
TAG=$(grep "tag:" helm/github-etl/values-dev.yaml | awk '{print $2}')
docker pull ghcr.io/ejpolicarpio/github-etl:$TAG
minikube image load ghcr.io/ejpolicarpio/github-etl:$TAG
kubectl rollout restart deployment github-etl -n github-etl

# 4. Access
echo "http://$(minikube ip):30080/docs"
```

**Open that URL in your browser!** 🚀

---

**Last Updated:** October 2025