#!/bin/bash
# Cloud sync script for Rclone container
# Uploads local backups to configured cloud storage

set -euo pipefail

echo "$(date): Starting cloud sync..." >> /logs/rclone.log

# Determine cloud target based on provider
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

# Sync to cloud with progress logging
rclone sync /backups "$CLOUD_TARGET" \
    --transfers "${PARALLEL_TRANSFERS:-4}" \
    --bwlimit "${MAX_TRANSFER_RATE:-10M}" \
    --exclude '.cache/**' \
    --verbose \
    --log-file /logs/rclone.log

echo "$(date): Cloud sync completed to $CLOUD_TARGET" >> /logs/rclone.log