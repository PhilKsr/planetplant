# PlanetPlant Makefile
# Production-ready commands for Raspberry Pi 5 and development

.DEFAULT_GOAL := help
.PHONY: help up down logs test clean dev prod install status

# Detect Docker Compose command (docker-compose vs docker compose)
DOCKER_COMPOSE := $(shell command -v docker-compose 2>/dev/null || echo "docker compose")

# =============================================================================
# QUICK COMMANDS (Primary Interface)
# =============================================================================

init: ## Initialize directories and config files
	@echo "🔧 Initializing PlanetPlant..."
	@chmod +x scripts/init-volumes.sh
	@./scripts/init-volumes.sh
	@echo "✅ Initialization complete"

up: init ## Start all services (production)
	@echo "🚀 Starting PlanetPlant..."
	$(DOCKER_COMPOSE) up -d
	@echo "⏳ Waiting 30 seconds for services to start..."
	@sleep 30
	@$(MAKE) test

down: ## Stop all services
	@echo "🛑 Stopping PlanetPlant..."
	$(DOCKER_COMPOSE) down
	@echo "✅ All services stopped!"

logs: ## Show logs from all services
	$(DOCKER_COMPOSE) logs -f --tail=50

test: ## Run comprehensive service tests
	@echo "🧪 Running service tests..."
	./scripts/test-services.sh

clean: ## Clean up Docker resources and volumes
	@echo "🧹 Cleaning up Docker resources..."
	$(DOCKER_COMPOSE) down -v
	docker system prune -f
	docker volume prune -f
	docker image prune -f
	docker builder prune -f
	rm -rf data logs
	@echo "✅ Cleanup completed!"

# =============================================================================
# DEVELOPMENT vs STAGING vs PRODUCTION
# =============================================================================

dev: ## Start development environment (Mac/Local)
	@echo "🚀 Starting PlanetPlant development environment..."
	$(DOCKER_COMPOSE) -f docker-compose.dev.yml up --build -d
	@echo "✅ Development environment started!"
	@echo "📊 Backend: http://localhost:3001"
	@echo "🌐 Frontend: Start with 'make frontend-dev'"
	@echo "📈 Grafana: http://localhost:3001 (admin/plantplant123)"

staging: staging-init ## Start staging environment (Testing)
	@echo "🎭 Starting PlanetPlant staging environment..."
	$(DOCKER_COMPOSE) -f docker-compose.staging.yml up --build -d
	@echo "✅ Staging environment started!"
	@echo "🌐 Frontend: http://localhost:8080"
	@echo "📊 Backend API: http://localhost:3002/api"
	@echo "📈 Grafana: http://localhost:3003 (admin/staging123)"
	@echo "🗄️ InfluxDB: http://localhost:8087"

prod: init ## Start production environment (Raspberry Pi 5)
	@echo "🍓 Starting PlanetPlant production environment..."
	$(DOCKER_COMPOSE) up --build -d
	@echo "✅ Production environment started!"
	@echo "🌐 Frontend: http://localhost"
	@echo "📊 Backend API: http://localhost/api"
	@echo "📈 Grafana: http://localhost:3001"

prod-reset: ## Reset production environment (fix database issues)
	@echo "🔄 Resetting production environment..."
	@echo "⚠️ This will delete all InfluxDB data!"
	@read -p "Continue? [y/N]: " confirm && \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		./scripts/fix-influxdb.sh; \
	else \
		echo "❌ Reset cancelled"; \
	fi

dev-down: ## Stop development environment
	$(DOCKER_COMPOSE) -f docker-compose.dev.yml down

staging-down: ## Stop staging environment
	$(DOCKER_COMPOSE) -f docker-compose.staging.yml down

# =============================================================================
# MONITORING & MAINTENANCE
# =============================================================================

monitoring: init ## Start with Grafana monitoring enabled
	@echo "📊 Starting with monitoring..."
	$(DOCKER_COMPOSE) --profile monitoring up --build -d

backup: ## Create system backup
	@echo "📦 Creating backup..."
	./scripts/backup.sh

