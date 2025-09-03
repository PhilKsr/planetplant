# Portainer Container Management Guide

## 🐳 Overview
Portainer provides a web-based interface for managing Docker containers, stacks, and deployments across PlanetPlant environments.

## 🚀 Installation

### Automated Setup
```bash
# Run the installation script
sudo ./scripts/install-portainer.sh

# Setup webhooks for auto-deployment
./scripts/setup-webhooks.sh
```

### Manual Installation
1. Navigate to deployment directory:
   ```bash
   cd deployment/portainer
   ```

2. Start Portainer:
   ```bash
   docker compose up -d
   ```

3. Access web interface: http://localhost:9000
   - Username: `admin`
   - Password: `planetplant123!`

## 📋 Stack Templates

### Production Stack (`planetplant-production`)
- **Purpose**: Complete production deployment
- **Port**: 80 (HTTP), 443 (HTTPS)
- **Components**: InfluxDB, MQTT, Redis, Backend API, Frontend PWA, Nginx
- **Image Tag**: `latest`
- **Environment**: Production-optimized settings

### Staging Stack (`planetplant-staging`) 
- **Purpose**: Testing environment parallel to production
- **Port**: 8080 (HTTP), 8443 (HTTPS) 
- **Components**: Same as production with debugging enabled
- **Image Tag**: `develop`
- **Environment**: Enhanced logging and debugging

### Monitoring Stack (`planetplant-monitoring`)
- **Purpose**: Observability and metrics collection
- **Components**: Prometheus, Grafana, AlertManager, Loki, Node Exporter
- **Ports**: 
  - Prometheus: 9090
  - Grafana: 3004
  - AlertManager: 9093
  - Loki: 3100

## 🔗 Webhook Integration

### GitHub Repository Setup
1. Navigate to repository settings: `https://github.com/PhilKsr/planetplant/settings/hooks`
2. Add webhook with:
   - **URL**: Provided by installation script
   - **Content Type**: `application/json`
   - **Secret**: `planetplant-webhook-secret`
   - **Events**: `Push` events only

### Automatic Deployment Flow
1. **Staging**: Push to `develop` → triggers staging deployment
2. **Production**: Push to `main` → triggers production deployment
3. **Monitoring**: Updates monitoring stack when main changes

### Manual Webhook Triggers
```bash
# Deploy latest production
./deployment/portainer/update-webhook.sh production latest

# Deploy staging with specific tag
./deployment/portainer/update-webhook.sh staging v1.2.3
```

## 🎛️ Stack Management

### Deploying Stacks
1. Login to Portainer web interface
2. Navigate to **App Templates**
3. Select desired PlanetPlant template
4. Configure environment variables:
   - `REGISTRY_PREFIX`: `ghcr.io/philksr/planetplant`
   - `IMAGE_TAG`: Target deployment tag
   - `JWT_SECRET`: Production JWT secret
5. Click **Deploy the stack**

### Environment Variables
| Variable | Production | Staging | Description |
|----------|------------|---------|-------------|
| `IMAGE_TAG` | `latest` | `develop` | Container image version |
| `NODE_ENV` | `production` | `staging` | Runtime environment |
| `LOG_LEVEL` | `info` | `debug` | Logging verbosity |
| `INFLUXDB_TOKEN` | Secret | Test token | Database authentication |
| `JWT_SECRET` | Secret | Test secret | API authentication |

### Network Configuration
- **Production**: `planetplant-network` (172.25.0.0/16)
- **Staging**: `planetplant-staging-network` (172.27.0.0/16)
- **Monitoring**: `monitoring-network` (172.29.0.0/16)
- **Portainer**: `portainer-network` (172.28.0.0/16)

## 📊 Monitoring & Health Checks

### Container Health Status
All services include comprehensive health checks:
- **InfluxDB**: `/ping` endpoint monitoring
- **MQTT**: Message pub/sub test
- **Redis**: Connection and ping test
- **Backend**: `/api/system/status` endpoint
- **Frontend**: `/health` endpoint

### Log Access
View container logs directly in Portainer:
1. Navigate to **Containers**
2. Click container name
3. Select **Logs** tab
4. Configure log filters and tail options

### Resource Monitoring
- **CPU/Memory Usage**: Real-time container metrics
- **Network Traffic**: Service communication monitoring
- **Volume Usage**: Persistent data storage tracking

## 🔧 Maintenance Operations

### Backup Management
```bash
# Manual backup
./deployment/portainer/backup-portainer.sh

# Automated daily backup (configured by installation script)
# Runs at 3:00 AM daily, keeps last 10 backups
```

### SSL Configuration
```bash
# Setup SSL certificates
./deployment/portainer/setup-ssl.sh planetplant.local

# Enable HTTPS in docker-compose.yml
# Set PORTAINER_HTTPS_ENABLED=true
```

### Container Updates
1. **Via Webhook**: Automatic on Git push (recommended)
2. **Via Portainer UI**: Navigate to stack → Update
3. **Via API**: Use webhook update script

### Troubleshooting
Common issues and solutions:

#### Stack Deployment Fails
- Check environment variables are correctly set
- Verify Docker networks exist
- Review container logs for specific errors
- Ensure sufficient system resources

#### Webhook Not Triggering
- Verify webhook URL is accessible
- Check secret token matches GitHub configuration
- Review GitHub webhook delivery logs
- Confirm branch name matches trigger configuration

#### Health Check Failures
- Check service dependencies are running
- Verify port mappings and network connectivity
- Review container resource limits
- Check volume mount permissions

## 🔐 Security Considerations

### Access Control
- Admin password stored securely in Portainer data volume
- JWT tokens used for API authentication
- Webhook secrets for deployment authorization

### Network Security
- Isolated Docker networks for each environment
- Health checks prevent unhealthy container exposure
- SSL/TLS support for encrypted communications

### Credential Management
- Environment variables for sensitive data
- No hardcoded secrets in compose files
- Backup encryption for sensitive configurations

## 📈 Scaling & Performance

### Resource Limits
Configured limits prevent resource exhaustion:
- **Portainer**: 512M memory, 0.5 CPU
- **InfluxDB**: 2G memory, 2.0 CPU (production)
- **Backend**: Based on environment requirements

### Multi-Environment Strategy
- **Development**: Local Docker with hot-reload
- **Staging**: Full production simulation with debugging
- **Production**: Optimized containers with monitoring
- **Monitoring**: Dedicated observability stack

## 🔄 Integration Points

### CI/CD Pipeline
- Portainer webhooks integrate with GitHub Actions
- Automatic image building and deployment
- Health check validation post-deployment

### Service Discovery
- Docker Compose service names for internal communication
- External access via configured port mappings
- Network isolation between environments

### Data Persistence
- Bind mounts to `/opt/planetplant/` directories
- Automatic backup scheduling and rotation
- Volume configuration for each environment