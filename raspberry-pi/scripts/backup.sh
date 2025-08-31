#!/bin/bash
set -e

# PlanetPlant Backup Script
# Creates compressed backups of all data volumes

BACKUP_DIR="/opt/planetplant/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="planetplant_backup_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

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

# Check if running as root (required for Docker volume access)
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (for Docker volume access)"
   exit 1
fi

log_info "🌱 Starting PlanetPlant backup process..."
log_info "📅 Backup timestamp: ${TIMESTAMP}"

# Create backup directory
mkdir -p "${BACKUP_DIR}"
mkdir -p "${BACKUP_PATH}"

# Check if containers are running
COMPOSE_FILE="/home/pi/planetplant/raspberry-pi/docker-compose.prod.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "Production docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
fi

cd "$(dirname "$COMPOSE_FILE")"

# Function to backup a service's volumes
backup_service() {
    local service=$1
    local description=$2
    
    log_info "💾 Backing up ${description}..."
    
    # Create service-specific backup directory
    local service_backup="${BACKUP_PATH}/${service}"
    mkdir -p "${service_backup}"
    
    # Get container name
    local container=$(docker-compose -f docker-compose.prod.yml ps -q ${service})
    
    if [ -z "$container" ]; then
        log_warn "⚠️  Container ${service} not running, skipping..."
        return 0
    fi
    
    # Backup volumes
    case $service in
        "influxdb")
            # Stop InfluxDB temporarily for consistent backup
            docker-compose -f docker-compose.prod.yml stop influxdb
            log_info "📊 Creating InfluxDB backup..."
            docker run --rm -v planetplant_influxdb_data:/data -v "${service_backup}:/backup" alpine tar czf /backup/data.tar.gz -C /data .
            docker-compose -f docker-compose.prod.yml start influxdb
            ;;
        "grafana")
            log_info "📈 Creating Grafana backup..."
            docker run --rm -v planetplant_grafana_data:/data -v "${service_backup}:/backup" alpine tar czf /backup/data.tar.gz -C /data .
            ;;
        "mosquitto")
            log_info "📡 Creating Mosquitto backup..."
            docker run --rm -v planetplant_mosquitto_data:/data -v "${service_backup}:/backup" alpine tar czf /backup/data.tar.gz -C /data .
            ;;
        "redis")
            log_info "💾 Creating Redis backup..."
            # Force Redis save
            docker-compose -f docker-compose.prod.yml exec -T redis redis-cli --no-auth-warning -a plantplant123 BGSAVE
            sleep 2
            docker run --rm -v planetplant_redis_data:/data -v "${service_backup}:/backup" alpine tar czf /backup/data.tar.gz -C /data .
            ;;
        "backend")
            log_info "⚙️  Creating Backend backup..."
            docker run --rm -v planetplant_backend_data:/data -v planetplant_backend_logs:/logs -v "${service_backup}:/backup" alpine sh -c "
                mkdir -p /backup/data /backup/logs
                tar czf /backup/data.tar.gz -C /data . 2>/dev/null || echo 'No data to backup'
                tar czf /backup/logs.tar.gz -C /logs . 2>/dev/null || echo 'No logs to backup'
            "
            ;;
    esac
}

# Create configuration backup
log_info "⚙️  Backing up configuration files..."
mkdir -p "${BACKUP_PATH}/config"
cp -r config/ "${BACKUP_PATH}/config/" 2>/dev/null || log_warn "No config directory found"
cp .env "${BACKUP_PATH}/config/" 2>/dev/null || log_warn "No .env file found"
cp docker-compose.prod.yml "${BACKUP_PATH}/config/"
cp ecosystem.config.js "${BACKUP_PATH}/config/" 2>/dev/null || log_warn "No ecosystem.config.js found"

# Backup each service
backup_service "influxdb" "InfluxDB time-series data"
backup_service "grafana" "Grafana dashboards and settings"
backup_service "mosquitto" "MQTT broker data"
backup_service "redis" "Redis cache data"
backup_service "backend" "Backend application data"

# Create system info backup
log_info "📋 Collecting system information..."
mkdir -p "${BACKUP_PATH}/system"
cat > "${BACKUP_PATH}/system/info.txt" << EOF
PlanetPlant Backup Information
==============================
Timestamp: ${TIMESTAMP}
Hostname: $(hostname)
OS: $(uname -a)
Docker Version: $(docker --version)
Docker Compose Version: $(docker-compose --version)
Free Space: $(df -h / | tail -1)
Memory: $(free -h | head -2 | tail -1)

Container Status:
$(docker-compose -f docker-compose.prod.yml ps)

Volume Information:
$(docker volume ls | grep planetplant)
EOF

# Create backup metadata
cat > "${BACKUP_PATH}/backup.json" << EOF
{
  "backup_name": "${BACKUP_NAME}",
  "timestamp": "${TIMESTAMP}",
  "version": "1.0.0",
  "hostname": "$(hostname)",
  "services": ["influxdb", "grafana", "mosquitto", "redis", "backend"],
  "backup_type": "full",
  "created_by": "backup.sh"
}
EOF

# Compress entire backup
log_info "🗜️  Compressing backup..."
cd "${BACKUP_DIR}"
tar czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}/"

# Calculate backup size
BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)

# Cleanup uncompressed backup
rm -rf "${BACKUP_PATH}"

# Keep only last 7 backups
log_info "🧹 Cleaning up old backups (keeping last 7)..."
ls -t planetplant_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm -f

log_info "✅ Backup completed successfully!"
log_info "📦 Backup file: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
log_info "📏 Backup size: ${BACKUP_SIZE}"
log_info "📍 Location: ${BACKUP_DIR}"

# List all backups
echo ""
log_info "📚 Available backups:"
ls -lah "${BACKUP_DIR}"/planetplant_backup_*.tar.gz 2>/dev/null | tail -10 || log_warn "No previous backups found"

echo ""
log_info "🚀 Backup process finished. Your data is safe!"