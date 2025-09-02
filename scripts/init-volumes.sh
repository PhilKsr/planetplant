#!/bin/bash
# PlanetPlant Volume Initialization Script
# Creates necessary directories and configuration files

set -euo pipefail

echo "📁 Creating volume directories..."

# Create all necessary directories
mkdir -p data/{mosquitto,influxdb,redis,grafana}
mkdir -p config/{mosquitto,influxdb,grafana/provisioning/dashboards,grafana/provisioning/datasources}
mkdir -p logs/{mosquitto,backend}

# Set proper permissions
chmod -R 755 data config logs

echo "📝 Creating configuration files..."

# Create mosquitto config if not exists
if [ ! -f config/mosquitto/mosquitto.conf ]; then
    cat > config/mosquitto/mosquitto.conf << 'EOF'
# PlanetPlant MQTT Broker Configuration
persistence true
persistence_location /mosquitto/data/

# Standard MQTT listener
listener 1883
allow_anonymous true

# WebSocket listener for web clients
listener 9001
protocol websockets
allow_anonymous true

# Logging configuration
log_dest file /mosquitto/log/mosquitto.log
log_dest stdout
log_type error
log_type warning
log_type notice
log_type information
log_timestamp true

# Connection limits
max_connections 1000
max_inflight_messages 100
max_queued_messages 1000
message_size_limit 0

# Security (for production, consider disabling anonymous)
# password_file /mosquitto/config/passwd
# acl_file /mosquitto/config/acl
EOF
    echo "✅ Created mosquitto.conf"
fi

# Create Grafana datasource configuration
mkdir -p config/grafana/provisioning/datasources
if [ ! -f config/grafana/provisioning/datasources/influxdb.yml ]; then
    cat > config/grafana/provisioning/datasources/influxdb.yml << 'EOF'
apiVersion: 1

datasources:
  - name: InfluxDB
    type: influxdb
    access: proxy
    url: http://influxdb:8086
    database: sensor-data
    user: admin
    secureJsonData:
      password: plantplant123
      token: plantplant-super-secret-auth-token
    jsonData:
      version: Flux
      organization: planetplant
      defaultBucket: sensor-data
      tlsSkipVerify: false
    editable: true
EOF
    echo "✅ Created Grafana InfluxDB datasource"
fi

# Create Grafana dashboard provisioning
if [ ! -f config/grafana/provisioning/dashboards/dashboard.yml ]; then
    cat > config/grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'PlanetPlant Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF
    echo "✅ Created Grafana dashboard provisioning"
fi

# Set ownership (if running as root, adjust for container user)
if [ "$(id -u)" = "0" ]; then
    # Running as root, set ownership for container users
    chown -R 472:472 data/grafana config/grafana 2>/dev/null || true  # Grafana user
    chown -R 999:999 data/influxdb config/influxdb 2>/dev/null || true  # InfluxDB user
    chown -R 1883:1883 data/mosquitto logs/mosquitto 2>/dev/null || true  # Mosquitto user
fi

echo ""
echo "✅ Volume directories and configurations created successfully!"
echo ""
echo "📁 Created directories:"
echo "   data/mosquitto    - MQTT broker persistence"
echo "   data/influxdb     - Time-series database"
echo "   data/redis        - Cache and sessions"
echo "   data/grafana      - Dashboard data"
echo "   config/mosquitto  - MQTT configuration"
echo "   config/influxdb   - InfluxDB settings"
echo "   config/grafana    - Grafana provisioning"
echo "   logs/mosquitto    - MQTT logs"
echo "   logs/backend      - Backend application logs"
echo ""
echo "🚀 Ready to start services with: make up"