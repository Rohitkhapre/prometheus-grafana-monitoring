#!/bin/bash

# Prometheus & Grafana Monitoring Stack Deployment Script
# This script automatically detects the environment and deploys the appropriate monitoring stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect the environment
detect_environment() {
    log_info "Detecting environment..."
    
    if command_exists kubectl; then
        if kubectl cluster-info >/dev/null 2>&1; then
            ENVIRONMENT="kubernetes"
            log_success "Kubernetes environment detected"
            return
        fi
    fi
    
    if command_exists docker && command_exists docker-compose; then
        if docker info >/dev/null 2>&1; then
            ENVIRONMENT="docker"
            log_success "Docker environment detected"
            return
        fi
    fi
    
    log_error "No supported environment detected. Please ensure Docker or Kubernetes is available."
    exit 1
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    case $ENVIRONMENT in
        "docker")
            if ! command_exists docker; then
                log_error "Docker is not installed"
                exit 1
            fi
            
            if ! command_exists docker-compose; then
                log_error "Docker Compose is not installed"
                exit 1
            fi
            
            if ! docker info >/dev/null 2>&1; then
                log_error "Docker daemon is not running"
                exit 1
            fi
            ;;
        "kubernetes")
            if ! command_exists kubectl; then
                log_error "kubectl is not installed"
                exit 1
            fi
            
            if ! kubectl cluster-info >/dev/null 2>&1; then
                log_error "Cannot connect to Kubernetes cluster"
                exit 1
            fi
            ;;
    esac
    
    log_success "Prerequisites check passed"
}

# Function to create necessary directories
create_directories() {
    log_info "Creating necessary directories..."
    
    mkdir -p data/prometheus
    mkdir -p data/grafana
    mkdir -p data/alertmanager
    mkdir -p logs
    
    # Set proper permissions
    chmod 755 data/prometheus
    chmod 755 data/grafana
    chmod 755 data/alertmanager
    chmod 755 logs
    
    log_success "Directories created successfully"
}

# Function to deploy with Docker Compose
deploy_docker() {
    log_info "Deploying with Docker Compose..."
    
    # Stop existing containers if any
    docker-compose down 2>/dev/null || true
    
    # Pull latest images
    log_info "Pulling latest images..."
    docker-compose pull
    
    # Start services
    log_info "Starting services..."
    docker-compose up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 30
    
    # Check service health
    check_service_health
    
    log_success "Docker deployment completed"
}

# Function to deploy with Kubernetes
deploy_kubernetes() {
    log_info "Deploying with Kubernetes..."
    
    # Apply namespace first
    kubectl apply -f kubernetes/namespace.yaml
    
    # Apply RBAC
    kubectl apply -f kubernetes/rbac.yaml
    
    # Apply ConfigMaps
    kubectl apply -f kubernetes/prometheus-configmap.yaml
    
    # Apply deployments
    kubectl apply -f kubernetes/prometheus-deployment.yaml
    kubectl apply -f kubernetes/grafana-deployment.yaml
    kubectl apply -f kubernetes/node-exporter-daemonset.yaml
    
    # Apply ingress (optional)
    if [ "$1" = "--with-ingress" ]; then
        kubectl apply -f kubernetes/ingress.yaml
        log_info "Ingress configuration applied"
    fi
    
    # Wait for deployments to be ready
    log_info "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring
    
    log_success "Kubernetes deployment completed"
}

# Function to check service health
check_service_health() {
    log_info "Checking service health..."
    
    case $ENVIRONMENT in
        "docker")
            # Check if containers are running
            if docker-compose ps | grep -q "Up"; then
                log_success "All services are running"
            else
                log_error "Some services are not running"
                docker-compose ps
                exit 1
            fi
            ;;
        "kubernetes")
            # Check pod status
            if kubectl get pods -n monitoring | grep -q "Running"; then
                log_success "All pods are running"
            else
                log_error "Some pods are not running"
                kubectl get pods -n monitoring
                exit 1
            fi
            ;;
    esac
}

# Function to display access information
display_access_info() {
    log_info "Displaying access information..."
    
    case $ENVIRONMENT in
        "docker")
            echo ""
            echo "=========================================="
            echo "  Monitoring Stack Access Information"
            echo "=========================================="
            echo "Grafana:     http://localhost:3000"
            echo "Prometheus:  http://localhost:9090"
            echo "Alertmanager: http://localhost:9093"
            echo ""
            echo "Default Credentials:"
            echo "Grafana: admin/admin"
            echo "=========================================="
            ;;
        "kubernetes")
            echo ""
            echo "=========================================="
            echo "  Monitoring Stack Access Information"
            echo "=========================================="
            echo "To access services, use port-forward:"
            echo "kubectl port-forward -n monitoring svc/grafana 3000:3000"
            echo "kubectl port-forward -n monitoring svc/prometheus 9090:9090"
            echo "kubectl port-forward -n monitoring svc/alertmanager 9093:9093"
            echo ""
            echo "Default Credentials:"
            echo "Grafana: admin/admin"
            echo "=========================================="
            ;;
    esac
}

# Function to show logs
show_logs() {
    case $ENVIRONMENT in
        "docker")
            docker-compose logs -f
            ;;
        "kubernetes")
            kubectl logs -f -n monitoring -l app=prometheus
            ;;
    esac
}

# Function to cleanup
cleanup() {
    log_info "Cleaning up..."
    
    case $ENVIRONMENT in
        "docker")
            docker-compose down -v
            docker system prune -f
            ;;
        "kubernetes")
            kubectl delete namespace monitoring
            ;;
    esac
    
    log_success "Cleanup completed"
}

# Main function
main() {
    echo "=========================================="
    echo "  Prometheus & Grafana Monitoring Stack"
    echo "=========================================="
    
    # Parse command line arguments
    case "${1:-}" in
        "cleanup")
            detect_environment
            cleanup
            exit 0
            ;;
        "logs")
            detect_environment
            show_logs
            exit 0
            ;;
        "status")
            detect_environment
            check_service_health
            exit 0
            ;;
        "--help" | "-h")
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  cleanup    Remove all monitoring components"
            echo "  logs       Show logs from all services"
            echo "  status     Check status of all services"
            echo "  --help     Show this help message"
            echo ""
            echo "Environment Detection:"
            echo "  The script automatically detects Docker or Kubernetes environment"
            echo "  and deploys the appropriate monitoring stack."
            exit 0
            ;;
    esac
    
    # Main deployment flow
    detect_environment
    check_prerequisites
    create_directories
    
    case $ENVIRONMENT in
        "docker")
            deploy_docker
            ;;
        "kubernetes")
            deploy_kubernetes "$@"
            ;;
    esac
    
    display_access_info
    
    log_success "Deployment completed successfully!"
    log_info "Use '$0 logs' to view logs"
    log_info "Use '$0 status' to check status"
    log_info "Use '$0 cleanup' to remove all components"
}

# Run main function with all arguments
main "$@"
