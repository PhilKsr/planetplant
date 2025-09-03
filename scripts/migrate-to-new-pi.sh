#!/bin/bash
# PlanetPlant Pi Migration Script
# Migrates complete PlanetPlant installation to new Raspberry Pi hardware

set -euo pipefail

# Configuration
NEW_PI_IP="${1:-}"
BACKUP_SOURCE="${2:-latest}"
MIGRATION_DIR="/tmp/planetplant_migration"
OLD_PI_IP="${OLD_PI_IP:-localhost}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔄 PlanetPlant Pi Migration${NC}"
echo "=========================="
echo ""

if [ -z "$NEW_PI_IP" ]; then
    echo "Usage: $0 <new-pi-ip> [backup-source]"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.100 latest      # Migrate to new Pi with latest backup"
    echo "  $0 192.168.1.100 abc123def   # Migrate with specific snapshot"
    echo ""
    echo "Prerequisites:"
    echo "  1. New Pi with fresh Raspberry Pi OS"
    echo "  2. SSH access configured (ssh-copy-id)"
    echo "  3. Docker and Docker Compose installed on new Pi"
    echo "  4. Network connectivity between old and new Pi"
    exit 1
fi

echo "Migration Configuration:"
echo "  🎯 Target Pi: $NEW_PI_IP"
echo "  📦 Backup source: $BACKUP_SOURCE"
echo "  📂 Old Pi: $OLD_PI_IP"
echo ""

# Function to log with timestamp
log() {
    echo -e "${BLUE}$(date '+%H:%M:%S')${NC} $1"
}

# Function to run command on new Pi
remote_exec() {
    ssh "pi@$NEW_PI_IP" "$1"
}

# Function to check SSH connectivity
check_ssh_connectivity() {
    log "🔗 Testing SSH connectivity to new Pi..."
    
    if ! ssh -o ConnectTimeout=10 "pi@$NEW_PI_IP" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        echo -e "${RED}❌ Cannot connect to new Pi via SSH${NC}"
        echo ""
        echo "Setup SSH access:"
        echo "  1. ssh-copy-id pi@$NEW_PI_IP"
        echo "  2. Test: ssh pi@$NEW_PI_IP"
        exit 1
    fi
    
    log "✅ SSH connectivity verified"
}

# Function to prepare new Pi
prepare_new_pi() {
    log "🔧 Preparing new Pi environment..."
    
    # Update system
    remote_exec "sudo apt update && sudo apt upgrade -y"
    
    # Install required packages
    remote_exec "sudo apt install -y docker.io docker-compose git curl wget jq htop"
    
    # Add pi user to docker group
    remote_exec "sudo usermod -aG docker pi"
    
    # Create directory structure
    remote_exec "sudo mkdir -p /opt/planetplant/{data,config,logs,backup,scripts}"
    remote_exec "sudo chown -R pi:pi /opt/planetplant"
    
    # Install additional tools
    remote_exec "curl -sSL https://get.docker.com | sh || true"
    
    log "✅ New Pi environment prepared"
}

# Function to transfer system files
transfer_system_files() {
    log "📁 Transferring system files..."
    
    # Transfer entire PlanetPlant directory
    rsync -avz --progress /opt/planetplant/ "pi@$NEW_PI_IP:/opt/planetplant/" \
        --exclude 'data/influxdb/*' \
        --exclude 'data/redis/*' \
        --exclude 'logs/*' \
        --exclude 'backup/data/*'
    
    # Transfer scripts
    rsync -avz --progress /home/pi/PlanetPlant/ "pi@$NEW_PI_IP:/home/pi/PlanetPlant/" \
        --exclude 'raspberry-pi/data/*' \
        --exclude 'raspberry-pi/logs/*' \
        --exclude 'webapp/node_modules/' \
        --exclude 'webapp/dist/'
    
    log "✅ System files transferred"
}

