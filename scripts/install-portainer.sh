#!/bin/bash
# Portainer Installation and Configuration Script for PlanetPlant
# Sets up Portainer CE with PlanetPlant stack templates and webhooks

set -euo pipefail

# Configuration
PORTAINER_DIR="/opt/planetplant/portainer"
PORTAINER_PASSWORD="${PORTAINER_PASSWORD:-planetplant123!}"
PORTAINER_USERNAME="${PORTAINER_USERNAME:-admin}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
WEBHOOK_SECRET="${WEBHOOK_SECRET:-planetplant-webhook-secret}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🐳 PlanetPlant Portainer Setup${NC}"
echo "==============================="
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not available${NC}"
    exit 1
fi

# Detect docker-compose command
DOCKER_COMPOSE="docker-compose"
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
fi

# Setup Portainer directory structure
echo -e "${YELLOW}📁 Setting up Portainer directories...${NC}"
sudo mkdir -p "$PORTAINER_DIR"/{data,backups,ssl,stacks}
sudo chown -R "$USER":"$USER" "$PORTAINER_DIR"

# Copy deployment files
echo -e "${YELLOW}📋 Copying deployment files...${NC}"
cp -r deployment/portainer/* "$PORTAINER_DIR/"
cp -r deployment/portainer/stacks "$PORTAINER_DIR/"

# Generate admin password file
echo -e "${YELLOW}🔐 Setting up admin password...${NC}"
echo "$PORTAINER_PASSWORD" | docker run --rm -i portainer/portainer-ce:2.21.4 --hash > "$PORTAINER_DIR/data/admin_password"
echo "✅ Admin password configured (username: $PORTAINER_USERNAME)"

# Start Portainer
echo -e "${YELLOW}🚀 Starting Portainer...${NC}"
cd "$PORTAINER_DIR"
$DOCKER_COMPOSE up -d

# Wait for Portainer to start
echo -e "${YELLOW}⏳ Waiting for Portainer to start...${NC}"
sleep 30

# Function to make Portainer API calls
portainer_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    
    if [ -n "$data" ]; then
        curl -s -X "$method" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $PORTAINER_JWT" \
            -d "$data" \
            "http://localhost:9000/api/$endpoint"
    else
        curl -s -X "$method" \
            -H "Authorization: Bearer $PORTAINER_JWT" \
            "http://localhost:9000/api/$endpoint"
    fi
}

# Login and get JWT token
echo -e "${YELLOW}🔐 Authenticating with Portainer...${NC}"
AUTH_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"Username\":\"$PORTAINER_USERNAME\",\"Password\":\"$PORTAINER_PASSWORD\"}" \
    "http://localhost:9000/api/auth")

if echo "$AUTH_RESPONSE" | jq -e '.jwt' > /dev/null; then
    PORTAINER_JWT=$(echo "$AUTH_RESPONSE" | jq -r '.jwt')
    echo "✅ Authentication successful"
else
    echo -e "${RED}❌ Portainer authentication failed${NC}"
    echo "Response: $AUTH_RESPONSE"
    exit 1
fi

# Get endpoint ID (local Docker environment)
echo -e "${YELLOW}🎯 Getting Docker endpoint...${NC}"
ENDPOINTS=$(portainer_api "GET" "endpoints")
ENDPOINT_ID=$(echo "$ENDPOINTS" | jq -r '.[0].Id // 1')
echo "✅ Docker endpoint ID: $ENDPOINT_ID"

# Create PlanetPlant stack templates
echo -e "${YELLOW}📋 Creating stack templates...${NC}"

# Production stack
PROD_STACK=$(cat << 'EOF'
{
  "Name": "planetplant-production",
  "Type": 1,
  "Title": "PlanetPlant Production",
  "Description": "Complete PlanetPlant IoT system for production deployment",
  "Note": "Includes InfluxDB, MQTT, Redis, Backend API, Frontend PWA and Nginx proxy",
  "Categories": ["IoT", "Monitoring", "Smart Home"],
  "Platform": "linux",
  "Logo": "https://raw.githubusercontent.com/PhilKsr/planetplant/main/webapp/public/logo.png",
  "Repository": {
    "url": "https://github.com/PhilKsr/planetplant",
    "stackfile": "docker-compose.yml"
  },
  "Env": [
    {
      "name": "REGISTRY_PREFIX",
      "label": "Container Registry Prefix",
      "default": "ghcr.io/philksr/planetplant",
      "description": "Registry prefix for container images"
    },
    {
      "name": "IMAGE_TAG", 
      "label": "Image Tag",
      "default": "latest",
      "description": "Container image tag to deploy"
    },
    {
      "name": "INFLUXDB_TOKEN",
      "label": "InfluxDB Token",
      "default": "plantplant-super-secret-auth-token",
      "description": "InfluxDB authentication token"
    },
    {
      "name": "JWT_SECRET",
      "label": "JWT Secret",
      "default": "your-super-secret-jwt-key-change-this",
      "description": "JWT secret for backend authentication"
    }
  ]
}
EOF
)

# Create template via API
TEMPLATE_RESPONSE=$(portainer_api "POST" "custom_templates" "$PROD_STACK")
echo "✅ Production template created"

# Staging stack template
STAGING_STACK=$(cat << 'EOF'
{
  "Name": "planetplant-staging", 
  "Type": 1,
  "Title": "PlanetPlant Staging",
  "Description": "PlanetPlant staging environment for testing before production",
  "Note": "Runs on different ports to allow parallel staging/production deployment",
  "Categories": ["IoT", "Testing", "Development"],
  "Platform": "linux",
  "Logo": "https://raw.githubusercontent.com/PhilKsr/planetplant/main/webapp/public/logo.png",
  "Repository": {
    "url": "https://github.com/PhilKsr/planetplant",
    "stackfile": "docker-compose.staging.yml"
  },
  "Env": [
    {
      "name": "REGISTRY_PREFIX",
      "label": "Container Registry Prefix", 
      "default": "ghcr.io/philksr/planetplant",
      "description": "Registry prefix for container images"
    },
    {
      "name": "IMAGE_TAG",
      "label": "Image Tag",
      "default": "develop", 
      "description": "Container image tag to deploy (usually develop for staging)"
    },
    {
      "name": "LOG_LEVEL",
      "label": "Log Level",
      "default": "debug",
      "description": "Logging verbosity for staging"
    }
  ]
}
EOF
)

STAGING_TEMPLATE_RESPONSE=$(portainer_api "POST" "custom_templates" "$STAGING_STACK")
echo "✅ Staging template created"

# Create webhook for auto-deployment
if [ -n "$GITHUB_TOKEN" ]; then
    echo -e "${YELLOW}🔗 Setting up webhooks for auto-deployment...${NC}"
    
    # Create webhook for production stack
    PROD_WEBHOOK=$(cat << EOF
{
  "Name": "planetplant-production-webhook",
  "Description": "Auto-deploy production when main branch is updated",
  "WebhookType": 1,
  "EndpointID": $ENDPOINT_ID,
  "Token": "$WEBHOOK_SECRET"
}
EOF
)
    
    WEBHOOK_RESPONSE=$(portainer_api "POST" "webhooks" "$PROD_WEBHOOK")
    WEBHOOK_ID=$(echo "$WEBHOOK_RESPONSE" | jq -r '.Id // empty')
    
    if [ -n "$WEBHOOK_ID" ]; then
        echo "✅ Production webhook created: http://localhost:9000/api/webhooks/$WEBHOOK_ID"
        echo "   Add this to GitHub: http://your-pi:9000/api/webhooks/$WEBHOOK_ID"
    fi
fi

# Create backup script
cat > "$PORTAINER_DIR/backup-portainer.sh" << 'EOF'
#!/bin/bash
# Portainer Backup Script
set -euo pipefail

BACKUP_DIR="/opt/planetplant/portainer/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="portainer_backup_${DATE}.tar.gz"

echo "📦 Creating Portainer backup..."
mkdir -p "$BACKUP_DIR"

# Stop Portainer temporarily
docker compose -f /opt/planetplant/portainer/docker-compose.yml stop portainer

# Create backup
tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
    -C /opt/planetplant/portainer data/ ssl/ stacks/

# Restart Portainer
docker compose -f /opt/planetplant/portainer/docker-compose.yml start portainer

echo "✅ Backup created: $BACKUP_FILE"
echo "📍 Location: $BACKUP_DIR/$BACKUP_FILE"

# Clean old backups (keep last 10)
ls -t "$BACKUP_DIR"/portainer_backup_*.tar.gz | tail -n +11 | xargs -r rm

echo "🧹 Old backups cleaned (keeping last 10)"
EOF

chmod +x "$PORTAINER_DIR/backup-portainer.sh"
echo "✅ Backup script created"

# Create SSL setup script (for future use)
cat > "$PORTAINER_DIR/setup-ssl.sh" << 'EOF'
#!/bin/bash
# SSL Setup for Portainer
set -euo pipefail

SSL_DIR="/opt/planetplant/portainer/ssl"
DOMAIN="${1:-planetplant.local}"

echo "🔐 Setting up SSL for Portainer..."
echo "Domain: $DOMAIN"

mkdir -p "$SSL_DIR"

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 \
    -newkey rsa:4096 \
    -keyout "$SSL_DIR/portainer.key" \
    -out "$SSL_DIR/portainer.crt" \
    -subj "/CN=$DOMAIN/O=PlanetPlant/C=US"

# Set proper permissions
chmod 600 "$SSL_DIR/portainer.key"
chmod 644 "$SSL_DIR/portainer.crt"

echo "✅ SSL certificate generated"
echo "📁 Certificate: $SSL_DIR/portainer.crt"
echo "🔑 Private Key: $SSL_DIR/portainer.key"
echo ""
echo "To enable HTTPS:"
echo "1. Update docker-compose.yml: PORTAINER_HTTPS_ENABLED=true"
echo "2. Restart Portainer: make portainer-restart"
echo "3. Access via: https://$DOMAIN:9443"
EOF

chmod +x "$PORTAINER_DIR/setup-ssl.sh"
echo "✅ SSL setup script created"

# Setup cron job for automatic backups
echo -e "${YELLOW}⏰ Setting up automatic backups...${NC}"
CRON_JOB="0 3 * * * $PORTAINER_DIR/backup-portainer.sh >> $PORTAINER_DIR/backups/backup.log 2>&1"
(crontab -l 2>/dev/null | grep -v backup-portainer.sh; echo "$CRON_JOB") | crontab -
echo "✅ Daily backup scheduled at 3:00 AM"

# Final status check
echo -e "${YELLOW}🔍 Performing final health check...${NC}"
sleep 10

if curl -f -s http://localhost:9000/api/status > /dev/null; then
    echo -e "${GREEN}✅ Portainer is running successfully!${NC}"
else
    echo -e "${RED}❌ Portainer health check failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Portainer installation completed successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Access Portainer:${NC}"
echo "   🌐 Web Interface: http://localhost:9000"
echo "   🔐 Username: $PORTAINER_USERNAME"
echo "   🔑 Password: $PORTAINER_PASSWORD"
echo ""
echo -e "${BLUE}📋 Available Stack Templates:${NC}"
echo "   🍓 PlanetPlant Production"
echo "   🎭 PlanetPlant Staging"
echo ""
echo -e "${BLUE}🔧 Next Steps:${NC}"
echo "   1. Login to Portainer web interface"
echo "   2. Navigate to App Templates"
echo "   3. Deploy PlanetPlant stack"
echo "   4. Configure webhooks in GitHub repository settings"
echo ""
echo -e "${YELLOW}💡 Useful Commands:${NC}"
echo "   make portainer-logs      # View Portainer logs"
echo "   make portainer-backup    # Manual backup"
echo "   make portainer-restart   # Restart Portainer"
echo ""