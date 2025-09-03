#!/bin/bash
# DigitalOcean Droplet User Data Script for PlanetPlant Installation

set -euo pipefail

# Variables from Terraform
DOMAIN_NAME="${domain_name}"
INFLUXDB_PASSWORD="${influxdb_password}"
INFLUXDB_TOKEN="${influxdb_token}"
REDIS_PASSWORD="${redis_password}"
JWT_SECRET="${jwt_secret}"
GRAFANA_PASSWORD="${grafana_password}"
SPACES_KEY="${spaces_key}"
SPACES_SECRET="${spaces_secret}"
SPACES_ENDPOINT="${spaces_endpoint}"
SPACES_BUCKET="${spaces_bucket}"
DO_REGION="${do_region}"
SLACK_WEBHOOK="${slack_webhook}"

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    curl \
    wget \
    git \
    htop \
    jq \
    unzip \
    fail2ban \
    ufw \
    docker.io \
    docker-compose

# Configure firewall
ufw --force enable
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 1883  # MQTT
ufw allow 9001  # MQTT WebSocket

# Setup docker
systemctl enable docker
systemctl start docker
usermod -aG docker root

# Install Docker Compose v2
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install doctl (DigitalOcean CLI)
wget https://github.com/digitalocean/doctl/releases/latest/download/doctl-linux-amd64.tar.gz
tar xf doctl-linux-amd64.tar.gz
mv doctl /usr/local/bin

# Install Restic for backups
RESTIC_VERSION="0.16.0"
wget "https://github.com/restic/restic/releases/download/v$RESTIC_VERSION/restic_${RESTIC_VERSION}_linux_amd64.bz2"
bunzip2 "restic_${RESTIC_VERSION}_linux_amd64.bz2"
mv "restic_${RESTIC_VERSION}_linux_amd64" /usr/local/bin/restic
chmod +x /usr/local/bin/restic

# Create application directories
mkdir -p /opt/planetplant/{data,config,logs,backup,scripts}

# Clone application repository
cd /opt/planetplant
git clone https://github.com/your-org/planetplant.git .

# Create environment file
cat > /opt/planetplant/.env << EOF
NODE_ENV=production
PORT=3001

# Database Configuration
INFLUXDB_URL=http://influxdb:8086
INFLUXDB_USERNAME=admin
INFLUXDB_PASSWORD=$INFLUXDB_PASSWORD
INFLUXDB_TOKEN=$INFLUXDB_TOKEN
INFLUXDB_ORG=planetplant
INFLUXDB_BUCKET=sensor-data

# Redis Configuration
REDIS_URL=redis://redis:6379
REDIS_PASSWORD=$REDIS_PASSWORD

# MQTT Configuration
MQTT_HOST=mosquitto
MQTT_PORT=1883
MQTT_USERNAME=planetplant
MQTT_PASSWORD=$REDIS_PASSWORD

# Authentication
JWT_SECRET=$JWT_SECRET

# Monitoring
GRAFANA_PASSWORD=$GRAFANA_PASSWORD

# DigitalOcean Configuration
DO_REGION=$DO_REGION
DO_SPACES_KEY=$SPACES_KEY
DO_SPACES_SECRET=$SPACES_SECRET
DO_SPACES_ENDPOINT=$SPACES_ENDPOINT
DO_SPACES_BUCKET=$SPACES_BUCKET

# Application Configuration
DOMAIN_NAME=$DOMAIN_NAME
CLOUD_PROVIDER=digitalocean

# Notifications
SLACK_WEBHOOK=$SLACK_WEBHOOK
EOF

# Set secure permissions
chmod 600 /opt/planetplant/.env

# Create backup configuration
mkdir -p /opt/planetplant/backup
cat > /opt/planetplant/backup/.env << EOF
RESTIC_REPOSITORY=s3:$SPACES_ENDPOINT/$SPACES_BUCKET/restic
RESTIC_PASSWORD=$JWT_SECRET
AWS_ACCESS_KEY_ID=$SPACES_KEY
AWS_SECRET_ACCESS_KEY=$SPACES_SECRET
BACKUP_SCHEDULE=0 2 * * *
BACKUP_RETENTION=30d
SLACK_WEBHOOK=$SLACK_WEBHOOK
INFLUXDB_ORG=planetplant
INFLUXDB_TOKEN=$INFLUXDB_TOKEN
EOF

