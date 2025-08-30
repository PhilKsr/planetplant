#!/bin/bash

# PlanetPlant Backup Script
# Creates backups of configuration, database, and logs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="/home/pi/PlanetPlant"
BACKUP_DIR="/home/pi/backups/planetplant"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="planetplant_backup_${DATE}"

# Retention settings
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=3

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

create_backup_dirs() {
    log_info "Creating backup directories..."
    mkdir -p "${BACKUP_DIR}"/{daily,weekly,monthly}
    log_success "Backup directories created"
}

backup_configuration() {
    log_info "Backing up configuration files..."
    
    CONFIG_BACKUP_DIR="${BACKUP_DIR}/daily/${BACKUP_NAME}/config"
    mkdir -p "$CONFIG_BACKUP_DIR"
    
    # Backup main configuration files
    if [ -d "$PROJECT_DIR/config" ]; then
        cp -r "$PROJECT_DIR/config" "$CONFIG_BACKUP_DIR/"
    fi
    
    # Backup environment files (excluding sensitive data)
    if [ -f "$PROJECT_DIR/raspberry-pi/.env" ]; then
        # Create sanitized version of .env file
        grep -v -E "(PASSWORD|SECRET|TOKEN|KEY)" "$PROJECT_DIR/raspberry-pi/.env" > "$CONFIG_BACKUP_DIR/.env.sanitized" || true
    fi
    
    # Backup docker-compose.yml
    if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
        cp "$PROJECT_DIR/docker-compose.yml" "$CONFIG_BACKUP_DIR/"
    fi
    
    # Backup package.json files
    find "$PROJECT_DIR" -name "package.json" -exec cp --parents {} "$CONFIG_BACKUP_DIR/" \;
    
    log_success "Configuration files backed up"
}

backup_influxdb() {
    log_info "Backing up InfluxDB data..."
    
    INFLUX_BACKUP_DIR="${BACKUP_DIR}/daily/${BACKUP_NAME}/influxdb"
    mkdir -p "$INFLUX_BACKUP_DIR"
    
    # Export InfluxDB data
    docker-compose exec -T influxdb influx backup \
        --org plantplant \
        --token plantplant-super-secret-auth-token \
        /var/lib/influxdb2/backup_${DATE}
    
    # Copy backup from container
    docker cp $(docker-compose ps -q influxdb):/var/lib/influxdb2/backup_${DATE} "$INFLUX_BACKUP_DIR/"
    
    # Cleanup backup in container
    docker-compose exec -T influxdb rm -rf /var/lib/influxdb2/backup_${DATE}
    
    log_success "InfluxDB data backed up"
}

backup_redis() {
    log_info "Backing up Redis data..."
    
    REDIS_BACKUP_DIR="${BACKUP_DIR}/daily/${BACKUP_NAME}/redis"
    mkdir -p "$REDIS_BACKUP_DIR"
    
    # Save Redis data
    docker-compose exec -T redis redis-cli --rdb /data/dump_${DATE}.rdb
    
    # Copy backup from container
    docker cp $(docker-compose ps -q redis):/data/dump_${DATE}.rdb "$REDIS_BACKUP_DIR/"
    
    # Cleanup backup in container
    docker-compose exec -T redis rm -f /data/dump_${DATE}.rdb
    
    log_success "Redis data backed up"
}

backup_logs() {
    log_info "Backing up log files..."
    
    LOGS_BACKUP_DIR="${BACKUP_DIR}/daily/${BACKUP_NAME}/logs"
    mkdir -p "$LOGS_BACKUP_DIR"
    
    # Backup application logs
    if [ -d "$PROJECT_DIR/raspberry-pi/logs" ]; then
        cp -r "$PROJECT_DIR/raspberry-pi/logs" "$LOGS_BACKUP_DIR/app_logs"
    fi
    
    # Backup system logs (last 7 days)
    journalctl --since "7 days ago" --until "now" > "$LOGS_BACKUP_DIR/system.log"
    
    # Backup docker logs
    docker-compose logs --since 7d > "$LOGS_BACKUP_DIR/docker.log" 2>/dev/null || true
    
    log_success "Log files backed up"
}

