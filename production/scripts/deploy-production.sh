#!/bin/bash

# Production Deployment Script for Multi-Server Monitoring
# This script deploys monitoring agents to multiple servers based on their configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INVENTORY_FILE="production/inventory/servers.yml"
SSH_TIMEOUT=30
PARALLEL_JOBS=5

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
    log_info "Checking prerequisites..."
    
    if ! command_exists yq; then
        log_error "yq is required but not installed. Please install yq first."
        log_info "Install with: brew install yq (macOS) or apt-get install yq (Ubuntu)"
        exit 1
    fi
    
    if ! command_exists ssh; then
        log_error "SSH is required but not installed."
        exit 1
    fi
    
    if [ ! -f "$INVENTORY_FILE" ]; then
        log_error "Inventory file not found: $INVENTORY_FILE"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Function to parse inventory file
parse_inventory() {
    log_info "Parsing inventory file..."
    
    # Extract server information using yq
    SERVERS=$(yq eval '.servers[]' "$INVENTORY_FILE" -o json)
    
    if [ -z "$SERVERS" ]; then
        log_error "No servers found in inventory file"
        exit 1
    fi
    
    log_success "Inventory parsed successfully"
}

# Function to test SSH connectivity
test_ssh_connection() {
    local server_info="$1"
    local hostname=$(echo "$server_info" | jq -r '.hostname')
    local ssh_user=$(echo "$server_info" | jq -r '.ssh_user')
    local ssh_key=$(echo "$server_info" | jq -r '.ssh_key')
    
    log_info "Testing SSH connection to $hostname..."
    
    if ssh -i "$ssh_key" -o ConnectTimeout=$SSH_TIMEOUT -o BatchMode=yes "$ssh_user@$hostname" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        log_success "SSH connection to $hostname successful"
        return 0
    else
        log_error "SSH connection to $hostname failed"
        return 1
    fi
}

# Function to install Node Exporter
install_node_exporter() {
    local server_info="$1"
    local hostname=$(echo "$server_info" | jq -r '.hostname')
    local ssh_user=$(echo "$server_info" | jq -r '.ssh_user')
    local ssh_key=$(echo "$server_info" | jq -r '.ssh_key')
    local prometheus_port=$(echo "$server_info" | jq -r '.prometheus_port')
    
    log_info "Installing Node Exporter on $hostname..."
    
    ssh -i "$ssh_key" "$ssh_user@$hostname" << EOF
        # Check if Node Exporter is already installed
        if systemctl is-active --quiet node_exporter; then
            echo "Node Exporter is already running on $hostname"
            exit 0
        fi
        
        # Create node_exporter user
        sudo useradd --no-create-home --shell /bin/false node_exporter || true
        
        # Download and install Node Exporter
        cd /tmp
        wget https://github.com/prometheus/node_exporter/releases/download/v1.6.0/node_exporter-1.6.0.linux-amd64.tar.gz
        tar xzf node_exporter-1.6.0.linux-amd64.tar.gz
        sudo cp node_exporter-1.6.0.linux-amd64/node_exporter /usr/local/bin/
        sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
        
        # Create systemd service
        sudo tee /etc/systemd/system/node_exporter.service > /dev/null << 'EOL'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:$prometheus_port

[Install]
WantedBy=multi-user.target
EOL
        
        # Enable and start service
        sudo systemctl daemon-reload
        sudo systemctl enable node_exporter
        sudo systemctl start node_exporter
        
        # Configure firewall
        sudo ufw allow $prometheus_port/tcp comment "Node Exporter"
        
        echo "Node Exporter installed and started on $hostname"
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Node Exporter installed on $hostname"
    else
        log_error "Failed to install Node Exporter on $hostname"
        return 1
    fi
}

