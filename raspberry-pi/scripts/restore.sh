#!/bin/bash
set -e

# PlanetPlant Restore Script
# Restores data from compressed backup

BACKUP_DIR="/opt/planetplant/backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

# List available backups
log_info "🌱 PlanetPlant Restore Process"
echo ""
log_info "📚 Available backups:"

if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/*.tar.gz 2>/dev/null)" ]; then
    log_error "No backups found in $BACKUP_DIR"
    exit 1
fi

# Show numbered list of backups
backups=($(ls -t "$BACKUP_DIR"/planetplant_backup_*.tar.gz))
for i in "${!backups[@]}"; do
    backup_file=$(basename "${backups[$i]}")
    backup_date=$(echo "$backup_file" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
    backup_size=$(du -h "${backups[$i]}" | cut -f1)
    echo "$((i+1)). $backup_date ($backup_size)"
done

echo ""
read -p "Select backup number to restore (1-${#backups[@]}): " -r backup_choice

# Validate selection
if ! [[ "$backup_choice" =~ ^[0-9]+$ ]] || [ "$backup_choice" -lt 1 ] || [ "$backup_choice" -gt "${#backups[@]}" ]; then
    log_error "Invalid selection"
    exit 1
fi

SELECTED_BACKUP="${backups[$((backup_choice-1))]}"
BACKUP_NAME=$(basename "$SELECTED_BACKUP" .tar.gz)

log_info "📦 Selected backup: $BACKUP_NAME"

# Warning about data loss
echo ""
log_warn "⚠️  WARNING: This will REPLACE ALL current data!"
log_warn "⚠️  Current containers will be stopped and data will be overwritten!"
echo ""
read -p "Are you sure you want to continue? [y/N] " -r confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    log_info "❌ Restore cancelled"
    exit 0
fi

COMPOSE_FILE="/home/pi/planetplant/raspberry-pi/docker-compose.prod.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "Production docker-compose.yml not found"
    exit 1
fi

cd "$(dirname "$COMPOSE_FILE")"

# Stop all services
log_info "🛑 Stopping all services..."
docker-compose -f docker-compose.prod.yml down

# Extract backup
log_info "📂 Extracting backup..."
cd "$BACKUP_DIR"
tar xzf "$SELECTED_BACKUP"

RESTORE_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Restore function
restore_service() {
    local service=$1
    local description=$2
    
    log_info "📦 Restoring ${description}..."
    
    local service_backup="${RESTORE_PATH}/${service}"
    
    if [ ! -d "$service_backup" ]; then
        log_warn "⚠️  No backup data found for ${service}, skipping..."
        return 0
    fi
    
    case $service in
        "influxdb")
            if [ -f "${service_backup}/data.tar.gz" ]; then
                docker run --rm -v planetplant_influxdb_data:/data -v "${service_backup}:/backup" alpine sh -c "
                    rm -rf /data/* 2>/dev/null || true
                    tar xzf /backup/data.tar.gz -C /data
                "
                log_info "✅ InfluxDB data restored"
            fi
            ;;
        "grafana")
            if [ -f "${service_backup}/data.tar.gz" ]; then
                docker run --rm -v planetplant_grafana_data:/data -v "${service_backup}:/backup" alpine sh -c "
                    rm -rf /data/* 2>/dev/null || true
                    tar xzf /backup/data.tar.gz -C /data
                "
                log_info "✅ Grafana data restored"
            fi
            ;;
        "mosquitto")
            if [ -f "${service_backup}/data.tar.gz" ]; then
                docker run --rm -v planetplant_mosquitto_data:/data -v "${service_backup}:/backup" alpine sh -c "
                    rm -rf /data/* 2>/dev/null || true
                    tar xzf /backup/data.tar.gz -C /data
                "
                log_info "✅ Mosquitto data restored"
            fi
            ;;
        "redis")
            if [ -f "${service_backup}/data.tar.gz" ]; then
                docker run --rm -v planetplant_redis_data:/data -v "${service_backup}:/backup" alpine sh -c "
                    rm -rf /data/* 2>/dev/null || true
                    tar xzf /backup/data.tar.gz -C /data
                "
                log_info "✅ Redis data restored"
            fi
            ;;
        "backend")
            if [ -f "${service_backup}/data.tar.gz" ]; then
                docker run --rm -v planetplant_backend_data:/data -v "${service_backup}:/backup" alpine tar xzf /backup/data.tar.gz -C /data
                log_info "✅ Backend data restored"
            fi
            if [ -f "${service_backup}/logs.tar.gz" ]; then
                docker run --rm -v planetplant_backend_logs:/logs -v "${service_backup}:/backup" alpine tar xzf /backup/logs.tar.gz -C /logs
                log_info "✅ Backend logs restored"
            fi
            ;;
    esac
}

# Restore configuration files
if [ -d "${RESTORE_PATH}/config" ]; then
    log_info "⚙️  Restoring configuration files..."
    
    # Backup current config
    if [ -f ".env" ]; then
        cp .env .env.backup.$(date +%s)
        log_info "📄 Current .env backed up"
    fi
    
    # Restore config files
    cp -r "${RESTORE_PATH}/config/"* . 2>/dev/null || log_warn "No config files to restore"
    log_info "✅ Configuration restored"
fi

# Restore each service
restore_service "influxdb" "InfluxDB time-series data"
restore_service "grafana" "Grafana dashboards"  
restore_service "mosquitto" "MQTT broker data"
restore_service "redis" "Redis cache"
restore_service "backend" "Backend application data"

# Cleanup extracted backup
rm -rf "${RESTORE_PATH}"

# Start services
log_info "🚀 Starting services..."
docker-compose -f docker-compose.prod.yml up -d

# Wait for services to be healthy
log_info "⏳ Waiting for services to start..."
sleep 30

# Check service health
log_info "🏥 Checking service health..."
for i in {1..12}; do
    if docker-compose -f docker-compose.prod.yml ps | grep -q "Up (healthy)"; then
        log_info "✅ Services are healthy"
        break
    elif [ $i -eq 12 ]; then
        log_warn "⚠️  Some services may not be fully healthy yet"
    else
        echo -n "."
        sleep 5
    fi
done

echo ""
log_info "✅ Restore completed successfully!"
log_info "📊 Check the dashboard: http://$(hostname -I | awk '{print $1}')"
log_info "📈 Grafana: http://$(hostname -I | awk '{print $1}')/grafana"

# Show service status
echo ""
log_info "📊 Service Status:"
docker-compose -f docker-compose.prod.yml ps