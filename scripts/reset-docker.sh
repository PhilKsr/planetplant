#!/usr/bin/env bash

echo "🧹 Resetting PlanetPlant Docker Setup..."

# Stop all containers
docker compose down

# Remove problematic volumes
docker volume rm planetplant_influxdb-storage 2>/dev/null || true
docker volume rm planetplant_influxdb-config 2>/dev/null || true

# Remove old data directories (preserving structure)
sudo rm -rf ./data/influxdb/influxd.bolt
sudo rm -rf ./data/influxdb/influxd.sqlite
sudo rm -rf ./data/influxdb/engine
sudo rm -rf ./data/influxdb/configs

# Create fresh directories with proper permissions
mkdir -p ./data/influxdb
mkdir -p ./logs/backend
mkdir -p ./logs/mosquitto

# Set permissions
sudo chown -R $(whoami):$(whoami) ./data/
sudo chown -R $(whoami):$(whoami) ./logs/
chmod -R 755 ./data

echo "✅ Reset complete. Run 'docker compose up -d' to start fresh"
echo "🔄 For step-by-step startup, use: ./scripts/start-services.sh"