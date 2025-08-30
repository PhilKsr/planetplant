#!/bin/bash

# PlanetPlant Raspberry Pi Installation Script
# Installs all dependencies and sets up the environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
NODE_VERSION="18"

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

check_node_version() {
    if command -v node &> /dev/null; then
        current_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ $current_version -ge $NODE_VERSION ]]; then
            log_success "Node.js $current_version is already installed"
            return 0
        else
            log_warning "Node.js version $current_version is too old. Need version $NODE_VERSION+"
            return 1
        fi
    else
        log_info "Node.js is not installed"
        return 1
    fi
}

install_node() {
    log_info "Installing Node.js $NODE_VERSION..."
    
    # For Raspberry Pi, use NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    # Verify installation
    if check_node_version; then
        log_success "Node.js $(node --version) installed successfully"
    else
        log_error "Node.js installation failed"
        exit 1
    fi
}

install_dependencies() {
    log_info "Installing npm dependencies..."
    
    cd "$PROJECT_DIR"
    
    # Clear npm cache
    npm cache clean --force
    
    # Install dependencies
    npm install
    
    # Verify critical packages
    local critical_packages=("express" "mqtt" "@influxdata/influxdb-client" "socket.io" "winston")
    
    for package in "${critical_packages[@]}"; do
        if npm list "$package" &>/dev/null; then
            log_success "✓ $package installed"
        else
            log_error "✗ $package missing"
            exit 1
        fi
    done
    
    log_success "All npm dependencies installed"
}

setup_directories() {
    log_info "Setting up directories..."
    
    local directories=(
        "$PROJECT_DIR/logs"
        "$PROJECT_DIR/data"
        "$PROJECT_DIR/config"
        "$PROJECT_DIR/tmp"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_info "Created directory: $dir"
        fi
    done
    
    # Set correct permissions
    chmod 755 "$PROJECT_DIR/logs"
    chmod 755 "$PROJECT_DIR/data"
    
    log_success "Directories setup completed"
}

setup_environment() {
    log_info "Setting up environment..."
    
    # Copy .env.example to .env if it doesn't exist
    if [[ ! -f "$PROJECT_DIR/.env" ]]; then
        if [[ -f "$PROJECT_DIR/.env.example" ]]; then
            cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
            log_success "Created .env from .env.example"
            log_warning "Please edit $PROJECT_DIR/.env with your configuration"
        else
            log_warning ".env.example file not found"
        fi
    else
        log_info ".env file already exists"
    fi
}

install_pm2() {
    if command -v pm2 &> /dev/null; then
        log_success "PM2 is already installed"
    else
        log_info "Installing PM2 globally..."
        sudo npm install -g pm2
        
        # Setup PM2 startup script
        pm2 startup | tail -n 1 | sudo bash
        
        log_success "PM2 installed and configured"
    fi
}

test_installation() {
    log_info "Testing installation..."
    
    cd "$PROJECT_DIR"
    
    # Check if we can require main modules
    node -e "
        const express = require('express');
        const mqtt = require('mqtt');
        const { InfluxDB } = require('@influxdata/influxdb-client');
        const { Server } = require('socket.io');
        const winston = require('winston');
        console.log('✓ All critical modules can be loaded');
    " || {
        log_error "Module loading test failed"
        exit 1
    }
    
    # Test syntax
    if node --check src/app.js 2>/dev/null; then
        log_success "✓ Main application syntax check passed"
    else
        log_error "✗ Main application syntax check failed"
        exit 1
    fi
    
    log_success "Installation test passed"
}

setup_service_account() {
    log_info "Setting up service account permissions..."
    
    # Add pi user to necessary groups
    sudo usermod -a -G dialout,gpio,i2c,spi,audio,video pi
    
    # Set up GPIO permissions for hardware access
    if [[ -f /etc/udev/rules.d/99-gpio.rules ]]; then
        log_info "GPIO rules already configured"
    else
        sudo tee /etc/udev/rules.d/99-gpio.rules > /dev/null <<EOF
KERNEL=="gpiomem", GROUP="gpio", MODE="0664"
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'chown -R root:gpio /sys/class/gpio && chmod -R 775 /sys/class/gpio; chown -R root:gpio /sys/devices/virtual/gpio && chmod -R 775 /sys/devices/virtual/gpio'"
EOF
        log_success "GPIO rules configured"
    fi
}

check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check available memory
    local available_memory=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [[ $available_memory -lt 100 ]]; then
        log_warning "Low available memory: ${available_memory}MB (recommend 100MB+)"
    else
        log_success "Available memory: ${available_memory}MB"
    fi
    
    # Check disk space
    local available_space=$(df "$PROJECT_DIR" | awk 'NR==2 {print int($4/1024)}')
    if [[ $available_space -lt 500 ]]; then
        log_warning "Low disk space: ${available_space}MB (recommend 500MB+)"
    else
        log_success "Available disk space: ${available_space}MB"
    fi
    
    # Check if running on Raspberry Pi
    if [[ -f /proc/device-tree/model ]]; then
        local model=$(cat /proc/device-tree/model)
        log_info "Detected device: $model"
    fi
}

show_next_steps() {
    echo
    echo "=============================================="
    echo "🎉 PlanetPlant Backend Installation Complete!"
    echo "=============================================="
    echo
    echo "Next steps:"
    echo "1. Edit environment configuration:"
    echo "   nano $PROJECT_DIR/.env"
    echo
    echo "2. Start Docker services:"
    echo "   cd $(dirname "$PROJECT_DIR") && docker-compose up -d"
    echo
    echo "3. Start the application:"
    echo "   cd $PROJECT_DIR && npm start"
    echo
    echo "4. Or start with PM2:"
    echo "   cd $PROJECT_DIR && pm2 start ecosystem.config.js"
    echo
    echo "5. Check application status:"
    echo "   curl http://localhost:3000/health"
    echo
    echo "6. View logs:"
    echo "   pm2 logs planetplant-server"
    echo "   # or"
    echo "   tail -f $PROJECT_DIR/logs/plantplant-$(date +%Y-%m-%d).log"
    echo
    echo "Configuration files to review:"
    echo "- $PROJECT_DIR/.env (main configuration)"
    echo "- $(dirname "$PROJECT_DIR")/docker-compose.yml (services)"
    echo "- $PROJECT_DIR/ecosystem.config.js (PM2 configuration)"
    echo
    echo "API Documentation will be available at:"
    echo "http://localhost:3000/ (once started)"
    echo
}

main() {
    log_info "Starting PlanetPlant Backend installation..."
    
    check_system_requirements
    
    if ! check_node_version; then
        install_node
    fi
    
    setup_directories
    setup_environment
    install_dependencies
    install_pm2
    setup_service_account
    test_installation
    
    show_next_steps
    
    log_success "Installation completed successfully! 🌱"
}

# Handle script arguments
case "${1:-}" in
    -h|--help)
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  -h, --help     Show this help message"
        echo "  --test-only    Only run installation tests"
        echo "  --deps-only    Only install dependencies"
        echo
        echo "This script installs all necessary dependencies for the PlanetPlant backend."
        exit 0
        ;;
    --test-only)
        cd "$PROJECT_DIR"
        test_installation
        exit 0
        ;;
    --deps-only)
        install_dependencies
        exit 0
        ;;
esac

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root"
    log_info "Please run as: ./install.sh"
    exit 1
fi

# Run main installation
main "$@"