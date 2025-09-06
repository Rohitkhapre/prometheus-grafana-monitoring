# Prometheus & Grafana Monitoring Stack Makefile

.PHONY: help deploy clean status logs backup health-check

# Default target
help: ## Show this help message
	@echo "Prometheus & Grafana Monitoring Stack"
	@echo "====================================="
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Deployment targets
deploy: ## Deploy the monitoring stack
	@echo "Deploying monitoring stack..."
	@./scripts/deploy.sh

deploy-docker: ## Deploy using Docker Compose
	@echo "Deploying with Docker Compose..."
	@docker-compose up -d

deploy-k8s: ## Deploy to Kubernetes
	@echo "Deploying to Kubernetes..."
	@kubectl apply -f kubernetes/namespace.yaml
	@kubectl apply -f kubernetes/rbac.yaml
	@kubectl apply -f kubernetes/prometheus-configmap.yaml
	@kubectl apply -f kubernetes/prometheus-deployment.yaml
	@kubectl apply -f kubernetes/grafana-deployment.yaml
	@kubectl apply -f kubernetes/node-exporter-daemonset.yaml

# Management targets
status: ## Check status of all services
	@echo "Checking service status..."
	@./scripts/health-check.sh

logs: ## Show logs from all services
	@echo "Showing service logs..."
	@./scripts/deploy.sh logs

backup: ## Create a backup
	@echo "Creating backup..."
	@./scripts/backup.sh

restore: ## Restore from backup (usage: make restore BACKUP_FILE=backup.tar.gz)
	@echo "Restoring from backup: $(BACKUP_FILE)"
	@./scripts/backup.sh restore $(BACKUP_FILE)

health-check: ## Run comprehensive health check
	@echo "Running health check..."
	@./scripts/health-check.sh --report

# Cleanup targets
clean: ## Stop and remove all services
	@echo "Cleaning up services..."
	@./scripts/deploy.sh cleanup

clean-docker: ## Clean up Docker resources
	@echo "Cleaning up Docker resources..."
	@docker-compose down -v
	@docker system prune -f

clean-k8s: ## Clean up Kubernetes resources
	@echo "Cleaning up Kubernetes resources..."
	@kubectl delete namespace monitoring

# Development targets
dev: ## Start development environment
	@echo "Starting development environment..."
	@docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

dev-logs: ## Show development logs
	@echo "Showing development logs..."
	@docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

# Testing targets
test: ## Run tests
	@echo "Running tests..."
	@./scripts/health-check.sh

test-config: ## Validate configuration files
	@echo "Validating configuration files..."
	@docker run --rm -v $(PWD)/configs:/configs prom/prometheus:latest promtool check config /configs/prometheus.yml
	@docker run --rm -v $(PWD)/configs:/configs prom/alertmanager:latest amtool check-config /configs/alertmanager.yml

# Utility targets
pull: ## Pull latest images
	@echo "Pulling latest images..."
	@docker-compose pull

update: ## Update to latest versions
	@echo "Updating to latest versions..."
	@docker-compose pull
	@docker-compose up -d

port-forward: ## Set up port forwarding for Kubernetes
	@echo "Setting up port forwarding..."
	@kubectl port-forward -n monitoring svc/grafana 3000:3000 &
	@kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
	@kubectl port-forward -n monitoring svc/alertmanager 9093:9093 &
	@echo "Port forwarding active. Press Ctrl+C to stop."

# Documentation targets
docs: ## Generate documentation
	@echo "Generating documentation..."
	@echo "Documentation is available in the docs/ directory"

# Security targets
security-scan: ## Run security scan
	@echo "Running security scan..."
	@docker run --rm -v $(PWD):/workspace securecodewarrior/docker-security-scan:latest /workspace

# Monitoring targets
monitor: ## Monitor resource usage
	@echo "Monitoring resource usage..."
	@watch -n 5 'docker stats --no-stream || kubectl top pods -n monitoring'

# Backup management
list-backups: ## List available backups
	@echo "Available backups:"
	@./scripts/backup.sh list

cleanup-backups: ## Clean up old backups
	@echo "Cleaning up old backups..."
	@./scripts/backup.sh cleanup

# Environment setup
setup: ## Initial setup
	@echo "Setting up monitoring stack..."
	@mkdir -p data/{prometheus,grafana,alertmanager}
	@mkdir -p logs
	@mkdir -p backups
	@chmod +x scripts/*.sh
	@echo "Setup complete!"

# Quick access targets
grafana: ## Open Grafana in browser
	@echo "Opening Grafana..."
	@open http://localhost:3000 || xdg-open http://localhost:3000 || echo "Please open http://localhost:3000 in your browser"

prometheus: ## Open Prometheus in browser
	@echo "Opening Prometheus..."
	@open http://localhost:9090 || xdg-open http://localhost:9090 || echo "Please open http://localhost:9090 in your browser"

alertmanager: ## Open Alertmanager in browser
	@echo "Opening Alertmanager..."
	@open http://localhost:9093 || xdg-open http://localhost:9093 || echo "Please open http://localhost:9093 in your browser"

# All-in-one targets
start: setup deploy ## Complete setup and deployment
	@echo "Monitoring stack is ready!"
	@echo "Access Grafana at: http://localhost:3000 (admin/admin)"
	@echo "Access Prometheus at: http://localhost:9090"
	@echo "Access Alertmanager at: http://localhost:9093"

stop: clean ## Stop all services
	@echo "All services stopped"

restart: stop start ## Restart all services
	@echo "Services restarted"

# Default target
.DEFAULT_GOAL := help
