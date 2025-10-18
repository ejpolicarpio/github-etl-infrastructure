.PHONY: help setup-minikube install-argocd deploy-app install-observability access-grafana access-argocd status clean upgrade-observability full-setup
# Default target - show help
help:
	@echo "Available commands:"
	@echo "  make setup-minikube        - Start Minikube cluster"
	@echo "  make install-argocd        - Install ArgoCD"
	@echo "  make deploy-app           - Deploy github-etl application"
	@echo "  make install-observability - Install observability stack"
	@echo "  make access-grafana        - Get Grafana URL and credentials"
	@echo "  make access-argocd         - Port-forward to ArgoCD"
	@echo "  make status                - Show status of all components"
	@echo "  make clean                 - Delete everything"

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
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Full setup from scratch
full-setup: setup-minikube install-argocd deploy-app install-observability
	@echo ""
	@echo "🎉 Full setup complete!"
	@$(MAKE) status