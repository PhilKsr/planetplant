#!/bin/bash
# Container Rollback Script for PlanetPlant
# Rolls back containers to previous image tags with health verification

set -euo pipefail

# Configuration
SERVICE_NAME="${1:-}"
TARGET_TAG="${2:-previous}"
VERIFY_HEALTH="${3:-true}"
BACKUP_REGISTRY="${BACKUP_REGISTRY:-ghcr.io/philksr/planetplant}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$SERVICE_NAME" ]; then
    echo -e "${RED}❌ Usage: $0 <service_name> [target_tag] [verify_health]${NC}"
    echo ""
    echo "Examples:"
    echo "  $0 backend previous           # Rollback to previous image"
    echo "  $0 frontend v1.2.3           # Rollback to specific tag"
    echo "  $0 nginx-proxy latest false  # Rollback without health check"
    exit 1
fi

echo -e "${BLUE}🔄 PlanetPlant Container Rollback${NC}"
echo "================================="
echo ""
echo "Service: $SERVICE_NAME"
echo "Target: $TARGET_TAG"
echo "Health Check: $VERIFY_HEALTH"
echo ""

# Function to get current container image
get_current_image() {
    docker inspect "$1" --format='{{.Config.Image}}' 2>/dev/null || echo "none"
}

# Function to get available image tags
get_available_tags() {
    local service="$1"
    local registry_path="$BACKUP_REGISTRY/$service"
    
    echo -e "${YELLOW}🔍 Checking available image tags...${NC}"
    
    # Get recent tags from container registry
    if command -v crane &> /dev/null; then
        crane ls "$registry_path" | head -10
    else
        # Fallback: check Docker images locally
        docker images "$registry_path" --format "table {{.Tag}}" | grep -v TAG | head -10
    fi
}

# Function to determine previous image
determine_previous_image() {
    local service="$1"
    local current_image=$(get_current_image "planetplant-$service")
    
    if [ "$current_image" = "none" ]; then
        echo -e "${RED}❌ Container $service not found${NC}"
        exit 1
    fi
    
    echo "Current image: $current_image"
    
    # Extract current tag
    local current_tag=$(echo "$current_image" | cut -d':' -f2)
    echo "Current tag: $current_tag"
    
    # Get available tags
    local available_tags
    available_tags=$(get_available_tags "$service")
    
    if [ "$TARGET_TAG" = "previous" ]; then
        # Find previous tag (logic depends on your tagging strategy)
        if [ "$current_tag" = "latest" ]; then
            # For latest, try to find a versioned tag
            PREVIOUS_TAG=$(echo "$available_tags" | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$" | head -1)
            if [ -z "$PREVIOUS_TAG" ]; then
                PREVIOUS_TAG="develop"
            fi
        elif [ "$current_tag" = "develop" ]; then
            # For develop, rollback to latest stable
            PREVIOUS_TAG="latest"
        else
            # For versioned tags, try to find previous version
            PREVIOUS_TAG=$(echo "$available_tags" | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$" | grep -v "$current_tag" | head -1)
            if [ -z "$PREVIOUS_TAG" ]; then
                PREVIOUS_TAG="latest"
            fi
        fi
    else
        PREVIOUS_TAG="$TARGET_TAG"
    fi
    
    echo "Target tag: $PREVIOUS_TAG"
    echo "$PREVIOUS_TAG"
}

# Function to verify service health
verify_service_health() {
    local service="$1"
    local max_retries=30
    local retry_delay=10
    
    echo -e "${YELLOW}🔍 Verifying $service health...${NC}"
    
    # Determine health check URL
    local health_url=""
    case $service in
        "backend"|"backend-staging")
            if [ "$service" = "backend-staging" ]; then
                health_url="http://localhost:3002/api/system/status"
            else
                health_url="http://localhost:3001/api/system/status"
            fi
            ;;
        "frontend"|"frontend-staging"|"nginx-proxy"|"nginx-proxy-staging")
            if [[ "$service" =~ "staging" ]]; then
                health_url="http://localhost:8080/health"
            else
                health_url="http://localhost/health"
            fi
            ;;
        "grafana"|"grafana-staging"|"grafana-monitoring")
            case $service in
                "grafana") health_url="http://localhost:3001/api/health" ;;
                "grafana-staging") health_url="http://localhost:3003/api/health" ;;
                "grafana-monitoring") health_url="http://localhost:3004/api/health" ;;
            esac
            ;;
        *)
            echo "⚠️ No specific health check for $service"
            return 0
            ;;
    esac
    
    # Retry health check
    for i in $(seq 1 $max_retries); do
        if curl -f -s "$health_url" > /dev/null 2>&1; then
            echo "✅ $service health check passed (attempt $i)"
            return 0
        fi
        
        echo "⏳ Health check failed, retry $i/$max_retries in ${retry_delay}s..."
        sleep $retry_delay
    done
    
    echo -e "${RED}❌ $service health check failed after $max_retries attempts${NC}"
    return 1
}

