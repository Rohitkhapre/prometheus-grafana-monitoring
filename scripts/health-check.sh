#!/bin/bash

# Health Check Script for Prometheus & Grafana Monitoring Stack
# This script performs comprehensive health checks on all monitoring components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TIMEOUT=30
RETRY_COUNT=3

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

# Function to detect environment
detect_environment() {
    if command_exists kubectl && kubectl cluster-info >/dev/null 2>&1; then
        ENVIRONMENT="kubernetes"
    elif command_exists docker && docker info >/dev/null 2>&1; then
        ENVIRONMENT="docker"
    else
        log_error "No supported environment detected"
        exit 1
    fi
    log_info "Environment detected: $ENVIRONMENT"
}

# Function to check HTTP endpoint
check_http_endpoint() {
    local url=$1
    local service_name=$2
    local expected_status=${3:-200}
    
    log_info "Checking $service_name at $url"
    
    for i in $(seq 1 $RETRY_COUNT); do
        if response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "$url" 2>/dev/null); then
            if [ "$response" = "$expected_status" ]; then
                log_success "$service_name is healthy (HTTP $response)"
                return 0
            else
                log_warning "$service_name returned HTTP $response (expected $expected_status)"
            fi
        else
            log_warning "$service_name connection failed (attempt $i/$RETRY_COUNT)"
        fi
        
        if [ $i -lt $RETRY_COUNT ]; then
            sleep 5
        fi
    done
    
    log_error "$service_name health check failed"
    return 1
}

