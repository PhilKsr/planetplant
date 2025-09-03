#!/bin/bash
# PlanetPlant Complete Data Export Script
# Exports all system data for migration or external backup

set -euo pipefail

# Configuration
TARGET_DIR="${1:-/opt/planetplant/exports/export_$(date +%Y%m%d_%H%M%S)}"
EXPORT_FORMAT="${2:-json}"  # json, csv, influx
INCLUDE_LOGS="${3:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📤 PlanetPlant Data Export${NC}"
echo "=========================="
echo "Target: $TARGET_DIR"
echo "Format: $EXPORT_FORMAT"
echo "Include logs: $INCLUDE_LOGS"
echo ""

# Create export directory
mkdir -p "$TARGET_DIR"/{influxdb,redis,config,logs,docker,metadata}

# Function to log with timestamp
log() {
    echo -e "${BLUE}$(date '+%H:%M:%S')${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$TARGET_DIR/export.log"
}

# Function to export InfluxDB data
export_influxdb_data() {
    log "📊 Exporting InfluxDB data..."
    
    local influx_export_dir="$TARGET_DIR/influxdb"
    
    # Export from production InfluxDB
    if docker ps --format '{{.Names}}' | grep -q "planetplant-influxdb$"; then
        log "Exporting production InfluxDB..."
        
        # Create InfluxDB backup
        docker exec planetplant-influxdb \
            influx backup \
            --org "${INFLUXDB_ORG:-planetplant}" \
            --token "${INFLUXDB_TOKEN:-plantplant-super-secret-auth-token}" \
            /tmp/export-backup 2>/dev/null || \
            log "Warning: Production InfluxDB backup failed"
        
        # Copy backup from container
        docker cp planetplant-influxdb:/tmp/export-backup "$influx_export_dir/production" 2>/dev/null || \
            log "Warning: Could not copy production backup"
        
        # Export specific data in requested format
        case $EXPORT_FORMAT in
            "json"|"csv")
                log "Exporting sensor data as $EXPORT_FORMAT..."
                
                # Export recent sensor data (last 30 days)
                local query='
                    from(bucket: "sensor-data")
                    |> range(start: -30d)
                    |> filter(fn: (r) => r._measurement == "sensor_data")
                '
                
                docker exec planetplant-influxdb \
                    influx query \
                    --org "${INFLUXDB_ORG:-planetplant}" \
                    --token "${INFLUXDB_TOKEN:-plantplant-super-secret-auth-token}" \
                    --format "$EXPORT_FORMAT" \
                    "$query" > "$influx_export_dir/sensor-data-30d.$EXPORT_FORMAT" 2>/dev/null || \
                    log "Warning: Sensor data export failed"
                
                # Export watering events
                local watering_query='
                    from(bucket: "sensor-data")
                    |> range(start: -90d)
                    |> filter(fn: (r) => r._measurement == "watering_events")
                '
                
                docker exec planetplant-influxdb \
                    influx query \
                    --org "${INFLUXDB_ORG:-planetplant}" \
                    --token "${INFLUXDB_TOKEN:-plantplant-super-secret-auth-token}" \
                    --format "$EXPORT_FORMAT" \
                    "$watering_query" > "$influx_export_dir/watering-events-90d.$EXPORT_FORMAT" 2>/dev/null || \
                    log "Warning: Watering events export failed"
                ;;
        esac
    fi
    
    # Export from staging InfluxDB
    if docker ps --format '{{.Names}}' | grep -q "planetplant-influxdb-staging"; then
        log "Exporting staging InfluxDB..."
        
        docker exec planetplant-influxdb-staging \
            influx backup \
            --org "${INFLUXDB_ORG:-planetplant-staging}" \
            --token "${INFLUXDB_TOKEN:-plantplant-staging-token}" \
            /tmp/export-backup 2>/dev/null || \
            log "Warning: Staging InfluxDB backup failed"
            
        docker cp planetplant-influxdb-staging:/tmp/export-backup "$influx_export_dir/staging" 2>/dev/null || \
            log "Warning: Could not copy staging backup"
    fi
    
    log "✅ InfluxDB export completed"
}

