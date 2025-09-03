#!/bin/bash
# Post-update monitoring and automatic rollback for Watchtower
# Monitors service health after updates and triggers rollback if needed

set -euo pipefail

SERVICE_NAME="${1:-}"
UPDATE_IMAGE="${2:-}"
PREVIOUS_IMAGE="${3:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
HEALTH_CHECK_TIMEOUT=300  # 5 minutes
HEALTH_CHECK_INTERVAL=15  # 15 seconds
MAX_ROLLBACK_ATTEMPTS=1

echo -e "${BLUE}🔍 Post-Update Monitor: $SERVICE_NAME${NC}"
echo "=================================="
echo "Updated to: $UPDATE_IMAGE"
echo "Previous: $PREVIOUS_IMAGE"
echo ""

# Function to check service health
check_service_health() {
    local service="$1"
    
    case $service in
        "planetplant-backend"|"planetplant-backend-staging")
            local port=$( [ "$service" = "planetplant-backend-staging" ] && echo "3002" || echo "3001" )
            curl -f -s "http://localhost:$port/api/system/status" > /dev/null
            ;;
        "planetplant-frontend"|"planetplant-frontend-staging"|"planetplant-nginx"|"planetplant-nginx-staging")
            local port=$( [[ "$service" =~ "staging" ]] && echo "8080" || echo "80" )
            curl -f -s "http://localhost:$port/health" > /dev/null
            ;;
        "planetplant-grafana"|"planetplant-grafana-staging"|"planetplant-grafana-monitoring")
            case $service in
                "planetplant-grafana") local port="3001" ;;
                "planetplant-grafana-staging") local port="3003" ;;
                "planetplant-grafana-monitoring") local port="3004" ;;
            esac
            curl -f -s "http://localhost:$port/api/health" > /dev/null
            ;;
        *)
            echo "⚠️ No health check available for $service"
            return 0
            ;;
    esac
}

# Function to send notification
send_notification() {
    local status="$1"
    local message="$2"
    
    # Load notification configuration
    if [ -f "/opt/planetplant/watchtower/.env" ]; then
        source /opt/planetplant/watchtower/.env
    fi
    
    local color="danger"
    local emoji="❌"
    if [ "$status" = "success" ]; then
        color="good"
        emoji="✅"
    elif [ "$status" = "warning" ]; then
        color="warning"
        emoji="⚠️"
    fi
    
    # Send Slack notification if configured
    if [ -n "${SLACK_WEBHOOK:-}" ]; then
        local slack_payload=$(cat << EOL
{
    "channel": "#planetplant-alerts",
    "username": "planetplant-watchtower",
    "text": "$emoji Container Update: $SERVICE_NAME",
    "attachments": [
        {
            "color": "$color",
            "fields": [
                {
                    "title": "Service",
                    "value": "$SERVICE_NAME",
                    "short": true
                },
                {
                    "title": "Status",
                    "value": "$status",
                    "short": true
                },
                {
                    "title": "Message",
                    "value": "$message",
                    "short": false
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
        
        curl -s -X POST \
            -H "Content-type: application/json" \
            -d "$slack_payload" \
            "$SLACK_WEBHOOK" > /dev/null || true
    fi
    
    # Log to watchtower logs
    echo "$(date): [$status] $SERVICE_NAME - $message" >> /opt/planetplant/watchtower/logs/rollback.log
}

# Function to perform automatic rollback
perform_rollback() {
    local service="$1"
    local previous_image="$2"
    
    echo -e "${YELLOW}🔄 Performing automatic rollback...${NC}"
    
    # Extract service name without prefix
    local service_short=${service#planetplant-}
    
    # Extract tag from previous image
    local previous_tag=$(echo "$previous_image" | cut -d':' -f2)
    
    # Execute rollback script
    if /opt/planetplant/scripts/rollback-container.sh "$service_short" "$previous_tag" "false"; then
        echo -e "${GREEN}✅ Automatic rollback completed${NC}"
        send_notification "warning" "Automatic rollback completed due to health check failure. Service restored to $previous_image"
        return 0
    else
        echo -e "${RED}❌ Automatic rollback failed${NC}"
        send_notification "danger" "Automatic rollback FAILED! Manual intervention required. Service: $service, Previous: $previous_image"
        return 1
    fi
}

# Main monitoring loop
echo -e "${YELLOW}⏳ Monitoring service health for $HEALTH_CHECK_TIMEOUT seconds...${NC}"

start_time=$(date +%s)
end_time=$((start_time + HEALTH_CHECK_TIMEOUT))
consecutive_failures=0
max_consecutive_failures=3

while [ $(date +%s) -lt $end_time ]; do
    if check_service_health "$SERVICE_NAME"; then
        consecutive_failures=0
        echo "✅ Health check passed ($(date +%H:%M:%S))"
    else
        consecutive_failures=$((consecutive_failures + 1))
        echo -e "${YELLOW}⚠️ Health check failed ($consecutive_failures/$max_consecutive_failures)${NC}"
        
        if [ $consecutive_failures -ge $max_consecutive_failures ]; then
            echo -e "${RED}❌ Service $SERVICE_NAME failed health checks${NC}"
            
            if [ -n "$PREVIOUS_IMAGE" ] && [ "$PREVIOUS_IMAGE" != "$UPDATE_IMAGE" ]; then
                echo "🔄 Triggering automatic rollback..."
                if perform_rollback "$SERVICE_NAME" "$PREVIOUS_IMAGE"; then
                    echo -e "${GREEN}✅ Rollback successful, exiting monitor${NC}"
                    exit 0
                else
                    echo -e "${RED}❌ Rollback failed, manual intervention required${NC}"
                    send_notification "danger" "Critical: Update failed AND rollback failed for $SERVICE_NAME"
                    exit 1
                fi
            else
                echo -e "${RED}❌ No previous image available for rollback${NC}"
                send_notification "danger" "Update failed for $SERVICE_NAME, no rollback possible"
                exit 1
            fi
        fi
    fi
    
    sleep $HEALTH_CHECK_INTERVAL
done

echo -e "${GREEN}✅ Service $SERVICE_NAME health monitoring completed successfully${NC}"
send_notification "success" "Update completed successfully for $SERVICE_NAME (image: $UPDATE_IMAGE)"

exit 0