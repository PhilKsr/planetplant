#!/bin/bash
# PlanetPlant Emergency Restore Script
# Fast recovery for critical system failures - minimal user interaction

set -euo pipefail

# Configuration
EMERGENCY_MODE="${1:-auto}"
BACKUP_TYPE="${2:-latest}"
RESTORE_TIMEOUT=1800  # 30 minutes maximum

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}🚨 EMERGENCY RESTORE PROCEDURE${NC}"
echo "==============================="
echo "Mode: $EMERGENCY_MODE"
echo "Backup: $BACKUP_TYPE"
echo "Started: $(date)"
echo ""

# Load environment
if [ -f "/opt/planetplant/backup/.env" ]; then
    source /opt/planetplant/backup/.env
fi

RESTIC_PASSWORD="${RESTIC_PASSWORD:-planetplant-backup-encryption-key}"
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-/opt/planetplant/backups/restic-repo}"

# Function to log with timestamp
log() {
    echo -e "${BLUE}$(date '+%H:%M:%S')${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> /opt/planetplant/backup/logs/emergency-restore.log
}

# Function for emergency notification
emergency_notify() {
    local status="$1"
    local message="$2"
    
    log "EMERGENCY: $status - $message"
    
    # Send emergency notification
    if [ -n "${SLACK_WEBHOOK:-}" ]; then
        curl -s -X POST -H "Content-type: application/json" \
            -d "{\"text\":\"🚨 EMERGENCY: $status\\n$message\\nTime: $(date)\"}" \
            "$SLACK_WEBHOOK" > /dev/null || true
    fi
    
    # Log to system log
    logger "PlanetPlant EMERGENCY: $status - $message"
}

# Function to check system requirements
check_requirements() {
    log "🔍 Checking system requirements..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Emergency restore must be run as root${NC}"
        echo "Usage: sudo $0 [auto|manual] [latest|snapshot-id]"
        exit 1
    fi
    
    # Check available disk space
    local available_gb=$(df /opt/planetplant --output=avail | tail -1 | awk '{print int($1/1024/1024)}')
    if [ "$available_gb" -lt 5 ]; then
        log "❌ Insufficient disk space: ${available_gb}GB available"
        emergency_notify "CRITICAL" "Insufficient disk space for restore: ${available_gb}GB"
        exit 1
    fi
    
    # Check if backup repository exists
    if [ ! -d "$RESTIC_REPOSITORY" ]; then
        log "❌ Backup repository not found: $RESTIC_REPOSITORY"
        emergency_notify "CRITICAL" "No backup repository found - cannot restore"
        exit 1
    fi
    
    log "✅ Requirements check passed"
}

# Function to stop all services immediately
emergency_stop_services() {
    log "🛑 Emergency stop of all PlanetPlant services..."
    
    # Stop all docker-compose stacks
    cd /opt/planetplant
    
    # Main stack
    docker compose down --timeout 30 || {
        log "Warning: Forceful container termination"
        docker kill $(docker ps -q --filter name=planetplant) 2>/dev/null || true
    }
    
    # Staging stack
    docker compose -f docker-compose.staging.yml down --timeout 30 2>/dev/null || true
    
    # Monitoring stack
    cd /opt/planetplant/monitoring 2>/dev/null && docker compose down --timeout 30 || true
    
    log "✅ Services stopped"
}

# Function to get latest snapshot automatically
get_latest_snapshot() {
    export RESTIC_REPOSITORY
    export RESTIC_PASSWORD
    
    log "🔍 Finding latest backup snapshot..."
    
    local latest_snapshot
    latest_snapshot=$(restic snapshots --json | jq -r '.[-1].short_id' 2>/dev/null)
    
    if [ "$latest_snapshot" = "null" ] || [ -z "$latest_snapshot" ]; then
        log "❌ No snapshots found in repository"
        emergency_notify "CRITICAL" "No backup snapshots available for restore"
        exit 1
    fi
    
    log "Latest snapshot: $latest_snapshot"
    echo "$latest_snapshot"
}

