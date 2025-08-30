#!/bin/bash

# PlanetPlant Deployment Script
# Handles deployment to production environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="/home/pi/PlanetPlant"
BACKUP_DIR="/home/pi/backups/planetplant/pre-deploy"
GIT_REPO="https://github.com/yourusername/PlanetPlant.git"

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

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running as pi user
    if [ "$USER" != "pi" ]; then
        log_error "This script must be run as the 'pi' user"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check internet connection
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        log_error "No internet connection"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

create_pre_deploy_backup() {
    log_info "Creating pre-deployment backup..."
    
    mkdir -p "$BACKUP_DIR"
    BACKUP_NAME="pre_deploy_$(date +%Y%m%d_%H%M%S)"
    
    # Backup current installation
    if [ -d "$PROJECT_DIR" ]; then
        tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" -C "$PROJECT_DIR" . 2>/dev/null || true
        log_success "Pre-deployment backup created: ${BACKUP_NAME}.tar.gz"
    fi
}

stop_services() {
    log_info "Stopping services..."
    
    # Stop systemd service if it exists
    if systemctl is-active --quiet planetplant.service 2>/dev/null; then
        sudo systemctl stop planetplant.service
        log_info "Stopped planetplant.service"
    fi
    
    # Stop PM2 processes
    if command -v pm2 >/dev/null && pm2 list | grep -q "planetplant"; then
        pm2 stop planetplant 2>/dev/null || true
        log_info "Stopped PM2 processes"
    fi
    
    # Stop Docker containers gracefully
    if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
        cd "$PROJECT_DIR"
        docker-compose down
        log_info "Stopped Docker services"
    fi
    
    log_success "Services stopped"
}

pull_latest_code() {
    log_info "Pulling latest code..."
    
    cd "$PROJECT_DIR"
    
    # Stash local changes
    git stash push -m "Pre-deployment stash $(date)"
    
    # Pull latest changes
    git pull origin main
    
    # Show what changed
    log_info "Recent commits:"
    git log --oneline -5
    
    log_success "Code updated"
}

update_dependencies() {
    log_info "Updating dependencies..."
    
    # Update Raspberry Pi server dependencies
    if [ -f "$PROJECT_DIR/raspberry-pi/package.json" ]; then
        cd "$PROJECT_DIR/raspberry-pi"
        npm ci --production
        log_success "Server dependencies updated"
    fi
    
    # Update webapp dependencies and build
    if [ -f "$PROJECT_DIR/webapp/package.json" ]; then
        cd "$PROJECT_DIR/webapp"
        npm ci
        npm run build
        log_success "Web app built"
    fi
}

update_docker_images() {
    log_info "Updating Docker images..."
    
    cd "$PROJECT_DIR"
    
    # Pull latest images
    docker-compose pull
    
    log_success "Docker images updated"
}

migrate_database() {
    log_info "Running database migrations..."
    
    # Start InfluxDB temporarily for migrations
    cd "$PROJECT_DIR"
    docker-compose up -d influxdb
    
    # Wait for InfluxDB to be ready
    sleep 30
    
    # Run any necessary migrations
    if [ -f "$PROJECT_DIR/raspberry-pi/scripts/migrate.js" ]; then
        cd "$PROJECT_DIR/raspberry-pi"
        node scripts/migrate.js
        log_success "Database migrations completed"
    else
        log_info "No migrations to run"
    fi
}

start_services() {
    log_info "Starting services..."
    
    cd "$PROJECT_DIR"
    
    # Start Docker services
    docker-compose up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 30
    
    # Start the main application
    if [ -f "$PROJECT_DIR/raspberry-pi/ecosystem.config.js" ]; then
        cd "$PROJECT_DIR/raspberry-pi"
        pm2 start ecosystem.config.js --env production
    else
        # Fallback to systemd service
        sudo systemctl start planetplant.service
    fi
    
    log_success "Services started"
}

