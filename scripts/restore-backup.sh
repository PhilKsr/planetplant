#!/bin/bash
# PlanetPlant Backup Restore Script
# Interactive restore with verification and rollback capability

set -euo pipefail

# Configuration
BACKUP_DIR="/opt/planetplant/backups"
RESTORE_DIR="/tmp/planetplant_restore_$$"
CURRENT_BACKUP_DIR="/opt/planetplant/backups/pre-restore-$(date +%Y%m%d_%H%M%S)"

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

echo -e "${BLUE}🔄 PlanetPlant Backup Restore${NC}"
echo "==============================="
echo ""

# Function to list available snapshots
list_snapshots() {
    export RESTIC_REPOSITORY
    export RESTIC_PASSWORD
    
    echo -e "${YELLOW}📋 Available snapshots:${NC}"
    restic snapshots --compact || {
        echo -e "${RED}❌ Could not access backup repository${NC}"
        echo "Make sure the repository exists and password is correct"
        exit 1
    }
}

# Function to select snapshot interactively
select_snapshot() {
    local snapshots_json
    snapshots_json=$(restic snapshots --json) || {
        echo -e "${RED}❌ Could not retrieve snapshots${NC}"
        exit 1
    }
    
    echo ""
    echo -e "${YELLOW}Available snapshots:${NC}"
    echo ""
    
    # Display snapshots with numbers
    echo "$snapshots_json" | jq -r '.[] | "\(.short_id) - \(.time) - \(.tags // [] | join(","))"' | \
    nl -w3 -s') '
    
    echo ""
    read -p "Select snapshot number (or 'q' to quit): " selection
    
    if [ "$selection" = "q" ]; then
        echo "Restore cancelled"
        exit 0
    fi
    
    # Get selected snapshot ID
    local snapshot_id
    snapshot_id=$(echo "$snapshots_json" | jq -r ".[$((selection-1))].short_id" 2>/dev/null)
    
    if [ "$snapshot_id" = "null" ] || [ -z "$snapshot_id" ]; then
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
    fi
    
    echo "Selected snapshot: $snapshot_id"
    echo "$snapshot_id"
}

# Function to create pre-restore backup
create_pre_restore_backup() {
    echo -e "${YELLOW}💾 Creating pre-restore backup...${NC}"
    
    mkdir -p "$CURRENT_BACKUP_DIR"
    
    # Backup current state
    if ! /opt/planetplant/scripts/backup-all.sh manual; then
        echo -e "${YELLOW}⚠️ Warning: Could not create pre-restore backup${NC}"
        read -p "Continue without pre-restore backup? (y/N): " continue_restore
        if [ "$continue_restore" != "y" ]; then
            echo "Restore cancelled"
            exit 1
        fi
    else
        echo "✅ Pre-restore backup created"
    fi
}

# Function to stop services safely
stop_services() {
    echo -e "${YELLOW}🛑 Stopping PlanetPlant services...${NC}"
    
    local services_stopped=true
    
    # Stop main stack
    if [ -f "/opt/planetplant/docker-compose.yml" ]; then
        cd /opt/planetplant
        docker compose down || {
            echo -e "${YELLOW}⚠️ Some services may still be running${NC}"
            services_stopped=false
        }
    fi
    
    # Stop staging stack
    if [ -f "/opt/planetplant/docker-compose.staging.yml" ]; then
        cd /opt/planetplant
        docker compose -f docker-compose.staging.yml down || {
            echo -e "${YELLOW}⚠️ Some staging services may still be running${NC}"
            services_stopped=false
        }
    fi
    
    if [ "$services_stopped" = true ]; then
        echo "✅ All services stopped successfully"
    else
        echo -e "${YELLOW}⚠️ Some services may still be running${NC}"
        read -p "Continue with restore anyway? (y/N): " continue_restore
        if [ "$continue_restore" != "y" ]; then
            echo "Restore cancelled"
            exit 1
        fi
    fi
}

