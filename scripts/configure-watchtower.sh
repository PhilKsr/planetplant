#!/bin/bash
# Watchtower Configuration Script for PlanetPlant
# Sets up email notifications, update schedule, and monitoring integration

set -euo pipefail

# Configuration
WATCHTOWER_DIR="/opt/planetplant/watchtower"
SMTP_SERVER="${SMTP_SERVER:-smtp.gmail.com}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASSWORD="${SMTP_PASSWORD:-}"
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-admin@planetplant.local}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🐕 PlanetPlant Watchtower Configuration${NC}"
echo "======================================"
echo ""

# Create watchtower directory structure
echo -e "${YELLOW}📁 Setting up Watchtower directories...${NC}"
sudo mkdir -p "$WATCHTOWER_DIR"/{config,logs,scripts}
sudo chown -R "$USER":"$USER" "$WATCHTOWER_DIR"

# Copy deployment files
echo -e "${YELLOW}📋 Copying deployment files...${NC}"
cp -r deployment/watchtower/* "$WATCHTOWER_DIR/"

# Interactive SMTP configuration if not provided
if [ -z "$SMTP_USER" ]; then
    echo -e "${YELLOW}📧 Configure Email Notifications${NC}"
    echo "Current SMTP settings:"
    echo "  Server: $SMTP_SERVER"
    echo "  Port: $SMTP_PORT"
    echo "  To: $NOTIFICATION_EMAIL"
    echo ""
    
    read -p "Enter SMTP username (email): " SMTP_USER
    read -s -p "Enter SMTP password/app-password: " SMTP_PASSWORD
    echo ""
    read -p "Enter notification email recipient [$NOTIFICATION_EMAIL]: " EMAIL_INPUT
    NOTIFICATION_EMAIL="${EMAIL_INPUT:-$NOTIFICATION_EMAIL}"
fi

# Create environment file for Watchtower
echo -e "${YELLOW}⚙️ Creating environment configuration...${NC}"
cat > "$WATCHTOWER_DIR/.env" << EOF
# Watchtower Configuration for PlanetPlant
# Generated on $(date)

# Update Schedule (2-4 AM CET)
WATCHTOWER_SCHEDULE=0 0 2-4 * * *
TZ=Europe/Berlin

# SMTP Email Configuration
SMTP_SERVER=$SMTP_SERVER
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASSWORD=$SMTP_PASSWORD
SMTP_FROM=watchtower@planetplant.local
NOTIFICATION_EMAIL=$NOTIFICATION_EMAIL

# Slack Configuration (optional)
SLACK_WEBHOOK=$SLACK_WEBHOOK

# API Configuration
WATCHTOWER_API_TOKEN=$(openssl rand -hex 32)

# Debug Settings
WATCHTOWER_DEBUG=false
WATCHTOWER_LOG_LEVEL=info
EOF

echo "✅ Environment configuration created"

# Create backup script for pre-update hooks
echo -e "${YELLOW}💾 Creating backup scripts...${NC}"
cat > "$WATCHTOWER_DIR/scripts/backup-service.sh" << 'EOF'
#!/bin/bash
# Pre-update backup script for Watchtower lifecycle hooks
# Usage: backup-service.sh <service_name>

set -euo pipefail

SERVICE_NAME="${1:-unknown}"
BACKUP_DIR="/opt/planetplant/backups/watchtower"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="pre_update_${SERVICE_NAME}_${TIMESTAMP}.tar.gz"

echo "📦 Creating pre-update backup for $SERVICE_NAME..."
mkdir -p "$BACKUP_DIR"

# Backup strategy based on service type
case $SERVICE_NAME in
    "backend"|"backend-staging")
        echo "🔧 Backing up backend configuration and logs..."
        tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
            -C /opt/planetplant logs/backend/ || true
        ;;
    "frontend"|"frontend-staging")
        echo "🌐 Backing up frontend assets..."
        # No persistent data to backup for frontend
        touch "$BACKUP_DIR/${SERVICE_NAME}_${TIMESTAMP}.backup"
        ;;
    "nginx-proxy"|"nginx-proxy-staging")
        echo "🔀 Backing up nginx configuration..."
        # No persistent data to backup for nginx proxy
        touch "$BACKUP_DIR/${SERVICE_NAME}_${TIMESTAMP}.backup"
        ;;
    *)
        echo "ℹ️ Generic backup for $SERVICE_NAME"
        touch "$BACKUP_DIR/${SERVICE_NAME}_${TIMESTAMP}.backup"
        ;;
esac

echo "✅ Pre-update backup completed: $BACKUP_FILE"

# Keep only last 5 backups per service
ls -t "$BACKUP_DIR"/pre_update_${SERVICE_NAME}_*.* 2>/dev/null | tail -n +6 | xargs -r rm

echo "🧹 Old backups cleaned (keeping last 5)"
EOF

chmod +x "$WATCHTOWER_DIR/scripts/backup-service.sh"
echo "✅ Backup script created"

# Create health check verification script
cat > "$WATCHTOWER_DIR/scripts/verify-health.sh" << 'EOF'
#!/bin/bash
# Post-update health verification for critical services
# Usage: verify-health.sh <service_name>

set -euo pipefail

SERVICE_NAME="${1:-unknown}"
MAX_RETRIES=30
RETRY_DELAY=10

echo "🔍 Verifying health for $SERVICE_NAME..."

# Health check endpoints based on service type
case $SERVICE_NAME in
    "backend"|"backend-staging")
        HEALTH_URL="http://localhost:3000/api/system/status"
        if [ "$SERVICE_NAME" = "backend-staging" ]; then
            HEALTH_URL="http://localhost:3000/api/system/status"  # Internal port
        fi
        ;;
    "frontend"|"frontend-staging"|"nginx-proxy"|"nginx-proxy-staging")
        HEALTH_URL="http://localhost/health"
        ;;
    *)
        echo "⚠️ No specific health check for $SERVICE_NAME"
        exit 0
        ;;
esac

# Retry health check
for i in $(seq 1 $MAX_RETRIES); do
    if curl -f -s "$HEALTH_URL" > /dev/null 2>&1; then
        echo "✅ $SERVICE_NAME health check passed (attempt $i)"
        exit 0
    fi
    
    echo "⏳ Health check failed, retry $i/$MAX_RETRIES in ${RETRY_DELAY}s..."
    sleep $RETRY_DELAY
done

echo "❌ $SERVICE_NAME health check failed after $MAX_RETRIES attempts"
exit 1
EOF

chmod +x "$WATCHTOWER_DIR/scripts/verify-health.sh"
echo "✅ Health verification script created"

# Create notification test script
cat > "$WATCHTOWER_DIR/scripts/test-notifications.sh" << 'EOF'
#!/bin/bash
# Test Watchtower notification configuration

set -euo pipefail

source /opt/planetplant/watchtower/.env

echo "📧 Testing Watchtower notifications..."

# Test email notification
if [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASSWORD" ]; then
    echo "📬 Testing email notification to $NOTIFICATION_EMAIL..."
    
    # Create test message
    TEST_MESSAGE="Subject: [PlanetPlant] Watchtower Configuration Test
To: $NOTIFICATION_EMAIL
From: $SMTP_FROM

This is a test notification from PlanetPlant Watchtower configuration.

Timestamp: $(date)
Server: $(hostname)
Configuration: Valid

If you receive this message, email notifications are working correctly.
"

    # Send test email using curl
    curl -s --url "smtps://$SMTP_SERVER:$SMTP_PORT" \
        --ssl-reqd \
        --mail-from "$SMTP_FROM" \
        --mail-rcpt "$NOTIFICATION_EMAIL" \
        --user "$SMTP_USER:$SMTP_PASSWORD" \
        --upload-file <(echo "$TEST_MESSAGE") && \
        echo "✅ Test email sent successfully" || \
        echo "❌ Email test failed"
else
    echo "⚠️ SMTP credentials not configured, skipping email test"
fi

# Test Slack notification
if [ -n "$SLACK_WEBHOOK" ]; then
    echo "💬 Testing Slack notification..."
    
    SLACK_PAYLOAD=$(cat << EOL
{
    "channel": "#planetplant-alerts",
    "username": "planetplant-watchtower", 
    "text": "🧪 Watchtower configuration test from $(hostname)",
    "attachments": [
        {
            "color": "good",
            "fields": [
                {
                    "title": "Status",
                    "value": "Configuration test successful",
                    "short": true
                },
                {
                    "title": "Timestamp", 
                    "value": "$(date)",
                    "short": true
                }
            ]
        }
    ]
}
EOL
)

    if curl -s -X POST \
        -H "Content-type: application/json" \
        -d "$SLACK_PAYLOAD" \
        "$SLACK_WEBHOOK" > /dev/null; then
        echo "✅ Slack test message sent successfully"
    else
        echo "❌ Slack test failed"
    fi
else
    echo "⚠️ Slack webhook not configured, skipping Slack test"
fi

echo ""
echo "🎯 Notification testing completed"
EOF

chmod +x "$WATCHTOWER_DIR/scripts/test-notifications.sh"
echo "✅ Notification test script created"

# Start Watchtower
echo -e "${YELLOW}🚀 Starting Watchtower...${NC}"
cd "$WATCHTOWER_DIR"
docker compose up -d

# Wait for startup
echo -e "${YELLOW}⏳ Waiting for Watchtower to start...${NC}"
sleep 15

# Verify Watchtower API
echo -e "${YELLOW}🔍 Verifying Watchtower API...${NC}"
if curl -f -s http://localhost:8080/v1/health > /dev/null; then
    echo "✅ Watchtower API is healthy"
else
    echo -e "${RED}❌ Watchtower API health check failed${NC}"
fi

# Final summary
echo ""
echo -e "${GREEN}🎉 Watchtower configuration completed successfully!${NC}"
echo ""
echo -e "${BLUE}⚙️ Configuration Summary:${NC}"
echo "   📧 Email: $NOTIFICATION_EMAIL"
echo "   ⏰ Schedule: 2-4 AM CET daily"
echo "   🎯 Scope: planetplant labeled containers"
echo "   🔄 Policy: Frontend/Nginx auto-update, Backend with pre-check, Databases manual"
echo ""
echo -e "${BLUE}🔧 Management Commands:${NC}"
echo "   Test notifications: $WATCHTOWER_DIR/scripts/test-notifications.sh"
echo "   Manual update check: curl -H \"Authorization: Bearer \$WATCHTOWER_API_TOKEN\" http://localhost:8080/v1/update"
echo "   View logs: docker logs planetplant-watchtower"
echo ""
echo -e "${BLUE}📊 Monitoring:${NC}"
echo "   API Health: http://localhost:8080/v1/health"
echo "   Metrics: http://localhost:8080/v1/metrics"
echo "   Logs: $WATCHTOWER_DIR/logs/"