# Function for fast restore
fast_restore() {
    local snapshot_id="$1"
    
    export RESTIC_REPOSITORY
    export RESTIC_PASSWORD
    
    log "⚡ Starting fast restore from $snapshot_id..."
    
    # Create temporary directory
    local restore_dir="/tmp/emergency_restore_$$"
    mkdir -p "$restore_dir"
    trap "rm -rf $restore_dir" EXIT
    
    # Restore critical components only
    log "📦 Restoring critical files..."
    
    if restic restore "$snapshot_id" \
        --target "$restore_dir" \
        --include '/config' \
        --include '/influxdb' \
        --include '/redis'; then
        
        log "✅ Critical files restored"
    else
        log "❌ Restore failed"
        emergency_notify "CRITICAL" "Emergency restore failed - snapshot $snapshot_id"
        exit 1
    fi
    
    # Restore configuration files
    log "⚙️ Restoring configuration..."
    if [ -d "$restore_dir/config" ]; then
        cp -r "$restore_dir/config"/* /opt/planetplant/config/ 2>/dev/null || \
            log "Warning: Some config files could not be restored"
    fi
    
    # Restore .env file
    if [ -f "$restore_dir/config/.env" ]; then
        cp "$restore_dir/config/.env" /opt/planetplant/.env
        log "✅ Environment file restored"
    fi
    
    # Restore database data (critical)
    log "🗄️ Restoring database data..."
    if [ -d "$restore_dir/influxdb" ]; then
        # Stop InfluxDB if running
        docker stop planetplant-influxdb 2>/dev/null || true
        
        # Restore data
        rm -rf /opt/planetplant/data/influxdb/* 2>/dev/null || true
        cp -r "$restore_dir/influxdb"/* /opt/planetplant/data/influxdb/ 2>/dev/null || \
            log "Warning: InfluxDB restore may have issues"
        
        # Fix permissions
        sudo chown -R 1001:1001 /opt/planetplant/data/influxdb/
    fi
    
    # Restore Redis data
    if [ -d "$restore_dir/redis" ] && [ -f "$restore_dir/redis/production.rdb" ]; then
        cp "$restore_dir/redis/production.rdb" /opt/planetplant/data/redis/dump.rdb 2>/dev/null || \
            log "Warning: Redis restore may have issues"
    fi
    
    log "✅ Fast restore completed"
}

# Function to start services with timeout
start_services_emergency() {
    log "🚀 Starting services in emergency mode..."
    
    cd /opt/planetplant
    
    # Start services with timeout
    timeout 300 docker compose up -d || {
        log "❌ Services failed to start within timeout"
        emergency_notify "CRITICAL" "Service startup failed during emergency restore"
        return 1
    }
    
    # Wait for critical services
    log "⏳ Waiting for critical services..."
    sleep 30
    
    # Check critical services only
    local critical_services=("influxdb" "backend")
    local failed_services=()
    
    for service in "${critical_services[@]}"; do
        local container_name="planetplant-$service"
        local health_status
        health_status=$(docker inspect "$container_name" --format '{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
        
        if [ "$health_status" = "healthy" ] || [ "$health_status" = "no-healthcheck" ]; then
            # Additional check for services without health checks
            if docker ps --filter name="$container_name" --filter status=running | grep -q "$container_name"; then
                log "✅ $service is running"
            else
                failed_services+=("$service")
            fi
        else
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        log "✅ All critical services started successfully"
        return 0
    else
        log "❌ Failed services: ${failed_services[*]}"
        return 1
    fi
}

# Function to verify emergency recovery
verify_emergency_recovery() {
    log "🔍 Verifying emergency recovery..."
    
    local verification_failed=false
    
    # Test backend API
    if curl -f -s http://localhost:3001/api/health >/dev/null 2>&1; then
        log "✅ Backend API responding"
    else
        log "❌ Backend API not responding"
        verification_failed=true
    fi
    
    # Test database connection
    if curl -f -s http://localhost:8086/ping >/dev/null 2>&1; then
        log "✅ Database responding"
    else
        log "❌ Database not responding"
        verification_failed=true
    fi
    
    # Test MQTT broker
    if docker exec planetplant-mosquitto mosquitto_pub -h localhost -t test -m 'emergency-test' >/dev/null 2>&1; then
        log "✅ MQTT broker responding"
    else
        log "❌ MQTT broker not responding"
        verification_failed=true
    fi
    
    if [ "$verification_failed" = true ]; then
        log "❌ Emergency recovery verification failed"
        return 1
    else
        log "✅ Emergency recovery verification passed"
        return 0
    fi
}

# Main emergency restore procedure
main() {
    local start_time=$(date +%s)
    emergency_notify "STARTED" "Emergency restore procedure initiated"
    
    # Pre-flight checks
    check_requirements
    
    # Determine snapshot to restore
    local snapshot_id
    if [ "$BACKUP_TYPE" = "latest" ]; then
        snapshot_id=$(get_latest_snapshot)
    else
        snapshot_id="$BACKUP_TYPE"
    fi
    
    log "Target snapshot: $snapshot_id"
    
    # Emergency confirmation for manual mode
    if [ "$EMERGENCY_MODE" = "manual" ]; then
        echo ""
        echo -e "${RED}⚠️ WARNING: EMERGENCY RESTORE PROCEDURE${NC}"
        echo "This will:"
        echo "  1. Stop all PlanetPlant services immediately"
        echo "  2. Restore from backup snapshot: $snapshot_id"
        echo "  3. Restart services"
        echo ""
        read -p "Continue? Type 'EMERGENCY' to confirm: " confirmation
        
        if [ "$confirmation" != "EMERGENCY" ]; then
            log "Emergency restore cancelled by user"
            exit 0
        fi
    fi
    
    # Execute emergency restore steps
    log "🚨 Beginning emergency restore procedure..."
    
    # Step 1: Emergency stop
    emergency_stop_services
    
    # Step 2: Fast restore critical data
    fast_restore "$snapshot_id"
    
    # Step 3: Start services
    if ! start_services_emergency; then
        log "❌ Service startup failed"
        emergency_notify "FAILED" "Emergency restore failed at service startup"
        
        # Attempt basic service start without dependencies
        log "🔄 Attempting minimal service recovery..."
        docker compose up -d influxdb mosquitto
        sleep 20
        docker compose up -d backend
        
        if curl -f -s http://localhost:3001/api/health >/dev/null 2>&1; then
            log "✅ Minimal recovery successful"
            emergency_notify "PARTIAL" "Minimal service recovery achieved"
        else
            log "❌ Complete recovery failure"
            emergency_notify "CRITICAL" "Emergency restore completely failed"
            exit 1
        fi
    fi
    
    # Step 4: Verify recovery
    if verify_emergency_recovery; then
        local end_time=$(date +%s)
        local duration=$(((end_time - start_time) / 60))
        
        log "✅ Emergency restore completed successfully"
        emergency_notify "SUCCESS" "Emergency restore completed in ${duration} minutes"
        
        echo ""
        echo -e "${GREEN}🎉 EMERGENCY RESTORE SUCCESSFUL${NC}"
        echo ""
        echo "📊 Recovery Summary:"
        echo "   Duration: ${duration} minutes"
        echo "   Snapshot: $snapshot_id"
        echo "   Status: ✅ All critical services restored"
        echo ""
        echo -e "${BLUE}🔧 Next Steps:${NC}"
        echo "   1. Verify plant data: http://localhost"
        echo "   2. Check all services: docker ps"
        echo "   3. Review logs: docker compose logs"
        echo "   4. Test ESP32 connectivity"
        echo "   5. Update incident documentation"
        
    else
        log "❌ Emergency recovery verification failed"
        emergency_notify "FAILED" "Emergency restore completed but verification failed"
        exit 1
    fi
}

# Show usage if no arguments
if [ $# -eq 0 ]; then
    echo "PlanetPlant Emergency Restore"
    echo ""
    echo "Usage:"
    echo "  $0 auto latest          # Automatic restore from latest backup"
    echo "  $0 manual <snapshot>    # Manual restore with confirmation"
    echo ""
    echo "Emergency contacts:"
    echo "  📞 On-call: [Configure in DR plan]"
    echo "  📧 Email: admin@planetplant.local"
    echo ""
    echo "Before running:"
    echo "  ⚠️ This will stop ALL services immediately"
    echo "  ⚠️ Use only for critical system failures"
    echo "  ⚠️ Have emergency contacts ready"
    echo ""
    exit 0
fi

# Execute main procedure
main