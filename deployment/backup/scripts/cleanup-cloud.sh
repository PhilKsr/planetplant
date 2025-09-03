#!/bin/bash
# Cloud cleanup script for Rclone container
# Removes old cloud backups based on retention policy

set -euo pipefail

echo "$(date): Starting cloud cleanup..." >> /logs/rclone.log

# Determine cloud target
case "${CLOUD_PROVIDER:-s3}" in
    "s3")
        CLOUD_TARGET="s3:${S3_BUCKET:-planetplant-backups}/$(hostname)"
        ;;
    "gdrive") 
        CLOUD_TARGET="gdrive:PlanetPlant-Backups/$(hostname)"
        ;;
    "b2")
        CLOUD_TARGET="b2:${B2_BUCKET:-planetplant-backups}/$(hostname)"
        ;;
    *)
        echo "$(date): Error: Unknown cloud provider: ${CLOUD_PROVIDER}" >> /logs/rclone.log
        exit 1
        ;;
esac

# Clean up files older than retention period
RETENTION_DAYS="${CLOUD_RETENTION_DAYS:-30}"

rclone delete "$CLOUD_TARGET" \
    --min-age "${RETENTION_DAYS}d" \
    --verbose \
    --log-file /logs/rclone.log

echo "$(date): Cloud cleanup completed - removed files older than ${RETENTION_DAYS} days" >> /logs/rclone.log