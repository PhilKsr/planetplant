# PlanetPlant Makefile - Easy Docker Commands
.PHONY: help dev prod stop clean backup restore update rebuild logs status test

# Default target
help:
	@echo "🌱 PlanetPlant Docker Commands"
	@echo ""
	@echo "Development:"
	@echo "  make dev          Start development environment (Mac)"
	@echo "  make dev-logs     Show development logs"
	@echo "  make dev-stop     Stop development environment"
	@echo ""
	@echo "Production:"
	@echo "  make prod         Start production environment (Pi 5)"
	@echo "  make prod-logs    Show production logs"
	@echo "  make prod-stop    Stop production environment"
	@echo ""
	@echo "Maintenance:"
	@echo "  make backup       Backup all data"
	@echo "  make restore      Restore from backup"
	@echo "  make update       Git pull and rebuild"
	@echo "  make rebuild      Rebuild all containers"
	@echo "  make clean        Remove all containers and volumes"
	@echo ""
	@echo "Monitoring:"
	@echo "  make status       Show container status"
	@echo "  make logs         Show all logs"
	@echo "  make test         Run backend tests"

# Development environment (Mac)
dev:
	@echo "🚀 Starting PlanetPlant development environment..."
	docker-compose -f docker-compose.dev.yml up --build

dev-logs:
	@echo "📋 Showing development logs..."
	docker-compose -f docker-compose.dev.yml logs -f

dev-stop:
	@echo "🛑 Stopping development environment..."
	docker-compose -f docker-compose.dev.yml down

# Production environment (Raspberry Pi 5)
prod:
	@echo "🚀 Starting PlanetPlant production environment..."
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found. Copy .env.example to .env first!"; \
		exit 1; \
	fi
	docker-compose -f docker-compose.prod.yml up -d --build

prod-logs:
	@echo "📋 Showing production logs..."
	docker-compose -f docker-compose.prod.yml logs -f

prod-stop:
	@echo "🛑 Stopping production environment..."
	docker-compose -f docker-compose.prod.yml down

# Backup and restore
backup:
	@echo "💾 Creating backup..."
	@./scripts/backup.sh

restore:
	@echo "📦 Restoring from backup..."
	@./scripts/restore.sh

# Update and rebuild
update:
	@echo "🔄 Updating PlanetPlant..."
	git pull
	@echo "🔨 Rebuilding containers..."
	$(MAKE) rebuild

rebuild:
	@echo "🔨 Rebuilding all containers..."
	docker-compose -f docker-compose.prod.yml build --no-cache
	docker-compose -f docker-compose.dev.yml build --no-cache

# Cleanup
clean:
	@echo "🧹 Cleaning up Docker resources..."
	@read -p "⚠️  This will remove ALL containers and volumes. Continue? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose -f docker-compose.prod.yml down -v; \
		docker-compose -f docker-compose.dev.yml down -v; \
		docker system prune -af; \
		echo "✅ Cleanup completed"; \
	else \
		echo "❌ Cleanup cancelled"; \
	fi

# Monitoring
status:
	@echo "📊 Container Status:"
	@echo "Production:"
	@docker-compose -f docker-compose.prod.yml ps || echo "  No production containers running"
	@echo ""
	@echo "Development:"
	@docker-compose -f docker-compose.dev.yml ps || echo "  No development containers running"

logs:
	@echo "📋 Recent logs from all services..."
	@if docker-compose -f docker-compose.prod.yml ps -q | grep -q .; then \
		echo "Production logs:"; \
		docker-compose -f docker-compose.prod.yml logs --tail=50; \
	fi
	@if docker-compose -f docker-compose.dev.yml ps -q | grep -q .; then \
		echo "Development logs:"; \
		docker-compose -f docker-compose.dev.yml logs --tail=50; \
	fi

# Testing
test:
	@echo "🧪 Running backend tests..."
	@if docker-compose -f docker-compose.dev.yml ps backend-dev | grep -q Up; then \
		docker-compose -f docker-compose.dev.yml exec backend-dev npm test; \
	else \
		echo "❌ Development backend not running. Start with 'make dev' first."; \
	fi

# Quick commands
quick-dev: dev-stop dev
quick-prod: prod-stop prod

# Health check
health:
	@echo "🏥 Health Check:"
	@echo "Backend: $$(curl -s http://localhost:3000/health | jq -r '.status' 2>/dev/null || echo 'Not responding')"
	@echo "InfluxDB: $$(curl -s http://localhost:8086/ping 2>/dev/null && echo 'OK' || echo 'Not responding')"
	@echo "Frontend: $$(curl -s http://localhost:5173 >/dev/null 2>&1 && echo 'OK' || echo 'Not responding')"

# Install dependencies
install:
	@echo "📦 Installing backend dependencies..."
	npm install
	@echo "📦 Installing frontend dependencies..."
	cd ../webapp && npm install

# Setup for first time
setup:
	@echo "🔧 Setting up PlanetPlant for first time..."
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✅ Created .env file from template"; \
		echo "⚠️  Please edit .env file with your settings"; \
	fi
	@$(MAKE) install
	@echo "✅ Setup completed. Run 'make dev' to start development."