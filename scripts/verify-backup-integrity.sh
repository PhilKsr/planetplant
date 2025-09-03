#!/bin/bash
# PlanetPlant Backup Integrity Verification Script
# Automated verification of backup completeness and integrity

set -euo pipefail

# Configuration
VERIFICATION_TYPE="${1:-daily}"
LOG_FILE="/opt/planetplant/backup/logs/verification.log"

# Load environment
if [ -f "/opt/planetplant/backup/.env" ]; then
    source /opt/planetplant/backup/.env
fi

RESTIC_PASSWORD="${RESTIC_PASSWORD:-planetplant-backup-encryption-key}"
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-/opt/planetplant/backups/restic-repo}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to log with timestamp
log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $message" | tee -a "$LOG_FILE"
}

# Function to send alert
send_alert() {
    local level="$1"
    local message="$2"
    
    # Log alert
    log "ALERT [$level]: $message"
    
    # Send Slack notification if configured
    if [ -n "${SLACK_WEBHOOK:-}" ]; then
        local color="danger"
        [ "$level" = "WARNING" ] && color="warning"
        [ "$level" = "INFO" ] && color="good"
        
        local slack_payload=$(cat << EOF
{
    "channel": "#planetplant-alerts",
    "username": "planetplant-backup-monitor",
    "text": "🚨 Backup Alert: $level",
    "attachments": [
        {
            "color": "$color",
            "fields": [
                {
                    "title": "Verification Type",
                    "value": "$VERIFICATION_TYPE",
                    "short": true
                },
                {
                    "title": "Alert Level",
                    "value": "$level",
                    "short": true
                },
                {
                    "title": "Message",
                    "value": "$message",
                    "short": false
                },
                {
                    "title": "Timestamp",
                    "value": "$(date)",
                    "short": true
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
            "$SLACK_WEBHOOK" > /dev/null || true
    fi
}

# Function to verify restic repository
verify_restic_repository() {
    log "🔍 Verifying Restic repository integrity..."
    
    export RESTIC_REPOSITORY
    export RESTIC_PASSWORD
    
    # Basic repository check
    if ! restic snapshots >/dev/null 2>&1; then
        send_alert "CRITICAL" "Restic repository is inaccessible or corrupted"
        return 1
    fi
    
    # Get repository statistics
    local snapshot_count=$(restic snapshots --json | jq length)
    local latest_snapshot=$(restic snapshots --json | jq -r '.[-1].time')
    local repo_size=$(restic stats --mode raw-data | grep "Total Size" | awk '{print $3 $4}')
    
    log "Repository stats: $snapshot_count snapshots, latest: $latest_snapshot, size: $repo_size"
    
    # Check if latest snapshot is recent enough
    local latest_timestamp=$(date -d "$latest_snapshot" +%s)
    local now=$(date +%s)
    local hours_since_backup=$(( (now - latest_timestamp) / 3600 ))
    
    if [ $hours_since_backup -gt 48 ]; then
        send_alert "WARNING" "Latest backup is $hours_since_backup hours old (threshold: 48h)"
    fi
    
    # Integrity check based on verification type
    case $VERIFICATION_TYPE in
        "daily")
            # Quick integrity check (5% of data)
            log "Running quick integrity check..."
            if restic check --read-data-subset=5% >/dev/null 2>&1; then
                log "✅ Quick integrity check passed"
            else
                send_alert "CRITICAL" "Backup repository integrity check failed"
                return 1
            fi
            ;;
        "weekly"|"monthly")
            # Full integrity check
            log "Running full integrity check..."
            if restic check --read-data >/dev/null 2>&1; then
                log "✅ Full integrity check passed"
            else
                send_alert "CRITICAL" "Full backup repository integrity check failed"
                return 1
            fi
            ;;
    esac
    
    log "✅ Repository verification completed"
    return 0
}

# Function to verify backup contents
verify_backup_contents() {
    log "📋 Verifying backup contents..."
    
    export RESTIC_REPOSITORY
    export RESTIC_PASSWORD
    
    # Get latest snapshot
    local latest_snapshot
    latest_snapshot=$(restic snapshots --json | jq -r '.[-1].short_id')
    
    # Check if critical files are in backup
    local critical_files=(
        "config/.env"
        "config/mosquitto/mosquitto.conf"
        "influxdb"
        "docker-volumes"
    )
    
    local missing_files=()
    
    for file in "${critical_files[@]}"; do
        if restic ls "$latest_snapshot" | grep -q "$file"; then
            log "✅ Found: $file"
        else
            missing_files+=("$file")
            log "❌ Missing: $file"
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        send_alert "WARNING" "Missing critical files in backup: ${missing_files[*]}"
        return 1
    fi
    
    log "✅ Backup contents verification passed"
    return 0
}

# Function to test backup restore capability
test_restore_capability() {
    if [ "$VERIFICATION_TYPE" != "monthly" ]; then
        log "ℹ️ Skipping restore test (only monthly)"
        return 0
    fi
    
    log "🧪 Testing backup restore capability..."
    
    export RESTIC_REPOSITORY
    export RESTIC_PASSWORD
    
    # Create test restore directory
    local test_dir="/tmp/backup_test_$$"
    mkdir -p "$test_dir"
    trap "rm -rf $test_dir" EXIT
    
    # Get latest snapshot
    local latest_snapshot
    latest_snapshot=$(restic snapshots --json | jq -r '.[-1].short_id')
    
    # Test restore a small subset
    if restic restore "$latest_snapshot" \
        --target "$test_dir" \
        --include '/config/.env' \
        --include '/config/docker-compose.yml' >/dev/null 2>&1; then
        
        # Verify restored files
        if [ -f "$test_dir/config/.env" ] && [ -f "$test_dir/config/docker-compose.yml" ]; then
            log "✅ Test restore successful"
            return 0
        else
            send_alert "CRITICAL" "Test restore completed but files are missing"
            return 1
        fi
    else
        send_alert "CRITICAL" "Test restore failed - backup may be corrupted"
        return 1
    fi
}

# Function to verify service backups
verify_service_backups() {
    log "🔍 Verifying service-specific backups..."
    
    # Check InfluxDB backup availability
    if docker ps --format '{{.Names}}' | grep -q "planetplant-influxdb"; then
        # Test InfluxDB backup functionality
        if docker exec planetplant-influxdb \
            influx backup \
            --org "${INFLUXDB_ORG:-planetplant}" \
            --token "${INFLUXDB_TOKEN:-plantplant-super-secret-auth-token}" \
            /tmp/verify-backup >/dev/null 2>&1; then
            
            log "✅ InfluxDB backup capability verified"
            docker exec planetplant-influxdb rm -rf /tmp/verify-backup 2>/dev/null || true
        else
            send_alert "WARNING" "InfluxDB backup functionality test failed"
        fi
    fi
    
    # Check Redis backup capability
    if docker ps --format '{{.Names}}' | grep -q "planetplant-redis"; then
        if docker exec planetplant-redis redis-cli LASTSAVE >/dev/null 2>&1; then
            log "✅ Redis backup capability verified"
        else
            send_alert "WARNING" "Redis backup capability test failed"
        fi
    fi
    
    # Check Docker volume accessibility
    local volumes=$(docker volume ls --filter name=planetplant --format '{{.Name}}')
    for volume in $volumes; do
        if docker run --rm -v "$volume:/test" alpine ls /test >/dev/null 2>&1; then
            log "✅ Volume accessible: $volume"
        else
            send_alert "WARNING" "Volume not accessible: $volume"
        fi
    done
    
    log "✅ Service backup verification completed"
}

# Function to check backup storage space
check_storage_space() {
    log "💽 Checking backup storage space..."
    
    local backup_dir_size=$(du -sh "/opt/planetplant/backups" 2>/dev/null | cut -f1 || echo "0")
    local available_space=$(df "/opt/planetplant" --output=avail | tail -1 | awk '{print int($1/1024/1024)}')
    local used_percent=$(df "/opt/planetplant" --output=pcent | tail -1 | tr -d '%')
    
    log "Storage status: $backup_dir_size used, ${available_space}GB available (${used_percent}% full)"
    
    # Alert if storage is getting full
    if [ "$used_percent" -gt 80 ]; then
        send_alert "WARNING" "Backup storage nearly full: ${used_percent}% used, ${available_space}GB remaining"
    elif [ "$available_space" -lt 5 ]; then
        send_alert "CRITICAL" "Backup storage critically low: ${available_space}GB remaining"
        return 1
    fi
    
    log "✅ Storage space check passed"
}

# Main verification procedure
main() {
    local start_time=$(date +%s)
    
    log "🔍 Starting $VERIFICATION_TYPE backup verification..."
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Track verification status
    local verification_success=true
    local issues=()
    
    # Execute verification steps
    echo -e "${YELLOW}1/5 Verifying Restic repository...${NC}"
    if ! verify_restic_repository; then
        verification_success=false
        issues+=("Repository integrity")
    fi
    
    echo -e "${YELLOW}2/5 Verifying backup contents...${NC}"
    if ! verify_backup_contents; then
        verification_success=false
        issues+=("Missing critical files")
    fi
    
    echo -e "${YELLOW}3/5 Testing restore capability...${NC}"
    if ! test_restore_capability; then
        verification_success=false
        issues+=("Restore capability")
    fi
    
    echo -e "${YELLOW}4/5 Verifying service backups...${NC}"
    if ! verify_service_backups; then
        verification_success=false
        issues+=("Service backup capability")
    fi
    
    echo -e "${YELLOW}5/5 Checking storage space...${NC}"
    if ! check_storage_space; then
        verification_success=false
        issues+=("Storage space critical")
    fi
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Generate verification report
    if [ "$verification_success" = true ]; then
        log "SUCCESS: Backup verification completed successfully in ${duration}s"
        
        echo ""
        echo -e "${GREEN}✅ BACKUP VERIFICATION PASSED${NC}"
        echo ""
        echo "📊 Verification Summary:"
        echo "   Type: $VERIFICATION_TYPE"
        echo "   Duration: ${duration}s"
        echo "   Status: ✅ All checks passed"
        echo "   Repository: $RESTIC_REPOSITORY"
        echo ""
        
        # Send success notification only for weekly/monthly
        if [ "$VERIFICATION_TYPE" != "daily" ]; then
            send_alert "INFO" "Backup verification completed successfully ($VERIFICATION_TYPE)"
        fi
        
    else
        log "FAILED: Backup verification failed with issues: ${issues[*]}"
        
        echo ""
        echo -e "${RED}❌ BACKUP VERIFICATION FAILED${NC}"
        echo ""
        echo "🚨 Issues detected:"
        for issue in "${issues[@]}"; do
            echo "   ❌ $issue"
        done
        echo ""
        echo -e "${BLUE}🔧 Recommended Actions:${NC}"
        echo "   1. Check backup system status: docker ps | grep backup"
        echo "   2. Review backup logs: cat $LOG_FILE"
        echo "   3. Run manual backup: /opt/planetplant/scripts/backup-all.sh manual"
        echo "   4. Check storage space: df -h /opt/planetplant"
        echo "   5. Contact technical support if issues persist"
        
        send_alert "CRITICAL" "Backup verification failed: ${issues[*]}"
        exit 1
    fi
}

# Execute verification
echo -e "${BLUE}🔍 PlanetPlant Backup Verification${NC}"
echo "Verification type: $VERIFICATION_TYPE"
echo "Started: $(date)"
echo ""

main