#!/usr/bin/env bash

echo "🔍 PlanetPlant Docker Debugging"
echo "================================"
echo ""

# Funktion für farbige Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "📦 Container Status:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.State}}"
echo ""

echo "🔴 Gestoppte/Crashed Container:"
docker ps -a --filter "status=exited" --format "table {{.Names}}\t{{.Status}}"
echo ""

echo "📝 InfluxDB Logs (letzte 50 Zeilen):"
docker logs planetplant-influxdb --tail=50 2>&1
echo ""

echo "📝 Backend Logs (falls vorhanden):"
docker logs planetplant-backend --tail=50 2>&1 || echo "Backend Container nicht gefunden"
echo ""

echo "📝 Nginx Logs (falls vorhanden):"
docker logs planetplant-nginx --tail=50 2>&1 || echo "Nginx Container nicht gefunden"
echo ""

echo "💾 Docker Volumes:"
docker volume ls | grep planetplant
echo ""

echo "🔍 Disk Space:"
df -h /var/lib/docker
echo ""

echo "🔍 Memory:"
free -h
echo ""

echo "🔍 Docker System Info:"
docker system df
echo ""

echo "🌐 Network Info:"
docker network ls | grep planetplant
echo ""

echo "📁 Data Directory Structure:"
ls -la ./data/ 2>/dev/null || echo "No data directory found"
echo ""

echo "🔧 Config Directory Structure:"
ls -la ./config/ 2>/dev/null || echo "No config directory found"