# Function to install cAdvisor
install_cadvisor() {
    local server_info="$1"
    local hostname=$(echo "$server_info" | jq -r '.hostname')
    local ssh_user=$(echo "$server_info" | jq -r '.ssh_user')
    local ssh_key=$(echo "$server_info" | jq -r '.ssh_key')
    local cadvisor_port=$(echo "$server_info" | jq -r '.cadvisor_port')
    
    log_info "Installing cAdvisor on $hostname..."
    
    ssh -i "$ssh_key" "$ssh_user@$hostname" << EOF
        # Check if Docker is installed
        if ! command -v docker >/dev/null 2>&1; then
            echo "Docker is not installed on $hostname. Skipping cAdvisor installation."
            exit 0
        fi
        
        # Check if cAdvisor container is already running
        if docker ps --format "table {{.Names}}" | grep -q "cadvisor"; then
            echo "cAdvisor is already running on $hostname"
            exit 0
        fi
        
        # Run cAdvisor container
        docker run -d \\
            --name=cadvisor \\
            --restart=always \\
            --volume=/:/rootfs:ro \\
            --volume=/var/run:/var/run:ro \\
            --volume=/sys:/sys:ro \\
            --volume=/var/lib/docker/:/var/lib/docker:ro \\
            --volume=/dev/disk/:/dev/disk:ro \\
            --publish=$cadvisor_port:8080 \\
            --privileged \\
            --device=/dev/kmsg \\
            gcr.io/cadvisor/cadvisor:v0.47.0
        
        # Configure firewall
        sudo ufw allow $cadvisor_port/tcp comment "cAdvisor"
        
        echo "cAdvisor installed and started on $hostname"
EOF
    
    if [ $? -eq 0 ]; then
        log_success "cAdvisor installed on $hostname"
    else
        log_error "Failed to install cAdvisor on $hostname"
        return 1
    fi
}

# Function to configure firewall
configure_firewall() {
    local server_info="$1"
    local hostname=$(echo "$server_info" | jq -r '.hostname')
    local ssh_user=$(echo "$server_info" | jq -r '.ssh_user')
    local ssh_key=$(echo "$server_info" | jq -r '.ssh_key')
    
    log_info "Configuring firewall on $hostname..."
    
    ssh -i "$ssh_key" "$ssh_user@$hostname" << EOF
        # Enable UFW if not already enabled
        sudo ufw --force enable
        
        # Allow SSH
        sudo ufw allow 22/tcp comment "SSH"
        
        # Allow monitoring ports from monitoring network
        sudo ufw allow from 10.0.7.0/24 to any port 9100 comment "Node Exporter"
        sudo ufw allow from 10.0.7.0/24 to any port 8080 comment "cAdvisor"
        
        echo "Firewall configured on $hostname"
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Firewall configured on $hostname"
    else
        log_error "Failed to configure firewall on $hostname"
        return 1
    fi
}

# Function to deploy monitoring to a single server
deploy_to_server() {
    local server_info="$1"
    local hostname=$(echo "$server_info" | jq -r '.hostname')
    local monitoring_type=$(echo "$server_info" | jq -r '.monitoring_type')
    local system_monitoring=$(echo "$server_info" | jq -r '.system_monitoring')
    local docker_enabled=$(echo "$server_info" | jq -r '.docker_enabled')
    
    log_info "Deploying monitoring to $hostname (type: $monitoring_type)..."
    
    # Test SSH connection
    if ! test_ssh_connection "$server_info"; then
        return 1
    fi
    
    # Configure firewall
    configure_firewall "$server_info"
    
    # Install Node Exporter for system monitoring
    if [ "$system_monitoring" = "true" ]; then
        install_node_exporter "$server_info"
    fi
    
    # Install cAdvisor for Docker monitoring
    if [ "$docker_enabled" = "true" ]; then
        install_cadvisor "$server_info"
    fi
    
    log_success "Monitoring deployed to $hostname"
}

# Function to deploy central monitoring stack
deploy_central_monitoring() {
    log_info "Deploying central monitoring stack..."
    
    # Check if we're on the monitoring server
    local monitoring_server=$(yq eval '.servers[] | select(.role == "monitoring")' "$INVENTORY_FILE" -o json)
    local monitoring_hostname=$(echo "$monitoring_server" | jq -r '.hostname')
    
    if [ "$(hostname)" != "$monitoring_hostname" ]; then
        log_warning "This script should be run on the monitoring server ($monitoring_hostname)"
        log_info "Current hostname: $(hostname)"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Deploy using docker-compose
    if [ -f "docker-compose.yml" ]; then
        log_info "Deploying central monitoring with Docker Compose..."
        docker-compose up -d
        log_success "Central monitoring stack deployed"
    else
        log_error "docker-compose.yml not found"
        return 1
    fi
}

