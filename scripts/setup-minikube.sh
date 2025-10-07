#!/bin/bash

set -e  # Exit on any error

echo "🚀 Setting up Minikube cluster..."

# Check if Minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "❌ Minikube is not installed. Please install it first:"
    echo "   macOS: brew install minikube"
    echo "   Linux: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker Desktop first."
    exit 1
fi

# Check if Minikube is already running
if minikube status &> /dev/null; then
    echo "✅ Minikube is already running"
else
    echo "🔧 Starting Minikube with Docker driver..."
    minikube start --driver=docker --cpus=4 --memory=8192
fi

# Enable necessary addons
echo "🔌 Enabling Minikube addons..."
minikube addons enable ingress
minikube addons enable metrics-server

# Verify cluster is ready
echo "✅ Verifying cluster..."
kubectl cluster-info

echo ""
echo "🎉 Minikube setup complete!"
echo "   Cluster: $(kubectl config current-context)"
echo "   Nodes: $(kubectl get nodes --no-headers | wc -l | tr -d ' ')"
echo ""
echo "💡 Tip: Use 'minikube dashboard' to open the Kubernetes dashboard"