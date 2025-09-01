#!/bin/bash
# PlanetPlant Raspberry Pi 5 Setup Script
# This script prepares a fresh Raspberry Pi 5 for PlanetPlant production deployment

set -euo pipefail

echo "🍓 PlanetPlant Raspberry Pi 5 Setup"
echo "===================================="

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo "⚠️  Warning: This script is designed for Raspberry Pi hardware"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Docker and Docker Compose
echo "🐳 Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
fi

if ! command -v docker-compose &> /dev/null; then
    echo "🐳 Installing Docker Compose..."
    sudo apt install -y docker-compose-plugin
fi

# Install Node.js and npm (for local development)
echo "📦 Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# Install Git (if not present)
if ! command -v git &> /dev/null; then
    echo "📦 Installing Git..."
    sudo apt install -y git
fi

# Create application directories
echo "📁 Creating application directories..."
sudo mkdir -p /opt/planetplant/{influxdb-data,influxdb-config,mosquitto-data,mosquitto-logs,grafana-data,redis-data}
sudo chown -R $USER:$USER /opt/planetplant
chmod -R 755 /opt/planetplant

# Set up log rotation
echo "📝 Setting up log rotation..."
sudo tee /etc/logrotate.d/planetplant > /dev/null <<EOF
/opt/planetplant/*/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 $USER $USER
    postrotate
        docker-compose restart backend 2>/dev/null || true
    endscript
}
EOF

# Install Tailscale for secure remote access (optional)
read -p "🔐 Install Tailscale for secure remote access? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! command -v tailscale &> /dev/null; then
        echo "🔐 Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh
        echo "ℹ️  Run 'sudo tailscale up' to connect this Pi to your Tailscale network"
    fi
fi

# Configure firewall (UFW)
echo "🔥 Configuring firewall..."
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw allow 1883/tcp # MQTT
sudo ufw allow 3000/tcp # Backend API
sudo ufw allow 3001/tcp # Grafana
sudo ufw allow 8086/tcp # InfluxDB

# Optimize for Raspberry Pi 5
echo "⚡ Optimizing system for PlanetPlant..."

# Enable container features
echo "📝 Enabling container features..."
if ! grep -q "cgroup_enable=memory" /boot/cmdline.txt; then
    sudo sed -i 's/$/ cgroup_enable=memory cgroup_memory=1/' /boot/cmdline.txt
fi

# Increase vm.max_map_count for containers
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Set timezone to UTC (recommended for IoT systems)
sudo timedatectl set-timezone UTC

# Create systemd service for PlanetPlant (optional)
read -p "🚀 Create systemd service for auto-start? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo tee /etc/systemd/system/planetplant.service > /dev/null <<EOF
[Unit]
Description=PlanetPlant IoT Plant Watering System
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable planetplant.service
fi

echo ""
echo "✅ Raspberry Pi 5 setup completed!"
echo ""
echo "🚀 Next steps:"
echo "1. Copy .env.example to .env and configure your settings"
echo "2. Run 'make prod' to start the production environment"
echo "3. Access the dashboard at http://$(hostname -I | awk '{print $1}')"
echo "4. Configure your ESP32 devices to connect to this Pi"
echo ""
echo "📚 For more information, see README.md"