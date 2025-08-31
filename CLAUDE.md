# CLAUDE.md - PlanetPlant Development Context

## 🌱 Project Overview
PlanetPlant is a smart IoT plant watering system with three main components:
- **Raspberry Pi Server**: Node.js/Express backend with MQTT and InfluxDB
- **ESP32 Controller**: Arduino/C++ sensor and pump controller  
- **React PWA**: Modern web dashboard for monitoring and control

## 🏗️ Architecture & Stack

### Backend (`/raspberry-pi`)
- **Framework**: Node.js 18+ with Express
- **Database**: InfluxDB 2.7 (time-series data)
- **Message Broker**: Mosquitto MQTT
- **Caching**: Redis 7
- **Real-time**: WebSocket (Socket.io)
- **Process Manager**: PM2
- **Logging**: Winston with daily rotation

### Frontend (`/webapp`) 
- **Framework**: React 18.3.1 with Vite 5.4.6
- **Styling**: Tailwind CSS 3.4.10
- **State Management**: @tanstack/react-query 5.56.2
- **Charts**: Recharts 2.12.7
- **Animations**: Framer Motion 11.5.4
- **PWA**: Workbox service worker
- **Real-time**: Socket.io client

### Infrastructure
- **Container**: Docker Compose with InfluxDB, Mosquitto, Redis
- **VPN**: Tailscale for remote access
- **Monitoring**: Grafana (optional)

## 🔧 Development Setup

### Prerequisites
- Node.js 18+
- Docker & Docker Compose
- Arduino IDE/PlatformIO (for ESP32)

### Environment-Specific Setup

#### Development (Mac/Local)
```bash
# Use development Docker Compose with hot-reload
cd raspberry-pi
make dev                    # Start all services with docker-compose.dev.yml
npm run dev                 # Alternative: Start backend with nodemon (Port 3000)
```

#### Production (Raspberry Pi 5)
```bash
# Use production Docker Compose with optimizations
cd raspberry-pi
make prod                   # Start all services with docker-compose.prod.yml
make backup                 # Create full system backup
make restore file=backup.tar.gz  # Restore from backup
```

### Key Files & Directories
```
PlanetPlant/
├── raspberry-pi/
│   ├── .env                      # Environment variables (copy from .env.example)
│   ├── package.json             # Fixed versions for backend dependencies
│   ├── Makefile                 # Build automation for dev/prod environments
│   ├── docker-compose.dev.yml   # Development environment (Mac/local)
│   ├── docker-compose.prod.yml  # Production environment (Pi 5)
│   ├── src/app.js              # Main server entry point (dotenv config at top!)
│   ├── src/services/           # Core services (MQTT, InfluxDB, Plant, Automation)
│   ├── scripts/                # Backup/restore automation scripts
│   └── ecosystem.config.js     # PM2 configuration
├── webapp/
│   ├── package.json            # Fixed versions for frontend dependencies  
│   ├── src/App.jsx             # Main React app entry
│   └── src/components/         # Reusable UI components
├── config/
│   ├── mosquitto.conf          # MQTT broker configuration
│   ├── grafana/                # Grafana dashboards and provisioning
│   └── nginx/                  # Reverse proxy configuration
├── .github/workflows/          # CI/CD automation
└── docker-compose.yml          # Legacy - use dev/prod variants instead
```

## 🚨 Common Issues & Fixes

### 1. InfluxDB Authentication
- **Problem**: `unauthorized access` error
- **Cause**: Environment variables loaded after service imports
- **Fix**: Ensure `dotenv.config()` is called BEFORE service imports in app.js

### 2. MQTT Connection Errors
- **Problem**: `ECONNREFUSED` to Mosquitto
- **Cause**: Invalid configuration in mosquitto.conf
- **Fix**: Use minimal config with `allow_anonymous true` for development

### 3. React Dependencies
- **Problem**: ESLint version conflicts, react-query vs @tanstack/react-query
- **Fix**: Use only @tanstack/react-query, ESLint 8.x (not 9.x), fixed versions

### 4. Package Manager Issues
- **Problem**: npm/pnpm conflicts, package-lock vs pnpm-lock
- **Fix**: Use npm consistently, remove pnpm-lock.yaml, fixed versions in package.json

## 🔒 Security & Configuration

### Environment Variables (.env)
- Located in `/raspberry-pi/.env` (copy from .env.example)
- Contains InfluxDB token, MQTT credentials, JWT secrets
- **Never commit .env files to git**

### Default Credentials (Development Only)
- InfluxDB: admin/plantplant123, token: plantplant-super-secret-auth-token
- Redis: password plantplant123
- MQTT: Anonymous enabled for development

## 📋 API Endpoints

### Plant Management
- `GET /api/plants` - List all plants with current sensor data
- `GET /api/plants/:id` - Get specific plant details
- `GET /api/plants/:id/current` - Current sensor data from InfluxDB
- `GET /api/plants/:id/history` - Historical data with configurable range
- `GET /api/plants/:id/anomalies` - Detect sensor anomalies using Flux queries
- `GET /api/plants/:id/aggregates` - Daily/weekly aggregated statistics
- `POST /api/plants/:id/water` - Manual watering with MQTT command
- `PUT /api/plants/:id/config` - Update plant settings

### System & Monitoring
- `GET /api/system/status` - System health (MQTT, InfluxDB, Redis)
- `GET /api/system/stats` - System performance metrics
- `GET /api/alerts/active` - Active plant alerts and warnings

## 📡 MQTT Topics

### Sensors (ESP32 → Server)
- `sensors/+/data` - Sensor readings (moisture, temperature, humidity)
- `sensors/+/status` - Sensor status updates
- `devices/+/heartbeat` - Device health

