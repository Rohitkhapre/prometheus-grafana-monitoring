# Production Deployment Guide

This guide explains how to deploy the Prometheus & Grafana monitoring stack in production environments with multiple servers and different monitoring scenarios.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Server Inventory Setup](#server-inventory-setup)
4. [Monitoring Scenarios](#monitoring-scenarios)
5. [Deployment Process](#deployment-process)
6. [Configuration Examples](#configuration-examples)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

## Overview

The production deployment supports:

- **Multiple Servers**: Monitor 20+ servers with different configurations
- **Flexible Scenarios**: Docker-only, system-only, or hybrid monitoring
- **Centralized Management**: Single monitoring server with distributed agents
- **Automated Deployment**: Scripts for mass deployment and configuration
- **Environment Separation**: Production, staging, and development environments

## Prerequisites

### System Requirements

#### Monitoring Server (Central)
- **CPU**: 4+ cores
- **RAM**: 8GB+ (16GB recommended for 20+ servers)
- **Disk**: 100GB+ (depends on retention policy)
- **Network**: Stable connection to all monitored servers

#### Monitored Servers
- **CPU**: 1+ core
- **RAM**: 1GB+ (2GB recommended)
- **Disk**: 10GB+ free space
- **Network**: Access to monitoring server

### Software Requirements

#### Monitoring Server
- Docker and Docker Compose
- SSH access to all monitored servers
- yq (YAML processor)
- curl and jq

#### Monitored Servers
- SSH access configured
- Docker (for Docker monitoring scenarios)
- systemd (for service management)
- ufw (for firewall configuration)

## Server Inventory Setup

### 1. Create Server Inventory

Edit `production/inventory/servers.yml` to define your servers:

```yaml
servers:
  # Web Application Servers (Docker + System Monitoring)
  - name: "web-app-01"
    hostname: "web01.yourdomain.com"
    ip: "10.0.1.10"
    environment: "production"
    role: "web-application"
    monitoring_type: "docker+system"
    docker_enabled: true
    system_monitoring: true
    prometheus_port: 9100
    cadvisor_port: 8080
    ssh_user: "monitoring"
    ssh_key: "~/.ssh/monitoring_key"
    tags: ["web", "docker", "production"]
    
  # Database Servers (System Monitoring Only)
  - name: "db-primary"
    hostname: "db01.yourdomain.com"
    ip: "10.0.2.10"
    environment: "production"
    role: "database"
    monitoring_type: "system"
    docker_enabled: false
    system_monitoring: true
    prometheus_port: 9100
    ssh_user: "monitoring"
    ssh_key: "~/.ssh/monitoring_key"
    tags: ["database", "system", "production"]
```

### 2. Configure SSH Access

Set up SSH key-based authentication:

```bash
# Generate SSH key for monitoring
ssh-keygen -t rsa -b 4096 -f ~/.ssh/monitoring_key -N ""

# Copy public key to all servers
for server in web01.yourdomain.com db01.yourdomain.com; do
    ssh-copy-id -i ~/.ssh/monitoring_key.pub monitoring@$server
done
```

### 3. Update DNS/Hosts

Ensure all hostnames resolve correctly:

```bash
# Add to /etc/hosts or configure DNS
10.0.1.10 web01.yourdomain.com
10.0.2.10 db01.yourdomain.com
10.0.3.10 k8s-master.yourdomain.com
```

## Monitoring Scenarios

### Scenario 1: Docker + System Monitoring

**Use Case**: Web applications, development servers, containerized workloads

**Components**:
- Node Exporter (system metrics)
- cAdvisor (container metrics)
- Docker daemon metrics

**Configuration**:
```yaml
monitoring_type: "docker+system"
docker_enabled: true
system_monitoring: true
```

### Scenario 2: System-Only Monitoring

**Use Case**: Database servers, load balancers, bare metal servers

**Components**:
- Node Exporter (system metrics)
- Blackbox Exporter (health checks)

**Configuration**:
```yaml
monitoring_type: "system"
docker_enabled: false
system_monitoring: true
```

### Scenario 3: Kubernetes Monitoring

**Use Case**: Kubernetes clusters, microservices

**Components**:
- Node Exporter
- cAdvisor
- kube-state-metrics
- Kubernetes API metrics

**Configuration**:
```yaml
monitoring_type: "kubernetes+system"
docker_enabled: true
system_monitoring: true
kubernetes_enabled: true
```

## Deployment Process

### 1. Prepare Monitoring Server

```bash
# Clone the repository
git clone <your-repo-url>
cd prometheus-grafana-monitoring

# Install prerequisites
sudo apt-get update
sudo apt-get install -y yq jq curl

# Configure inventory
cp production/inventory/servers.yml.example production/inventory/servers.yml
# Edit the file with your server details
```

### 2. Deploy Central Monitoring Stack

```bash
# Deploy central monitoring (Prometheus, Grafana, Alertmanager)
./production/scripts/deploy-production.sh --central-only
```

### 3. Deploy Monitoring Agents

```bash
# Deploy agents to all servers
./production/scripts/deploy-production.sh --agents-only

# Or deploy with parallel jobs for faster deployment
./production/scripts/deploy-production.sh --agents-only --parallel 10
```

### 4. Verify Deployment

```bash
# Verify all components are working
./production/scripts/deploy-production.sh --verify-only
```

## Configuration Examples

### Example 1: 20+ Server Setup

```yaml
# production/inventory/servers.yml
servers:
  # Web Tier (5 servers)
  - name: "web-01"
    hostname: "web01.yourdomain.com"
    monitoring_type: "docker+system"
    role: "web-application"
    environment: "production"
    
  - name: "web-02"
    hostname: "web02.yourdomain.com"
    monitoring_type: "docker+system"
    role: "web-application"
    environment: "production"
    
  # ... (web-03, web-04, web-05)
  
  # Database Tier (3 servers)
  - name: "db-primary"
    hostname: "db01.yourdomain.com"
    monitoring_type: "system"
    role: "database"
    environment: "production"
    
  - name: "db-replica-1"
    hostname: "db02.yourdomain.com"
    monitoring_type: "system"
    role: "database"
    environment: "production"
    
  - name: "db-replica-2"
    hostname: "db03.yourdomain.com"
    monitoring_type: "system"
    role: "database"
    environment: "production"
  
  # Kubernetes Cluster (5 nodes)
  - name: "k8s-master"
    hostname: "k8s-master.yourdomain.com"
    monitoring_type: "kubernetes+system"
    role: "kubernetes-master"
    environment: "production"
    
  - name: "k8s-worker-01"
    hostname: "k8s-worker-01.yourdomain.com"
    monitoring_type: "kubernetes+system"
    role: "kubernetes-worker"
    environment: "production"
    
  # ... (k8s-worker-02, k8s-worker-03, k8s-worker-04)
  
  # Load Balancers (2 servers)
  - name: "lb-primary"
    hostname: "lb01.yourdomain.com"
    monitoring_type: "system"
    role: "load-balancer"
    environment: "production"
    
  - name: "lb-secondary"
    hostname: "lb02.yourdomain.com"
    monitoring_type: "system"
    role: "load-balancer"
    environment: "production"
  
  # Development Servers (3 servers)
  - name: "dev-01"
    hostname: "dev01.yourdomain.com"
    monitoring_type: "docker+system"
    role: "development"
    environment: "development"
    
  - name: "dev-02"
    hostname: "dev02.yourdomain.com"
    monitoring_type: "docker+system"
    role: "development"
    environment: "development"
    
  - name: "dev-03"
    hostname: "dev03.yourdomain.com"
    monitoring_type: "docker+system"
    role: "development"
    environment: "development"
  
  # Staging Servers (2 servers)
  - name: "staging-01"
    hostname: "staging01.yourdomain.com"
    monitoring_type: "docker+system"
    role: "staging"
    environment: "staging"
    
  - name: "staging-02"
    hostname: "staging02.yourdomain.com"
    monitoring_type: "docker+system"
    role: "staging"
    environment: "staging"
```

### Example 2: Environment-Specific Configuration

```yaml
# Different configurations for different environments
global_config:
  production:
    prometheus_retention: "30d"
    scrape_interval: "15s"
    alerting_enabled: true
    
  staging:
    prometheus_retention: "7d"
    scrape_interval: "30s"
    alerting_enabled: false
    
  development:
    prometheus_retention: "3d"
    scrape_interval: "60s"
    alerting_enabled: false
```

### Example 3: Custom Metrics Integration

```yaml
# Add custom application metrics
scrape_configs:
  - job_name: 'application-metrics'
    static_configs:
      - targets:
          - 'web01.yourdomain.com:8080'
          - 'web02.yourdomain.com:8080'
        labels:
          environment: 'production'
          role: 'web-application'
          metrics_type: 'application'
    
    scrape_interval: 30s
    metrics_path: /metrics
```

## Troubleshooting

### Common Issues

#### 1. SSH Connection Failures

```bash
# Test SSH connectivity
ssh -i ~/.ssh/monitoring_key monitoring@web01.yourdomain.com "echo 'SSH working'"

# Check SSH key permissions
chmod 600 ~/.ssh/monitoring_key
chmod 644 ~/.ssh/monitoring_key.pub
```

#### 2. Firewall Issues

```bash
# Check firewall status on monitored servers
ssh monitoring@web01.yourdomain.com "sudo ufw status"

# Open required ports
ssh monitoring@web01.yourdomain.com "sudo ufw allow 9100/tcp comment 'Node Exporter'"
```

#### 3. Service Not Starting

```bash
# Check service status
ssh monitoring@web01.yourdomain.com "sudo systemctl status node_exporter"

# Check logs
ssh monitoring@web01.yourdomain.com "sudo journalctl -u node_exporter -f"
```

#### 4. Metrics Not Appearing

```bash
# Test metrics endpoint
curl http://web01.yourdomain.com:9100/metrics

# Check Prometheus targets
curl http://monitoring.yourdomain.com:9090/api/v1/targets
```

### Debugging Commands

```bash
# Check all server connectivity
./production/scripts/deploy-production.sh --verify-only

# Test specific server
ssh -i ~/.ssh/monitoring_key monitoring@web01.yourdomain.com "curl -s http://localhost:9100/metrics | head -5"

# Check Prometheus configuration
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

## Best Practices

### 1. Security

- Use SSH key-based authentication
- Configure firewall rules properly
- Use VPN or private networks for monitoring traffic
- Regularly rotate SSH keys
- Implement network segmentation

### 2. Performance

- Adjust scrape intervals based on server load
- Use appropriate retention policies
- Monitor the monitoring system itself
- Implement horizontal scaling for large deployments

### 3. Reliability

- Deploy monitoring agents with systemd
- Configure automatic restarts
- Implement health checks
- Use redundant monitoring servers for critical environments

### 4. Maintenance

- Regular backup of configurations
- Update monitoring components regularly
- Monitor disk usage and cleanup old data
- Document custom configurations

### 5. Scaling

For 50+ servers, consider:

- Multiple Prometheus instances with federation
- Grafana clustering
- Load balancing for monitoring endpoints
- Dedicated monitoring networks
- Automated deployment pipelines

### 6. Monitoring Strategy

- Start with basic system metrics
- Gradually add application-specific metrics
- Implement alerting rules incrementally
- Regular review and optimization of metrics

## Advanced Configuration

### Prometheus Federation

For large deployments, use Prometheus federation:

```yaml
# production/configs/prometheus-federation.yml
scrape_configs:
  - job_name: 'federate'
    scrape_interval: 15s
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job=~"node-exporter|docker-containers"}'
    static_configs:
      - targets:
          - 'prometheus-1:9090'
          - 'prometheus-2:9090'
```

### Custom Dashboards

Create environment-specific dashboards:

```json
{
  "dashboard": {
    "title": "Production Environment Overview",
    "tags": ["production", "environment"],
    "panels": [
      {
        "title": "Production Servers",
        "targets": [
          {
            "expr": "up{environment=\"production\"}",
            "legendFormat": "{{instance}}"
          }
        ]
      }
    ]
  }
}
```

This production deployment guide provides comprehensive instructions for deploying monitoring across multiple servers with different configurations and scenarios.