# Function to check Docker services
check_docker_services() {
    log_info "Checking Docker services..."
    
    # Check if containers are running
    local containers=("prometheus" "grafana" "node-exporter" "cadvisor" "alertmanager" "blackbox-exporter")
    local failed_containers=()
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            log_success "Container $container is running"
        else
            log_error "Container $container is not running"
            failed_containers+=("$container")
        fi
    done
    
    if [ ${#failed_containers[@]} -gt 0 ]; then
        log_error "Failed containers: ${failed_containers[*]}"
        return 1
    fi
    
    # Check service endpoints
    check_http_endpoint "http://localhost:9090/-/healthy" "Prometheus" 200
    check_http_endpoint "http://localhost:3000/api/health" "Grafana" 200
    check_http_endpoint "http://localhost:9093/-/healthy" "Alertmanager" 200
    check_http_endpoint "http://localhost:9100/metrics" "Node Exporter" 200
    check_http_endpoint "http://localhost:8080/healthz" "cAdvisor" 200
    check_http_endpoint "http://localhost:9115/metrics" "Blackbox Exporter" 200
}

# Function to check Kubernetes services
check_kubernetes_services() {
    log_info "Checking Kubernetes services..."
    
    # Check if namespace exists
    if ! kubectl get namespace monitoring >/dev/null 2>&1; then
        log_error "Monitoring namespace does not exist"
        return 1
    fi
    
    # Check pod status
    local pods=("prometheus" "grafana" "node-exporter")
    local failed_pods=()
    
    for pod in "${pods[@]}"; do
        if kubectl get pods -n monitoring -l app="$pod" --no-headers 2>/dev/null | grep -q "Running"; then
            log_success "Pod $pod is running"
        else
            log_error "Pod $pod is not running"
            failed_pods+=("$pod")
        fi
    done
    
    if [ ${#failed_pods[@]} -gt 0 ]; then
        log_error "Failed pods: ${failed_pods[*]}"
        return 1
    fi
    
    # Check service endpoints via port-forward
    log_info "Checking service endpoints..."
    
    # Start port-forwarding in background
    kubectl port-forward -n monitoring svc/prometheus 9090:9090 >/dev/null 2>&1 &
    local prometheus_pf=$!
    kubectl port-forward -n monitoring svc/grafana 3000:3000 >/dev/null 2>&1 &
    local grafana_pf=$!
    kubectl port-forward -n monitoring svc/alertmanager 9093:9093 >/dev/null 2>&1 &
    local alertmanager_pf=$!
    
    # Wait for port-forwarding to be ready
    sleep 5
    
    # Check endpoints
    check_http_endpoint "http://localhost:9090/-/healthy" "Prometheus" 200
    check_http_endpoint "http://localhost:3000/api/health" "Grafana" 200
    check_http_endpoint "http://localhost:9093/-/healthy" "Alertmanager" 200
    
    # Cleanup port-forwarding
    kill $prometheus_pf $grafana_pf $alertmanager_pf 2>/dev/null || true
}

# Function to check metrics collection
check_metrics_collection() {
    log_info "Checking metrics collection..."
    
    # Check Prometheus targets
    local targets_url="http://localhost:9090/api/v1/targets"
    if [ "$ENVIRONMENT" = "kubernetes" ]; then
        kubectl port-forward -n monitoring svc/prometheus 9090:9090 >/dev/null 2>&1 &
        local pf_pid=$!
        sleep 5
    fi
    
    if targets_response=$(curl -s --connect-timeout $TIMEOUT "$targets_url" 2>/dev/null); then
        local active_targets=$(echo "$targets_response" | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
        local up_targets=$(echo "$targets_response" | jq -r '.data.activeTargets | map(select(.health == "up")) | length' 2>/dev/null || echo "0")
        
        if [ "$up_targets" -gt 0 ]; then
            log_success "Metrics collection is working ($up_targets/$active_targets targets up)"
        else
            log_error "No targets are up for metrics collection"
        fi
    else
        log_error "Failed to check Prometheus targets"
    fi
    
    if [ "$ENVIRONMENT" = "kubernetes" ] && [ -n "$pf_pid" ]; then
        kill $pf_pid 2>/dev/null || true
    fi
}

# Function to check disk usage
check_disk_usage() {
    log_info "Checking disk usage..."
    
    case $ENVIRONMENT in
        "docker")
            # Check Docker volume usage
            local volumes=("prometheus_data" "grafana_data" "alertmanager_data")
            for volume in "${volumes[@]}"; do
                if docker volume inspect "$volume" >/dev/null 2>&1; then
                    local size=$(docker system df -v | grep "$volume" | awk '{print $3}' || echo "unknown")
                    log_info "Volume $volume size: $size"
                fi
            done
            ;;
        "kubernetes")
            # Check PVC usage
            kubectl get pvc -n monitoring --no-headers 2>/dev/null | while read -r name status size; do
                log_info "PVC $name: $size"
            done
            ;;
    esac
}

# Function to check resource usage
check_resource_usage() {
    log_info "Checking resource usage..."
    
    case $ENVIRONMENT in
        "docker")
            # Check container resource usage
            docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "(prometheus|grafana|node-exporter|cadvisor|alertmanager)" || true
            ;;
        "kubernetes")
            # Check pod resource usage
            kubectl top pods -n monitoring 2>/dev/null || log_warning "Metrics server not available"
            ;;
    esac
}

# Function to generate health report
generate_health_report() {
    local report_file="health-report-$(date +%Y%m%d-%H%M%S).txt"
    
    log_info "Generating health report: $report_file"
    
    {
        echo "=========================================="
        echo "  Monitoring Stack Health Report"
        echo "  Generated: $(date)"
        echo "  Environment: $ENVIRONMENT"
        echo "=========================================="
        echo ""
        
        case $ENVIRONMENT in
            "docker")
                echo "=== Docker Services ==="
                docker-compose ps
                echo ""
                echo "=== Container Resource Usage ==="
                docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
                echo ""
                ;;
            "kubernetes")
                echo "=== Kubernetes Pods ==="
                kubectl get pods -n monitoring
                echo ""
                echo "=== Pod Resource Usage ==="
                kubectl top pods -n monitoring 2>/dev/null || echo "Metrics server not available"
                echo ""
                ;;
        esac
        
        echo "=== Service Health ==="
        echo "Prometheus: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy 2>/dev/null || echo "unreachable")"
        echo "Grafana: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health 2>/dev/null || echo "unreachable")"
        echo "Alertmanager: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:9093/-/healthy 2>/dev/null || echo "unreachable")"
        echo ""
        
    } > "$report_file"
    
    log_success "Health report saved to $report_file"
}

# Main function
main() {
    echo "=========================================="
    echo "  Monitoring Stack Health Check"
    echo "=========================================="
    
    detect_environment
    
    local overall_status=0
    
    # Run health checks
    case $ENVIRONMENT in
        "docker")
            if ! check_docker_services; then
                overall_status=1
            fi
            ;;
        "kubernetes")
            if ! check_kubernetes_services; then
                overall_status=1
            fi
            ;;
    esac
    
    check_metrics_collection
    check_disk_usage
    check_resource_usage
    
    # Generate report if requested
    if [ "${1:-}" = "--report" ]; then
        generate_health_report
    fi
    
    # Summary
    echo ""
    echo "=========================================="
    if [ $overall_status -eq 0 ]; then
        log_success "All health checks passed!"
    else
        log_error "Some health checks failed!"
    fi
    echo "=========================================="
    
    exit $overall_status
}

# Run main function with all arguments
main "$@"
