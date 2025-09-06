#!/bin/bash

# Inventory Manager Script
# This script helps manage the server inventory for production monitoring

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INVENTORY_FILE="production/inventory/servers.yml"

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

# Function to check prerequisites
check_prerequisites() {
    if ! command_exists yq; then
        log_error "yq is required but not installed. Please install yq first."
        log_info "Install with: brew install yq (macOS) or apt-get install yq (Ubuntu)"
        exit 1
    fi
}

# Function to list all servers
list_servers() {
    log_info "Listing all servers in inventory..."
    
    if [ ! -f "$INVENTORY_FILE" ]; then
        log_error "Inventory file not found: $INVENTORY_FILE"
        exit 1
    fi
    
    echo ""
    echo "=========================================="
    echo "  Server Inventory"
    echo "=========================================="
    
    yq eval '.servers[] | "\(.name) | \(.hostname) | \(.environment) | \(.role) | \(.monitoring_type)"' "$INVENTORY_FILE" | \
    while IFS='|' read -r name hostname environment role monitoring_type; do
        printf "%-20s %-25s %-12s %-15s %s\n" \
            "$(echo $name | xargs)" \
            "$(echo $hostname | xargs)" \
            "$(echo $environment | xargs)" \
            "$(echo $role | xargs)" \
            "$(echo $monitoring_type | xargs)"
    done
    
    echo "=========================================="
}

# Function to add a new server
add_server() {
    local name="$1"
    local hostname="$2"
    local ip="$3"
    local environment="$4"
    local role="$5"
    local monitoring_type="$6"
    
    if [ -z "$name" ] || [ -z "$hostname" ] || [ -z "$ip" ] || [ -z "$environment" ] || [ -z "$role" ] || [ -z "$monitoring_type" ]; then
        log_error "All parameters are required: name, hostname, ip, environment, role, monitoring_type"
        return 1
    fi
    
    log_info "Adding server: $name ($hostname)"
    
    # Create temporary file with new server
    cat > /tmp/new_server.yml << EOF
  - name: "$name"
    hostname: "$hostname"
    ip: "$ip"
    environment: "$environment"
    role: "$role"
    monitoring_type: "$monitoring_type"
    docker_enabled: $([ "$monitoring_type" = "docker+system" ] && echo "true" || echo "false")
    system_monitoring: true
    prometheus_port: 9100
    cadvisor_port: $([ "$monitoring_type" = "docker+system" ] && echo "8080" || echo "null")
    ssh_user: "monitoring"
    ssh_key: "~/.ssh/monitoring_key"
    tags: ["$role", "$environment"]
EOF
    
    # Add to inventory file
    yq eval '.servers += load("/tmp/new_server.yml")' "$INVENTORY_FILE" > /tmp/updated_inventory.yml
    mv /tmp/updated_inventory.yml "$INVENTORY_FILE"
    
    # Clean up
    rm -f /tmp/new_server.yml
    
    log_success "Server $name added to inventory"
}

# Function to remove a server
remove_server() {
    local name="$1"
    
    if [ -z "$name" ]; then
        log_error "Server name is required"
        return 1
    fi
    
    log_info "Removing server: $name"
    
    # Remove server from inventory
    yq eval "del(.servers[] | select(.name == \"$name\"))" "$INVENTORY_FILE" > /tmp/updated_inventory.yml
    mv /tmp/updated_inventory.yml "$INVENTORY_FILE"
    
    log_success "Server $name removed from inventory"
}

# Function to update server configuration
update_server() {
    local name="$1"
    local field="$2"
    local value="$3"
    
    if [ -z "$name" ] || [ -z "$field" ] || [ -z "$value" ]; then
        log_error "All parameters are required: name, field, value"
        return 1
    fi
    
    log_info "Updating server $name: $field = $value"
    
    # Update server field
    yq eval "(.servers[] | select(.name == \"$name\").$field) = \"$value\"" "$INVENTORY_FILE" > /tmp/updated_inventory.yml
    mv /tmp/updated_inventory.yml "$INVENTORY_FILE"
    
    log_success "Server $name updated"
}

