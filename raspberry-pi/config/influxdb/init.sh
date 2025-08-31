#!/bin/bash
set -e

echo "🔧 Initializing InfluxDB for PlanetPlant..."

# Wait for InfluxDB to be ready
until curl -f http://localhost:8086/ping; do
  echo "⏳ Waiting for InfluxDB to be ready..."
  sleep 2
done

echo "✅ InfluxDB is ready!"

# Create retention policy for 90 days
echo "⏰ Setting up retention policies..."

# Create bucket with 90-day retention if it doesn't exist
influx bucket create \
  --org "${DOCKER_INFLUXDB_INIT_ORG}" \
  --name "${DOCKER_INFLUXDB_INIT_BUCKET}" \
  --retention "${DOCKER_INFLUXDB_INIT_RETENTION}" \
  --token "${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}" \
  || echo "📊 Bucket already exists or error occurred"

# Create additional buckets for different data types
influx bucket create \
  --org "${DOCKER_INFLUXDB_INIT_ORG}" \
  --name "system-metrics" \
  --retention "30d" \
  --token "${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}" \
  || echo "📊 System metrics bucket already exists or error occurred"

influx bucket create \
  --org "${DOCKER_INFLUXDB_INIT_ORG}" \
  --name "watering-events" \
  --retention "365d" \
  --token "${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}" \
  || echo "📊 Watering events bucket already exists or error occurred"

echo "🌱 InfluxDB initialization completed successfully!"