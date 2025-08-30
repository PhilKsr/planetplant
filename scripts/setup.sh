#!/bin/bash

# PlanetPlant Setup Script
# Automated setup for Raspberry Pi Zero 2 W

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/home/pi/PlanetPlant"
NODE_VERSION="18"
DOCKER_COMPOSE_VERSION="2.21.0"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Please run as pi user."
        exit 1
    fi
}

check_internet() {
    log_info "Checking internet connection..."
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "No internet connection. Please check your network settings."
        exit 1
    fi
    log_success "Internet connection OK"
}

update_system() {
    log_info "Updating system packages..."
    sudo apt update -y
    sudo apt upgrade -y
    log_success "System updated"
}

install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker is already installed"
    else
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        log_success "Docker installed"
    fi

    if command -v docker-compose &> /dev/null; then
        log_info "Docker Compose is already installed"
    else
        log_info "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose installed"
    fi
}

install_nodejs() {
    if command -v node &> /dev/null; then
        current_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ $current_version -ge $NODE_VERSION ]]; then
            log_info "Node.js $current_version is already installed"
            return
        fi
    fi

    log_info "Installing Node.js ${NODE_VERSION}..."
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
    sudo apt-get install -y nodejs
    log_success "Node.js $(node --version) installed"
}

install_system_dependencies() {
    log_info "Installing system dependencies..."
    sudo apt install -y \
        git \
        curl \
        wget \
        vim \
        htop \
        mosquitto-clients \
        python3-pip \
        build-essential \
        cmake \
        pkg-config \
        libjpeg-dev \
        libpng-dev \
        libtiff-dev \
        libavcodec-dev \
        libavformat-dev \
        libswscale-dev \
        libv4l-dev \
        libgtk-3-dev \
        libcairo2-dev \
        libgdk-pixbuf2.0-dev \
        libpango1.0-dev \
        libatk1.0-dev \
        libglib2.0-dev
    
    log_success "System dependencies installed"
}

setup_project_structure() {
    log_info "Setting up project structure..."
    
    if [ ! -d "$PROJECT_DIR" ]; then
        mkdir -p "$PROJECT_DIR"
    fi
    
    cd "$PROJECT_DIR"
    
    # Create necessary directories
    mkdir -p {raspberry-pi/{src,config,logs},esp32/src,webapp/{src,public},docs,config,scripts}
    
    log_success "Project structure created"
}

install_npm_dependencies() {
    log_info "Installing Node.js dependencies..."
    
    # Install Raspberry Pi server dependencies
    if [ -f "$PROJECT_DIR/raspberry-pi/package.json" ]; then
        cd "$PROJECT_DIR/raspberry-pi"
        npm install
        log_success "Raspberry Pi server dependencies installed"
    fi
    
    # Install webapp dependencies
    if [ -f "$PROJECT_DIR/webapp/package.json" ]; then
        cd "$PROJECT_DIR/webapp"
        npm install
        log_success "Web app dependencies installed"
    fi
}

setup_docker_services() {
    log_info "Setting up Docker services..."
    cd "$PROJECT_DIR"
    
    if [ -f "docker-compose.yml" ]; then
        # Create necessary directories for volumes
        mkdir -p docker-volumes/{influxdb-storage,influxdb-config,mosquitto-config,mosquitto-data,mosquitto-logs,grafana-storage,redis-data}
        
        # Start services
        docker-compose up -d influxdb mosquitto redis
        
        log_info "Waiting for services to start..."
        sleep 30
        
        # Check if services are running
        if docker-compose ps | grep -q "Up"; then
            log_success "Docker services are running"
        else
            log_warning "Some Docker services may not be running properly"
        fi
    else
        log_warning "docker-compose.yml not found"
    fi
}

setup_mosquitto_auth() {
    log_info "Setting up Mosquitto authentication..."
    
    # Create mosquitto password file
    docker-compose exec mosquitto mosquitto_passwd -c -b /mosquitto/config/passwd plantplant plantplant123
    
    # Restart mosquitto to apply changes
    docker-compose restart mosquitto
    
    log_success "Mosquitto authentication configured"
}

install_pm2() {
    log_info "Installing PM2 process manager..."
    sudo npm install -g pm2
    pm2 startup
    sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u pi --hp /home/pi
    log_success "PM2 installed and configured"
}

setup_environment_files() {
    log_info "Setting up environment files..."
    
    if [ -f "$PROJECT_DIR/raspberry-pi/.env.example" ]; then
        if [ ! -f "$PROJECT_DIR/raspberry-pi/.env" ]; then
            cp "$PROJECT_DIR/raspberry-pi/.env.example" "$PROJECT_DIR/raspberry-pi/.env"
            log_info "Created .env file from template. Please edit it with your settings."
        else
            log_info ".env file already exists"
        fi
    fi
}

configure_firewall() {
    log_info "Configuring firewall..."
    sudo ufw --force enable
    sudo ufw allow ssh
    sudo ufw allow 3000    # Node.js server
    sudo ufw allow 1883    # MQTT
    sudo ufw allow 8086    # InfluxDB
    sudo ufw allow 6379    # Redis
    sudo ufw allow 3001    # Grafana (if enabled)
    log_success "Firewall configured"
}

setup_systemd_services() {
    log_info "Setting up systemd services..."
    
    # Create systemd service for PlanetPlant server
    sudo tee /etc/systemd/system/planetplant.service > /dev/null <<EOF
[Unit]
Description=PlanetPlant Smart Watering System
After=docker.service
Requires=docker.service

[Service]
Type=exec
User=pi
Group=pi
WorkingDirectory=$PROJECT_DIR/raspberry-pi
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable planetplant.service
    
    log_success "Systemd services configured"
}

cleanup() {
    log_info "Cleaning up temporary files..."
    sudo apt autoremove -y
    sudo apt autoclean
    log_success "Cleanup completed"
}

main() {
    log_info "Starting PlanetPlant setup..."
    
    check_root
    check_internet
    update_system
    install_system_dependencies
    install_docker
    install_nodejs
    install_pm2
    setup_project_structure
    install_npm_dependencies
    setup_environment_files
    setup_docker_services
    setup_mosquitto_auth
    configure_firewall
    setup_systemd_services
    cleanup
    
    log_success "PlanetPlant setup completed!"
    log_info "Next steps:"
    echo "1. Edit $PROJECT_DIR/raspberry-pi/.env with your configuration"
    echo "2. Upload your ESP32 code using PlatformIO"
    echo "3. Start the services: docker-compose up -d"
    echo "4. Start the Node.js server: npm start (in raspberry-pi directory)"
    echo "5. Access the web interface at http://$(hostname -I | cut -d' ' -f1):3000"
    
    log_warning "Please reboot your Raspberry Pi to ensure all changes take effect."
    read -p "Reboot now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo reboot
    fi
}

# Run main function
main "$@"