# Function to validate inventory
validate_inventory() {
    log_info "Validating inventory file..."
    
    if [ ! -f "$INVENTORY_FILE" ]; then
        log_error "Inventory file not found: $INVENTORY_FILE"
        exit 1
    fi
    
    # Check if file is valid YAML
    if ! yq eval '.' "$INVENTORY_FILE" >/dev/null 2>&1; then
        log_error "Invalid YAML syntax in inventory file"
        exit 1
    fi
    
    # Check required fields
    local servers=$(yq eval '.servers[]' "$INVENTORY_FILE" -o json)
    local errors=0
    
    while IFS= read -r server; do
        if [ -n "$server" ]; then
            local name=$(echo "$server" | jq -r '.name // empty')
            local hostname=$(echo "$server" | jq -r '.hostname // empty')
            local ip=$(echo "$server" | jq -r '.ip // empty')
            local environment=$(echo "$server" | jq -r '.environment // empty')
            local role=$(echo "$server" | jq -r '.role // empty')
            local monitoring_type=$(echo "$server" | jq -r '.monitoring_type // empty')
            
            if [ -z "$name" ]; then
                log_error "Server missing 'name' field"
                errors=$((errors + 1))
            fi
            
            if [ -z "$hostname" ]; then
                log_error "Server $name missing 'hostname' field"
                errors=$((errors + 1))
            fi
            
            if [ -z "$ip" ]; then
                log_error "Server $name missing 'ip' field"
                errors=$((errors + 1))
            fi
            
            if [ -z "$environment" ]; then
                log_error "Server $name missing 'environment' field"
                errors=$((errors + 1))
            fi
            
            if [ -z "$role" ]; then
                log_error "Server $name missing 'role' field"
                errors=$((errors + 1))
            fi
            
            if [ -z "$monitoring_type" ]; then
                log_error "Server $name missing 'monitoring_type' field"
                errors=$((errors + 1))
            fi
        fi
    done <<< "$servers"
    
    if [ $errors -eq 0 ]; then
        log_success "Inventory validation passed"
    else
        log_error "Inventory validation failed with $errors errors"
        exit 1
    fi
}

# Function to generate Prometheus configuration
generate_prometheus_config() {
    log_info "Generating Prometheus configuration from inventory..."
    
    if [ ! -f "$INVENTORY_FILE" ]; then
        log_error "Inventory file not found: $INVENTORY_FILE"
        exit 1
    fi
    
    # Generate Prometheus configuration
    cat > production/configs/prometheus-generated.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'production-monitoring'
    environment: 'production'
    replica: 'prometheus-1'

rule_files:
  - "/etc/prometheus/rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 5s
    metrics_path: /metrics

  # Node Exporter - System metrics from all servers
  - job_name: 'node-exporter'
    static_configs:
EOF
    
    # Add node exporter targets
    yq eval '.servers[] | select(.system_monitoring == true) | "      - targets: [\"\(.hostname):\(.prometheus_port)\"]\n        labels:\n          environment: \"\(.environment)\"\n          role: \"\(.role)\"\n          monitoring_type: \"\(.monitoring_type)\""' "$INVENTORY_FILE" >> production/configs/prometheus-generated.yml
    
    # Add cAdvisor targets
    cat >> production/configs/prometheus-generated.yml << 'EOF'

  # cAdvisor - Container metrics from Docker-enabled servers
  - job_name: 'cadvisor'
    static_configs:
EOF
    
    yq eval '.servers[] | select(.docker_enabled == true) | "      - targets: [\"\(.hostname):\(.cadvisor_port)\"]\n        labels:\n          environment: \"\(.environment)\"\n          role: \"\(.role)\"\n          monitoring_type: \"\(.monitoring_type)\""' "$INVENTORY_FILE" >> production/configs/prometheus-generated.yml
    
    log_success "Prometheus configuration generated: production/configs/prometheus-generated.yml"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  list                    List all servers in inventory"
    echo "  add NAME HOSTNAME IP ENV ROLE TYPE    Add a new server"
    echo "  remove NAME             Remove a server from inventory"
    echo "  update NAME FIELD VALUE Update a server field"
    echo "  validate                Validate inventory file"
    echo "  generate-config         Generate Prometheus configuration"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 add web-03 web03.example.com 10.0.1.13 production web-application docker+system"
    echo "  $0 remove web-03"
    echo "  $0 update web-03 environment staging"
    echo "  $0 validate"
    echo "  $0 generate-config"
}

# Main function
main() {
    echo "=========================================="
    echo "  Inventory Manager"
    echo "=========================================="
    
    # Check prerequisites
    check_prerequisites
    
    case "${1:-}" in
        "list")
            list_servers
            ;;
        "add")
            add_server "$2" "$3" "$4" "$5" "$6" "$7"
            ;;
        "remove")
            remove_server "$2"
            ;;
        "update")
            update_server "$2" "$3" "$4"
            ;;
        "validate")
            validate_inventory
            ;;
        "generate-config")
            generate_prometheus_config
            ;;
        "--help" | "-h")
            show_usage
            ;;
        *)
            log_error "Unknown command: ${1:-}"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