# Initialize Restic repository
cd /opt/planetplant
export RESTIC_REPOSITORY="s3:$SPACES_ENDPOINT/$SPACES_BUCKET/restic"
export RESTIC_PASSWORD="$JWT_SECRET"
export AWS_ACCESS_KEY_ID="$SPACES_KEY"
export AWS_SECRET_ACCESS_KEY="$SPACES_SECRET"
restic init || echo "Repository already exists"

# Setup systemd service
cat > /etc/systemd/system/planetplant.service << EOF
[Unit]
Description=PlanetPlant Application
Requires=docker.service
After=docker.service
StartLimitBurst=3
StartLimitInterval=60s

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/planetplant
ExecStart=/usr/local/bin/docker-compose -f deployment/cloud/docker-compose.digitalocean.yml up -d
ExecStop=/usr/local/bin/docker-compose -f deployment/cloud/docker-compose.digitalocean.yml down
TimeoutStartSec=300
User=root
Group=root
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Setup backup cron job
cat > /etc/cron.d/planetplant-backup << EOF
# PlanetPlant automated backups
0 2 * * * root /opt/planetplant/scripts/backup-all.sh automated >> /opt/planetplant/logs/backup.log 2>&1
0 5 * * 0 root /opt/planetplant/scripts/test-restore-procedure.sh weekly >> /opt/planetplant/logs/restore-test.log 2>&1
0 6 1 * * root /opt/planetplant/scripts/test-restore-procedure.sh monthly >> /opt/planetplant/logs/restore-test.log 2>&1
EOF

# Setup log rotation
cat > /etc/logrotate.d/planetplant << EOF
/opt/planetplant/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        /usr/bin/docker exec planetplant-backend-do pkill -SIGUSR1 node 2>/dev/null || true
    endscript
}
EOF

# Setup monitoring agent
wget https://repos.insights.digitalocean.com/install.sh
bash install.sh

# Configure monitoring
cat > /etc/do-agent/config.yaml << EOF
api:
  endpoint: https://insights.nyc1.digitalocean.com/
tags:
  - planetplant
  - $environment
log_level: info
EOF

# Enable and start services
systemctl daemon-reload
systemctl enable planetplant.service
systemctl start planetplant.service
systemctl restart do-agent

# Setup SSL certificate (Let's Encrypt)
apt-get install -y certbot
mkdir -p /opt/planetplant/ssl

# Create health check endpoint for load balancer
mkdir -p /opt/planetplant/config/nginx
cat > /opt/planetplant/config/nginx/health.conf << EOF
server {
    listen 80 default_server;
    server_name _;
    
    location /health {
        access_log off;
        add_header Content-Type text/plain;
        return 200 "healthy\n";
    }
    
    location / {
        proxy_pass http://backend:3001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Port \$server_port;
    }
}
EOF

# Mount additional volume if specified
if [ -b /dev/disk/by-id/scsi-0DO_Volume_planetplant-data* ]; then
    VOLUME_DEVICE=$(ls /dev/disk/by-id/scsi-0DO_Volume_planetplant-data*)
    mkfs.ext4 -F "$VOLUME_DEVICE"
    mkdir -p /opt/planetplant/data
    mount "$VOLUME_DEVICE" /opt/planetplant/data
    echo "$VOLUME_DEVICE /opt/planetplant/data ext4 defaults,nofail,discard 0 2" >> /etc/fstab
fi

# Final setup
chown -R root:root /opt/planetplant
chmod +x /opt/planetplant/scripts/*.sh

# Final message
echo "PlanetPlant DigitalOcean installation completed at $(date)" > /opt/planetplant/installation.log
echo "Application starting up - allow 2-3 minutes for full initialization" >> /opt/planetplant/installation.log

# Send completion notification
if [ -n "$SLACK_WEBHOOK" ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"🌱 PlanetPlant deployed successfully on DigitalOcean '"$DO_REGION"'"}' \
        "$SLACK_WEBHOOK" || true
fi