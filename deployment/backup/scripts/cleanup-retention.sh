#!/bin/bash
# Retention policy cleanup script
# Runs inside Restic container via cron

set -euo pipefail

echo "$(date): Starting retention cleanup..." >> /logs/backup.log

# Apply retention policy
restic forget \
    --keep-daily "${KEEP_DAILY:-7}" \
    --keep-weekly "${KEEP_WEEKLY:-4}" \
    --keep-monthly "${KEEP_MONTHLY:-12}" \
    --keep-yearly "${KEEP_YEARLY:-2}" \
    --prune >> /logs/backup.log 2>&1

echo "$(date): Retention cleanup completed" >> /logs/backup.log