# Function to restore from snapshot
restore_snapshot() {
    local snapshot_id="$1"
    
    echo -e "${YELLOW}📦 Restoring from snapshot $snapshot_id...${NC}"
    
    export RESTIC_REPOSITORY
    export RESTIC_PASSWORD
    
    # Create temporary restore directory
    mkdir -p "$RESTORE_DIR"
    
    # Restore snapshot
    if restic restore "$snapshot_id" --target "$RESTORE_DIR"; then
        echo "✅ Snapshot restored to temporary directory"
    else
        echo -e "${RED}❌ Failed to restore snapshot${NC}"
        return 1
    fi
    
    # Restore components selectively
    echo -e "${YELLOW}🔄 Restoring components...${NC}"
    
    # 1. Restore configuration files
    if [ -d "$RESTORE_DIR/config" ]; then
        echo "Restoring configuration files..."
        cp -r "$RESTORE_DIR/config"/* /opt/planetplant/config/ 2>/dev/null || \
            echo "Warning: Could not restore some config files"
    fi
    
    # 2. Restore InfluxDB data
    if [ -d "$RESTORE_DIR/influxdb" ]; then
        echo "Restoring InfluxDB data..."
        # Note: InfluxDB restore requires special handling when containers are running
        cp -r "$RESTORE_DIR/influxdb"/* /opt/planetplant/data/influxdb/ 2>/dev/null || \
            echo "Warning: InfluxDB restore may require manual intervention"
    fi
    
    # 3. Restore Redis data
    if [ -d "$RESTORE_DIR/redis" ]; then
        echo "Restoring Redis data..."
        cp "$RESTORE_DIR/redis"/*.rdb /opt/planetplant/data/redis/ 2>/dev/null || \
            echo "Warning: Could not restore Redis data"
    fi
    
    # 4. Restore Docker volumes (for full backups only)
    if [ -d "$RESTORE_DIR/docker-volumes" ]; then
        echo "Restoring Docker volumes..."
        for volume_backup in "$RESTORE_DIR/docker-volumes"/*.tar.gz; do
            if [ -f "$volume_backup" ]; then
                local volume_name=$(basename "$volume_backup" .tar.gz)
                echo "Restoring volume: $volume_name"
                
                # Create volume if it doesn't exist
                docker volume create "$volume_name" 2>/dev/null || true
                
                # Restore volume data
                docker run --rm \
                    -v "$volume_name:/volume" \
                    -v "$RESTORE_DIR/docker-volumes:/backup:ro" \
                    alpine \
                    sh -c "cd /volume && tar -xzf /backup/${volume_name}.tar.gz" 2>/dev/null || \
                    echo "Warning: Could not restore volume $volume_name"
            fi
        done
    fi
    
    echo "✅ Component restore completed"
}

# Function to start services
start_services() {
    echo -e "${YELLOW}🚀 Starting PlanetPlant services...${NC}"
    
    cd /opt/planetplant
    
    # Start main stack
    if docker compose up -d; then
        echo "✅ Main services started"
    else
        echo -e "${RED}❌ Failed to start main services${NC}"
        return 1
    fi
    
    # Wait for health checks
    echo "⏳ Waiting for services to become healthy..."
    sleep 30
    
    # Check service health
    local health_check_failed=false
    
    # Check backend health
    if ! curl -f -s http://localhost:3001/api/health > /dev/null; then
        echo -e "${RED}❌ Backend health check failed${NC}"
        health_check_failed=true
    else
        echo "✅ Backend is healthy"
    fi
    
    # Check InfluxDB
    if ! curl -f -s http://localhost:8086/ping > /dev/null; then
        echo -e "${RED}❌ InfluxDB health check failed${NC}"
        health_check_failed=true
    else
        echo "✅ InfluxDB is healthy"
    fi
    
    # Check frontend via nginx
    if ! curl -f -s http://localhost/health > /dev/null; then
        echo -e "${RED}❌ Frontend health check failed${NC}"
        health_check_failed=true
    else
        echo "✅ Frontend is healthy"
    fi
    
    if [ "$health_check_failed" = true ]; then
        echo -e "${RED}❌ Some services failed health checks${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ All services are healthy${NC}"
}

# Function to verify restore
verify_restore() {
    echo -e "${YELLOW}🔍 Verifying restore integrity...${NC}"
    
    local verification_failed=false
    
    # Check if key files exist
    local required_files=(
        "/opt/planetplant/.env"
        "/opt/planetplant/docker-compose.yml"
        "/opt/planetplant/config/mosquitto/mosquitto.conf"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            echo -e "${RED}❌ Missing required file: $file${NC}"
            verification_failed=true
        fi
    done
    
    # Check if databases have data
    local influx_check
    influx_check=$(curl -s -H "Authorization: Token ${INFLUXDB_TOKEN:-plantplant-super-secret-auth-token}" \
        "http://localhost:8086/api/v2/query?org=${INFLUXDB_ORG:-planetplant}" \
        -d 'query=buckets() |> yield()' 2>/dev/null | jq '.tables | length' 2>/dev/null || echo "0")
    
    if [ "$influx_check" -eq "0" ]; then
        echo -e "${YELLOW}⚠️ InfluxDB appears to have no data${NC}"
    else
        echo "✅ InfluxDB has data"
    fi
    
    # Check Redis
    if docker exec planetplant-redis redis-cli ping 2>/dev/null | grep -q PONG; then
        echo "✅ Redis is responding"
    else
        echo -e "${RED}❌ Redis is not responding${NC}"
        verification_failed=true
    fi
    
    if [ "$verification_failed" = true ]; then
        echo -e "${RED}❌ Restore verification failed${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Restore verification passed${NC}"
        return 0
    fi
}

# Function to rollback on failure
rollback_restore() {
    echo -e "${YELLOW}🔄 Rolling back failed restore...${NC}"
    
    # Stop current services
    cd /opt/planetplant
    docker compose down || true
    
    # Restore from pre-restore backup if available
    if [ -d "$CURRENT_BACKUP_DIR" ] && [ -n "$(ls -A "$CURRENT_BACKUP_DIR" 2>/dev/null)" ]; then
        echo "Restoring from pre-restore backup..."
        
        # This is a simplified rollback - in practice might need more sophisticated logic
        echo -e "${YELLOW}⚠️ Automatic rollback not fully implemented${NC}"
        echo "Manual intervention required:"
        echo "1. Check pre-restore backup in: $CURRENT_BACKUP_DIR"
        echo "2. Manually restore critical files"
        echo "3. Restart services: cd /opt/planetplant && docker compose up -d"
    else
        echo -e "${RED}❌ No pre-restore backup available for rollback${NC}"
        echo "Manual recovery required"
    fi
    
    exit 1
}

# Main restore process
main() {
    # Check if running as root (required for file operations)
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ This script must be run as root${NC}"
        echo "Usage: sudo $0 [snapshot_id]"
        exit 1
    fi
    
    # Set up Restic environment
    export RESTIC_REPOSITORY
    export RESTIC_PASSWORD
    export RESTIC_CACHE_DIR="/opt/planetplant/backup/cache"
    
    # Check if snapshot ID provided as argument
    local snapshot_id="${1:-}"
    
    if [ -z "$snapshot_id" ]; then
        list_snapshots
        snapshot_id=$(select_snapshot)
    fi
    
    # Confirm restore operation
    echo ""
    echo -e "${YELLOW}⚠️ WARNING: This will restore PlanetPlant from backup${NC}"
    echo "Selected snapshot: $snapshot_id"
    echo "Current data will be backed up before restore"
    echo ""
    read -p "Continue with restore? (type 'yes' to confirm): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        echo "Restore cancelled"
        exit 0
    fi
    
    # Create temporary directory
    mkdir -p "$RESTORE_DIR"
    trap 'rm -rf "$RESTORE_DIR"' EXIT
    
    # Execute restore steps
    local restore_success=true
    local start_time=$(date +%s)
    
    echo -e "${YELLOW}1/6 Creating pre-restore backup...${NC}"
    if ! create_pre_restore_backup; then
        echo -e "${YELLOW}⚠️ Pre-restore backup failed, but continuing...${NC}"
    fi
    
    echo -e "${YELLOW}2/6 Stopping services...${NC}"
    if ! stop_services; then
        restore_success=false
    fi
    
    echo -e "${YELLOW}3/6 Restoring from snapshot...${NC}"
    if ! restore_snapshot "$snapshot_id"; then
        restore_success=false
    fi
    
    echo -e "${YELLOW}4/6 Starting services...${NC}"
    if ! start_services; then
        restore_success=false
    fi
    
    echo -e "${YELLOW}5/6 Verifying restore...${NC}"
    if ! verify_restore; then
        restore_success=false
    fi
    
    echo -e "${YELLOW}6/6 Final health check...${NC}"
    sleep 10
    if ! curl -f -s http://localhost:3001/api/health > /dev/null; then
        echo -e "${RED}❌ Final health check failed${NC}"
        restore_success=false
    else
        echo "✅ Final health check passed"
    fi
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Handle restore result
    if [ "$restore_success" = true ]; then
        echo ""
        echo -e "${GREEN}🎉 Restore completed successfully!${NC}"
        echo ""
        echo "📊 Restore Summary:"
        echo "   Snapshot: $snapshot_id"
        echo "   Duration: ${duration}s"
        echo "   Status: ✅ Success"
        echo "   Timestamp: $(date)"
        echo ""
        echo -e "${BLUE}🔧 Next Steps:${NC}"
        echo "   1. Verify your plant data: http://localhost"
        echo "   2. Check system status: curl http://localhost:3001/api/health"
        echo "   3. Monitor logs: docker compose logs -f"
        echo "   4. Clean up pre-restore backup when confident: rm -rf $CURRENT_BACKUP_DIR"
        
    else
        echo ""
        echo -e "${RED}❌ Restore failed or verification issues detected!${NC}"
        echo ""
        
        read -p "Attempt automatic rollback? (y/N): " attempt_rollback
        if [ "$attempt_rollback" = "y" ]; then
            rollback_restore
        else
            echo -e "${YELLOW}⚠️ Manual intervention required${NC}"
            echo ""
            echo "🔧 Recovery Options:"
            echo "   1. Check service logs: docker compose logs"
            echo "   2. Retry restore: $0 $snapshot_id"
            echo "   3. Use pre-restore backup: $CURRENT_BACKUP_DIR"
            echo "   4. Contact support with restore logs"
            exit 1
        fi
    fi
}

# Function to list restore options (non-interactive mode)
list_restore_options() {
    echo -e "${BLUE}🔍 Restore Options${NC}"
    echo ""
    
    echo "Usage:"
    echo "   $0                    # Interactive snapshot selection"
    echo "   $0 <snapshot_id>      # Restore specific snapshot"
    echo "   $0 --list            # List available snapshots"
    echo "   $0 --latest          # Restore latest snapshot"
    echo ""
    
    if [ "$1" = "--list" ]; then
        list_snapshots
        exit 0
    elif [ "$1" = "--latest" ]; then
        export RESTIC_REPOSITORY
        export RESTIC_PASSWORD
        local latest_snapshot
        latest_snapshot=$(restic snapshots --json | jq -r '.[-1].short_id')
        if [ "$latest_snapshot" = "null" ]; then
            echo -e "${RED}❌ No snapshots found${NC}"
            exit 1
        fi
        echo "Latest snapshot: $latest_snapshot"
        main "$latest_snapshot"
    else
        echo -e "${RED}❌ Invalid option: $1${NC}"
        exit 1
    fi
}

# Check command line arguments
case "${1:-}" in
    --help|-h)
        list_restore_options "--help"
        ;;
    --list)
        list_restore_options "--list"
        ;;
    --latest)
        list_restore_options "--latest"
        ;;
    "")
        main
        ;;
    *)
        # Assume it's a snapshot ID
        main "$1"
        ;;
esac