### Commands (Server → ESP32)
- `commands/+/water` - Watering commands
- `commands/+/config` - Configuration updates

## 🎯 Development Rules

### Code Quality
1. **No comments unless requested** - Code should be self-documenting
2. **Follow existing patterns** - Match code style of surrounding files
3. **Fixed versions** - Use exact versions in package.json (no ^ or ~)
4. **Security first** - Never commit secrets, use environment variables
5. **Clean commit messages** - Never mention Claude or AI assistance in commits

### File Organization
1. **Prefer editing over creating** - Modify existing files when possible
2. **No documentation files** unless explicitly requested
3. **Use existing utilities** - Check what's already available before adding new dependencies

### Error Handling
1. **Graceful degradation** - Services should handle missing dependencies
2. **Comprehensive logging** - Use winston with appropriate log levels
3. **Health checks** - All services should report status

### Testing & Deployment
1. **Test locally first** - Ensure stack starts without errors
2. **Run lint/typecheck** - Fix all warnings before committing
3. **Use PM2 for production** - Process management with ecosystem.config.js

## 🔄 Development Workflow

### When Making Changes
1. Read existing files to understand patterns
2. Check package.json for available libraries
3. Follow existing component structure
4. Test locally before finalizing
5. Update this CLAUDE.md if architecture changes

### Docker & Infrastructure Commands
```bash
# Development Environment (Mac/Local)
make dev                          # Start dev environment with hot-reload
make dev-logs                     # View development logs
make dev-down                     # Stop development environment

# Production Environment (Pi 5)
make prod                         # Start production environment
make prod-logs                    # View production logs
make prod-down                    # Stop production environment

# Maintenance & Operations
make backup                       # Create timestamped backup
make restore file=backup.tar.gz   # Restore from backup
make update                       # Update and rebuild containers
make rebuild                      # Force rebuild all containers
make clean                        # Clean unused Docker resources

# Service Management
docker-compose -f docker-compose.dev.yml logs mosquitto
docker-compose -f docker-compose.prod.yml restart influxdb
docker-compose -f docker-compose.dev.yml exec backend npm run lint
```

### Backend Development
```bash
cd raspberry-pi
npm run dev          # Development with nodemon
npm run lint         # ESLint code quality check
npm run test         # Run tests (if available)
npm start            # Production start
```

### Frontend Development
```bash
cd webapp
npm run dev          # Vite dev server (Port 5173)
npm run build        # Production build
npm run preview      # Preview production build
```

## 🗄️ InfluxDB Integration

### Data Model
- **Bucket**: `sensor-data` (configurable via INFLUXDB_BUCKET)
- **Measurements**:
  - `sensor_data`: Temperature, humidity, moisture, light readings
  - `watering_events`: Pump activation logs with duration and success status
  - `system_stats`: Server performance metrics

### Key Features
- **Batch Processing**: Automatic batching with 100-point buffer and 5s flush interval
- **Retry Logic**: Exponential backoff for failed writes with 3 max retries
- **Anomaly Detection**: Flux queries for detecting unusual sensor patterns
- **Aggregation**: Daily/weekly statistical summaries
- **Grafana Integration**: Predefined Flux queries for dashboard provisioning

### Critical Implementation Notes
- InfluxDB service MUST be initialized before MQTT client in app.js
- All sensor data goes through plantService.updateSensorData() → influxService.writeSensorData()
- Use Point objects with proper tags (device_id, plant_id, sensor_type) and fields (value, unit)

## 🐳 Docker Architecture

### Development Environment (docker-compose.dev.yml)
- **Backend**: Live code mounting with nodemon hot-reload
- **Frontend**: Vite dev server with HMR
- **Services**: InfluxDB, Mosquitto, Redis with development settings
- **Debugging**: Node.js debug port 9229 exposed
- **Networks**: Custom bridge network for service discovery

### Production Environment (docker-compose.prod.yml)
- **Optimization**: Multi-stage builds, ARM64 native compilation
- **Security**: Non-root users, read-only filesystems where possible
- **Performance**: Resource limits, health checks, restart policies
- **Storage**: Bind-mounted volumes to `/opt/planetplant/` directories
- **Monitoring**: Comprehensive logging and metrics collection

### Container Images
- **Backend**: Custom Node.js 18-alpine with PM2
- **Frontend**: Nginx-alpine serving static build
- **Infrastructure**: Official InfluxDB 2.7, Eclipse Mosquitto, Redis 7-alpine

## 🔄 CI/CD Pipeline (.github/workflows/deploy.yml)

### Automated Workflow
1. **Testing**: ESLint, build verification, dependency audit
2. **Building**: Multi-arch Docker images (AMD64, ARM64)
3. **Registry**: GitHub Container Registry with automated tagging
4. **Deployment**: SSH-based deployment to Raspberry Pi 5
5. **Verification**: Health checks and service status validation

### Deployment Strategy
- **Staging**: Automatic deployment on `develop` branch
- **Production**: Manual approval required for `main` branch
- **Rollback**: Previous container images kept for quick recovery
- **Monitoring**: Real-time deployment status and error reporting

## 📝 Notes for Claude Code
- Environment loading order is critical in app.js (dotenv BEFORE service imports)
- SQLite completely removed - all data now in InfluxDB time-series format
- Use `make dev` for development, `make prod` for production deployments
- MQTT client depends on InfluxDB service for sensor data persistence
- All Docker configurations tested and optimized for respective environments
- ESLint configuration enforces consistent code style across the project
- Backup/restore scripts handle complete system state including Docker volumes