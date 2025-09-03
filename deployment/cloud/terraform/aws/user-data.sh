#!/bin/bash
# AWS EC2 User Data Script for PlanetPlant Installation

set -euo pipefail

# Variables from Terraform
DOMAIN_NAME="${domain_name}"
INFLUXDB_PASSWORD="${influxdb_password}"
INFLUXDB_TOKEN="${influxdb_token}"
REDIS_PASSWORD="${redis_password}"
JWT_SECRET="${jwt_secret}"
GRAFANA_PASSWORD="${grafana_password}"
BACKUP_BUCKET="${backup_bucket}"
AWS_REGION="${aws_region}"
SLACK_WEBHOOK="${slack_webhook}"

# System setup
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
usermod -aG docker ubuntu

# Install Docker Compose v2
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install Restic for backups
RESTIC_VERSION="0.16.0"
wget "https://github.com/restic/restic/releases/download/v$RESTIC_VERSION/restic_${RESTIC_VERSION}_linux_amd64.bz2"
bunzip2 "restic_${RESTIC_VERSION}_linux_amd64.bz2"
mv "restic_${RESTIC_VERSION}_linux_amd64" /usr/local/bin/restic
chmod +x /usr/local/bin/restic

# Create application directories
mkdir -p /opt/planetplant/{data,config,logs,backup,scripts}
chown -R ubuntu:ubuntu /opt/planetplant

# Clone application repository
cd /opt/planetplant
git clone https://github.com/your-org/planetplant.git .
chown -R ubuntu:ubuntu /opt/planetplant

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

# AWS Configuration
AWS_REGION=$AWS_REGION
AWS_S3_BACKUP_BUCKET=$BACKUP_BUCKET

# Application Configuration
DOMAIN_NAME=$DOMAIN_NAME
CLOUD_PROVIDER=aws

# Notifications
SLACK_WEBHOOK=$SLACK_WEBHOOK
EOF

# Set secure permissions
chown ubuntu:ubuntu /opt/planetplant/.env
chmod 600 /opt/planetplant/.env

# Create backup configuration
mkdir -p /opt/planetplant/backup
cat > /opt/planetplant/backup/.env << EOF
RESTIC_REPOSITORY=s3:s3.amazonaws.com/$BACKUP_BUCKET/restic
RESTIC_PASSWORD=$JWT_SECRET
AWS_ACCESS_KEY_ID=\$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/planetplant-role | jq -r '.AccessKeyId')
AWS_SECRET_ACCESS_KEY=\$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/planetplant-role | jq -r '.SecretAccessKey')
AWS_SESSION_TOKEN=\$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/planetplant-role | jq -r '.Token')
AWS_DEFAULT_REGION=$AWS_REGION
BACKUP_SCHEDULE=0 2 * * *
BACKUP_RETENTION=30d
SLACK_WEBHOOK=$SLACK_WEBHOOK
INFLUXDB_ORG=planetplant
INFLUXDB_TOKEN=$INFLUXDB_TOKEN
EOF

# Initialize Restic repository
cd /opt/planetplant
export RESTIC_REPOSITORY="s3:s3.amazonaws.com/$BACKUP_BUCKET/restic"
export RESTIC_PASSWORD="$JWT_SECRET"
restic init || echo "Repository already exists"

# Setup systemd services
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
ExecStart=/usr/local/bin/docker-compose -f deployment/cloud/docker-compose.aws.yml up -d
ExecStop=/usr/local/bin/docker-compose -f deployment/cloud/docker-compose.aws.yml down
TimeoutStartSec=300
User=ubuntu
Group=ubuntu
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Setup backup cron job
cat > /etc/cron.d/planetplant-backup << EOF
# PlanetPlant automated backups
0 2 * * * ubuntu /opt/planetplant/scripts/backup-all.sh automated >> /opt/planetplant/logs/backup.log 2>&1
0 5 * * 0 ubuntu /opt/planetplant/scripts/test-restore-procedure.sh weekly >> /opt/planetplant/logs/restore-test.log 2>&1
0 6 1 * * ubuntu /opt/planetplant/scripts/test-restore-procedure.sh monthly >> /opt/planetplant/logs/restore-test.log 2>&1
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
        /usr/bin/docker exec planetplant-backend-aws pkill -SIGUSR1 node 2>/dev/null || true
    endscript
}
EOF

# Enable and start services
systemctl daemon-reload
systemctl enable planetplant.service
systemctl start planetplant.service

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/opt/planetplant/logs/app.log",
                        "log_group_name": "/planetplant/${environment}",
                        "log_stream_name": "application",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/opt/planetplant/logs/backup.log",
                        "log_group_name": "/planetplant/${environment}",
                        "log_stream_name": "backup",
                        "timezone": "UTC"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "PlanetPlant",
        "metrics_collected": {
            "cpu": {
                "measurement": ["cpu_usage_idle", "cpu_usage_iowait"],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": ["used_percent"],
                "metrics_collection_interval": 60,
                "resources": ["*"]
            },
            "mem": {
                "measurement": ["mem_used_percent"],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Setup health check endpoint
cat > /opt/planetplant/health-check.sh << EOF
#!/bin/bash
# Simple health check for load balancer

# Check if main services are running
if ! docker ps | grep -q "planetplant-backend-aws"; then
    exit 1
fi

if ! curl -f -s http://localhost:3001/api/health > /dev/null; then
    exit 1
fi

if ! curl -f -s http://localhost:8086/ping > /dev/null; then
    exit 1
fi

exit 0
EOF

chmod +x /opt/planetplant/health-check.sh

# Create health check service for nginx
mkdir -p /opt/planetplant/config/nginx
cat > /opt/planetplant/config/nginx/health.conf << EOF
server {
    listen 80;
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
    }
}
EOF

# Final message
echo "PlanetPlant AWS installation completed at $(date)" > /opt/planetplant/installation.log
echo "Application starting up - allow 2-3 minutes for full initialization" >> /opt/planetplant/installation.log