#!/bin/bash
# PlanetPlant Restore Script
# Restores system from backup archive

set -euo pipefail

echo "📦 PlanetPlant Restore Script"
echo "============================="

# Check if backup file is provided
if [ $# -eq 0 ]; then
    echo "❌ Error: No backup file specified"
    echo "Usage: $0 <backup-file.tar.gz>"
    echo ""
    echo "Available backups:"
    ls -lah /opt/planetplant/backups/planetplant_backup_*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Validate backup file
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Error: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Restore Details:${NC}"
echo "   Backup file: $BACKUP_FILE"
echo "   File size: $(du -h "$BACKUP_FILE" | cut -f1)"
echo "   Date: $(date)"

# Warning about data loss
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will overwrite existing data!${NC}"
read -p "Continue with restore? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

# Stop services
echo -e "\n${BLUE}🛑 Stopping PlanetPlant services...${NC}"
docker-compose down 2>/dev/null || true

# Create temporary extraction directory
TEMP_DIR=$(mktemp -d)
echo -e "${BLUE}📁 Extracting backup to: $TEMP_DIR${NC}"

# Extract backup
cd "$TEMP_DIR"
tar -xzf "$BACKUP_FILE"

# Find the backup directory
BACKUP_DIR=$(find . -maxdepth 1 -type d -name "planetplant_backup_*" | head -1)
if [ -z "$BACKUP_DIR" ]; then
    echo -e "${RED}❌ Error: Invalid backup file format${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${BLUE}📂 Backup directory found: $BACKUP_DIR${NC}"

# Function to restore directory
restore_directory() {
    local source="$BACKUP_DIR/$1"
    local dest="$2"
    local desc="$3"
    
    if [ -d "$source" ]; then
        echo -e "${BLUE}📁 Restoring $desc...${NC}"
        sudo mkdir -p "$(dirname "$dest")"
        sudo rm -rf "$dest"
        sudo cp -r "$source" "$dest"
        sudo chown -R $USER:$USER "$dest"
        echo -e "${GREEN}✅ $desc restored${NC}"
    else
        echo -e "${YELLOW}⚠️  $desc not found in backup, skipping${NC}"
    fi
}

# Function to restore file
restore_file() {
    local source="$BACKUP_DIR/$1"
    local dest="$2"
    local desc="$3"
    
    if [ -f "$source" ]; then
        echo -e "${BLUE}📄 Restoring $desc...${NC}"
        sudo mkdir -p "$(dirname "$dest")"
        sudo cp "$source" "$dest"
        sudo chown $USER:$USER "$dest"
        echo -e "${GREEN}✅ $desc restored${NC}"
    else
        echo -e "${YELLOW}⚠️  $desc not found in backup, skipping${NC}"
    fi
}

# Restore application data
echo -e "\n${BLUE}💾 Restoring application data...${NC}"
restore_directory "influxdb-data" "/opt/planetplant/influxdb-data" "InfluxDB data"
restore_directory "influxdb-config" "/opt/planetplant/influxdb-config" "InfluxDB config"
restore_directory "mosquitto-data" "/opt/planetplant/mosquitto-data" "Mosquitto data"
restore_directory "mosquitto-logs" "/opt/planetplant/mosquitto-logs" "Mosquitto logs"
restore_directory "grafana-data" "/opt/planetplant/grafana-data" "Grafana data"
restore_directory "redis-data" "/opt/planetplant/redis-data" "Redis data"

# Restore configuration
echo -e "\n${BLUE}⚙️  Restoring configuration...${NC}"
restore_directory "config" "$(pwd)/config" "Application config"
restore_file ".env" "$(pwd)/.env" "Environment variables"
restore_file "docker-compose.yml" "$(pwd)/docker-compose.yml" "Docker Compose config"
restore_file "Makefile" "$(pwd)/Makefile" "Makefile"

# Restore logs
echo -e "\n${BLUE}📝 Restoring logs...${NC}"
restore_directory "raspberry-pi-logs" "$(pwd)/raspberry-pi/logs" "Application logs"

# Cleanup
rm -rf "$TEMP_DIR"

# Set proper permissions
echo -e "\n${BLUE}🔐 Setting proper permissions...${NC}"
sudo chown -R $USER:$USER /opt/planetplant
chmod -R 755 /opt/planetplant

# Show backup info if available
if [ -f "$BACKUP_DIR/backup-info.txt" ]; then
    echo -e "\n${BLUE}📋 Backup Information:${NC}"
    cat "$BACKUP_DIR/backup-info.txt" | head -10
fi

echo ""
echo "=================================="
echo -e "${GREEN}✅ Restore completed successfully!${NC}"
echo ""
echo -e "${BLUE}🚀 Next steps:${NC}"
echo "1. Review the restored .env file for correct settings"
echo "2. Run 'make prod' to start the services"
echo "3. Run 'make test' to verify everything is working"
echo ""
echo -e "${YELLOW}ℹ️  Note: You may need to restart the system if Docker volumes were restored${NC}"