# Function to export Redis data
export_redis_data() {
    log "🔴 Exporting Redis data..."
    
    local redis_export_dir="$TARGET_DIR/redis"
    
    # Production Redis
    if docker ps --format '{{.Names}}' | grep -q "planetplant-redis$"; then
        log "Exporting production Redis..."
        
        # Create Redis dump
        docker exec planetplant-redis redis-cli BGSAVE
        sleep 5  # Wait for background save
        
        # Copy dump file
        docker cp planetplant-redis:/data/dump.rdb "$redis_export_dir/production.rdb" || \
            log "Warning: Production Redis export failed"
        
        # Export as JSON if requested
        if [ "$EXPORT_FORMAT" = "json" ]; then
            docker exec planetplant-redis redis-cli --json KEYS '*' > "$redis_export_dir/production-keys.json" || \
                log "Warning: Redis keys export failed"
        fi
    fi
    
    # Staging Redis
    if docker ps --format '{{.Names}}' | grep -q "planetplant-redis-staging"; then
        log "Exporting staging Redis..."
        
        docker exec planetplant-redis-staging redis-cli BGSAVE
        sleep 5
        
        docker cp planetplant-redis-staging:/data/dump.rdb "$redis_export_dir/staging.rdb" || \
            log "Warning: Staging Redis export failed"
    fi
    
    log "✅ Redis export completed"
}

