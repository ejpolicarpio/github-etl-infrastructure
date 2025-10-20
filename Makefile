.PHONY: help setup-minikube install-argocd deploy-app install-observability access-grafana access-argocd status clean upgrade-observability full-setup create-ghcr-secret apply-instrumentation setup-observability

# Default target - show help
help:
	@echo "Available commands:"
	@echo "  make setup-minikube           - Start Minikube cluster"
	@echo "  make install-argocd           - Install ArgoCD"
	@echo "  make deploy-app              - Deploy github-etl application"
	@echo "  make install-observability    - Install observability stack"
	@echo "  make setup-observability      - Complete observability setup (stack + secrets + instrumentation)"
	@echo "  make create-ghcr-secret       - Create GitHub Container Registry pull secret"
	@echo "  make apply-instrumentation    - Apply OpenTelemetry Instrumentation resource"
	@echo "  make access-grafana           - Get Grafana URL and credentials"
	@echo "  make access-argocd            - Port-forward to ArgoCD"
	@echo "  make status                   - Show status of all components"
	@echo "  make clean                    - Delete everything"
	@echo "  make full-setup               - Complete setup from scratch (Minikube + ArgoCD + App + Observability)"

# Setup Minikube
setup-minikube:
	@echo "🚀 Starting Minikube..."
	./scripts/setup-minikube.sh

# Install ArgoCD
install-argocd:
	@echo "🔧 Installing ArgoCD..."
	./scripts/install-argocd.sh

# Deploy application
deploy-app:
	@echo "📦 Deploying application..."
	./scripts/deploy.sh dev

# Install observability stack
install-observability:
	@echo "📊 Installing observability stack..."
	helm dependency update helm/observability
	helm install observability ./helm/observability \
					--values helm/observability/values.yaml \
					--values helm/observability/values-dev.yaml \
					--namespace observability \
					--create-namespace \
					--wait \
					--timeout 10m
	@echo ""
	@echo "✅ Observability stack installed!"
	@$(MAKE) access-grafana

# Create GitHub Container Registry secret
create-ghcr-secret:
	@echo "🔐 Creating GitHub Container Registry secret..."
	@echo "⚠️  You need to provide your GitHub Personal Access Token"
	@read -p "Enter your GitHub username [ejpolicarpio]: " GITHUB_USER; \
	GITHUB_USER=$${GITHUB_USER:-ejpolicarpio}; \
	read -p "Enter your GitHub email: " GITHUB_EMAIL; \
	read -sp "Enter your GitHub PAT (with read:packages scope): " GITHUB_PAT; \
	echo ""; \
	kubectl create secret docker-registry ghcr-secret \
			--docker-server=ghcr.io \
			--docker-username=$$GITHUB_USER \
			--docker-password=$$GITHUB_PAT \
			--docker-email=$$GITHUB_EMAIL \
			-n github-etl || echo "Secret may already exist"

# Apply OpenTelemetry Instrumentation
apply-instrumentation:
	@echo "🔭 Applying OpenTelemetry Instrumentation..."
	kubectl apply -f k8s/dev/instrumentation.yaml

# Complete observability setup
setup-observability: install-observability apply-instrumentation
	@echo ""
	@echo "✅ Complete observability setup finished!"
	@echo "   - Observability stack: Installed"
	@echo "   - OpenTelemetry Instrumentation: Applied"
	@echo ""
	@echo "📊 Access Grafana with: make access-grafana"

# Upgrade observability stack
upgrade-observability:
	@echo "🔄 Upgrading observability stack..."
	helm dependency update helm/observability
	helm upgrade observability ./helm/observability \
					--values helm/observability/values.yaml \
					--values helm/observability/values-dev.yaml \
					--namespace observability \
					--wait \
					--timeout 10m

# Access Grafana
access-grafana:
	@echo ""
	@echo "📊 Opening Grafana in your browser..."
	@echo "   Username: admin"
	@echo "   Password: admin"
	@echo ""
	minikube service observability-grafana -n observability

# Port-forward to ArgoCD
access-argocd:
	@echo "🎛️  Starting ArgoCD port-forward..."
	@echo "   Access at: https://localhost:8080"
	@echo "   Username: admin"
	@echo "   Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" |base64 -d)"
	@echo ""
	kubectl port-forward svc/argocd-server -n argocd 8080:443

# Show status of all components
status:
	@echo "=== Minikube Status ==="
	@minikube status || true
	@echo ""
	@echo "=== Application Pods ==="
	@kubectl get pods -n github-etl || true
	@echo ""
	@echo "=== Observability Pods ==="
	@kubectl get pods -n observability || true
	@echo ""
	@echo "=== ArgoCD Applications ==="
	@kubectl get application -n argocd || true

# Clean up everything
clean:
	@echo "⚠️  This will delete everything!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
					helm uninstall github-etl -n github-etl || true; \
					helm uninstall observability -n observability || true; \
					kubectl delete namespace github-etl || true; \
					kubectl delete namespace observability || true; \
					minikube delete; \
	fi

# Install cert-manager
install-cert-manager:
	@echo "📜 Installing cert-manager..."
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
	@echo "⏳ Waiting for cert-manager to be ready..."
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s

# Full setup from scratch
full-setup: setup-minikube install-cert-manager create-ghcr-secret install-argocd deploy-app install-observability apply-instrumentation
	@echo ""
	@echo "🎉 Full setup complete!"
	@echo ""
	@echo "📋 Summary:"
	@echo "   ✅ Minikube cluster running"
	@echo "   ✅ cert-manager installed"
	@echo "   ✅ GitHub Container Registry secret created"
	@echo "   ✅ ArgoCD installed and managing deployments"
	@echo "   ✅ github-etl application deployed"
	@echo "   ✅ Observability stack (Grafana, Prometheus, Loki, Tempo, Alloy) installed"
	@echo "   ✅ OpenTelemetry auto-instrumentation configured"
	@echo ""
	@echo "🌐 Access Points:"
	@echo "   - Grafana: make access-grafana"
	@echo "   - ArgoCD: make access-argocd"
	@echo "   - App status: make status"
	@echo ""
	@$(MAKE) status