health_check() {
    log_info "Performing health check..."
    
    # Wait for application to start
    sleep 10
    
    # Check if main application is responding
    if curl -f http://localhost:3000/health >/dev/null 2>&1; then
        log_success "Application is healthy"
    else
        log_warning "Application health check failed"
        return 1
    fi
    
    # Check Docker services
    cd "$PROJECT_DIR"
    if docker-compose ps | grep -q "Up"; then
        log_success "Docker services are healthy"
    else
        log_error "Some Docker services are not running"
        return 1
    fi
    
    return 0
}

rollback() {
    log_error "Deployment failed. Initiating rollback..."
    
    # Stop services
    stop_services
    
    # Restore from backup
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/pre_deploy_*.tar.gz | head -1)
    if [ -n "$LATEST_BACKUP" ]; then
        log_info "Restoring from backup: $(basename "$LATEST_BACKUP")"
        
        rm -rf "$PROJECT_DIR"
        mkdir -p "$PROJECT_DIR"
        tar -xzf "$LATEST_BACKUP" -C "$PROJECT_DIR"
        
        # Restart services
        start_services
        
        log_warning "Rollback completed"
    else
        log_error "No backup found for rollback"
    fi
}

cleanup() {
    log_info "Cleaning up..."
    
    # Remove old Docker images
    docker image prune -f
    
    # Remove old backups (keep last 5)
    cd "$BACKUP_DIR"
    ls -t pre_deploy_*.tar.gz | tail -n +6 | xargs -r rm -f
    
    log_success "Cleanup completed"
}

send_deployment_notification() {
    local status=$1
    local version=$2
    
    # Send notification if email is configured
    if [ -f "$PROJECT_DIR/raspberry-pi/.env" ]; then
        source "$PROJECT_DIR/raspberry-pi/.env"
        if [ "$EMAIL_ENABLED" = "true" ] && [ -n "$ALERT_RECIPIENTS" ]; then
            local subject="PlanetPlant Deployment $status"
            local message="Deployment $status at $(date)"
            if [ -n "$version" ]; then
                message="$message\nVersion: $version"
            fi
            echo -e "$message" | mail -s "$subject" "$ALERT_RECIPIENTS" 2>/dev/null || true
        fi
    fi
}

main() {
    log_info "Starting PlanetPlant deployment..."
    
    local start_time=$(date +%s)
    
    # Set up error handling
    trap 'rollback; exit 1' ERR
    
    check_prerequisites
    create_pre_deploy_backup
    stop_services
    pull_latest_code
    update_dependencies
    update_docker_images
    migrate_database
    start_services
    
    # Health check with retry
    local retry_count=0
    local max_retries=3
    
    while [ $retry_count -lt $max_retries ]; do
        if health_check; then
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log_warning "Health check failed, retrying in 10 seconds... ($retry_count/$max_retries)"
                sleep 10
            else
                log_error "Health check failed after $max_retries attempts"
                exit 1
            fi
        fi
    done
    
    cleanup
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Get current version/commit
    cd "$PROJECT_DIR"
    local version=$(git rev-parse --short HEAD)
    
    log_success "Deployment completed successfully!"
    echo
    echo "=== DEPLOYMENT SUMMARY ==="
    echo "Version: $version"
    echo "Duration: ${duration} seconds"
    echo "Time: $(date)"
    echo "=========================="
    
    send_deployment_notification "SUCCESS" "$version"
}

# Show usage if help is requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo
    echo "This script deploys the latest version of PlanetPlant to production."
    echo "It includes:"
    echo "  - Pre-deployment backup"
    echo "  - Service shutdown"
    echo "  - Code update"
    echo "  - Dependency updates"
    echo "  - Database migrations"
    echo "  - Service restart"
    echo "  - Health checks"
    echo "  - Automatic rollback on failure"
    exit 0
fi

# Confirm production deployment
read -p "Deploy to production? This will restart all services. (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Deployment cancelled"
    exit 0
fi

# Run main function
main "$@"