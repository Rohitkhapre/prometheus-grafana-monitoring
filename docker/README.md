# Docker Directory

This directory contains Docker-related files for building custom images and development configurations.

## Files

### Custom Dockerfiles
- **`Dockerfile.prometheus`** - Custom Prometheus image with pre-configured settings
- **`Dockerfile.grafana`** - Custom Grafana image with pre-configured dashboards

### Development Configuration
- **`docker-compose.dev.yml`** - Development override for docker-compose
- **`nginx-test.conf`** - Nginx configuration for test application
- **`build-images.sh`** - Script to build custom Docker images

## Usage

### Build Custom Images
```bash
# Build all custom images
./docker/build-images.sh

# Build only Prometheus
./docker/build-images.sh prometheus

# Build only Grafana
./docker/build-images.sh grafana
```

### Development Environment
```bash
# Start development environment with custom images
docker-compose -f docker-compose.yml -f docker/docker-compose.dev.yml up -d

# View development logs
docker-compose -f docker-compose.yml -f docker/docker-compose.dev.yml logs -f
```

### Test Application
The development configuration includes a test Nginx application that exposes:
- **Health endpoint**: http://localhost:8080/health
- **Metrics endpoint**: http://localhost:8080/metrics

This is useful for testing the monitoring stack with a real application.

## Custom Images

### Prometheus Custom Image
- Pre-configured with monitoring rules
- Optimized for production use
- Includes custom configurations

### Grafana Custom Image
- Pre-loaded with dashboards
- Configured data sources
- Production-ready settings

## Development Features

- **Debug logging** enabled
- **Shorter retention** for development
- **Test application** included
- **Hot reload** for configurations
- **Development-friendly** settings
