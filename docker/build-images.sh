#!/bin/bash

# Build Custom Docker Images Script
# This script builds custom Docker images for Prometheus and Grafana

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

# Function to build Prometheus image
build_prometheus() {
    log_info "Building custom Prometheus image..."
    
    if [ ! -f "Dockerfile.prometheus" ]; then
        log_error "Dockerfile.prometheus not found"
        return 1
    fi
    
    docker build -f Dockerfile.prometheus -t prometheus-custom:latest .
    
    if [ $? -eq 0 ]; then
        log_success "Prometheus image built successfully"
    else
        log_error "Failed to build Prometheus image"
        return 1
    fi
}

# Function to build Grafana image
build_grafana() {
    log_info "Building custom Grafana image..."
    
    if [ ! -f "Dockerfile.grafana" ]; then
        log_error "Dockerfile.grafana not found"
        return 1
    fi
    
    docker build -f Dockerfile.grafana -t grafana-custom:latest .
    
    if [ $? -eq 0 ]; then
        log_success "Grafana image built successfully"
    else
        log_error "Failed to build Grafana image"
        return 1
    fi
}

# Function to build all images
build_all() {
    log_info "Building all custom images..."
    
    build_prometheus
    build_grafana
    
    log_success "All images built successfully"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  prometheus    Build only Prometheus image"
    echo "  grafana       Build only Grafana image"
    echo "  all           Build all images (default)"
    echo "  --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Build all images"
    echo "  $0 prometheus         # Build only Prometheus"
    echo "  $0 grafana            # Build only Grafana"
}

# Main function
main() {
    echo "=========================================="
    echo "  Docker Image Builder"
    echo "=========================================="
    
    case "${1:-all}" in
        "prometheus")
            build_prometheus
            ;;
        "grafana")
            build_grafana
            ;;
        "all")
            build_all
            ;;
        "--help" | "-h")
            show_usage
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
