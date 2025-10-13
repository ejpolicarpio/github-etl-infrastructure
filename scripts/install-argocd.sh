#!/bin/bash

set -e  # Exit on any error

echo "🔧 Installing ArgoCD..."

# Create argocd namespace
echo "📦 Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo "⬇️  Installing ArgoCD components..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready (this may take 2-3 minutes)..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Patch argocd-server service to use NodePort for easy access
echo "🔌 Configuring ArgoCD server access..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# Get the ArgoCD admin password
echo ""
echo "✅ ArgoCD installation complete!"
echo ""
echo "📋 Access Information:"
echo "   Dashboard: http://$(minikube ip):$(kubectl get svc argocd-server -n argocd -o
jsonpath='{.spec.ports[0].nodePort}')"
echo "   Username: admin"
echo "   Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64
-d)"
echo ""
echo "💡 Tip: You can also use port-forward:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Then access: https://localhost:8080"