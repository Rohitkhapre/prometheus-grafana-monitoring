# Deployment Guide

This guide provides detailed instructions for deploying the Prometheus & Grafana monitoring stack in different environments.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Docker Deployment](#docker-deployment)
3. [Kubernetes Deployment](#kubernetes-deployment)
4. [Production Considerations](#production-considerations)
5. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

#### Minimum Requirements
- **CPU**: 2 cores
- **RAM**: 4GB
- **Disk**: 10GB free space
- **Network**: Internet access for image downloads

#### Recommended Requirements
- **CPU**: 4 cores
- **RAM**: 8GB
- **Disk**: 50GB free space
- **Network**: Stable internet connection

### Software Requirements

#### For Docker Deployment
- Docker Engine 20.10 or later
- Docker Compose 2.0 or later
- curl (for health checks)
- jq (for JSON processing)

#### For Kubernetes Deployment
- Kubernetes 1.20 or later
- kubectl configured and connected to cluster
- Storage class configured
- RBAC enabled
- curl and jq (for health checks)

## Docker Deployment

### Quick Deployment

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd prometheus-grafana-monitoring
   ```

2. **Run the deployment script**:
   ```bash
   ./scripts/deploy.sh
   ```

3. **Verify deployment**:
   ```bash
   ./scripts/health-check.sh
   ```

### Manual Docker Deployment

1. **Create necessary directories**:
   ```bash
   mkdir -p data/{prometheus,grafana,alertmanager}
   ```

2. **Set environment variables** (optional):
   ```bash
   export GRAFANA_ADMIN_USER=admin
   export GRAFANA_ADMIN_PASSWORD=your-secure-password
   export PROMETHEUS_RETENTION=200h
   ```

3. **Start the services**:
   ```bash
   docker-compose up -d
   ```

4. **Verify services are running**:
   ```bash
   docker-compose ps
   ```

### Docker Configuration

#### Customizing Docker Compose

Edit `docker-compose.yml` to customize:

- **Resource limits**: Adjust CPU and memory limits
- **Port mappings**: Change exposed ports
- **Volume mounts**: Modify data persistence
- **Environment variables**: Customize configurations

#### Example Customizations

```yaml
# Custom resource limits
services:
  prometheus:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G

# Custom port mapping
services:
  grafana:
    ports:
      - "8080:3000"  # Map to port 8080 instead of 3000
```

### Docker Networking

The stack uses a custom network (`monitoring`) for internal communication:

```yaml
networks:
  monitoring:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

Services communicate using service names:
- `prometheus:9090`
- `grafana:3000`
- `alertmanager:9093`

## Kubernetes Deployment

### Quick Deployment

1. **Ensure kubectl is configured**:
   ```bash
   kubectl cluster-info
   ```

2. **Run the deployment script**:
   ```bash
   ./scripts/deploy.sh
   ```

3. **Verify deployment**:
   ```bash
   ./scripts/health-check.sh
   ```

### Manual Kubernetes Deployment

1. **Create namespace**:
   ```bash
   kubectl apply -f kubernetes/namespace.yaml
   ```

2. **Apply RBAC**:
   ```bash
   kubectl apply -f kubernetes/rbac.yaml
   ```

3. **Deploy Prometheus**:
   ```bash
   kubectl apply -f kubernetes/prometheus-configmap.yaml
   kubectl apply -f kubernetes/prometheus-deployment.yaml
   ```

4. **Deploy Grafana**:
   ```bash
   kubectl apply -f kubernetes/grafana-deployment.yaml
   ```

5. **Deploy Node Exporter**:
   ```bash
   kubectl apply -f kubernetes/node-exporter-daemonset.yaml
   ```

6. **Apply ingress** (optional):
   ```bash
   kubectl apply -f kubernetes/ingress.yaml
   ```

### Kubernetes Configuration

#### Storage Classes

Ensure your cluster has a storage class configured:

```bash
kubectl get storageclass
```

If no storage class exists, create one:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

#### Resource Management

Customize resource requests and limits in the deployment manifests:

```yaml
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

#### Service Accounts and RBAC

The deployment includes:
- Service account for Prometheus
- ClusterRole with necessary permissions
- ClusterRoleBinding to bind the role

### Accessing Services in Kubernetes

#### Port Forwarding
```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Alertmanager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
```

#### Ingress Configuration

The project includes ingress configurations for:
- Single domain with path-based routing
- Multiple domains with subdomain routing

Edit `kubernetes/ingress.yaml` to match your domain configuration.

#### LoadBalancer Services

For cloud environments, you can expose services using LoadBalancer:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: grafana-lb
  namespace: monitoring
spec:
  type: LoadBalancer
  selector:
    app: grafana
  ports:
  - port: 80
    targetPort: 3000
```

## Production Considerations

### Security

#### Authentication and Authorization
- Change default passwords
- Configure LDAP/AD integration
- Implement RBAC policies
- Use secrets management

#### Network Security
- Enable TLS/HTTPS
- Configure firewall rules
- Use network policies
- Implement service mesh

#### Data Security
- Encrypt data at rest
- Use secure communication
- Regular security updates
- Audit logging

### High Availability

#### Docker Deployment
- Use Docker Swarm mode
- Implement load balancing
- Configure health checks
- Use external storage

#### Kubernetes Deployment
- Deploy multiple replicas
- Use anti-affinity rules
- Configure pod disruption budgets
- Implement horizontal pod autoscaling

### Monitoring and Alerting

#### Custom Metrics
- Add application metrics
- Configure service discovery
- Create custom dashboards
- Set up alerting rules

#### Log Management
- Centralize logging
- Configure log rotation
- Implement log analysis
- Set up log-based alerts

### Backup and Recovery

#### Data Backup
- Regular configuration backups
- Database backups
- Volume snapshots
- Cross-region replication

#### Disaster Recovery
- Document recovery procedures
- Test backup restoration
- Maintain runbooks
- Regular DR drills

## Troubleshooting

### Common Issues

#### Services Not Starting

**Docker**:
```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs <service-name>

# Check resource usage
docker stats
```

**Kubernetes**:
```bash
# Check pod status
kubectl get pods -n monitoring

# View pod logs
kubectl logs -n monitoring <pod-name>

# Check events
kubectl get events -n monitoring
```

#### Metrics Not Appearing

1. **Check Prometheus targets**:
   - Access http://localhost:9090/targets
   - Verify targets are up and healthy

2. **Check service discovery**:
   - Review Prometheus configuration
   - Verify network connectivity
   - Check firewall rules

3. **Check RBAC** (Kubernetes):
   - Verify service account permissions
   - Check cluster role bindings
   - Review security contexts

#### High Resource Usage

1. **Monitor resource consumption**:
   ```bash
   # Docker
   docker stats
   
   # Kubernetes
   kubectl top pods -n monitoring
   ```

2. **Optimize configurations**:
   - Adjust scrape intervals
   - Reduce retention periods
   - Optimize alerting rules
   - Scale resources

#### Network Issues

1. **Check connectivity**:
   ```bash
   # Test internal connectivity
   docker exec -it <container> ping <service>
   
   # Test external connectivity
   curl -I http://localhost:9090
   ```

2. **Review network configuration**:
   - Check port mappings
   - Verify firewall rules
   - Review DNS resolution
   - Check network policies

### Performance Tuning

#### Prometheus Optimization
- Adjust scrape intervals
- Configure data retention
- Use recording rules
- Optimize query performance

#### Grafana Optimization
- Limit dashboard refresh rates
- Use data source caching
- Optimize query performance
- Configure appropriate time ranges

#### System Optimization
- Monitor resource usage
- Scale components appropriately
- Use resource limits
- Implement monitoring for the monitoring stack

### Getting Help

1. **Check logs**:
   ```bash
   ./scripts/deploy.sh logs
   ```

2. **Run health checks**:
   ```bash
   ./scripts/health-check.sh --report
   ```

3. **Review documentation**:
   - Prometheus documentation
   - Grafana documentation
   - Kubernetes documentation

4. **Community support**:
   - GitHub issues
   - Stack Overflow
   - Prometheus community
   - Grafana community
