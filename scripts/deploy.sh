#!/bin/bash

set -e  # Exit on any error

# Get environment argument (default to dev)
ENVIRONMENT=${1:-dev}

# Validate environment
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo "❌ Invalid environment: $ENVIRONMENT"
    echo "Usage: $0 [dev|prod]"
    exit 1
fi

echo "🚀 Deploying GitHub ETL to $ENVIRONMENT environment..."

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed. Please install it first:"
    echo "   macOS: brew install helm"
    echo "   Linux: https://helm.sh/docs/intro/install/"
    exit 1
fi

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ kubectl is not configured or cluster is not accessible"
    echo "   Run './scripts/setup-minikube.sh' first"
    exit 1
fi

# Set values file based on environment
VALUES_FILE="helm/github-etl/values-${ENVIRONMENT}.yaml"

echo "📦 Installing/Upgrading github-etl chart..."
helm upgrade --install github-etl ./helm/github-etl \
    --values helm/github-etl/values.yaml \
    --values $VALUES_FILE \
    --create-namespace \
    --namespace github-etl \
    --wait \
    --timeout 5m

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Deployment Information:"
kubectl get all -n github-etl

echo ""
echo "🔍 Checking pod status..."
kubectl get pods -n github-etl -w &
WATCH_PID=$!
sleep 5
kill $WATCH_PID 2>/dev/null || true

echo ""
echo "📊 Access Information:"
if [[ "$ENVIRONMENT" == "dev" ]]; then
    NODE_PORT=$(kubectl get svc github-etl -n github-etl -o jsonpath='{.spec.ports[0].nodePort}')
    echo "   Application: http://$(minikube ip):${NODE_PORT}"
    echo "   API Docs: http://$(minikube ip):${NODE_PORT}/docs"
    echo ""
    echo "💡 Tip: You can also use port-forward:"
    echo "   kubectl port-forward -n github-etl svc/github-etl 8000:8000"
    echo "   Then access: http://localhost:8000"
else
    echo "   Application: kubectl port-forward -n github-etl svc/github-etl 8000:8000"
    echo "   Then access: http://localhost:8000"
fi

echo ""
echo "📝 Useful commands:"
echo "   View logs: kubectl logs -f -n github-etl -l app=github-etl"
echo "   View postgres logs: kubectl logs -f -n github-etl -l app=github-etl-postgres"
echo "   Shell into app: kubectl exec -it -n github-etl deployment/github-etl -- /bin/sh"
echo "   Delete deployment: helm uninstall github-etl -n github-etl"