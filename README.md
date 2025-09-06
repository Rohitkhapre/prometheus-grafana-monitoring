# 🚀 Prometheus & Grafana Monitoring Stack

<div align="center">

![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=Prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-F46800?style=for-the-badge&logo=Grafana&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=Docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=Kubernetes&logoColor=white)

**A comprehensive, production-ready monitoring solution for Docker containers and system metrics**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/Rohitkhapre/prometheus-grafana-monitoring.svg)](https://github.com/Rohitkhapre/prometheus-grafana-monitoring/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/Rohitkhapre/prometheus-grafana-monitoring.svg)](https://github.com/Rohitkhapre/prometheus-grafana-monitoring/network)

</div>

---

## 🎯 **What This Project Delivers**

> **Transform your infrastructure monitoring with a single command!** This project provides automated deployment, health checks, and backup capabilities with support for both Docker and Kubernetes environments.

### 🔥 **Key Highlights**
- ⚡ **One-Command Deployment** - Deploy to 20+ servers automatically
- 🎨 **Beautiful Dashboards** - Pre-configured Grafana dashboards
- 🚨 **Smart Alerting** - Production-ready alerting rules
- 🔧 **Multi-Environment** - Docker, Kubernetes, and hybrid setups
- 📊 **Real-time Monitoring** - System, container, and application metrics

## ✨ **Features**

### 🎯 **Core Features**
- 🔄 **Multi-Environment Support** - Auto-detects Docker/Kubernetes
- 🏭 **Production-Ready** - Supports 20+ servers
- 🎛️ **Flexible Monitoring** - Docker-only, system-only, or hybrid
- 📈 **Comprehensive Metrics** - System, container, and application health
- 🎯 **Centralized Management** - Single server manages all agents

### 🛠️ **Advanced Features**
- ⚡ **One-Command Deployment** - Automated system detection
- 🎨 **Custom Dashboards** - Pre-configured Grafana dashboards
- 🚨 **Smart Alerting** - Production-ready alerting rules
- 💾 **Backup & Restore** - Automated backup functionality
- 🔍 **Health Monitoring** - Comprehensive health check scripts
- 📋 **Inventory Management** - YAML-based server configuration

## 📋 **Prerequisites**

| 🐳 **Docker Deployment** | ☸️ **Kubernetes Deployment** |
|:---:|:---:|
| Docker Engine 20.10+ | Kubernetes 1.20+ |
| Docker Compose 2.0+ | kubectl configured |
| 4GB RAM minimum | 4GB RAM minimum |
| 10GB disk space | 10GB disk space |
| | Storage class configured |

> 💡 **Tip**: For production deployments with 20+ servers, we recommend 8GB+ RAM and 50GB+ disk space on the monitoring server.

## 🚀 **Quick Start**

### 🧪 **Local Development/Testing**

```bash
# 1️⃣ Clone the Repository
git clone https://github.com/Rohitkhapre/prometheus-grafana-monitoring.git
cd prometheus-grafana-monitoring

# 2️⃣ Deploy the Stack (auto-detects environment)
./scripts/deploy.sh

# 3️⃣ Access the Services
# 🎨 Grafana: http://localhost:3000 (admin/admin)
# 📊 Prometheus: http://localhost:9090
# 🚨 Alertmanager: http://localhost:9093
```

### 🏭 **Production (20+ Servers)**

```bash
# 1️⃣ Clone and setup
git clone https://github.com/Rohitkhapre/prometheus-grafana-monitoring.git
cd prometheus-grafana-monitoring

# 2️⃣ Configure server inventory
cp production/inventory/servers.yml.example production/inventory/servers.yml
# ✏️ Edit servers.yml with your server details

# 3️⃣ Deploy central monitoring
./production/scripts/deploy-production.sh --central-only

# 4️⃣ Deploy agents to all servers
./production/scripts/deploy-production.sh --agents-only

# 5️⃣ Verify deployment
./production/scripts/deploy-production.sh --verify-only
```

> 🎉 **That's it!** Your monitoring stack is now running and ready to monitor your infrastructure!

## 📁 **Project Structure**

```
prometheus-grafana-monitoring/
├── 📁 configs/                    # ⚙️ Configuration files
│   ├── 📄 prometheus.yml         # 📊 Prometheus configuration
│   ├── 📄 alertmanager.yml       # 🚨 Alertmanager configuration
│   ├── 📄 blackbox.yml          # 🔍 Blackbox exporter configuration
│   ├── 📄 nginx.conf            # 🌐 Nginx reverse proxy configuration
│   ├── 📁 grafana/              # 🎨 Grafana configuration
│   └── 📁 rules/                # 📋 Alerting rules
├── 📁 dashboards/                # 📈 Grafana dashboards
│   ├── 📄 docker-overview.json  # 🐳 Docker monitoring dashboard
│   └── 📄 system-overview.json  # 🖥️ System monitoring dashboard
├── 📁 production/                # 🏭 Production deployment files
│   ├── 📁 configs/              # ⚙️ Production configurations
│   ├── 📁 inventory/            # 📋 Server inventory management
│   ├── 📁 scripts/              # 🚀 Production deployment scripts
│   └── 📁 scenarios/            # 🎯 Monitoring scenarios
├── 📁 kubernetes/                # ☸️ Kubernetes manifests
│   ├── 📄 namespace.yaml
│   ├── 📄 prometheus-deployment.yaml
│   ├── 📄 grafana-deployment.yaml
│   ├── 📄 node-exporter-daemonset.yaml
│   ├── 📄 rbac.yaml
│   └── 📄 ingress.yaml
├── 📁 scripts/                   # 🛠️ Automated deployment scripts
│   ├── 🚀 deploy.sh             # Main deployment script
│   ├── 🔍 health-check.sh       # Health check script
│   └── 💾 backup.sh             # Backup and restore script
├── 📁 docs/                      # 📚 Comprehensive documentation
├── 📁 docker/                    # 🐳 Docker-related files
├── 📄 docker-compose.yml        # 🐳 Docker Compose configuration
├── 📄 Makefile                  # ⚡ Easy command interface
└── 📄 README.md                 # 📖 This file
```

## 🔧 Configuration

### Environment Variables

You can customize the deployment using environment variables:

```bash
# Grafana Configuration
export GRAFANA_ADMIN_USER=admin
export GRAFANA_ADMIN_PASSWORD=your-secure-password

# Prometheus Configuration
export PROMETHEUS_RETENTION=200h
export PROMETHEUS_SCRAPE_INTERVAL=15s

# Alertmanager Configuration
export ALERTMANAGER_EMAIL_FROM=alerts@yourdomain.com
export ALERTMANAGER_EMAIL_TO=admin@yourdomain.com
```

### Customizing Dashboards

1. Access Grafana at http://localhost:3000
2. Import dashboards from the `dashboards/` directory
3. Customize panels and queries as needed
4. Export updated dashboards back to the repository

### Adding Custom Metrics

To monitor your applications:

1. Add Prometheus metrics to your application
2. Configure service discovery in `configs/prometheus.yml`
3. Add custom alerting rules in `configs/rules/`
4. Create custom dashboards in Grafana

## 📊 **Monitoring Components**

| 🎯 **Component** | 🎨 **Purpose** | 🔌 **Port** | ✨ **Key Features** |
|:---:|:---|:---:|:---|
| 📊 **Prometheus** | Metrics collection and storage | `9090` | Service discovery, alerting rules, data retention |
| 🎨 **Grafana** | Visualization and dashboards | `3000` | Pre-configured dashboards, alerting, user management |
| 🖥️ **Node Exporter** | System metrics collection | `9100` | CPU, memory, disk, network metrics |
| 🐳 **cAdvisor** | Container metrics collection | `8080` | Container CPU, memory, network, filesystem metrics |
| 🚨 **Alertmanager** | Alert handling and routing | `9093` | Email notifications, webhook integrations |
| 🔍 **Blackbox Exporter** | Service health checks | `9115` | HTTP, TCP, DNS, ICMP probes |

## 🚨 **Alerting**

### 🔥 **Pre-configured Alerts**

The stack includes comprehensive alerting rules for:

### 🖥️ **System Alerts**
- 🔴 **High CPU usage** (>80%)
- 🟡 **High memory usage** (>85%)
- 🔴 **High disk usage** (>90%)
- 🟡 **System load high**
- 🔴 **Node down**

### 🐳 **Docker Alerts**
- 🔴 **Container down**
- 🟡 **High container CPU** (>80%)
- 🟡 **High container memory** (>80%)
- 🔴 **Container OOM killed**
- 🟡 **Container restarting frequently**
- 🔴 **Docker daemon down**
- 🟡 **High disk usage**
- 🟡 **Network errors**

### Configuring Notifications

Edit `configs/alertmanager.yml` to configure:

- Email notifications
- Slack webhooks
- PagerDuty integration
- Custom webhook endpoints

## 🔍 Health Checks

### Running Health Checks
```bash
# Check overall health
./scripts/health-check.sh

# Generate detailed report
./scripts/health-check.sh --report
```

### Health Check Components
- Service availability
- Metrics collection
- Resource usage
- Disk space
- Network connectivity

## 💾 Backup & Restore

### Creating Backups
```bash
# Create a backup
./scripts/backup.sh

# List available backups
./scripts/backup.sh list

# Clean up old backups (older than 7 days)
./scripts/backup.sh cleanup
```

### Restoring from Backup
```bash
# Restore from backup
./scripts/backup.sh restore backups/monitoring-backup-20231201-120000.tar.gz
```

## 🐳 Docker Deployment

### Manual Docker Deployment
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Docker Environment Variables
```bash
# Customize Grafana
export GRAFANA_ADMIN_USER=admin
export GRAFANA_ADMIN_PASSWORD=secure-password

# Customize Prometheus
export PROMETHEUS_RETENTION=200h
```

## ☸️ Kubernetes Deployment

### Manual Kubernetes Deployment
```bash
# Create namespace
kubectl apply -f kubernetes/namespace.yaml

# Apply RBAC
kubectl apply -f kubernetes/rbac.yaml

# Deploy Prometheus
kubectl apply -f kubernetes/prometheus-configmap.yaml
kubectl apply -f kubernetes/prometheus-deployment.yaml

# Deploy Grafana
kubectl apply -f kubernetes/grafana-deployment.yaml

# Deploy Node Exporter
kubectl apply -f kubernetes/node-exporter-daemonset.yaml

# Apply ingress (optional)
kubectl apply -f kubernetes/ingress.yaml
```

### Accessing Services in Kubernetes
```bash
# Port forward to access services
kubectl port-forward -n monitoring svc/grafana 3000:3000
kubectl port-forward -n monitoring svc/prometheus 9090:9090
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
```

## 🔧 Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check service status
./scripts/health-check.sh

# View logs
./scripts/deploy.sh logs

# Check resource usage
docker stats  # or kubectl top pods -n monitoring
```

#### Metrics Not Appearing
1. Check Prometheus targets: http://localhost:9090/targets
2. Verify service discovery configuration
3. Check firewall rules
4. Ensure proper RBAC permissions (Kubernetes)

#### High Resource Usage
1. Adjust resource limits in docker-compose.yml or Kubernetes manifests
2. Increase retention period for Prometheus
3. Optimize scrape intervals
4. Review alerting rules

### Log Locations

#### Docker
- Container logs: `docker-compose logs <service-name>`
- Volume data: Docker volumes (prometheus_data, grafana_data, etc.)

#### Kubernetes
- Pod logs: `kubectl logs -n monitoring <pod-name>`
- Persistent volumes: Check PVC status

## 📈 Performance Tuning

### Prometheus Optimization
- Adjust scrape intervals based on needs
- Configure data retention policies
- Use recording rules for complex queries
- Optimize alerting rules

### Grafana Optimization
- Limit dashboard refresh rates
- Use data source caching
- Optimize query performance
- Configure appropriate time ranges

### Resource Optimization
- Monitor resource usage regularly
- Scale components based on load
- Use resource limits and requests
- Implement horizontal pod autoscaling (Kubernetes)

## 🔒 Security Considerations

### Production Security
1. Change default passwords
2. Enable HTTPS/TLS
3. Configure proper RBAC
4. Use secrets management
5. Implement network policies
6. Regular security updates

### Network Security
- Use reverse proxy (Nginx included)
- Configure firewall rules
- Implement network segmentation
- Use service mesh (Kubernetes)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Check the troubleshooting section
- Review the health check reports
- Consult the official Prometheus and Grafana documentation

## 🔄 Updates and Maintenance

### Regular Maintenance Tasks
1. Update container images regularly
2. Review and update alerting rules
3. Monitor disk usage and cleanup old data
4. Backup configurations and data
5. Review security configurations

### Version Updates
```bash
# Update Docker images
docker-compose pull
docker-compose up -d

# Update Kubernetes manifests
kubectl apply -f kubernetes/
```

---

## 🎯 **Quick Commands Reference**

| 🚀 **Action** | 💻 **Command** | 📝 **Description** |
|:---:|:---|:---|
| 🏃 **Deploy** | `./scripts/deploy.sh` | Deploy monitoring stack |
| 🔍 **Health Check** | `./scripts/health-check.sh` | Check all services |
| 💾 **Backup** | `./scripts/backup.sh` | Create backup |
| 📋 **List Servers** | `./production/scripts/inventory-manager.sh list` | List all servers |
| 🏭 **Production Deploy** | `./production/scripts/deploy-production.sh` | Deploy to production |
| 📊 **View Logs** | `./scripts/deploy.sh logs` | View service logs |

## 🌟 **What's Next?**

### 🎉 **Congratulations!** You now have a complete monitoring solution!

| 🎯 **Next Steps** | 📚 **Documentation** | 🛠️ **Tools** |
|:---:|:---:|:---:|
| 📊 **Customize Dashboards** | 📖 [Configuration Guide](docs/CONFIGURATION.md) | 🐳 [Docker Tools](docker/README.md) |
| 🚨 **Set Up Alerting** | 🚀 [Deployment Guide](docs/DEPLOYMENT.md) | 🏭 [Production Guide](docs/PRODUCTION-DEPLOYMENT.md) |
| 📈 **Add Custom Metrics** | 📋 [Production Summary](PRODUCTION-SUMMARY.md) | ⚡ [Makefile Commands](Makefile) |

---

### 🤝 **Contributing & Support**

[![GitHub Issues](https://img.shields.io/github/issues/Rohitkhapre/prometheus-grafana-monitoring.svg)](https://github.com/Rohitkhapre/prometheus-grafana-monitoring/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr/Rohitkhapre/prometheus-grafana-monitoring.svg)](https://github.com/Rohitkhapre/prometheus-grafana-monitoring/pulls)

**⭐ Star this repository if you found it helpful!**

**🐛 Found a bug?** [Open an issue](https://github.com/Rohitkhapre/prometheus-grafana-monitoring/issues)

**💡 Have an idea?** [Submit a PR](https://github.com/Rohitkhapre/prometheus-grafana-monitoring/pulls)

---

> 💡 **Note**: This monitoring stack is designed for production use but should be customized based on your specific requirements and security policies.
