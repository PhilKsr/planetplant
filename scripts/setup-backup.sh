#!/bin/bash
# PlanetPlant Backup System Setup Script
# Configures automated encrypted backups with cloud storage

set -euo pipefail

# Configuration
BACKUP_DIR="/opt/planetplant/backup"
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-admin@planetplant.local}"
CLOUD_PROVIDER="${CLOUD_PROVIDER:-s3}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}💾 PlanetPlant Backup System Setup${NC}"
echo "=================================="
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

# Create backup directory structure
echo -e "${YELLOW}📁 Setting up backup directories...${NC}"
sudo mkdir -p "$BACKUP_DIR"/{data,config,cache,logs,scripts}
sudo mkdir -p "$BACKUP_DIR/data"/{restic,monitoring}
sudo chown -R "$USER":"$USER" "$BACKUP_DIR"

# Copy deployment files
echo -e "${YELLOW}📋 Copying deployment files...${NC}"
cp -r deployment/backup/* "$BACKUP_DIR/"

# Interactive configuration setup
echo -e "${YELLOW}⚙️ Configuring backup system...${NC}"
echo ""

# Generate secure password if not provided
if [ -z "${RESTIC_PASSWORD:-}" ]; then
    RESTIC_PASSWORD=$(openssl rand -base64 32)
    echo "Generated secure encryption password"
fi

echo "Backup configuration:"
echo "  📧 Notification email: $NOTIFICATION_EMAIL"
echo "  ☁️ Cloud provider: $CLOUD_PROVIDER"
echo ""

# Configure cloud storage
configure_cloud_storage() {
    local provider="$1"
    
    case $provider in
        "s3")
            echo -e "${BLUE}🪣 Configuring AWS S3 / MinIO...${NC}"
            read -p "S3 Access Key ID: " S3_ACCESS_KEY
            read -s -p "S3 Secret Access Key: " S3_SECRET_KEY
            echo ""
            read -p "S3 Region [eu-central-1]: " S3_REGION
            S3_REGION=${S3_REGION:-eu-central-1}
            read -p "S3 Endpoint (leave empty for AWS): " S3_ENDPOINT
            read -p "S3 Bucket name [planetplant-backups]: " S3_BUCKET
            S3_BUCKET=${S3_BUCKET:-planetplant-backups}
            ;;
        "gdrive")
            echo -e "${BLUE}💾 Configuring Google Drive...${NC}"
            echo "Google Drive setup requires OAuth setup."
            echo "Visit: https://rclone.org/drive/ for instructions"
            read -p "Google Drive Client ID: " GDRIVE_CLIENT_ID
            read -s -p "Google Drive Client Secret: " GDRIVE_CLIENT_SECRET
            echo ""
            echo "OAuth token setup will be completed during first sync"
            ;;
        "b2")
            echo -e "${BLUE}☁️ Configuring Backblaze B2...${NC}"
            read -p "B2 Account ID: " B2_ACCOUNT_ID
            read -s -p "B2 Application Key: " B2_APPLICATION_KEY
            echo ""
            read -p "B2 Bucket name [planetplant-backups]: " B2_BUCKET
            B2_BUCKET=${B2_BUCKET:-planetplant-backups}
            ;;
    esac
}

# Ask about cloud storage
read -p "Enable cloud storage backup? (y/N): " enable_cloud
if [ "$enable_cloud" = "y" ] || [ "$enable_cloud" = "Y" ]; then
    CLOUD_UPLOAD_ENABLED="true"
    
    echo ""
    echo "Available cloud providers:"
    echo "  1) AWS S3 / MinIO"
    echo "  2) Google Drive"  
    echo "  3) Backblaze B2"
    echo ""
    read -p "Select provider [1]: " provider_choice
    provider_choice=${provider_choice:-1}
    
    case $provider_choice in
        1) CLOUD_PROVIDER="s3"; configure_cloud_storage "s3" ;;
        2) CLOUD_PROVIDER="gdrive"; configure_cloud_storage "gdrive" ;;
        3) CLOUD_PROVIDER="b2"; configure_cloud_storage "b2" ;;
        *) echo "Invalid choice, using S3"; CLOUD_PROVIDER="s3"; configure_cloud_storage "s3" ;;
    esac
else
    CLOUD_UPLOAD_ENABLED="false"
fi

# Create environment file
echo -e "${YELLOW}📝 Creating environment configuration...${NC}"
cat > "$BACKUP_DIR/.env" << EOF
# PlanetPlant Backup Configuration
# Generated on $(date)

# Restic Configuration
RESTIC_REPOSITORY=/backups/restic-repo
RESTIC_PASSWORD=$RESTIC_PASSWORD

# Retention Policy
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=12
KEEP_YEARLY=2

# Cloud Configuration
CLOUD_UPLOAD_ENABLED=$CLOUD_UPLOAD_ENABLED
CLOUD_PROVIDER=$CLOUD_PROVIDER
CLOUD_RETENTION_DAYS=30

# Notification Configuration
NOTIFICATION_EMAIL=$NOTIFICATION_EMAIL
SLACK_WEBHOOK=${SLACK_WEBHOOK:-}

# SMTP Configuration
SMTP_SERVER=${SMTP_SERVER:-smtp.gmail.com}
SMTP_PORT=${SMTP_PORT:-587}
SMTP_USER=${SMTP_USER:-}
SMTP_PASSWORD=${SMTP_PASSWORD:-}

# Performance Settings
PARALLEL_TRANSFERS=4
MAX_TRANSFER_RATE=10M

EOF

# Add cloud-specific configuration
if [ "$CLOUD_UPLOAD_ENABLED" = "true" ]; then
    case $CLOUD_PROVIDER in
        "s3")
            cat >> "$BACKUP_DIR/.env" << EOF

# S3 Configuration
S3_ACCESS_KEY=${S3_ACCESS_KEY:-}
S3_SECRET_KEY=${S3_SECRET_KEY:-}
S3_REGION=${S3_REGION:-eu-central-1}
S3_ENDPOINT=${S3_ENDPOINT:-}
S3_BUCKET=${S3_BUCKET:-planetplant-backups}
EOF
            ;;
        "gdrive")
            cat >> "$BACKUP_DIR/.env" << EOF

# Google Drive Configuration
GDRIVE_CLIENT_ID=${GDRIVE_CLIENT_ID:-}
GDRIVE_CLIENT_SECRET=${GDRIVE_CLIENT_SECRET:-}
GDRIVE_TOKEN=${GDRIVE_TOKEN:-}
EOF
            ;;
        "b2")
            cat >> "$BACKUP_DIR/.env" << EOF

# Backblaze B2 Configuration  
B2_ACCOUNT_ID=${B2_ACCOUNT_ID:-}
B2_APPLICATION_KEY=${B2_APPLICATION_KEY:-}
B2_BUCKET=${B2_BUCKET:-planetplant-backups}
EOF
            ;;
    esac
fi

echo "✅ Environment configuration created"

# Start backup system
echo -e "${YELLOW}🚀 Starting backup system...${NC}"
cd "$BACKUP_DIR"
docker compose up -d

# Initialize Restic repository
echo -e "${YELLOW}🔧 Initializing Restic repository...${NC}"
sleep 10

# Initialize repository if needed
docker exec planetplant-restic-backup restic snapshots || \
docker exec planetplant-restic-backup restic init || {
    echo -e "${RED}❌ Failed to initialize backup repository${NC}"
    exit 1
}

echo "✅ Backup repository initialized"

# Test backup functionality
echo -e "${YELLOW}🧪 Testing backup functionality...${NC}"
if /opt/planetplant/scripts/backup-all.sh manual; then
    echo "✅ Test backup completed successfully"
else
    echo -e "${YELLOW}⚠️ Test backup failed, but setup completed${NC}"
fi

# Setup cron jobs for host system (fallback)
echo -e "${YELLOW}⏰ Setting up backup schedules...${NC}"

# Create cron jobs
CRON_DAILY="0 2 * * * /opt/planetplant/scripts/backup-all.sh daily >> /opt/planetplant/backup/logs/cron.log 2>&1"
CRON_WEEKLY="0 3 * * 0 /opt/planetplant/scripts/backup-all.sh weekly >> /opt/planetplant/backup/logs/cron.log 2>&1"
CRON_MONTHLY="0 4 1 * * /opt/planetplant/scripts/backup-all.sh monthly >> /opt/planetplant/backup/logs/cron.log 2>&1"

# Add to crontab (avoiding duplicates)
(crontab -l 2>/dev/null | grep -v backup-all.sh; echo "$CRON_DAILY"; echo "$CRON_WEEKLY"; echo "$CRON_MONTHLY") | crontab -

echo "✅ Backup schedules configured"

# Final status check
echo -e "${YELLOW}🔍 Performing final health check...${NC}"
sleep 5

if curl -f -s http://localhost:3008/health > /dev/null; then
    echo "✅ Backup monitor is healthy"
else
    echo -e "${YELLOW}⚠️ Backup monitor health check failed${NC}"
fi

# Final summary
echo ""
echo -e "${GREEN}🎉 Backup system setup completed successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Configuration Summary:${NC}"
echo "   💾 Repository: $BACKUP_DIR/data/restic"
echo "   🔐 Encryption: AES-256 (password protected)"
echo "   ☁️ Cloud upload: $CLOUD_UPLOAD_ENABLED ($CLOUD_PROVIDER)"
echo "   📧 Notifications: $NOTIFICATION_EMAIL"
echo ""
echo -e "${BLUE}📅 Backup Schedule:${NC}"
echo "   🌅 Daily: 02:00 (configs + databases)"
echo "   📅 Weekly: 03:00 Sunday (full backup + verification)"
echo "   📊 Monthly: 04:00 first day (archive + cloud sync)"
echo ""
echo -e "${BLUE}🔧 Management Commands:${NC}"
echo "   Manual backup: /opt/planetplant/scripts/backup-all.sh manual"
echo "   List snapshots: restic -r $BACKUP_DIR/data/restic snapshots"
echo "   Restore: sudo /opt/planetplant/scripts/restore-backup.sh"
echo "   Monitor: http://localhost:3008/api/status"
echo ""
echo -e "${BLUE}🎯 Next Steps:${NC}"
echo "   1. Test restore procedure: sudo /opt/planetplant/scripts/restore-backup.sh --list"
echo "   2. Configure cloud storage credentials if enabled"
echo "   3. Set up monitoring alerts for backup failures"
echo "   4. Document recovery procedures for your team"