# Function to verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    local failed_servers=()
    local success_count=0
    local total_count=0
    
    # Check each server
    while IFS= read -r server_info; do
        if [ -n "$server_info" ]; then
            total_count=$((total_count + 1))
            local hostname=$(echo "$server_info" | jq -r '.hostname')
            local prometheus_port=$(echo "$server_info" | jq -r '.prometheus_port')
            local cadvisor_port=$(echo "$server_info" | jq -r '.cadvisor_port // empty')
            local system_monitoring=$(echo "$server_info" | jq -r '.system_monitoring')
            local docker_enabled=$(echo "$server_info" | jq -r '.docker_enabled')
            
            log_info "Verifying $hostname..."
            
            # Check Node Exporter
            if [ "$system_monitoring" = "true" ]; then
                if curl -s --connect-timeout 5 "http://$hostname:$prometheus_port/metrics" >/dev/null 2>&1; then
                    log_success "Node Exporter is responding on $hostname"
                else
                    log_error "Node Exporter is not responding on $hostname"
                    failed_servers+=("$hostname (Node Exporter)")
                fi
            fi
            
            # Check cAdvisor
            if [ "$docker_enabled" = "true" ] && [ -n "$cadvisor_port" ]; then
                if curl -s --connect-timeout 5 "http://$hostname:$cadvisor_port/metrics" >/dev/null 2>&1; then
                    log_success "cAdvisor is responding on $hostname"
                else
                    log_error "cAdvisor is not responding on $hostname"
                    failed_servers+=("$hostname (cAdvisor)")
                fi
            fi
            
            if [ "$system_monitoring" = "true" ] && [ "$docker_enabled" = "true" ]; then
                if curl -s --connect-timeout 5 "http://$hostname:$prometheus_port/metrics" >/dev/null 2>&1 && \
                   curl -s --connect-timeout 5 "http://$hostname:$cadvisor_port/metrics" >/dev/null 2>&1; then
                    success_count=$((success_count + 1))
                fi
            elif [ "$system_monitoring" = "true" ]; then
                if curl -s --connect-timeout 5 "http://$hostname:$prometheus_port/metrics" >/dev/null 2>&1; then
                    success_count=$((success_count + 1))
                fi
            fi
        fi
    done <<< "$(yq eval '.servers[]' "$INVENTORY_FILE" -o json)"
    
    # Summary
    echo ""
    echo "=========================================="
    echo "  Deployment Verification Summary"
    echo "=========================================="
    echo "Total servers: $total_count"
    echo "Successful deployments: $success_count"
    echo "Failed deployments: ${#failed_servers[@]}"
    
    if [ ${#failed_servers[@]} -gt 0 ]; then
        echo ""
        echo "Failed servers:"
        for server in "${failed_servers[@]}"; do
            echo "  - $server"
        done
    fi
    echo "=========================================="
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --central-only    Deploy only central monitoring stack"
    echo "  --agents-only     Deploy only monitoring agents to servers"
    echo "  --verify-only     Only verify existing deployment"
    echo "  --parallel N      Number of parallel deployments (default: 5)"
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Deploy everything"
    echo "  $0 --central-only     # Deploy only central monitoring"
    echo "  $0 --agents-only      # Deploy only agents to servers"
    echo "  $0 --verify-only      # Verify deployment"
    echo "  $0 --parallel 10      # Deploy with 10 parallel jobs"
}

# Main function
main() {
    echo "=========================================="
    echo "  Production Monitoring Deployment"
    echo "=========================================="
    
    # Parse command line arguments
    CENTRAL_ONLY=false
    AGENTS_ONLY=false
    VERIFY_ONLY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --central-only)
                CENTRAL_ONLY=true
                shift
                ;;
            --agents-only)
                AGENTS_ONLY=true
                shift
                ;;
            --verify-only)
                VERIFY_ONLY=true
                shift
                ;;
            --parallel)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_prerequisites
    
    if [ "$VERIFY_ONLY" = "true" ]; then
        verify_deployment
        exit 0
    fi
    
    # Parse inventory
    parse_inventory
    
    # Deploy central monitoring
    if [ "$AGENTS_ONLY" = "false" ]; then
        deploy_central_monitoring
    fi
    
    # Deploy agents to servers
    if [ "$CENTRAL_ONLY" = "false" ]; then
        log_info "Deploying monitoring agents to servers..."
        
        # Deploy to each server
        while IFS= read -r server_info; do
            if [ -n "$server_info" ]; then
                deploy_to_server "$server_info" &
                
                # Limit parallel jobs
                if [ $(jobs -r | wc -l) -ge $PARALLEL_JOBS ]; then
                    wait -n
                fi
            fi
        done <<< "$(yq eval '.servers[]' "$INVENTORY_FILE" -o json)"
        
        # Wait for all jobs to complete
        wait
        
        log_success "All monitoring agents deployed"
    fi
    
    # Verify deployment
    verify_deployment
    
    log_success "Production deployment completed!"
    log_info "Access Grafana at: http://monitoring.yourdomain.com:3000"
    log_info "Access Prometheus at: http://monitoring.yourdomain.com:9090"
}

# Run main function with all arguments
main "$@"
