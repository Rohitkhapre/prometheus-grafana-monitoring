# Configuration Guide

This guide explains how to configure and customize the Prometheus & Grafana monitoring stack for your specific needs.

## Table of Contents

1. [Prometheus Configuration](#prometheus-configuration)
2. [Grafana Configuration](#grafana-configuration)
3. [Alerting Configuration](#alerting-configuration)
4. [Dashboard Configuration](#dashboard-configuration)
5. [Service Discovery](#service-discovery)
6. [Custom Metrics](#custom-metrics)
7. [Security Configuration](#security-configuration)

## Prometheus Configuration

### Basic Configuration

The main Prometheus configuration is located in `configs/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'docker-monitoring'
    replica: 'prometheus-1'
```

#### Key Parameters

- **scrape_interval**: How often to scrape targets (default: 15s)
- **evaluation_interval**: How often to evaluate alerting rules (default: 15s)
- **external_labels**: Labels added to all metrics

### Scrape Configuration

#### Adding New Targets

To monitor additional services, add new scrape configs:

```yaml
scrape_configs:
  - job_name: 'my-application'
    static_configs:
      - targets: ['my-app:8080']
    scrape_interval: 30s
    metrics_path: /metrics
    scheme: http
```

#### Service Discovery

For dynamic target discovery, use service discovery:

```yaml
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
```

### Data Retention

Configure data retention in the deployment:

```yaml
# Docker Compose
command:
  - '--storage.tsdb.retention.time=200h'

# Kubernetes
args:
  - '--storage.tsdb.retention.time=200h'
```

### Recording Rules

Create recording rules for complex queries:

```yaml
# configs/rules/recording-rules.yml
groups:
- name: recording_rules
  rules:
  - record: instance:node_cpu_usage:rate5m
    expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

## Grafana Configuration

### Basic Configuration

Grafana configuration is in `configs/grafana/grafana.ini`:

```ini
[server]
protocol = http
http_port = 3000
domain = localhost

[security]
admin_user = admin
admin_password = admin
secret_key = SW2YcwTIb9zpOOhoPsMm
```

### Data Source Configuration

Data sources are configured in `configs/grafana/provisioning/datasources/prometheus.yml`:

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
```

### Dashboard Provisioning

Dashboards are automatically provisioned from the `dashboards/` directory:

```yaml
# configs/grafana/provisioning/dashboards/dashboard.yml
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
```

### User Management

#### Authentication

Configure authentication methods:

```ini
[auth.anonymous]
enabled = false
org_name = Main Org.
org_role = Viewer

[auth.github]
enabled = false
allow_sign_up = true
client_id = your_github_client_id
client_secret = your_github_client_secret
```

#### Organizations and Teams

```ini
[users]
allow_sign_up = true
allow_org_create = true
auto_assign_org = true
auto_assign_org_id = 1
auto_assign_org_role = Viewer
```

## Alerting Configuration

### Alertmanager Configuration

Configure alert routing in `configs/alertmanager.yml`:

```yaml
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alertmanager@example.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
  routes:
  - match:
      severity: critical
    receiver: 'critical-alerts'
```

### Alert Rules

#### System Alerts

```yaml
# configs/rules/system-alerts.yml
groups:
- name: system.rules
  rules:
  - alert: HighCPUUsage
    expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ $labels.instance }}"
```

#### Docker Alerts

```yaml
# configs/rules/docker-alerts.yml
groups:
- name: docker.rules
  rules:
  - alert: DockerContainerDown
    expr: up{job="docker-containers"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Docker container {{ $labels.container_name }} is down"
```

### Notification Channels

#### Email Notifications

```yaml
receivers:
- name: 'email-alerts'
  email_configs:
  - to: 'admin@example.com'
    subject: '[ALERT] {{ .GroupLabels.alertname }}'
    body: |
      {{ range .Alerts }}
      Alert: {{ .Annotations.summary }}
      Description: {{ .Annotations.description }}
      {{ end }}
```

#### Slack Notifications

```yaml
receivers:
- name: 'slack-alerts'
  slack_configs:
  - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
    channel: '#alerts'
    title: 'Prometheus Alert'
    text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
```

#### Webhook Notifications

```yaml
receivers:
- name: 'webhook-alerts'
  webhook_configs:
  - url: 'http://your-webhook-endpoint.com/alerts'
    send_resolved: true
```

## Dashboard Configuration

### Creating Custom Dashboards

1. **Access Grafana**: http://localhost:3000
2. **Create Dashboard**: Click "+" → "Dashboard"
3. **Add Panels**: Click "Add panel"
4. **Configure Queries**: Use PromQL queries
5. **Export Dashboard**: Save as JSON

### Dashboard Variables

Add variables for dynamic dashboards:

```json
{
  "templating": {
    "list": [
      {
        "name": "instance",
        "type": "query",
        "query": "label_values(node_cpu_seconds_total, instance)",
        "refresh": 1,
        "includeAll": true,
        "multi": true
      }
    ]
  }
}
```

### Panel Configuration

#### Time Series Panels

```json
{
  "targets": [
    {
      "expr": "rate(node_cpu_seconds_total[5m])",
      "legendFormat": "{{cpu}}"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "percent",
      "min": 0,
      "max": 100
    }
  }
}
```

#### Stat Panels

```json
{
  "targets": [
    {
      "expr": "count(up == 1)",
      "legendFormat": "Up Services"
    }
  ],
  "options": {
    "colorMode": "value",
    "graphMode": "area"
  }
}
```

## Service Discovery

### Docker Service Discovery

Monitor Docker containers automatically:

```yaml
scrape_configs:
  - job_name: 'docker-containers'
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
        filters:
          - name: label
            values: ["prometheus.io/scrape=true"]
```

### Kubernetes Service Discovery

#### Pod Discovery

```yaml
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
```

#### Service Discovery

```yaml
scrape_configs:
  - job_name: 'kubernetes-services'
    kubernetes_sd_configs:
      - role: service
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
        action: keep
        regex: true
```

### Consul Service Discovery

```yaml
scrape_configs:
  - job_name: 'consul-services'
    consul_sd_configs:
      - server: 'consul:8500'
        services: ['prometheus']
```

## Custom Metrics

### Adding Metrics to Applications

#### Go Application

```go
package main

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
    "net/http"
)

var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
)

func init() {
    prometheus.MustRegister(httpRequestsTotal)
}

func main() {
    http.Handle("/metrics", promhttp.Handler())
    http.ListenAndServe(":8080", nil)
}
```

#### Node.js Application

```javascript
const express = require('express');
const client = require('prom-client');

const app = express();
const register = new client.Registry();

// Add default metrics
client.collectDefaultMetrics({ register });

// Custom metric
const httpRequestsTotal = new client.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'endpoint', 'status'],
    registers: [register]
});

app.get('/metrics', (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(register.metrics());
});

app.listen(8080);
```

#### Python Application

```python
from prometheus_client import Counter, Histogram, start_http_server
import time

# Custom metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')

def process_request():
    REQUEST_COUNT.labels(method='GET', endpoint='/api').inc()
    with REQUEST_DURATION.time():
        # Your application logic here
        time.sleep(0.1)

if __name__ == '__main__':
    start_http_server(8080)
    # Your application code here
```

### Configuring Scraping

Add your application to Prometheus configuration:

```yaml
scrape_configs:
  - job_name: 'my-application'
    static_configs:
      - targets: ['my-app:8080']
    scrape_interval: 15s
    metrics_path: /metrics
```

## Security Configuration

### Authentication

#### Grafana Authentication

```ini
[auth.ldap]
enabled = true
config_file = /etc/grafana/ldap.toml
allow_sign_up = true

[auth.oauth]
enabled = true
name = OAuth
client_id = your_client_id
client_secret = your_client_secret
scopes = user:email,read:org
auth_url = https://github.com/login/oauth/authorize
token_url = https://github.com/login/oauth/access_token
api_url = https://api.github.com/user
```

#### Prometheus Authentication

Use reverse proxy for authentication:

```nginx
location /prometheus/ {
    auth_basic "Prometheus";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://prometheus:9090/;
}
```

### TLS/SSL Configuration

#### Grafana HTTPS

```ini
[server]
protocol = https
cert_file = /etc/grafana/cert.pem
cert_key = /etc/grafana/key.pem
```

#### Nginx SSL

```nginx
server {
    listen 443 ssl http2;
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
}
```

### Network Security

#### Firewall Rules

```bash
# Allow only necessary ports
ufw allow 3000/tcp  # Grafana
ufw allow 9090/tcp  # Prometheus
ufw allow 9093/tcp  # Alertmanager
ufw deny 9100/tcp   # Node Exporter (internal only)
```

#### Kubernetes Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: monitoring-network-policy
  namespace: monitoring
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: monitoring
```

### Secrets Management

#### Docker Secrets

```yaml
# docker-compose.yml
services:
  grafana:
    environment:
      - GF_SECURITY_ADMIN_PASSWORD_FILE=/run/secrets/grafana_password
    secrets:
      - grafana_password

secrets:
  grafana_password:
    file: ./secrets/grafana_password.txt
```

#### Kubernetes Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-secrets
  namespace: monitoring
type: Opaque
data:
  admin-password: <base64-encoded-password>
```

### RBAC Configuration

#### Kubernetes RBAC

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
```

## Performance Tuning

### Prometheus Performance

#### Scrape Configuration

```yaml
global:
  scrape_interval: 30s  # Increase for high-volume environments
  scrape_timeout: 10s
  evaluation_interval: 30s
```

#### Storage Configuration

```yaml
# Command line arguments
- '--storage.tsdb.retention.time=30d'
- '--storage.tsdb.retention.size=10GB'
- '--storage.tsdb.wal-compression'
- '--storage.tsdb.min-block-duration=2h'
- '--storage.tsdb.max-block-duration=25h'
```

### Grafana Performance

#### Caching

```ini
[dataproxy]
timeout = 30
dial_timeout = 10
keep_alive_seconds = 30
max_idle_connections_per_host = 10

[datasources]
timeout = 30
```

#### Dashboard Optimization

- Limit dashboard refresh rates
- Use appropriate time ranges
- Optimize query performance
- Use data source caching

### Resource Optimization

#### Docker Resource Limits

```yaml
services:
  prometheus:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
```

#### Kubernetes Resource Management

```yaml
resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```

This configuration guide provides comprehensive information for customizing the monitoring stack to meet your specific requirements. Remember to test configurations in a non-production environment before applying them to production systems.
