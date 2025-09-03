#!/bin/bash
# Portainer Webhook Setup Script for PlanetPlant Auto-Deployment
# Configures GitHub → Portainer webhooks for automatic stack updates

set -euo pipefail

# Configuration
PORTAINER_URL="${PORTAINER_URL:-http://localhost:9000}"
PORTAINER_USERNAME="${PORTAINER_USERNAME:-admin}"
PORTAINER_PASSWORD="${PORTAINER_PASSWORD:-planetplant123!}"
WEBHOOK_SECRET="${WEBHOOK_SECRET:-planetplant-webhook-secret}"
GITHUB_REPO="${GITHUB_REPO:-PhilKsr/planetplant}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔗 PlanetPlant Webhook Setup${NC}"
echo "=============================="
echo ""

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
            "$PORTAINER_URL/api/$endpoint"
    else
        curl -s -X "$method" \
            -H "Authorization: Bearer $PORTAINER_JWT" \
            "$PORTAINER_URL/api/$endpoint"
    fi
}

# Login and get JWT token
echo -e "${YELLOW}🔐 Authenticating with Portainer...${NC}"
AUTH_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"Username\":\"$PORTAINER_USERNAME\",\"Password\":\"$PORTAINER_PASSWORD\"}" \
    "$PORTAINER_URL/api/auth")

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

# Create webhooks for each environment
echo -e "${YELLOW}🔗 Creating webhooks...${NC}"

# Production webhook
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

PROD_WEBHOOK_RESPONSE=$(portainer_api "POST" "webhooks" "$PROD_WEBHOOK")
PROD_WEBHOOK_ID=$(echo "$PROD_WEBHOOK_RESPONSE" | jq -r '.Id // empty')

if [ -n "$PROD_WEBHOOK_ID" ]; then
    PROD_WEBHOOK_URL="$PORTAINER_URL/api/webhooks/$PROD_WEBHOOK_ID"
    echo "✅ Production webhook created: $PROD_WEBHOOK_URL"
else
    echo -e "${RED}❌ Failed to create production webhook${NC}"
fi

# Staging webhook
STAGING_WEBHOOK=$(cat << EOF
{
  "Name": "planetplant-staging-webhook", 
  "Description": "Auto-deploy staging when develop branch is updated",
  "WebhookType": 1,
  "EndpointID": $ENDPOINT_ID,
  "Token": "$WEBHOOK_SECRET"
}
EOF
)

STAGING_WEBHOOK_RESPONSE=$(portainer_api "POST" "webhooks" "$STAGING_WEBHOOK")
STAGING_WEBHOOK_ID=$(echo "$STAGING_WEBHOOK_RESPONSE" | jq -r '.Id // empty')

if [ -n "$STAGING_WEBHOOK_ID" ]; then
    STAGING_WEBHOOK_URL="$PORTAINER_URL/api/webhooks/$STAGING_WEBHOOK_ID"
    echo "✅ Staging webhook created: $STAGING_WEBHOOK_URL"
else
    echo -e "${RED}❌ Failed to create staging webhook${NC}"
fi