# Function to restore data from backup
restore_data_on_new_pi() {
    log "📦 Restoring data on new Pi..."
    
    # Load backup environment
    if [ -f "/opt/planetplant/backup/.env" ]; then
        source /opt/planetplant/backup/.env
    fi
    
    # Transfer backup repository if needed
    if [ "$BACKUP_SOURCE" = "latest" ] || [ ${#BACKUP_SOURCE} -eq 8 ]; then
        log "Transferring backup repository..."
        rsync -avz --progress "$RESTIC_REPOSITORY/" "pi@$NEW_PI_IP:/opt/planetplant/backups/restic-repo/"
        
        # Restore on new Pi
        remote_exec "cd /opt/planetplant && sudo ./scripts/restore-backup.sh $BACKUP_SOURCE"
    else
        log "Manual data restore required for backup source: $BACKUP_SOURCE"
    fi
}

# Function to update configuration for new environment
update_configuration() {
    log "⚙️ Updating configuration for new Pi..."
    
    # Update IP addresses in configuration files
    remote_exec "sed -i 's/$OLD_PI_IP/$NEW_PI_IP/g' /opt/planetplant/.env 2>/dev/null || true"
    
    # Update monitoring URLs
    remote_exec "find /opt/planetplant -name '*.yml' -o -name '*.json' | xargs sed -i 's/$OLD_PI_IP/$NEW_PI_IP/g' 2>/dev/null || true"
    
    # Update MQTT client configuration if needed
    remote_exec "sed -i 's/MQTT_HOST=.*/MQTT_HOST=mosquitto/g' /opt/planetplant/.env 2>/dev/null || true"
    
    log "✅ Configuration updated"
}

# Function to verify migration
verify_migration() {
    log "🔍 Verifying migration..."
    
    local verification_failed=false
    
    # Check if services are running
    if ! remote_exec "docker ps | grep planetplant-backend"; then
        log "❌ Backend not running on new Pi"
        verification_failed=true
    fi
    
    # Check health endpoints
    if ! remote_exec "curl -f -s http://localhost:3001/api/health > /dev/null"; then
        log "❌ Backend health check failed"
        verification_failed=true
    fi
    
    # Check database
    if ! remote_exec "curl -f -s http://localhost:8086/ping > /dev/null"; then
        log "❌ Database health check failed"  
        verification_failed=true
    fi
    
    # Check frontend
    if ! remote_exec "curl -f -s http://localhost/health > /dev/null"; then
        log "❌ Frontend health check failed"
        verification_failed=true
    else
        log "✅ Frontend accessible"
    fi
    
    if [ "$verification_failed" = true ]; then
        log "❌ Migration verification failed"
        return 1
    else
        log "✅ Migration verification passed"
        return 0
    fi
}

# Function to update DNS/networking
update_networking() {
    log "🌐 Updating networking configuration..."
    
    echo ""
    echo -e "${YELLOW}📡 Network Configuration Updates Needed:${NC}"
    echo ""
    echo "Manual steps required:"
    echo "  1. Update router DHCP reservation: $OLD_PI_IP → $NEW_PI_IP"
    echo "  2. Update firewall rules if applicable"
    echo "  3. Update monitoring external URLs"
    echo "  4. Update ESP32 device configuration:"
    echo "     - Connect to ESP32 WiFi setup"
    echo "     - Update MQTT broker IP: $OLD_PI_IP → $NEW_PI_IP"
    echo "  5. Update any external services pointing to old IP"
    echo ""
    
    read -p "Press Enter when network updates are completed..."
}

# Function to finalize migration
finalize_migration() {
    log "🎯 Finalizing migration..."
    
    # Create migration report
    local report_file="/opt/planetplant/migration-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
PlanetPlant Migration Report
===========================
Date: $(date)
Source Pi: $OLD_PI_IP
Target Pi: $NEW_PI_IP  
Backup Source: $BACKUP_SOURCE

Migration Steps Completed:
✅ SSH connectivity verified
✅ New Pi environment prepared  
✅ System files transferred
✅ Data restored from backup
✅ Configuration updated
✅ Services verified
✅ Migration completed

Next Steps:
1. Update ESP32 devices with new IP: $NEW_PI_IP
2. Update external monitoring/DNS
3. Test end-to-end functionality
4. Decommission old Pi: $OLD_PI_IP
5. Update documentation with new IP addresses

New Pi Access:
- Frontend: http://$NEW_PI_IP
- Backend API: http://$NEW_PI_IP:3001/api
- Grafana: http://$NEW_PI_IP:3001
- Portainer: http://$NEW_PI_IP:9000

Migration completed successfully!
EOF

    # Transfer report to new Pi
    scp "$report_file" "pi@$NEW_PI_IP:/opt/planetplant/"
    
    log "✅ Migration report created: $report_file"
}

# Main migration procedure
main() {
    local start_time=$(date +%s)
    
    echo -e "${YELLOW}🚀 Starting Pi migration procedure...${NC}"
    
    # Step 1: Verify connectivity
    check_ssh_connectivity
    
    # Step 2: Prepare new Pi
    prepare_new_pi
    
    # Step 3: Transfer system files  
    transfer_system_files
    
    # Step 4: Restore data
    restore_data_on_new_pi
    
    # Step 5: Update configuration
    update_configuration
    
    # Step 6: Start services on new Pi
    log "🚀 Starting services on new Pi..."
    remote_exec "cd /opt/planetplant && docker compose up -d"
    
    # Wait for startup
    sleep 45
    
    # Step 7: Verify migration
    if verify_migration; then
        local end_time=$(date +%s)
        local duration=$(((end_time - start_time) / 60))
        
        echo ""
        echo -e "${GREEN}🎉 MIGRATION COMPLETED SUCCESSFULLY${NC}"
        echo ""
        echo "📊 Migration Summary:"
        echo "   Duration: ${duration} minutes"
        echo "   Source: $OLD_PI_IP"
        echo "   Target: $NEW_PI_IP"
        echo "   Backup: $BACKUP_SOURCE"
        echo ""
        echo -e "${BLUE}🔗 New Pi Access:${NC}"
        echo "   Frontend: http://$NEW_PI_IP"
        echo "   Backend: http://$NEW_PI_IP:3001/api/health"
        echo "   Grafana: http://$NEW_PI_IP:3001"
        echo "   Portainer: http://$NEW_PI_IP:9000"
        echo ""
        
        # Step 8: Update networking
        update_networking
        
        # Step 9: Finalize
        finalize_migration
        
        echo -e "${GREEN}✅ Migration finalized successfully!${NC}"
        
    else
        echo -e "${RED}❌ Migration verification failed${NC}"
        echo ""
        echo "🔧 Troubleshooting steps:"
        echo "  1. Check new Pi logs: ssh pi@$NEW_PI_IP 'cd /opt/planetplant && docker compose logs'"
        echo "  2. Check resource usage: ssh pi@$NEW_PI_IP 'docker stats --no-stream'"
        echo "  3. Manual service restart: ssh pi@$NEW_PI_IP 'cd /opt/planetplant && docker compose restart'"
        echo "  4. Contact technical support"
        exit 1
    fi
}

# Execute migration
main