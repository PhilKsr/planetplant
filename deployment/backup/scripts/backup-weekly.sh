#!/bin/bash
# Weekly backup script for Restic container
# Runs inside Restic container via cron

set -euo pipefail

echo "$(date): Starting weekly backup..." >> /logs/backup.log

# Execute main backup script with full verification
/scripts/backup-all.sh weekly >> /logs/backup.log 2>&1

# Log completion
echo "$(date): Weekly backup completed" >> /logs/backup.log