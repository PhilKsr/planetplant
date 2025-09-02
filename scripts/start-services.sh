#!/usr/bin/env bash

echo "🚀 Starting PlanetPlant services step by step..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Helper function to wait for service health
wait_for_service() {
  local service_name="$1"
  local max_attempts="${2:-30}"
  
  echo "⏳ Waiting for ${service_name} to be healthy..."
  for i in $(seq 1 $max_attempts); do
    if docker compose ps $service_name | grep -q "(healthy)"; then
      echo -e "${GREEN}✅ ${service_name} is healthy${NC}"
      return 0
    fi
    sleep 2
  done
  echo -e "${RED}❌ ${service_name} failed to become healthy${NC}"
  return 1
}

# Start base services first
echo "📡 Starting Mosquitto MQTT..."
docker compose up -d mosquitto
wait_for_service mosquitto

echo "🔄 Starting Redis..."
docker compose up -d redis
wait_for_service redis

echo "📊 Starting InfluxDB..."
docker compose up -d influxdb
sleep 10
wait_for_service influxdb 60

# Check InfluxDB API
echo "🔍 Checking InfluxDB API..."
if curl -s http://localhost:8086/health; then
  echo -e "${GREEN}✅ InfluxDB API is responding${NC}"
else
  echo -e "${YELLOW}⚠️  InfluxDB API not yet ready${NC}"
fi

echo "🎨 Starting Frontend..."
docker compose up -d frontend
sleep 5

echo "⚙️  Starting Backend..."
docker compose up -d backend
sleep 10
wait_for_service backend

echo "🌐 Starting Nginx Proxy..."
docker compose up -d nginx-proxy
sleep 5

echo ""
echo "✅ All services started. Final status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"