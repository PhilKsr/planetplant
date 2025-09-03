#!/bin/bash
# PlanetPlant Comprehensive Backup Script
# Creates encrypted backups of all system components with cloud upload

set -euo pipefail

# Configuration
BACKUP_TYPE="${1:-daily}"
BACKUP_DIR="/opt/planetplant/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="planetplant_${BACKUP_TYPE}_${TIMESTAMP}"
TEMP_DIR="/tmp/planetplant_backup_$$"

# Load environment
if [ -f "/opt/planetplant/backup/.env" ]; then
    source /opt/planetplant/backup/.env
fi

# Default configuration
RESTIC_PASSWORD="${RESTIC_PASSWORD:-planetplant-backup-encryption-key}"
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-/opt/planetplant/backups/restic-repo}"
CLOUD_UPLOAD_ENABLED="${CLOUD_UPLOAD_ENABLED:-false}"
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-admin@planetplant.local}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}💾 PlanetPlant Backup: $BACKUP_TYPE${NC}"
echo "============================================"
echo "Timestamp: $(date)"
echo "Backup name: $BACKUP_NAME"
echo ""

# Create temporary directory
mkdir -p "$TEMP_DIR"
trap 'rm -rf "$TEMP_DIR"' EXIT

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$BACKUP_DIR/backup.log"
}

# Function to send notification
send_notification() {
    local status="$1"
    local message="$2"
    local details="${3:-}"
    
    log "Notification: [$status] $message"
    
    # Email notification
    if [ -n "${SMTP_USER:-}" ] && [ -n "${SMTP_PASSWORD:-}" ]; then
        local subject="[PlanetPlant Backup] $status: $BACKUP_TYPE"
        local body="Backup Status: $status
Message: $message
Timestamp: $(date)
Backup Name: $BACKUP_NAME

$details"
        
        echo "$body" | mail -s "$subject" "$NOTIFICATION_EMAIL" 2>/dev/null || \
        log "Failed to send email notification"
    fi
    
    # Slack notification
    if [ -n "${SLACK_WEBHOOK:-}" ]; then
        local color="good"
        [ "$status" = "FAILED" ] && color="danger"
        [ "$status" = "WARNING" ] && color="warning"
        
        local slack_payload=$(cat << EOF
{
    "channel": "#planetplant-backups",
    "username": "planetplant-backup",
    "text": "$status: $BACKUP_TYPE backup",
    "attachments": [
        {
            "color": "$color",
            "fields": [
                {
                    "title": "Status",
                    "value": "$status",
                    "short": true
                },
                {
                    "title": "Type",
                    "value": "$BACKUP_TYPE",
                    "short": true
                },
                {
                    "title": "Message",
                    "value": "$message",
                    "short": false
                },
                {
                    "title": "Details",
                    "value": "$details",
                    "short": false
                }
            ]
        }
    ]
}
EOF
)
        
        curl -s -X POST \
            -H "Content-type: application/json" \
            -d "$slack_payload" \
            "$SLACK_WEBHOOK" > /dev/null || \
            log "Failed to send Slack notification"
    fi
}

# Function to backup InfluxDB
backup_influxdb() {
    log "📊 Backing up InfluxDB..."
    
    local influx_backup_dir="$TEMP_DIR/influxdb"
    mkdir -p "$influx_backup_dir"
    
    # Production InfluxDB
    if docker ps --format '{{.Names}}' | grep -q "planetplant-influxdb$"; then
        log "Backing up production InfluxDB..."
        docker exec planetplant-influxdb influx backup \
            --org "${INFLUXDB_ORG:-planetplant}" \
            --token "${INFLUXDB_TOKEN:-plantplant-super-secret-auth-token}" \
            /tmp/influx-backup/production 2>/dev/null || \
            log "Warning: Production InfluxDB backup failed"
            
        docker cp planetplant-influxdb:/tmp/influx-backup/production "$influx_backup_dir/" 2>/dev/null || \
            log "Warning: Could not copy production InfluxDB backup"
    fi
    
    # Staging InfluxDB
    if docker ps --format '{{.Names}}' | grep -q "planetplant-influxdb-staging"; then
        log "Backing up staging InfluxDB..."
        docker exec planetplant-influxdb-staging influx backup \
            --org "${INFLUXDB_ORG:-planetplant-staging}" \
            --token "${INFLUXDB_TOKEN:-plantplant-staging-token}" \
            /tmp/influx-backup/staging 2>/dev/null || \
            log "Warning: Staging InfluxDB backup failed"
            
        docker cp planetplant-influxdb-staging:/tmp/influx-backup/staging "$influx_backup_dir/" 2>/dev/null || \
            log "Warning: Could not copy staging InfluxDB backup"
    fi
    
    log "✅ InfluxDB backup completed"
}

