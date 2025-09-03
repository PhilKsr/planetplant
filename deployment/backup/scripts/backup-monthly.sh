#!/bin/bash
# Monthly backup script for Restic container
# Runs inside Restic container via cron

set -euo pipefail

echo "$(date): Starting monthly backup..." >> /logs/backup.log

# Execute main backup script with full verification and cloud upload
CLOUD_UPLOAD_ENABLED=true /scripts/backup-all.sh monthly >> /logs/backup.log 2>&1

# Log completion  
echo "$(date): Monthly backup completed" >> /logs/backup.log