# Function to rollback container
rollback_container() {
    local service="$1"
    local target_tag="$2"
    local container_name="planetplant-$service"
    
    # Determine target image
    local target_image="$BACKUP_REGISTRY/$service:$target_tag"
    local current_image=$(get_current_image "$container_name")
    
    if [ "$current_image" = "$target_image" ]; then
        echo "ℹ️ Container already running target image: $target_image"
        return 0
    fi
    
    echo -e "${YELLOW}🔄 Rolling back $service...${NC}"
    echo "From: $current_image"
    echo "To: $target_image"
    
    # Pull target image if needed
    echo "📥 Pulling target image..."
    if ! docker pull "$target_image"; then
        echo -e "${RED}❌ Failed to pull target image: $target_image${NC}"
        return 1
    fi
    
    # Create backup of current container state
    echo "💾 Creating container state backup..."
    docker commit "$container_name" "$BACKUP_REGISTRY/$service:backup-$(date +%Y%m%d_%H%M%S)" || true
    
    # Stop current container
    echo "🛑 Stopping current container..."
    docker stop "$container_name" || true
    
    # Remove current container
    echo "🗑️ Removing current container..."
    docker rm "$container_name" || true
    
    # Determine docker compose file
    local compose_file=""
    if [[ "$service" =~ "staging" ]]; then
        compose_file="docker-compose.staging.yml"
    else
        compose_file="docker-compose.yml"
    fi
    
    # Update image tag in environment
    export IMAGE_TAG="$target_tag"
    
    # Start with new image
    echo "🚀 Starting container with rollback image..."
    cd /opt/planetplant
    docker compose -f "$compose_file" up -d "$service"
    
    # Wait for startup
    sleep 15
    
    echo "✅ Rollback completed for $service"
}

# Main rollback execution
echo -e "${YELLOW}📋 Preparing rollback for $SERVICE_NAME...${NC}"

# Determine target tag
if [ "$TARGET_TAG" = "previous" ]; then
    ROLLBACK_TAG=$(determine_previous_image "$SERVICE_NAME")
    if [ -z "$ROLLBACK_TAG" ]; then
        echo -e "${RED}❌ Could not determine previous image for $SERVICE_NAME${NC}"
        exit 1
    fi
else
    ROLLBACK_TAG="$TARGET_TAG"
fi

echo "Rollback target: $ROLLBACK_TAG"

# Perform rollback
if rollback_container "$SERVICE_NAME" "$ROLLBACK_TAG"; then
    echo -e "${GREEN}✅ Rollback completed successfully${NC}"
    
    # Verify health if requested
    if [ "$VERIFY_HEALTH" = "true" ]; then
        if verify_service_health "$SERVICE_NAME"; then
            echo -e "${GREEN}✅ Service health verification passed${NC}"
        else
            echo -e "${RED}❌ Service health verification failed${NC}"
            echo "🔧 Consider manual intervention or further rollback"
            exit 1
        fi
    fi
else
    echo -e "${RED}❌ Rollback failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Rollback operation completed successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Post-Rollback Status:${NC}"
echo "   Service: $SERVICE_NAME"
echo "   Image: $BACKUP_REGISTRY/$SERVICE_NAME:$ROLLBACK_TAG"
echo "   Health: $([ "$VERIFY_HEALTH" = "true" ] && echo "Verified" || echo "Not checked")"
echo ""
echo -e "${BLUE}🔧 Next Steps:${NC}"
echo "   1. Monitor service logs: docker logs planetplant-$SERVICE_NAME"
echo "   2. Check system status: curl http://localhost:3001/api/system/status"
echo "   3. Review Watchtower logs if auto-rollback triggered this"