#!/bin/bash
# PlanetPlant Image Push Script
# Builds and pushes multi-architecture images to GitHub Container Registry

set -euo pipefail

# Configuration
REGISTRY_PREFIX="${REGISTRY_PREFIX:-ghcr.io/philksr/planetplant}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏗️ PlanetPlant Multi-Arch Image Builder${NC}"
echo "========================================"
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

if ! docker buildx version &> /dev/null; then
    echo -e "${RED}❌ Docker Buildx is not available${NC}"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}❌ GITHUB_TOKEN environment variable is required${NC}"
    echo "   Export your GitHub token: export GITHUB_TOKEN=ghp_xxxxx"
    exit 1
fi

# Login to GitHub Container Registry
echo -e "${YELLOW}🔐 Logging in to GitHub Container Registry...${NC}"
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$USER" --password-stdin

# Create buildx builder if it doesn't exist
if ! docker buildx inspect planetplant-builder &> /dev/null; then
    echo -e "${YELLOW}🛠️ Creating multi-arch builder...${NC}"
    docker buildx create --name planetplant-builder --driver docker-container --use
fi

# Use the multi-arch builder
docker buildx use planetplant-builder

# Function to build and push an image
build_and_push() {
    local component=$1
    local context=$2
    local dockerfile=$3
    
    echo ""
    echo -e "${YELLOW}🏗️ Building $component...${NC}"
    echo "   Context: $context"
    echo "   Dockerfile: $dockerfile"
    echo "   Target: $REGISTRY_PREFIX/$component:$IMAGE_TAG"
    echo ""
    
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --tag "$REGISTRY_PREFIX/$component:$IMAGE_TAG" \
        --push \
        --file "$dockerfile" \
        "$context"
    
    echo -e "${GREEN}✅ $component image built and pushed successfully${NC}"
}

# Build and push all components
echo -e "${YELLOW}🚀 Starting multi-arch builds...${NC}"

build_and_push "backend" "./raspberry-pi" "./raspberry-pi/Dockerfile"
build_and_push "frontend" "./webapp" "./webapp/Dockerfile"
build_and_push "nginx-proxy" "./nginx" "./nginx/Dockerfile"

echo ""
echo -e "${GREEN}🎉 All images built and pushed successfully!${NC}"
echo ""
echo -e "${BLUE}📦 Published Images:${NC}"
echo "   🖥️  $REGISTRY_PREFIX/backend:$IMAGE_TAG"
echo "   🌐 $REGISTRY_PREFIX/frontend:$IMAGE_TAG"
echo "   🔀 $REGISTRY_PREFIX/nginx-proxy:$IMAGE_TAG"
echo ""
echo -e "${BLUE}🏛️ Architectures: linux/amd64, linux/arm64${NC}"
echo ""
echo -e "${YELLOW}💡 Next Steps:${NC}"
echo "   1. Update .env with REGISTRY_PREFIX=$REGISTRY_PREFIX"
echo "   2. Run: make prod (will use registry images)"
echo "   3. Run: make dev (will use local builds via override)"
echo ""