backup_source_code() {
    log_info "Backing up source code..."
    
    SOURCE_BACKUP_DIR="${BACKUP_DIR}/daily/${BACKUP_NAME}/source"
    mkdir -p "$SOURCE_BACKUP_DIR"
    
    # Backup source code (excluding node_modules and build directories)
    rsync -av \
        --exclude 'node_modules' \
        --exclude 'build' \
        --exclude 'dist' \
        --exclude '.git' \
        --exclude 'logs' \
        --exclude 'docker-volumes' \
        "$PROJECT_DIR/" "$SOURCE_BACKUP_DIR/"
    
    log_success "Source code backed up"
}

create_archive() {
    log_info "Creating compressed archive..."
    
    cd "$BACKUP_DIR/daily"
    tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
    rm -rf "$BACKUP_NAME"
    
    # Calculate archive size
    ARCHIVE_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
    
    log_success "Archive created: ${BACKUP_NAME}.tar.gz (${ARCHIVE_SIZE})"
}

rotate_backups() {
    log_info "Rotating old backups..."
    
    cd "$BACKUP_DIR/daily"
    
    # Keep only the last N daily backups
    ls -t planetplant_backup_*.tar.gz | tail -n +$((KEEP_DAILY + 1)) | xargs -r rm -f
    
    # Move weekly backups (every Sunday)
    if [ "$(date +%u)" = "7" ]; then
        LATEST_BACKUP=$(ls -t planetplant_backup_*.tar.gz | head -1)
        if [ -n "$LATEST_BACKUP" ]; then
            cp "$LATEST_BACKUP" "$BACKUP_DIR/weekly/"
            cd "$BACKUP_DIR/weekly"
            ls -t planetplant_backup_*.tar.gz | tail -n +$((KEEP_WEEKLY + 1)) | xargs -r rm -f
        fi
    fi
    
    # Move monthly backups (first day of month)
    if [ "$(date +%d)" = "01" ]; then
        LATEST_BACKUP=$(ls -t "$BACKUP_DIR/daily/planetplant_backup_*.tar.gz" | head -1)
        if [ -n "$LATEST_BACKUP" ]; then
            cp "$LATEST_BACKUP" "$BACKUP_DIR/monthly/"
            cd "$BACKUP_DIR/monthly"
            ls -t planetplant_backup_*.tar.gz | tail -n +$((KEEP_MONTHLY + 1)) | xargs -r rm -f
        fi
    fi
    
    log_success "Backup rotation completed"
}

send_notification() {
    local status=$1
    local message=$2
    
    # Send email notification if configured
    if [ -f "$PROJECT_DIR/raspberry-pi/.env" ]; then
        source "$PROJECT_DIR/raspberry-pi/.env"
        if [ "$EMAIL_ENABLED" = "true" ] && [ -n "$ALERT_RECIPIENTS" ]; then
            echo "$message" | mail -s "PlanetPlant Backup $status" "$ALERT_RECIPIENTS" 2>/dev/null || true
        fi
    fi
}

main() {
    log_info "Starting PlanetPlant backup process..."
    
    START_TIME=$(date +%s)
    
    trap 'log_error "Backup failed!"; send_notification "FAILED" "Backup process failed at $(date)"; exit 1' ERR
    
    create_backup_dirs
    backup_configuration
    backup_influxdb
    backup_redis
    backup_logs
    backup_source_code
    create_archive
    rotate_backups
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    log_success "Backup completed in ${DURATION} seconds"
    
    # Show backup summary
    echo
    echo "=== BACKUP SUMMARY ==="
    echo "Archive: ${BACKUP_DIR}/daily/${BACKUP_NAME}.tar.gz"
    echo "Size: $(du -h "${BACKUP_DIR}/daily/${BACKUP_NAME}.tar.gz" | cut -f1)"
    echo "Duration: ${DURATION} seconds"
    echo "======================="
    
    send_notification "SUCCESS" "Backup completed successfully at $(date). Duration: ${DURATION} seconds"
}

# Show usage if help is requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo
    echo "This script creates a complete backup of the PlanetPlant system including:"
    echo "  - Configuration files"
    echo "  - InfluxDB database"
    echo "  - Redis data"
    echo "  - Application logs"
    echo "  - Source code"
    echo
    echo "Backups are stored in: $BACKUP_DIR"
    echo "Retention policy:"
    echo "  - Daily backups: $KEEP_DAILY days"
    echo "  - Weekly backups: $KEEP_WEEKLY weeks"
    echo "  - Monthly backups: $KEEP_MONTHLY months"
    exit 0
fi

# Run main function
main "$@"