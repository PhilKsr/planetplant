#!/bin/bash
# PlanetPlant Health Monitoring Setup Script
# Configures Uptime Kuma, Prometheus, Grafana with automatic service discovery

set -euo pipefail

# Configuration
MONITORING_DIR="/opt/planetplant/monitoring"
UPTIME_KUMA_PASSWORD="${UPTIME_KUMA_PASSWORD:-healthmonitor123}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-health123}"
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-admin@planetplant.local}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📊 PlanetPlant Health Monitoring Setup${NC}"
echo "======================================"
echo ""

# Create monitoring directory structure
echo -e "${YELLOW}📁 Setting up monitoring directories...${NC}"
sudo mkdir -p "$MONITORING_DIR"/{data,config,logs}
sudo mkdir -p "$MONITORING_DIR/data"/{uptime-kuma,prometheus,grafana,alertmanager}
sudo chown -R "$USER":"$USER" "$MONITORING_DIR"

# Copy configuration files
echo -e "${YELLOW}📋 Copying configuration files...${NC}"
cp -r deployment/monitoring/* "$MONITORING_DIR/"

# Create environment file
echo -e "${YELLOW}⚙️ Creating environment configuration...${NC}"
cat > "$MONITORING_DIR/.env" << EOF
# PlanetPlant Health Monitoring Configuration
# Generated on $(date)

# Grafana Configuration
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASSWORD

# Alert Configuration  
NOTIFICATION_EMAIL=$NOTIFICATION_EMAIL
SLACK_WEBHOOK=$SLACK_WEBHOOK

# SMTP Configuration (for alerts)
SMTP_SERVER=${SMTP_SERVER:-smtp.gmail.com}
SMTP_PORT=${SMTP_PORT:-587}
SMTP_USER=${SMTP_USER:-}
SMTP_PASSWORD=${SMTP_PASSWORD:-}
ALERT_EMAIL_FROM=${ALERT_EMAIL_FROM:-alerts@planetplant.local}

# Monitoring Settings
PROMETHEUS_RETENTION=7d
UPTIME_KUMA_PASSWORD=$UPTIME_KUMA_PASSWORD

# InfluxDB Connection (for Grafana)
INFLUXDB_TOKEN=${INFLUXDB_TOKEN:-plantplant-super-secret-auth-token}
INFLUXDB_ORG=${INFLUXDB_ORG:-planetplant}
INFLUXDB_BUCKET=${INFLUXDB_BUCKET:-sensor-data}
EOF

echo "✅ Environment configuration created"

# Start monitoring stack
echo -e "${YELLOW}🚀 Starting monitoring stack...${NC}"
cd "$MONITORING_DIR"
docker compose up -d

# Wait for services to start
echo -e "${YELLOW}⏳ Waiting for services to start...${NC}"
sleep 30

# Function to make API calls with retry
api_call() {
    local url="$1"
    local max_retries=10
    local retry_delay=5
    
    for i in $(seq 1 $max_retries); do
        if curl -f -s "$url" > /dev/null 2>&1; then
            return 0
        fi
        echo "⏳ Waiting for $url (attempt $i/$max_retries)..."
        sleep $retry_delay
    done
    
    return 1
}

# Verify services are running
echo -e "${YELLOW}🔍 Verifying service health...${NC}"

if api_call "http://localhost:3005/api/status-page/heartbeat"; then
    echo "✅ Uptime Kuma is healthy"
else
    echo -e "${RED}❌ Uptime Kuma health check failed${NC}"
fi

if api_call "http://localhost:9091/-/healthy"; then
    echo "✅ Prometheus is healthy" 
else
    echo -e "${RED}❌ Prometheus health check failed${NC}"
fi

if api_call "http://localhost:3006/api/health"; then
    echo "✅ Grafana is healthy"
else
    echo -e "${RED}❌ Grafana health check failed${NC}"
fi

if api_call "http://localhost:9094/-/healthy"; then
    echo "✅ AlertManager is healthy"
else
    echo -e "${RED}❌ AlertManager health check failed${NC}"
fi

# Setup Uptime Kuma monitors via API
echo -e "${YELLOW}📊 Configuring Uptime Kuma monitors...${NC}"

# Wait for Uptime Kuma to be fully ready
sleep 20

UPTIME_KUMA_URL="http://localhost:3005"

# Create admin account if needed (first-time setup)
SETUP_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"admin\",\"password\":\"$UPTIME_KUMA_PASSWORD\",\"email\":\"$NOTIFICATION_EMAIL\"}" \
    "$UPTIME_KUMA_URL/api/setup" || echo "setup_exists")

echo "Uptime Kuma setup response: $SETUP_RESPONSE"

# Login to get auth token
LOGIN_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"admin\",\"password\":\"$UPTIME_KUMA_PASSWORD\"}" \
    "$UPTIME_KUMA_URL/api/login")

if echo "$LOGIN_RESPONSE" | jq -e '.token' > /dev/null 2>&1; then
    UPTIME_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token')
    echo "✅ Uptime Kuma authentication successful"
    
    # Create monitors from configuration
    echo "📊 Creating monitoring configurations..."
    
    # Example monitor creation (simplified - real implementation would parse monitors.json)
    MONITOR_CONFIG=$(cat << 'EOL'
{
  "type": "http",
  "name": "PlanetPlant Backend Production",
  "url": "http://localhost:3001/api/health",
  "interval": 60,
  "retryInterval": 60,
  "maxretries": 3,
  "timeout": 30,
  "method": "GET"
}
EOL
)
    
    # Add monitor
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $UPTIME_TOKEN" \
        -d "$MONITOR_CONFIG" \
        "$UPTIME_KUMA_URL/api/add" > /dev/null && \
        echo "✅ Backend production monitor created" || \
        echo "⚠️ Monitor creation may need manual setup"
        
else
    echo -e "${YELLOW}⚠️ Uptime Kuma authentication failed, manual setup required${NC}"
fi

# Create status badge endpoint
cat > "$MONITORING_DIR/status-api.sh" << 'EOF'
#!/bin/bash
# Status API for external badge generation
# Returns JSON status for README badges

set -euo pipefail

# Check if monitoring services are responding
UPTIME_STATUS="unknown"
PROMETHEUS_STATUS="unknown"
GRAFANA_STATUS="unknown"

# Check Uptime Kuma
if curl -f -s http://localhost:3005/api/status-page/heartbeat > /dev/null 2>&1; then
    UPTIME_STATUS="online"
else
    UPTIME_STATUS="offline"
fi

# Check Prometheus
if curl -f -s http://localhost:9091/-/healthy > /dev/null 2>&1; then
    PROMETHEUS_STATUS="online"
else
    PROMETHEUS_STATUS="offline"  
fi

# Check Grafana
if curl -f -s http://localhost:3006/api/health > /dev/null 2>&1; then
    GRAFANA_STATUS="online"
else
    GRAFANA_STATUS="offline"
fi

# Determine overall status
OVERALL_STATUS="online"
if [ "$UPTIME_STATUS" = "offline" ] || [ "$PROMETHEUS_STATUS" = "offline" ]; then
    OVERALL_STATUS="degraded"
fi

# Generate status JSON
cat << EOL
{
  "schemaVersion": 1,
  "label": "system",
  "message": "$OVERALL_STATUS",
  "color": "$([ "$OVERALL_STATUS" = "online" ] && echo "brightgreen" || echo "yellow")",
  "namedLogo": "raspberry-pi",
  "logoColor": "white",
  "services": {
    "uptime_kuma": "$UPTIME_STATUS",
    "prometheus": "$PROMETHEUS_STATUS", 
    "grafana": "$GRAFANA_STATUS"
  },
  "timestamp": "$(date -Iseconds)"
}
EOL
EOF

chmod +x "$MONITORING_DIR/status-api.sh"
echo "✅ Status API script created"

# Create monitoring management script
cat > "$MONITORING_DIR/manage-monitoring.sh" << 'EOF'
#!/bin/bash
# Monitoring Stack Management Script

set -euo pipefail

COMMAND="${1:-status}"

case $COMMAND in
    "start")
        echo "🚀 Starting monitoring stack..."
        cd /opt/planetplant/monitoring
        docker compose up -d
        ;;
    "stop")
        echo "🛑 Stopping monitoring stack..."
        cd /opt/planetplant/monitoring
        docker compose down
        ;;
    "restart")
        echo "🔄 Restarting monitoring stack..."
        cd /opt/planetplant/monitoring
        docker compose restart
        ;;
    "status")
        echo "📊 Monitoring stack status:"
        echo ""
        echo "Services:"
        curl -s http://localhost:3005/api/status-page/heartbeat > /dev/null && echo "  ✅ Uptime Kuma (http://localhost:3005)" || echo "  ❌ Uptime Kuma"
        curl -s http://localhost:9091/-/healthy > /dev/null && echo "  ✅ Prometheus (http://localhost:9091)" || echo "  ❌ Prometheus"
        curl -s http://localhost:3006/api/health > /dev/null && echo "  ✅ Grafana (http://localhost:3006)" || echo "  ❌ Grafana"
        curl -s http://localhost:9094/-/healthy > /dev/null && echo "  ✅ AlertManager (http://localhost:9094)" || echo "  ❌ AlertManager"
        ;;
    "logs")
        echo "📋 Recent monitoring logs:"
        cd /opt/planetplant/monitoring
        docker compose logs --tail=50
        ;;
    "backup")
        echo "💾 Creating monitoring backup..."
        BACKUP_FILE="/opt/planetplant/backups/monitoring_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$BACKUP_FILE" \
            -C /opt/planetplant monitoring/data/ monitoring/config/
        echo "✅ Backup created: $BACKUP_FILE"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|backup}"
        exit 1
        ;;
esac
EOF

chmod +x "$MONITORING_DIR/manage-monitoring.sh"
echo "✅ Management script created"

# Final health check
echo -e "${YELLOW}🔍 Performing final health verification...${NC}"
sleep 10

HEALTH_SUMMARY=""
if curl -f -s http://localhost:3005/api/status-page/heartbeat > /dev/null; then
    HEALTH_SUMMARY+="✅ Uptime Kuma "
else
    HEALTH_SUMMARY+="❌ Uptime Kuma "
fi

if curl -f -s http://localhost:9091/-/healthy > /dev/null; then
    HEALTH_SUMMARY+="✅ Prometheus "
else
    HEALTH_SUMMARY+="❌ Prometheus "
fi

if curl -f -s http://localhost:3006/api/health > /dev/null; then
    HEALTH_SUMMARY+="✅ Grafana "
else
    HEALTH_SUMMARY+="❌ Grafana "
fi

echo "Health Summary: $HEALTH_SUMMARY"

# Final summary
echo ""
echo -e "${GREEN}🎉 Health monitoring setup completed!${NC}"
echo ""
echo -e "${BLUE}📊 Access Points:${NC}"
echo "   🔍 Uptime Kuma Status: http://localhost:3005"
echo "   📈 Prometheus Metrics: http://localhost:9091"
echo "   📊 Grafana Dashboards: http://localhost:3006 (admin/$GRAFANA_PASSWORD)"
echo "   🚨 AlertManager: http://localhost:9094"
echo ""
echo -e "${BLUE}🔧 Management:${NC}"
echo "   Status: $MONITORING_DIR/manage-monitoring.sh status"
echo "   Restart: $MONITORING_DIR/manage-monitoring.sh restart"
echo "   Backup: $MONITORING_DIR/manage-monitoring.sh backup"
echo ""
echo -e "${BLUE}🎯 Next Steps:${NC}"
echo "   1. Configure notification endpoints in Uptime Kuma"
echo "   2. Set up SMTP credentials for AlertManager"
echo "   3. Create public status page in Uptime Kuma"
echo "   4. Add status badges to README.md"