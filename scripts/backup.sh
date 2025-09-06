#!/bin/bash

# Backup Script for Prometheus & Grafana Monitoring Stack
# This script creates backups of configuration and data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="monitoring-backup-$TIMESTAMP"

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

# Function to create backup directory
create_backup_directory() {
    log_info "Creating backup directory..."
    mkdir -p "$BACKUP_DIR/$BACKUP_NAME"
    log_success "Backup directory created: $BACKUP_DIR/$BACKUP_NAME"
}

# Function to backup Docker data
backup_docker_data() {
    log_info "Backing up Docker data..."
    
    # Create backup of volumes
    local volumes=("prometheus_data" "grafana_data" "alertmanager_data")
    
    for volume in "${volumes[@]}"; do
        if docker volume inspect "$volume" >/dev/null 2>&1; then
            log_info "Backing up volume: $volume"
            docker run --rm -v "$volume":/data -v "$(pwd)/$BACKUP_DIR/$BACKUP_NAME":/backup alpine tar czf "/backup/$volume.tar.gz" -C /data .
            log_success "Volume $volume backed up"
        else
            log_warning "Volume $volume not found"
        fi
    done
    
    # Backup docker-compose configuration
    if [ -f "docker-compose.yml" ]; then
        cp docker-compose.yml "$BACKUP_DIR/$BACKUP_NAME/"
        log_success "Docker Compose configuration backed up"
    fi
}

# Function to backup Kubernetes data
backup_kubernetes_data() {
    log_info "Backing up Kubernetes data..."
    
    # Backup namespace and resources
    kubectl get namespace monitoring -o yaml > "$BACKUP_DIR/$BACKUP_NAME/namespace.yaml" 2>/dev/null || true
    
    # Backup all resources in monitoring namespace
    kubectl get all -n monitoring -o yaml > "$BACKUP_DIR/$BACKUP_NAME/resources.yaml" 2>/dev/null || true
    
    # Backup ConfigMaps
    kubectl get configmaps -n monitoring -o yaml > "$BACKUP_DIR/$BACKUP_NAME/configmaps.yaml" 2>/dev/null || true
    
    # Backup Secrets
    kubectl get secrets -n monitoring -o yaml > "$BACKUP_DIR/$BACKUP_NAME/secrets.yaml" 2>/dev/null || true
    
    # Backup PVCs
    kubectl get pvc -n monitoring -o yaml > "$BACKUP_DIR/$BACKUP_NAME/pvcs.yaml" 2>/dev/null || true
    
    # Backup RBAC
    kubectl get clusterrole,clusterrolebinding,role,rolebinding -n monitoring -o yaml > "$BACKUP_DIR/$BACKUP_NAME/rbac.yaml" 2>/dev/null || true
    
    log_success "Kubernetes resources backed up"
}

# Function to backup configuration files
backup_configuration() {
    log_info "Backing up configuration files..."
    
    # Backup all configuration files
    if [ -d "configs" ]; then
        cp -r configs "$BACKUP_DIR/$BACKUP_NAME/"
        log_success "Configuration files backed up"
    fi
    
    # Backup dashboards
    if [ -d "dashboards" ]; then
        cp -r dashboards "$BACKUP_DIR/$BACKUP_NAME/"
        log_success "Dashboard files backed up"
    fi
    
    # Backup Kubernetes manifests
    if [ -d "kubernetes" ]; then
        cp -r kubernetes "$BACKUP_DIR/$BACKUP_NAME/"
        log_success "Kubernetes manifests backed up"
    fi
    
    # Backup scripts
    if [ -d "scripts" ]; then
        cp -r scripts "$BACKUP_DIR/$BACKUP_NAME/"
        log_success "Scripts backed up"
    fi
}

# Function to backup Grafana dashboards via API
backup_grafana_dashboards() {
    log_info "Backing up Grafana dashboards via API..."
    
    local grafana_url="http://localhost:3000"
    local username="admin"
    local password="admin"
    
    # Check if Grafana is accessible
    if ! curl -s -u "$username:$password" "$grafana_url/api/health" >/dev/null 2>&1; then
        log_warning "Grafana API not accessible, skipping dashboard backup"
        return
    fi
    
    # Create dashboards directory
    mkdir -p "$BACKUP_DIR/$BACKUP_NAME/grafana-dashboards"
    
    # Get all dashboards
    local dashboards=$(curl -s -u "$username:$password" "$grafana_url/api/search?type=dash-db" | jq -r '.[].uid' 2>/dev/null || echo "")
    
    if [ -n "$dashboards" ]; then
        for uid in $dashboards; do
            log_info "Backing up dashboard: $uid"
            curl -s -u "$username:$password" "$grafana_url/api/dashboards/uid/$uid" | jq '.' > "$BACKUP_DIR/$BACKUP_NAME/grafana-dashboards/$uid.json" 2>/dev/null || true
        done
        log_success "Grafana dashboards backed up via API"
    else
        log_warning "No dashboards found via API"
    fi
}