# Function to export configuration files
export_configuration() {
    log "⚙️ Exporting configuration files..."
    
    local config_export_dir="$TARGET_DIR/config"
    
    # Copy all configuration
    cp -r /opt/planetplant/config/* "$config_export_dir/" 2>/dev/null || \
        log "Warning: Some config files could not be copied"
    
    # Copy environment files
    cp /opt/planetplant/.env "$config_export_dir/" 2>/dev/null || \
        log "Warning: .env file not found"
    
    # Copy docker-compose files
    cp /opt/planetplant/docker-compose*.yml "$config_export_dir/" 2>/dev/null || \
        log "Warning: Docker compose files not found"
    
    # Copy scripts
    cp -r /opt/planetplant/scripts "$config_export_dir/" 2>/dev/null || \
        log "Warning: Scripts directory not found"
    
    # Export environment variables in readable format
    cat > "$config_export_dir/environment-export.txt" << EOF
# PlanetPlant Environment Export
# Generated: $(date)

NODE_ENV=${NODE_ENV:-production}
INFLUXDB_ORG=${INFLUXDB_ORG:-planetplant}
INFLUXDB_BUCKET=${INFLUXDB_BUCKET:-sensor-data}
MQTT_HOST=${MQTT_HOST:-mosquitto}
MQTT_PORT=${MQTT_PORT:-1883}
REDIS_HOST=${REDIS_HOST:-redis}
MOISTURE_THRESHOLD=${MOISTURE_THRESHOLD:-30}
WATERING_DURATION=${WATERING_DURATION:-5000}
MAX_WATERING_PER_DAY=${MAX_WATERING_PER_DAY:-3}
EOF

    log "✅ Configuration export completed"
}

# Function to export Docker metadata
export_docker_metadata() {
    log "🐳 Exporting Docker metadata..."
    
    local docker_export_dir="$TARGET_DIR/docker"
    
    # Export container information
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" > "$docker_export_dir/containers.txt"
    
    # Export image information
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" | \
        grep planetplant > "$docker_export_dir/images.txt" || true
    
    # Export network information
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | \
        grep planetplant > "$docker_export_dir/networks.txt" || true
    
    # Export volume information
    docker volume ls --format "table {{.Name}}\t{{.Driver}}" | \
        grep planetplant > "$docker_export_dir/volumes.txt" || true
    
    # Export Docker Compose configuration
    cd /opt/planetplant
    docker compose config > "$docker_export_dir/resolved-compose.yml" 2>/dev/null || \
        log "Warning: Could not export resolved compose configuration"
    
    log "✅ Docker metadata export completed"
}

# Function to export system metadata  
export_system_metadata() {
    log "🖥️ Exporting system metadata..."
    
    local metadata_dir="$TARGET_DIR/metadata"
    
    # System information
    cat > "$metadata_dir/system-info.txt" << EOF
# PlanetPlant System Information Export
# Generated: $(date)

Hostname: $(hostname)
OS Version: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Kernel: $(uname -r)
Architecture: $(uname -m)
CPU Info: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)
Memory: $(free -h | grep Mem | awk '{print $2}')
Disk Usage: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')

Docker Version: $(docker --version)
Docker Compose Version: $(docker compose version)

Network Configuration:
$(ip route show default)

Active Services:
$(systemctl list-units --state=active --type=service | grep -E "(docker|ssh|networking)")
EOF

    # Network configuration
    ip addr show > "$metadata_dir/network-interfaces.txt"
    
    # Installed packages relevant to PlanetPlant
    dpkg -l | grep -E "(docker|node|npm|git|curl|wget)" > "$metadata_dir/installed-packages.txt" || true
    
    # Cron jobs
    crontab -l > "$metadata_dir/crontab.txt" 2>/dev/null || echo "No cron jobs" > "$metadata_dir/crontab.txt"
    
    log "✅ System metadata export completed"
}

# Function to export logs
export_logs() {
    if [ "$INCLUDE_LOGS" != "true" ]; then
        log "ℹ️ Skipping logs export (disabled)"
        return 0
    fi
    
    log "📋 Exporting logs..."
    
    local logs_export_dir="$TARGET_DIR/logs"
    
    # Copy application logs (last 7 days only)
    find /opt/planetplant/logs -name "*.log" -mtime -7 -exec cp {} "$logs_export_dir/" \; 2>/dev/null || \
        log "Warning: Could not copy some log files"
    
    # Export Docker container logs
    local containers=$(docker ps --format '{{.Names}}' | grep planetplant)
    for container in $containers; do
        docker logs --tail 1000 "$container" > "$logs_export_dir/${container}.log" 2>&1 || \
            log "Warning: Could not export logs for $container"
    done
    
    # System logs
    journalctl --since "7 days ago" --unit docker > "$logs_export_dir/docker-system.log" 2>/dev/null || \
        log "Warning: Could not export system logs"
    
    log "✅ Logs export completed"
}

# Function to create export summary
create_export_summary() {
    log "📝 Creating export summary..."
    
    # Calculate sizes
    local total_size=$(du -sh "$TARGET_DIR" | cut -f1)
    local influx_size=$(du -sh "$TARGET_DIR/influxdb" 2>/dev/null | cut -f1 || echo "N/A")
    local redis_size=$(du -sh "$TARGET_DIR/redis" 2>/dev/null | cut -f1 || echo "N/A") 
    local config_size=$(du -sh "$TARGET_DIR/config" 2>/dev/null | cut -f1 || echo "N/A")
    
    cat > "$TARGET_DIR/EXPORT_SUMMARY.md" << EOF
# PlanetPlant Data Export Summary

## Export Information
- **Date:** $(date)
- **Hostname:** $(hostname)
- **Export Directory:** $TARGET_DIR
- **Total Size:** $total_size
- **Format:** $EXPORT_FORMAT
- **Includes Logs:** $INCLUDE_LOGS

## Component Sizes
| Component | Size | Description |
|-----------|------|-------------|
| InfluxDB | $influx_size | Time-series sensor data and backups |
| Redis | $redis_size | Cache dumps and session data |
| Configuration | $config_size | System config, env files, scripts |
| Docker Metadata | $(du -sh "$TARGET_DIR/docker" 2>/dev/null | cut -f1 || echo "N/A") | Container and image information |
| System Metadata | $(du -sh "$TARGET_DIR/metadata" 2>/dev/null | cut -f1 || echo "N/A") | System configuration and info |
| Logs | $(du -sh "$TARGET_DIR/logs" 2>/dev/null | cut -f1 || echo "N/A") | Application and system logs |

## Files Included

### InfluxDB Exports
$(ls "$TARGET_DIR/influxdb" 2>/dev/null | sed 's/^/- /' || echo "- No InfluxDB exports")

### Redis Exports  
$(ls "$TARGET_DIR/redis" 2>/dev/null | sed 's/^/- /' || echo "- No Redis exports")

### Configuration Files
$(ls "$TARGET_DIR/config" 2>/dev/null | sed 's/^/- /' || echo "- No config files")

## Import Instructions

### InfluxDB Restore
\`\`\`bash
# Restore InfluxDB backup
docker exec planetplant-influxdb \\
    influx restore \\
    --org planetplant \\
    --token \$INFLUXDB_TOKEN \\
    /path/to/influxdb/production/
\`\`\`

### Redis Restore
\`\`\`bash
# Copy Redis dump file
docker cp redis/production.rdb planetplant-redis:/data/dump.rdb
docker restart planetplant-redis
\`\`\`

### Configuration Restore
\`\`\`bash
# Copy configuration files
cp -r config/* /opt/planetplant/config/
cp config/.env /opt/planetplant/.env
\`\`\`

## Verification Commands
\`\`\`bash
# Check data integrity after import
curl http://localhost:3001/api/health
curl http://localhost:3001/api/plants

# Verify database contents
influx query "from(bucket: \\"sensor-data\\") |> range(start: -24h) |> count()"
\`\`\`

## Export Metadata
- **Export completed:** $(date)
- **System uptime:** $(uptime | awk '{print $3,$4}' | sed 's/,//')
- **Docker version:** $(docker --version)
- **Available memory:** $(free -h | grep Mem | awk '{print $7}')
- **Disk space:** $(df -h / | tail -1 | awk '{print $4}') available

---
Generated by PlanetPlant export-all-data.sh script
EOF

    log "✅ Export summary created"
}

# Function to compress export
compress_export() {
    log "🗜️ Compressing export..."
    
    local compressed_file="${TARGET_DIR}.tar.gz"
    
    # Create compressed archive
    tar -czf "$compressed_file" -C "$(dirname "$TARGET_DIR")" "$(basename "$TARGET_DIR")" || {
        log "❌ Compression failed"
        return 1
    }
    
    local compressed_size=$(du -sh "$compressed_file" | cut -f1)
    log "✅ Export compressed: $compressed_file ($compressed_size)"
    
    # Generate checksum
    sha256sum "$compressed_file" > "${compressed_file}.sha256"
    log "🔐 Checksum created: ${compressed_file}.sha256"
    
    echo ""
    echo -e "${GREEN}📦 Compressed export ready:${NC}"
    echo "   File: $compressed_file"
    echo "   Size: $compressed_size"
    echo "   Checksum: ${compressed_file}.sha256"
}

# Main export procedure
main() {
    local start_time=$(date +%s)
    
    log "🚀 Starting comprehensive data export..."
    
    # Check prerequisites
    if ! command -v docker &>/dev/null; then
        log "❌ Docker not available"
        exit 1
    fi
    
    # Execute export steps
    echo -e "${YELLOW}1/6 Exporting InfluxDB data...${NC}"
    export_influxdb_data
    
    echo -e "${YELLOW}2/6 Exporting Redis data...${NC}"  
    export_redis_data
    
    echo -e "${YELLOW}3/6 Exporting configuration...${NC}"
    export_configuration
    
    echo -e "${YELLOW}4/6 Exporting Docker metadata...${NC}"
    export_docker_metadata
    
    echo -e "${YELLOW}5/6 Exporting system metadata...${NC}"
    export_system_metadata
    
    echo -e "${YELLOW}6/6 Exporting logs...${NC}"
    export_logs
    
    # Create summary
    create_export_summary
    
    # Compress if successful
    compress_export
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo -e "${GREEN}🎉 Data export completed successfully!${NC}"
    echo ""
    echo "📊 Export Summary:"
    echo "   Duration: ${duration}s"
    echo "   Location: $TARGET_DIR"
    echo "   Format: $EXPORT_FORMAT"
    echo "   Total size: $(du -sh "$TARGET_DIR" | cut -f1)"
    echo ""
    echo -e "${BLUE}🔧 Usage:${NC}"
    echo "   View summary: cat $TARGET_DIR/EXPORT_SUMMARY.md"
    echo "   Import data: Follow instructions in summary"
    echo "   Transfer: scp ${TARGET_DIR}.tar.gz user@newserver:/opt/"
    echo ""
    
    log "Export completed: $TARGET_DIR"
}

# Show usage if invalid arguments
if [ "$EXPORT_FORMAT" != "json" ] && [ "$EXPORT_FORMAT" != "csv" ] && [ "$EXPORT_FORMAT" != "influx" ]; then
    echo "Usage: $0 [target-dir] [format] [include-logs]"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Default export to exports/ directory"
    echo "  $0 /backup/export json true          # JSON format with logs"
    echo "  $0 /mnt/usb/backup csv false         # CSV format without logs"
    echo ""
    echo "Formats:"
    echo "  json   - InfluxDB JSON format (human readable)"
    echo "  csv    - CSV format (Excel compatible)"
    echo "  influx - Native InfluxDB format (fastest restore)"
    exit 1
fi

# Execute main procedure
main