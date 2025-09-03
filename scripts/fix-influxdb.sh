#!/bin/bash
# Fix InfluxDB Authentication Issues
# Resets and properly initializes InfluxDB with correct token and bucket

set -euo pipefail

echo "🔧 PlanetPlant InfluxDB Fix Script"
echo "=================================="
echo ""

# Load environment
if [ -f "raspberry-pi/.env" ]; then
    source raspberry-pi/.env
else
    echo "❌ raspberry-pi/.env not found"
    exit 1
fi

# Configuration
INFLUXDB_TOKEN=${INFLUXDB_TOKEN:-plantplant-super-secret-auth-token}
INFLUXDB_ORG=${INFLUXDB_ORG:-planetplant}
INFLUXDB_BUCKET=${INFLUXDB_BUCKET:-sensor-data}
INFLUXDB_USERNAME=${INFLUXDB_USERNAME:-admin}
INFLUXDB_PASSWORD=${INFLUXDB_PASSWORD:-plantplant123}

echo "Configuration:"
echo "  Token: ${INFLUXDB_TOKEN:0:10}..."
echo "  Org: $INFLUXDB_ORG"
echo "  Bucket: $INFLUXDB_BUCKET"
echo "  Username: $INFLUXDB_USERNAME"
echo ""

# Step 1: Stop backend to prevent connection attempts
echo "🛑 Stopping backend to prevent connection loops..."
docker-compose stop backend

# Step 2: Reset InfluxDB completely
echo "🗑️ Resetting InfluxDB data..."
docker-compose stop influxdb
sudo rm -rf data/influxdb/*

# Step 3: Start InfluxDB with initialization enabled
echo "🚀 Starting InfluxDB with fresh initialization..."
docker-compose up -d influxdb

# Step 4: Wait for InfluxDB to be ready
echo "⏳ Waiting for InfluxDB to initialize..."
for i in {1..60}; do
    if curl -f -s http://localhost:8086/ping > /dev/null 2>&1; then
        echo "✅ InfluxDB is responding"
        break
    fi
    echo "   Waiting... ($i/60)"
    sleep 2
done

# Step 5: Verify initialization
echo "🔍 Verifying InfluxDB setup..."
sleep 10

# Test token authentication
if curl -H "Authorization: Token $INFLUXDB_TOKEN" \
   -H "Content-Type: application/json" \
   -s http://localhost:8086/api/v2/buckets | jq -r '.buckets[] | select(.name=="'$INFLUXDB_BUCKET'") | .name' | grep -q "$INFLUXDB_BUCKET"; then
    echo "✅ Token authentication successful"
    echo "✅ Bucket '$INFLUXDB_BUCKET' exists"
else
    echo "❌ Token authentication failed or bucket missing"
    echo "🔧 Attempting manual setup..."
    
    # Manual bucket creation if needed
    curl -X POST "http://localhost:8086/api/v2/buckets" \
         -H "Authorization: Token $INFLUXDB_TOKEN" \
         -H "Content-Type: application/json" \
         -d "{
               \"orgID\": \"$(curl -H "Authorization: Token $INFLUXDB_TOKEN" -s http://localhost:8086/api/v2/orgs | jq -r '.orgs[] | select(.name=="'$INFLUXDB_ORG'") | .id')\",
               \"name\": \"$INFLUXDB_BUCKET\",
               \"retentionRules\": [{\"type\": \"expire\", \"everySeconds\": 7776000}]
             }" 2>/dev/null || echo "Bucket creation failed or already exists"
fi

# Step 6: Start backend 
echo "🚀 Starting backend with fixed InfluxDB..."
docker-compose up -d backend

# Step 7: Wait and verify
echo "⏳ Waiting for backend to start..."
sleep 15

# Test complete system
echo "🧪 Testing system health..."
if curl -f -s http://localhost:3001/api/system/status > /dev/null; then
    echo "✅ Backend is healthy"
    
    # Test InfluxDB connection through backend
    response=$(curl -s http://localhost:3001/api/system/status | jq -r '.influxdb.connected')
    if [ "$response" = "true" ]; then
        echo "✅ Backend → InfluxDB connection successful"
    else
        echo "❌ Backend → InfluxDB connection still failing"
        echo "🔍 Backend health response:"
        curl -s http://localhost:3001/api/system/status | jq '.influxdb'
    fi
else
    echo "❌ Backend health check failed"
    echo "🔍 Backend logs:"
    docker-compose logs --tail=10 backend
fi

echo ""
echo "🔧 Manual Fix Commands (if still failing):"
echo "   1. Check InfluxDB logs: docker-compose logs influxdb"
echo "   2. Reset completely: docker-compose down && sudo rm -rf data/influxdb/* && docker-compose up -d"
echo "   3. Manual token check: curl -H 'Authorization: Token $INFLUXDB_TOKEN' http://localhost:8086/api/v2/buckets"
echo ""

echo "✅ InfluxDB fix script completed"