# Function to backup Prometheus configuration
backup_prometheus_config() {
    log_info "Backing up Prometheus configuration..."
    
    local prometheus_url="http://localhost:9090"
    
    # Check if Prometheus is accessible
    if ! curl -s "$prometheus_url/-/healthy" >/dev/null 2>&1; then
        log_warning "Prometheus API not accessible, skipping configuration backup"
        return
    fi
    
    # Get Prometheus configuration
    curl -s "$prometheus_url/api/v1/status/config" | jq '.data.yaml' -r > "$BACKUP_DIR/$BACKUP_NAME/prometheus-config.yml" 2>/dev/null || true
    
    # Get Prometheus rules
    curl -s "$prometheus_url/api/v1/rules" | jq '.' > "$BACKUP_DIR/$BACKUP_NAME/prometheus-rules.json" 2>/dev/null || true
    
    # Get Prometheus targets
    curl -s "$prometheus_url/api/v1/targets" | jq '.' > "$BACKUP_DIR/$BACKUP_NAME/prometheus-targets.json" 2>/dev/null || true
    
    log_success "Prometheus configuration backed up via API"
}

# Function to create backup archive
create_backup_archive() {
    log_info "Creating backup archive..."
    
    cd "$BACKUP_DIR"
    tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
    cd ..
    
    # Remove temporary directory
    rm -rf "$BACKUP_DIR/$BACKUP_NAME"
    
    log_success "Backup archive created: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
}

# Function to restore from backup
restore_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        log_error "Backup file not specified"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    log_info "Restoring from backup: $backup_file"
    
    # Extract backup
    local restore_dir="restore-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$restore_dir"
    tar -xzf "$backup_file" -C "$restore_dir"
    
    log_success "Backup extracted to: $restore_dir"
    log_info "Please manually restore the components from the extracted files"
}

# Function to list available backups
list_backups() {
    log_info "Available backups:"
    
    if [ -d "$BACKUP_DIR" ]; then
        ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || log_warning "No backup archives found"
    else
        log_warning "Backup directory not found"
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    local days_to_keep="${1:-7}"
    
    log_info "Cleaning up backups older than $days_to_keep days..."
    
    if [ -d "$BACKUP_DIR" ]; then
        find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$days_to_keep -delete
        log_success "Old backups cleaned up"
    fi
}

# Main function
main() {
    echo "=========================================="
    echo "  Monitoring Stack Backup Utility"
    echo "=========================================="
    
    case "${1:-}" in
        "restore")
            restore_backup "$2"
            exit 0
            ;;
        "list")
            list_backups
            exit 0
            ;;
        "cleanup")
            cleanup_old_backups "$2"
            exit 0
            ;;
        "--help" | "-h")
            echo "Usage: $0 [COMMAND] [OPTIONS]"
            echo ""
            echo "Commands:"
            echo "  (no command)    Create a new backup"
            echo "  restore FILE    Restore from backup file"
            echo "  list            List available backups"
            echo "  cleanup [DAYS]  Clean up backups older than DAYS (default: 7)"
            echo "  --help          Show this help message"
            exit 0
            ;;
    esac
    
    # Main backup flow
    detect_environment
    create_backup_directory
    backup_configuration
    
    case $ENVIRONMENT in
        "docker")
            backup_docker_data
            ;;
        "kubernetes")
            backup_kubernetes_data
            ;;
    esac
    
    # Try to backup via APIs (optional)
    backup_grafana_dashboards || true
    backup_prometheus_config || true
    
    create_backup_archive
    
    log_success "Backup completed successfully!"
    log_info "Backup file: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
    log_info "Use '$0 list' to see all backups"
    log_info "Use '$0 restore <file>' to restore from backup"
}

# Run main function with all arguments
main "$@"
