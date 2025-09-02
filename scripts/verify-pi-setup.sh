#!/usr/bin/env bash

echo "🍓 PlanetPlant Raspberry Pi 5 Verification"
echo "==========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running on ARM64
echo "🔍 System Architecture Check:"
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    echo -e "${GREEN}✅ ARM64 architecture detected: $ARCH${NC}"
else
    echo -e "${YELLOW}⚠️  Running on $ARCH (expected: aarch64/arm64)${NC}"
fi

# Check memory (should be 8GB for Pi 5)
echo ""
echo "💾 Memory Check:"
if command -v free &> /dev/null; then
    TOTAL_MEM=$(free -h | grep Mem | awk '{print $2}')
    AVAILABLE_MEM=$(free -h | grep Mem | awk '{print $7}')
    echo -e "${GREEN}✅ Total Memory: $TOTAL_MEM, Available: $AVAILABLE_MEM${NC}"
else
    echo -e "${YELLOW}⚠️  Memory check not available on this platform${NC}"
fi

# Check Docker version and platform
echo ""
echo "🐳 Docker Platform Check:"
DOCKER_ARCH=$(docker info --format '{{.Architecture}}' 2>/dev/null || echo "unknown")
if [[ "$DOCKER_ARCH" == "aarch64" ]]; then
    echo -e "${GREEN}✅ Docker is running natively on ARM64${NC}"
else
    echo -e "${YELLOW}⚠️  Docker architecture: $DOCKER_ARCH${NC}"
fi

# Check container status
echo ""
echo "📦 Container Health Check:"
containers=("planetplant-influxdb" "planetplant-mosquitto" "planetplant-redis" "planetplant-backend" "planetplant-frontend" "planetplant-nginx")
all_healthy=true

for container in "${containers[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-health-check")
        case $health in
            "healthy")
                echo -e "${GREEN}✅ $container: healthy${NC}"
                ;;
            "starting")
                echo -e "${YELLOW}🔄 $container: starting${NC}"
                ;;
            "no-health-check")
                echo -e "${GREEN}✅ $container: running (no health check)${NC}"
                ;;
            *)
                echo -e "${RED}❌ $container: $health${NC}"
                all_healthy=false
                ;;
        esac
    else
        echo -e "${RED}❌ $container: not running${NC}"
        all_healthy=false
    fi
done

# Check key endpoints
echo ""
echo "🌐 Service Endpoint Check:"

# Frontend
if curl -sf http://localhost/health >/dev/null; then
    echo -e "${GREEN}✅ Frontend: http://localhost${NC}"
else
    echo -e "${RED}❌ Frontend: http://localhost${NC}"
    all_healthy=false
fi

# Backend API
if curl -sf http://localhost:3001/api/system/status >/dev/null; then
    echo -e "${GREEN}✅ Backend API: http://localhost:3001/api${NC}"
else
    echo -e "${RED}❌ Backend API: http://localhost:3001/api${NC}"
    all_healthy=false
fi

# InfluxDB
if curl -sf http://localhost:8086/health >/dev/null; then
    echo -e "${GREEN}✅ InfluxDB: http://localhost:8086${NC}"
else
    echo -e "${RED}❌ InfluxDB: http://localhost:8086${NC}"
    all_healthy=false
fi

# Check resource usage
echo ""
echo "⚡ Performance Check:"

# CPU cores
CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "unknown")
echo "🖥️  CPU Cores: $CPU_CORES"

# Docker resource limits
echo ""
echo "🐳 Docker Resource Limits:"
for container in "${containers[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        memory_limit=$(docker inspect --format='{{.HostConfig.Memory}}' "$container" 2>/dev/null)
        cpu_limit=$(docker inspect --format='{{.HostConfig.CpuQuota}}' "$container" 2>/dev/null)
        if [[ "$memory_limit" != "0" ]]; then
            memory_gb=$((memory_limit / 1024 / 1024 / 1024))
            echo "   $container: ${memory_gb}GB memory limit"
        fi
    fi
done

echo ""
if $all_healthy; then
    echo -e "${GREEN}🎉 All systems healthy! PlanetPlant is ready for Raspberry Pi 5.${NC}"
    echo ""
    echo -e "${GREEN}🌐 Access your plant monitoring system:${NC}"
    echo "   Frontend:     http://localhost"
    echo "   Backend API:  http://localhost:3001/api"
    echo "   InfluxDB:     http://localhost:8086"
    echo "   MQTT:         localhost:1883"
    echo "   Redis:        localhost:6379"
    echo ""
    echo -e "${GREEN}📊 Next steps:${NC}"
    echo "   1. Connect your ESP32 sensors to MQTT broker"
    echo "   2. Configure plants in the web interface"
    echo "   3. Monitor sensor data and watering automation"
    echo ""
    exit 0
else
    echo -e "${RED}⚠️  Some services are not healthy. Check the errors above.${NC}"
    echo ""
    echo -e "${YELLOW}🔧 Troubleshooting commands:${NC}"
    echo "   make logs              # View all service logs"
    echo "   make status            # Detailed service status"
    echo "   ./scripts/debug-docker.sh  # Comprehensive debugging"
    echo ""
    exit 1
fi