# Setup GitHub webhooks if token provided
if [ -n "$GITHUB_TOKEN" ]; then
    echo -e "${YELLOW}🐙 Setting up GitHub webhooks...${NC}"
    
    # Production webhook (main branch)
    if [ -n "$PROD_WEBHOOK_ID" ]; then
        GITHUB_PROD_WEBHOOK=$(cat << EOF
{
  "name": "web",
  "active": true,
  "events": ["push"],
  "config": {
    "url": "$PROD_WEBHOOK_URL",
    "content_type": "json",
    "secret": "$WEBHOOK_SECRET",
    "insecure_ssl": "0"
  }
}
EOF
)
        
        GITHUB_PROD_RESPONSE=$(curl -s -X POST \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$GITHUB_PROD_WEBHOOK" \
            "https://api.github.com/repos/$GITHUB_REPO/hooks")
            
        if echo "$GITHUB_PROD_RESPONSE" | jq -e '.id' > /dev/null; then
            echo "✅ GitHub production webhook configured"
        else
            echo -e "${YELLOW}⚠️ GitHub production webhook setup failed (manual setup required)${NC}"
        fi
    fi
    
    # Staging webhook (develop branch)
    if [ -n "$STAGING_WEBHOOK_ID" ]; then
        GITHUB_STAGING_WEBHOOK=$(cat << EOF
{
  "name": "web",
  "active": true,
  "events": ["push"],
  "config": {
    "url": "$STAGING_WEBHOOK_URL", 
    "content_type": "json",
    "secret": "$WEBHOOK_SECRET",
    "insecure_ssl": "0"
  }
}
EOF
)
        
        GITHUB_STAGING_RESPONSE=$(curl -s -X POST \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$GITHUB_STAGING_WEBHOOK" \
            "https://api.github.com/repos/$GITHUB_REPO/hooks")
            
        if echo "$GITHUB_STAGING_RESPONSE" | jq -e '.id' > /dev/null; then
            echo "✅ GitHub staging webhook configured"
        else
            echo -e "${YELLOW}⚠️ GitHub staging webhook setup failed (manual setup required)${NC}"
        fi
    fi
fi

# Create webhook update script
cat > "/opt/planetplant/portainer/update-webhook.sh" << 'EOF'
#!/bin/bash
# Update Portainer stack via webhook
# Usage: ./update-webhook.sh <environment> [image_tag]

set -euo pipefail

ENVIRONMENT="${1:-production}"
IMAGE_TAG="${2:-latest}"
WEBHOOK_SECRET="${WEBHOOK_SECRET:-planetplant-webhook-secret}"

case $ENVIRONMENT in
    "production"|"prod")
        WEBHOOK_ID="${PROD_WEBHOOK_ID:-}"
        ;;
    "staging"|"stage")
        WEBHOOK_ID="${STAGING_WEBHOOK_ID:-}"
        ;;
    *)
        echo "❌ Invalid environment: $ENVIRONMENT (use: production, staging)"
        exit 1
        ;;
esac

if [ -z "$WEBHOOK_ID" ]; then
    echo "❌ Webhook ID not found for $ENVIRONMENT"
    exit 1
fi

WEBHOOK_PAYLOAD=$(cat << EOL
{
  "registry_credentials": null,
  "environment_variables": {
    "IMAGE_TAG": "$IMAGE_TAG",
    "REGISTRY_PREFIX": "ghcr.io/philksr/planetplant"
  }
}
EOL
)

echo "🚀 Triggering $ENVIRONMENT deployment with tag: $IMAGE_TAG"

RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "X-Hub-Signature-256: sha256=$(echo -n "$WEBHOOK_PAYLOAD" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" -binary | xxd -p)" \
    -d "$WEBHOOK_PAYLOAD" \
    "http://localhost:9000/api/webhooks/$WEBHOOK_ID")

if echo "$RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
    echo "✅ Deployment triggered successfully"
    echo "📊 Monitor progress in Portainer: http://localhost:9000"
else
    echo "❌ Deployment trigger failed"
    echo "Response: $RESPONSE"
    exit 1
fi
EOF

chmod +x "/opt/planetplant/portainer/update-webhook.sh"

# Update webhook IDs in the script
if [ -n "${PROD_WEBHOOK_ID:-}" ]; then
    sed -i "s/PROD_WEBHOOK_ID:-/PROD_WEBHOOK_ID:-$PROD_WEBHOOK_ID/" "/opt/planetplant/portainer/update-webhook.sh"
fi

if [ -n "${STAGING_WEBHOOK_ID:-}" ]; then
    sed -i "s/STAGING_WEBHOOK_ID:-/STAGING_WEBHOOK_ID:-$STAGING_WEBHOOK_ID/" "/opt/planetplant/portainer/update-webhook.sh"
fi

echo "✅ Webhook update script created"

# Final summary
echo ""
echo -e "${GREEN}🎉 Webhook integration completed successfully!${NC}"
echo ""
echo -e "${BLUE}🔗 Webhook URLs:${NC}"
if [ -n "${PROD_WEBHOOK_ID:-}" ]; then
    echo "   🍓 Production: $PROD_WEBHOOK_URL"
fi
if [ -n "${STAGING_WEBHOOK_ID:-}" ]; then
    echo "   🎭 Staging: $STAGING_WEBHOOK_URL"
fi
echo ""
echo -e "${BLUE}🐙 GitHub Setup Instructions:${NC}"
echo "   1. Go to: https://github.com/$GITHUB_REPO/settings/hooks"
echo "   2. Add webhook URL and secret: $WEBHOOK_SECRET"
echo "   3. Select 'Push' events"
echo "   4. Set Content-Type: application/json"
echo ""
echo -e "${BLUE}🚀 Manual Deployment:${NC}"
echo "   Production: ./update-webhook.sh production latest"
echo "   Staging: ./update-webhook.sh staging develop"