# Function to backup Redis
backup_redis() {
    log "🔴 Backing up Redis..."
    
    local redis_backup_dir="$TEMP_DIR/redis"
    mkdir -p "$redis_backup_dir"
    
    # Production Redis
    if docker ps --format '{{.Names}}' | grep -q "planetplant-redis$"; then
        log "Creating Redis production dump..."
        docker exec planetplant-redis redis-cli --rdb /data/backup.rdb 2>/dev/null || \
            log "Warning: Production Redis backup failed"
        docker cp planetplant-redis:/data/dump.rdb "$redis_backup_dir/production.rdb" 2>/dev/null || \
            log "Warning: Could not copy production Redis backup"
    fi
    
    # Staging Redis
    if docker ps --format '{{.Names}}' | grep -q "planetplant-redis-staging"; then
        log "Creating Redis staging dump..."
        docker exec planetplant-redis-staging redis-cli --rdb /data/backup.rdb 2>/dev/null || \
            log "Warning: Staging Redis backup failed"
        docker cp planetplant-redis-staging:/data/dump.rdb "$redis_backup_dir/staging.rdb" 2>/dev/null || \
            log "Warning: Could not copy staging Redis backup"
    fi
    
    log "✅ Redis backup completed"
}

# Function to backup configuration files
backup_configs() {
    log "⚙️ Backing up configuration files..."
    
    local config_backup_dir="$TEMP_DIR/config"
    mkdir -p "$config_backup_dir"
    
    # Copy all configuration directories
    cp -r /opt/planetplant/config/* "$config_backup_dir/" 2>/dev/null || \
        log "Warning: Some config files could not be backed up"
    
    # Copy environment files
    cp /opt/planetplant/.env "$config_backup_dir/" 2>/dev/null || \
        log "Warning: .env file not found"
    
    # Copy docker-compose files
    cp /opt/planetplant/docker-compose*.yml "$config_backup_dir/" 2>/dev/null || \
        log "Warning: Docker compose files not found"
    
    # Copy scripts
    cp -r /opt/planetplant/scripts "$config_backup_dir/" 2>/dev/null || \
        log "Warning: Scripts directory not found"
    
    log "✅ Configuration backup completed"
}

# Function to backup Docker volumes
backup_docker_volumes() {
    log "🐳 Backing up Docker volumes..."
    
    local volumes_backup_dir="$TEMP_DIR/docker-volumes"
    mkdir -p "$volumes_backup_dir"
    
    # Get list of PlanetPlant volumes
    local volumes=$(docker volume ls --filter name=planetplant --format '{{.Name}}')
    
    for volume in $volumes; do
        log "Backing up volume: $volume"
        
        # Create volume backup using temporary container
        docker run --rm \
            -v "$volume:/volume:ro" \
            -v "$volumes_backup_dir:/backup" \
            alpine \
            tar -czf "/backup/${volume}.tar.gz" -C /volume . 2>/dev/null || \
            log "Warning: Could not backup volume $volume"
    done
    
    log "✅ Docker volumes backup completed"
}

# Function to backup application logs
backup_logs() {
    log "📋 Backing up application logs..."
    
    local logs_backup_dir="$TEMP_DIR/logs"
    mkdir -p "$logs_backup_dir"
    
    # Copy recent logs (last 7 days only for daily backups)
    if [ "$BACKUP_TYPE" = "daily" ]; then
        find /opt/planetplant/logs -name "*.log" -mtime -7 -exec cp {} "$logs_backup_dir/" \; 2>/dev/null || \
            log "Warning: Could not copy recent logs"
    else
        # Full log backup for weekly/monthly
        cp -r /opt/planetplant/logs/* "$logs_backup_dir/" 2>/dev/null || \
            log "Warning: Could not copy all logs"
    fi
    
    log "✅ Logs backup completed"
}

# Function to create restic snapshot
create_restic_snapshot() {
    log "📦 Creating Restic snapshot..."
    
    # Set Restic environment
    export RESTIC_REPOSITORY
    export RESTIC_PASSWORD
    export RESTIC_CACHE_DIR="/opt/planetplant/backup/cache"
    
    # Initialize repository if it doesn't exist
    if ! restic snapshots &>/dev/null; then
        log "Initializing new Restic repository..."
        restic init || {
            log "Failed to initialize Restic repository"
            return 1
        }
    fi
    
    # Create snapshot with tags
    local tags="type:$BACKUP_TYPE,host:$(hostname),date:$(date +%Y-%m-%d)"
    
    if restic backup "$TEMP_DIR" \
        --tag "$tags" \
        --exclude-caches \
        --exclude '*.tmp' \
        --exclude '*.log.gz' \
        --verbose; then
        
        log "✅ Restic snapshot created successfully"
        
        # Get snapshot info
        local snapshot_id=$(restic snapshots --latest 1 --json | jq -r '.[0].id[:8]')
        local snapshot_size=$(restic snapshots --latest 1 --json | jq -r '.[0].size')
        
        echo "Snapshot ID: $snapshot_id"
        echo "Backup size: $snapshot_size bytes"
        
        return 0
    else
        log "❌ Restic snapshot creation failed"
        return 1
    fi
}

# Function to apply retention policy
apply_retention_policy() {
    log "🧹 Applying retention policy..."
    
    export RESTIC_REPOSITORY
    export RESTIC_PASSWORD
    
    # Forget old snapshots based on policy
    if restic forget \
        --keep-daily "${KEEP_DAILY:-7}" \
        --keep-weekly "${KEEP_WEEKLY:-4}" \
        --keep-monthly "${KEEP_MONTHLY:-12}" \
        --keep-yearly "${KEEP_YEARLY:-2}" \
        --prune; then
        
        log "✅ Retention policy applied successfully"
    else
        log "⚠️ Warning: Retention policy application failed"
    fi
}

# Function to upload to cloud
upload_to_cloud() {
    if [ "$CLOUD_UPLOAD_ENABLED" != "true" ]; then
        log "ℹ️ Cloud upload disabled, skipping..."
        return 0
    fi
    
    log "☁️ Uploading to cloud..."
    
    # Use rclone to sync to configured cloud provider
    local cloud_target="${CLOUD_PROVIDER:-s3}:${S3_BUCKET:-planetplant-backups}/$(hostname)"
    
    if rclone sync "$RESTIC_REPOSITORY" "$cloud_target" \
        --transfers "${PARALLEL_TRANSFERS:-4}" \
        --bwlimit "${MAX_TRANSFER_RATE:-10M}" \
        --exclude '.cache/**' \
        --verbose; then
        
        log "✅ Cloud upload completed successfully"
    else
        log "❌ Cloud upload failed"
        return 1
    fi
}

# Function to verify backup integrity
verify_backup() {
    log "🔍 Verifying backup integrity..."
    
    export RESTIC_REPOSITORY
    export RESTIC_PASSWORD
    
    # Check repository integrity
    if restic check --read-data-subset=5%; then
        log "✅ Backup integrity verification passed"
    else
        log "❌ Backup integrity verification failed"
        return 1
    fi
}

# Main backup execution
main() {
    local start_time=$(date +%s)
    
    log "🚀 Starting $BACKUP_TYPE backup..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Track backup status
    local backup_success=true
    local error_details=""
    
    # Execute backup steps
    echo -e "${YELLOW}1/7 Backing up InfluxDB...${NC}"
    if ! backup_influxdb; then
        backup_success=false
        error_details+="InfluxDB backup failed. "
    fi
    
    echo -e "${YELLOW}2/7 Backing up Redis...${NC}"
    if ! backup_redis; then
        backup_success=false
        error_details+="Redis backup failed. "
    fi
    
    echo -e "${YELLOW}3/7 Backing up configurations...${NC}"
    if ! backup_configs; then
        backup_success=false
        error_details+="Config backup failed. "
    fi
    
    echo -e "${YELLOW}4/7 Backing up Docker volumes...${NC}"
    if [ "$BACKUP_TYPE" != "daily" ]; then
        if ! backup_docker_volumes; then
            backup_success=false
            error_details+="Docker volumes backup failed. "
        fi
    else
        log "Skipping Docker volumes for daily backup"
    fi
    
    echo -e "${YELLOW}5/7 Backing up logs...${NC}"
    if ! backup_logs; then
        backup_success=false
        error_details+="Logs backup failed. "
    fi
    
    echo -e "${YELLOW}6/7 Creating Restic snapshot...${NC}"
    if ! create_restic_snapshot; then
        backup_success=false
        error_details+="Restic snapshot creation failed. "
    fi
    
    echo -e "${YELLOW}7/7 Applying retention policy...${NC}"
    if ! apply_retention_policy; then
        log "Warning: Retention policy failed"
        error_details+="Retention policy failed. "
    fi
    
    # Cloud upload for weekly and monthly backups
    if [ "$BACKUP_TYPE" != "daily" ] || [ "$CLOUD_UPLOAD_ENABLED" = "true" ]; then
        echo -e "${YELLOW}☁️ Uploading to cloud...${NC}"
        if ! upload_to_cloud; then
            backup_success=false
            error_details+="Cloud upload failed. "
        fi
    fi
    
    # Verify backup integrity for weekly/monthly backups
    if [ "$BACKUP_TYPE" != "daily" ]; then
        echo -e "${YELLOW}🔍 Verifying backup integrity...${NC}"
        if ! verify_backup; then
            backup_success=false
            error_details+="Backup verification failed. "
        fi
    fi
    
    # Calculate duration and size
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local backup_size=$(du -sh "$RESTIC_REPOSITORY" 2>/dev/null | cut -f1 || echo "unknown")
    
    # Generate summary
    local summary="Backup completed in ${duration}s
Total repository size: $backup_size
Backup type: $BACKUP_TYPE
Errors: ${error_details:-None}"
    
    if [ "$backup_success" = true ]; then
        echo -e "${GREEN}✅ Backup completed successfully!${NC}"
        log "SUCCESS: Backup completed successfully"
        send_notification "SUCCESS" "Backup completed successfully" "$summary"
    else
        echo -e "${RED}❌ Backup completed with errors!${NC}"
        log "FAILED: Backup completed with errors: $error_details"
        send_notification "FAILED" "Backup completed with errors" "$summary"
        exit 1
    fi
    
    # Cleanup old local backups (keep only what retention policy specifies)
    log "🧹 Cleaning up old local backups..."
    find "$BACKUP_DIR" -name "planetplant_*.tar.gz" -mtime +7 -delete 2>/dev/null || true
    
    # Log final status
    echo ""
    echo "📊 Backup Summary:"
    echo "   Type: $BACKUP_TYPE"
    echo "   Duration: ${duration}s"
    echo "   Repository size: $backup_size"
    echo "   Status: $([ "$backup_success" = true ] && echo "✅ Success" || echo "❌ Failed")"
    echo "   Timestamp: $(date)"
    echo ""
    
    log "Backup process completed: $BACKUP_NAME"
}

# Validate backup type
case $BACKUP_TYPE in
    daily|weekly|monthly|manual)
        main
        ;;
    *)
        echo -e "${RED}❌ Invalid backup type: $BACKUP_TYPE${NC}"
        echo "Usage: $0 {daily|weekly|monthly|manual}"
        exit 1
        ;;
esac