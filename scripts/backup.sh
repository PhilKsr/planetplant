#!/bin/bash
# PlanetPlant Backup Script
# Creates comprehensive backup of all data, configuration, and logs

set -euo pipefail

echo "📦 PlanetPlant Backup Script"
echo "============================"

# Configuration
BACKUP_DIR="/opt/planetplant/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="planetplant_backup_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Create backup directory
echo -e "${BLUE}📁 Creating backup directory...${NC}"
sudo mkdir -p "$BACKUP_DIR"
sudo chown -R $USER:$USER "$BACKUP_DIR"

# Create temporary backup staging area
TEMP_DIR=$(mktemp -d)
BACKUP_STAGING="$TEMP_DIR/$BACKUP_NAME"
mkdir -p "$BACKUP_STAGING"

echo -e "${BLUE}📋 Backup Details:${NC}"
echo "   Date: $(date)"
echo "   Name: $BACKUP_NAME"
echo "   Path: $BACKUP_PATH"
echo "   Staging: $BACKUP_STAGING"

# Function to backup directory with error handling
backup_directory() {
    local source="$1"
    local dest_name="$2"
    
    if [ -d "$source" ]; then
        echo -e "${BLUE}📁 Backing up $dest_name...${NC}"
        cp -r "$source" "$BACKUP_STAGING/$dest_name"
        echo -e "${GREEN}✅ $dest_name backed up${NC}"
    else
        echo -e "${YELLOW}⚠️  $source not found, skipping $dest_name${NC}"
    fi
}

# Function to backup file with error handling
backup_file() {
    local source="$1"
    local dest_name="$2"
    
    if [ -f "$source" ]; then
        echo -e "${BLUE}📄 Backing up $dest_name...${NC}"
        cp "$source" "$BACKUP_STAGING/$dest_name"
        echo -e "${GREEN}✅ $dest_name backed up${NC}"
    else
        echo -e "${YELLOW}⚠️  $source not found, skipping $dest_name${NC}"
    fi
}

# Backup application data
echo -e "\n${BLUE}💾 Backing up application data...${NC}"
backup_directory "/opt/planetplant/influxdb-data" "influxdb-data"
backup_directory "/opt/planetplant/influxdb-config" "influxdb-config"
backup_directory "/opt/planetplant/mosquitto-data" "mosquitto-data"
backup_directory "/opt/planetplant/mosquitto-logs" "mosquitto-logs"
backup_directory "/opt/planetplant/grafana-data" "grafana-data"
backup_directory "/opt/planetplant/redis-data" "redis-data"

# Backup application configuration
echo -e "\n${BLUE}⚙️  Backing up configuration...${NC}"
backup_directory "$(pwd)/config" "config"
backup_file "$(pwd)/.env" ".env"
backup_file "$(pwd)/docker-compose.yml" "docker-compose.yml"
backup_file "$(pwd)/Makefile" "Makefile"

# Backup application logs
echo -e "\n${BLUE}📝 Backing up logs...${NC}"
backup_directory "$(pwd)/raspberry-pi/logs" "raspberry-pi-logs"

# Create backup metadata
echo -e "\n${BLUE}📋 Creating backup metadata...${NC}"
cat > "$BACKUP_STAGING/backup-info.txt" <<EOF
PlanetPlant Backup Information
==============================

Backup Date: $(date)
Backup Name: $BACKUP_NAME
System Info: $(uname -a)
Docker Version: $(docker --version 2>/dev/null || echo "Not available")
Git Commit: $(git rev-parse HEAD 2>/dev/null || echo "Not available")
Git Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "Not available")

Backup Contents:
$(find "$BACKUP_STAGING" -type f | sort)

Environment Variables (excluding secrets):
$(env | grep -E '^(NODE_ENV|LOG_LEVEL|INFLUXDB_ORG|INFLUXDB_BUCKET|MQTT_CLIENT_ID)=' || echo "None found")

Docker Services Status:
$(docker-compose ps 2>/dev/null || echo "Docker Compose not running")
EOF

# Create compressed backup
echo -e "\n${BLUE}🗜️  Creating compressed backup...${NC}"
cd "$TEMP_DIR"
tar -czf "$BACKUP_PATH" "$BACKUP_NAME"

# Cleanup staging area
rm -rf "$TEMP_DIR"

# Set proper permissions
chmod 644 "$BACKUP_PATH"

# Backup size
BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)

echo ""
echo "=================================="
echo -e "${GREEN}✅ Backup completed successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Backup Details:${NC}"
echo "   File: $BACKUP_PATH"
echo "   Size: $BACKUP_SIZE"
echo "   Date: $(date)"

# Clean old backups (keep last 10)
echo -e "\n${BLUE}🧹 Cleaning old backups...${NC}"
find "$BACKUP_DIR" -name "planetplant_backup_*.tar.gz" -type f | sort -r | tail -n +11 | xargs rm -f 2>/dev/null || true

echo -e "\n${BLUE}📁 Available backups:${NC}"
ls -lah "$BACKUP_DIR"/planetplant_backup_*.tar.gz 2>/dev/null | tail -5 || echo "No backups found"

echo ""
echo -e "${GREEN}🎉 Backup process completed!${NC}"
echo -e "To restore: ${YELLOW}make restore file=$BACKUP_PATH${NC}"