restore: ## Restore from backup (usage: make restore file=backup.tar.gz)
	@if [ -z "$(file)" ]; then \
		echo "❌ Usage: make restore file=backup_file.tar.gz"; \
		echo "Available backups:"; \
		ls -lah /opt/planetplant/backups/*.tar.gz 2>/dev/null || echo "No backups found"; \
		exit 1; \
	fi
	@echo "📦 Restoring from: $(file)"
	./scripts/restore.sh $(file)

update: ## Update and rebuild all containers
	@echo "🔄 Updating containers..."
	$(DOCKER_COMPOSE) pull
	$(DOCKER_COMPOSE) up --build -d
	@echo "✅ Update completed!"

rebuild: ## Force rebuild all containers
	@echo "🔄 Force rebuilding..."
	$(DOCKER_COMPOSE) down
	$(DOCKER_COMPOSE) build --no-cache
	$(DOCKER_COMPOSE) up -d
	@echo "✅ Rebuild completed!"

# =============================================================================
# SETUP & INSTALLATION
# =============================================================================

setup-pi: ## Initial Raspberry Pi 5 setup
	@echo "🍓 Setting up Raspberry Pi 5..."
	chmod +x scripts/setup-pi.sh
	sudo ./scripts/setup-pi.sh

# setup-dirs removed - now using relative paths with init target

install: ## Install all dependencies
	@echo "📦 Installing dependencies..."
	cd raspberry-pi && npm install
	cd webapp && npm install
	@echo "✅ Dependencies installed!"

# =============================================================================
# DEVELOPMENT COMMANDS
# =============================================================================

frontend-dev: ## Start frontend development server
	@echo "🌐 Starting frontend dev server..."
	cd webapp && npm run dev

frontend-build: ## Build frontend for production
	@echo "🏗️ Building frontend..."
	cd webapp && npm run build

frontend-test: ## Run frontend tests
	@echo "🧪 Running frontend tests..."
	cd webapp && npm run test

backend-dev: ## Start backend development (without Docker)
	@echo "📊 Starting backend dev server..."
	cd raspberry-pi && npm run dev

backend-test: ## Run backend tests
	@echo "🧪 Running backend tests..."
	cd raspberry-pi && npm run test

backend-lint: ## Run backend linting
	@echo "🔍 Linting backend..."
	cd raspberry-pi && npm run lint

lint: ## Run linting for all components
	@echo "🔍 Running linting..."
	cd raspberry-pi && npm run lint
	cd webapp && npm run lint

# =============================================================================
# UTILITY & STATUS
# =============================================================================

status: ## Show detailed status of all services
	@echo "📊 PlanetPlant System Status"
	@echo "============================"
	@echo ""
	@echo "🐳 Docker Services:"
	@$(DOCKER_COMPOSE) ps 2>/dev/null || echo "❌ Production not running"
	@echo ""
	@echo "💻 Development Services:"
	@$(DOCKER_COMPOSE) -f docker-compose.dev.yml ps 2>/dev/null || echo "❌ Development not running"
	@echo ""
	@echo "💾 System Resources:"
	@echo "   Memory: $$(free -h | grep Mem | awk '{print $$3 "/" $$2}')"
	@echo "   Disk: $$(df -h / | tail -1 | awk '{print $$3 "/" $$2 " (" $$5 " used)"}')"
	@echo "   Load: $$(uptime | awk -F'load average:' '{print $$2}')"

health: ## Quick health check
	@echo "💓 Quick Health Check"
	@echo "===================="
	@curl -s http://localhost/health && echo " ✅ Frontend OK" || echo " ❌ Frontend DOWN"
	@curl -s http://localhost:3001/api/system/status > /dev/null && echo " ✅ Backend OK" || echo " ❌ Backend DOWN"
	@curl -s http://localhost:8086/ping > /dev/null && echo " ✅ InfluxDB OK" || echo " ❌ InfluxDB DOWN"
	@curl -s http://localhost:3001/api/health > /dev/null && echo " ✅ Grafana OK" || echo " ❌ Grafana DOWN"

shell: ## Open shell in backend container
	$(DOCKER_COMPOSE) exec backend sh

logs-follow: ## Follow logs from all services with timestamps
	$(DOCKER_COMPOSE) logs -f -t

logs-backend: ## Show backend logs
	$(DOCKER_COMPOSE) logs -f backend

logs-frontend: ## Show frontend logs
	$(DOCKER_COMPOSE) logs -f frontend

logs-influxdb: ## Show InfluxDB logs
	$(DOCKER_COMPOSE) logs -f influxdb

staging-init: ## Initialize staging directories and config
	@echo "🎭 Initializing staging environment..."
	@mkdir -p data/staging/{mosquitto,influxdb,redis,grafana}
	@mkdir -p config/staging/{mosquitto,grafana/provisioning}
	@mkdir -p logs/staging/{mosquitto,backend}
	@chmod -R 755 data/staging config/staging logs/staging
	@if [ ! -f config/staging/mosquitto/mosquitto.conf ]; then \
		echo "📝 Staging MQTT config already exists"; \
	fi
	@echo "✅ Staging initialization complete"

staging-logs: ## Show staging logs
	$(DOCKER_COMPOSE) -f docker-compose.staging.yml logs -f --tail=50

staging-status: ## Show staging status
	@echo "📊 Staging Environment Status"
	@echo "============================"
	@echo ""
	@$(DOCKER_COMPOSE) -f docker-compose.staging.yml ps 2>/dev/null || echo "❌ Staging not running"
	@echo ""
	@echo "🌐 Staging URLs:"
	@echo "   Frontend:  http://localhost:8080"
	@echo "   Backend:   http://localhost:3002/api"
	@echo "   InfluxDB:  http://localhost:8087"
	@echo "   Grafana:   http://localhost:3003"

staging-clean: ## Clean staging environment
	@echo "🧹 Cleaning staging environment..."
	$(DOCKER_COMPOSE) -f docker-compose.staging.yml down -v
	@rm -rf data/staging logs/staging
	@echo "✅ Staging cleanup completed"

staging-health: ## Quick staging health check
	@echo "💓 Staging Health Check"
	@echo "======================"
	@curl -s http://localhost:8080/health && echo " ✅ Frontend OK" || echo " ❌ Frontend DOWN"
	@curl -s http://localhost:3002/api/system/status > /dev/null && echo " ✅ Backend OK" || echo " ❌ Backend DOWN"
	@curl -s http://localhost:8087/ping > /dev/null && echo " ✅ InfluxDB OK" || echo " ❌ InfluxDB DOWN"

promote-to-prod: ## Merge develop to main (promote staging to production)
	@echo "🚀 Promoting staging to production..."
	@echo "This will merge develop branch to main and trigger production deployment"
	@echo ""
	@read -p "Are you sure? This will deploy to production [y/N]: " confirm && \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		git fetch origin && \
		git checkout main && \
		git pull origin main && \
		git merge develop && \
		git push origin main && \
		echo "✅ Promotion completed! Production deployment will start automatically."; \
	else \
		echo "❌ Promotion cancelled"; \
	fi

# =============================================================================
# SECURITY & MAINTENANCE
# =============================================================================

security-scan: ## Run security scan on containers
	@echo "🔐 Running security scan..."
	@command -v trivy >/dev/null 2>&1 || { echo "Install trivy for security scanning"; exit 1; }
	trivy image planetplant-backend:latest
	trivy image planetplant-frontend:latest

update-deps: ## Update dependencies
	@echo "📦 Updating dependencies..."
	cd raspberry-pi && npm update
	cd webapp && npm update

check-deps: ## Check for dependency vulnerabilities
	@echo "🔍 Checking dependencies..."
	cd raspberry-pi && npm audit --audit-level high
	cd webapp && npm audit --audit-level high

# =============================================================================
# HELP & DOCUMENTATION
# =============================================================================

help: ## Show this help message
	@echo -e "${CYAN}${BOLD}🌱 PlanetPlant - Smart IoT Plant Watering System${NC}"
	@echo ""
	@echo -e "${BOLD}Quick Start:${NC}"
	@echo -e "  ${GREEN}make up${NC}          Start production system"
	@echo -e "  ${GREEN}make dev${NC}         Start development system"
	@echo -e "  ${GREEN}make test${NC}        Test all services"
	@echo -e "  ${GREEN}make logs${NC}        View logs"
	@echo -e "  ${GREEN}make down${NC}        Stop all services"
	@echo ""
	@echo -e "${BOLD}Available commands:${NC}"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo -e "${BOLD}Environment:${NC}"
	@echo -e "  🍓 ${YELLOW}Production (Pi 5):${NC}     make prod"
	@echo -e "  🎭 ${YELLOW}Staging (Testing):${NC}     make staging"
	@echo -e "  💻 ${YELLOW}Development (Mac):${NC}     make dev"
	@echo -e "  📊 ${YELLOW}With Monitoring:${NC}       make monitoring"
	@echo ""
	@echo -e "${BOLD}Staging Commands:${NC}"
	@echo -e "  🎭 make staging           Start staging environment"
	@echo -e "  📊 make staging-status    Show staging status"
	@echo -e "  📋 make staging-logs      Show staging logs"
	@echo -e "  🧹 make staging-clean     Clean staging data"
	@echo -e "  🚀 make promote-to-prod   Promote staging to production"
	@echo ""
	@echo -e "${BOLD}For more information:${NC} see README.md"

info: ## Show system and project information
	@echo -e "${CYAN}${BOLD}🌱 PlanetPlant System Information${NC}"
	@echo "================================="
	@echo ""
	@echo "📍 Project Directory: $(PWD)"
	@echo "🐳 Docker Version: $$(docker --version 2>/dev/null || echo 'Not installed')"
	@echo "📦 Node.js Version: $$(node --version 2>/dev/null || echo 'Not installed')"
	@echo "🔧 Docker Compose Version: $$($(DOCKER_COMPOSE) --version 2>/dev/null || echo 'Not installed')"
	@echo "🏗️  Architecture: $$(uname -m)"
	@echo "💻 OS: $$(uname -s) $$(uname -r)"
	@echo ""
	@if [ -f .env ]; then \
		echo "✅ Environment file found"; \
	else \
		echo "⚠️  Environment file missing (copy .env.example to .env)"; \
	fi