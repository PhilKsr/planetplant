#!/bin/bash
# Daily backup script for Restic container
# Runs inside Restic container via cron

set -euo pipefail

echo "$(date): Starting daily backup..." >> /logs/backup.log

# Execute main backup script
/scripts/backup-all.sh daily >> /logs/backup.log 2>&1

# Log completion
echo "$(date): Daily backup completed" >> /logs/backup.log