#!/bin/bash
# PlanetPlant Backup Status Check Script
# Shows backup status, recent snapshots, and health information

set -euo pipefail

# Load environment
if [ -f "/opt/planetplant/backup/.env" ]; then
    source /opt/planetplant/backup/.env
fi

RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-/opt/planetplant/backups/restic-repo}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-planetplant-backup-encryption-key}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📊 PlanetPlant Backup Status${NC}"
echo "============================="
echo ""

# Export Restic environment
export RESTIC_REPOSITORY
export RESTIC_PASSWORD

# Function to format bytes
format_bytes() {
    local bytes=$1
    local sizes=('B' 'KB' 'MB' 'GB' 'TB')
    local i=0
    
    while [ $bytes -ge 1024 ] && [ $i -lt 4 ]; do
        bytes=$((bytes / 1024))
        i=$((i + 1))
    done
    
    echo "${bytes}${sizes[$i]}"
}

# Check if repository exists
if [ ! -d "$RESTIC_REPOSITORY" ]; then
    echo -e "${RED}❌ Backup repository not found: $RESTIC_REPOSITORY${NC}"
    echo ""
    echo -e "${BLUE}🔧 Setup Instructions:${NC}"
    echo "   Run: /opt/planetplant/scripts/setup-backup.sh"
    exit 1
fi

# Repository statistics
echo -e "${BLUE}📊 Repository Statistics${NC}"
echo "Repository: $RESTIC_REPOSITORY"
echo ""

if restic stats --mode raw-data > /tmp/restic_stats 2>/dev/null; then
    local repo_size=$(cat /tmp/restic_stats | grep "Total Size:" | awk '{print $3 $4}')
    local file_count=$(cat /tmp/restic_stats | grep "Total File Count:" | awk '{print $4}')
    
    echo "Total Size: ${repo_size:-Unknown}"
    echo "File Count: ${file_count:-Unknown}"
else
    echo -e "${YELLOW}⚠️ Could not retrieve repository statistics${NC}"
fi

echo ""

# Recent snapshots
echo -e "${BLUE}📋 Recent Snapshots (Last 10)${NC}"
echo ""

if restic snapshots --compact | tail -11 | head -10; then
    echo ""
else
    echo -e "${YELLOW}⚠️ Could not retrieve snapshots${NC}"
fi

# Backup schedule status
echo -e "${BLUE}⏰ Backup Schedule Status${NC}"
echo ""

# Check cron jobs
echo "Configured schedules:"
crontab -l 2>/dev/null | grep backup-all.sh | while read -r job; do
    local schedule=$(echo "$job" | cut -d' ' -f1-5)
    local type=$(echo "$job" | grep -o 'backup-all.sh [a-z]*' | cut -d' ' -f2)
    echo "  📅 $type: $schedule"
done

echo ""

# Check Docker containers
echo -e "${BLUE}🐳 Backup Services Status${NC}"
echo ""

local containers=("planetplant-restic-backup" "planetplant-rclone-sync" "planetplant-backup-monitor")

for container in "${containers[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^$container$"; then
        local status=$(docker inspect "$container" --format '{{.State.Status}}')
        local health=$(docker inspect "$container" --format '{{.State.Health.Status}}' 2>/dev/null || echo "no healthcheck")
        echo "  ✅ $container: $status ($health)"
    else
        echo "  ❌ $container: not running"
    fi
done

echo ""

# Last backup status
echo -e "${BLUE}📝 Last Backup Status${NC}"
echo ""

if [ -f "/opt/planetplant/backup/logs/backup.log" ]; then
    echo "Recent backup log entries:"
    tail -5 /opt/planetplant/backup/logs/backup.log | while read -r line; do
        if echo "$line" | grep -q "SUCCESS"; then
            echo -e "  ${GREEN}✅ $line${NC}"
        elif echo "$line" | grep -q "FAILED\|ERROR"; then
            echo -e "  ${RED}❌ $line${NC}"
        elif echo "$line" | grep -q "WARNING"; then
            echo -e "  ${YELLOW}⚠️ $line${NC}"
        else
            echo "  ℹ️ $line"
        fi
    done
else
    echo "No backup log found - backups may not have run yet"
fi

echo ""

# Cloud sync status
if [ "${CLOUD_UPLOAD_ENABLED:-false}" = "true" ]; then
    echo -e "${BLUE}☁️ Cloud Sync Status${NC}"
    echo ""
    
    if [ -f "/opt/planetplant/backup/logs/rclone.log" ]; then
        echo "Recent cloud sync log:"
        tail -3 /opt/planetplant/backup/logs/rclone.log
    else
        echo "No cloud sync log found"
    fi
    
    echo ""
fi

# Next scheduled backups
echo -e "${BLUE}⏭️ Next Scheduled Backups${NC}"
echo ""

# Calculate next run times based on cron
local now=$(date +%s)
local tomorrow_2am=$(date -d "tomorrow 02:00" +%s)
local next_sunday_3am=$(date -d "next sunday 03:00" +%s)
local next_month_4am=$(date -d "next month first day 04:00" +%s)

echo "  🌅 Next Daily: $(date -d @$tomorrow_2am)"
echo "  📅 Next Weekly: $(date -d @$next_sunday_3am)"
echo "  📊 Next Monthly: $(date -d @$next_month_4am)"

echo ""

# Quick actions
echo -e "${BLUE}🔧 Quick Actions${NC}"
echo ""
echo "Available commands:"
echo "  📦 Manual backup: /opt/planetplant/scripts/backup-all.sh manual"
echo "  🔍 List snapshots: restic -r $RESTIC_REPOSITORY snapshots"
echo "  🔄 Restore backup: sudo /opt/planetplant/scripts/restore-backup.sh"
echo "  📊 Backup monitor: curl http://localhost:3008/api/status"
echo "  🧹 Cleanup old backups: restic -r $RESTIC_REPOSITORY prune"
echo ""

# Disk space check
echo -e "${BLUE}💽 Storage Status${NC}"
echo ""
local backup_size=$(du -sh "$RESTIC_REPOSITORY" 2>/dev/null | cut -f1 || echo "Unknown")
local available_space=$(df -h /opt/planetplant | tail -1 | awk '{print $4}')
echo "  📦 Backup repository size: $backup_size"
echo "  💾 Available disk space: $available_space"

echo ""
echo -e "${GREEN}✅ Backup status check completed${NC}"