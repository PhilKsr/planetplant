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

### Local Development
1. **Start Docker services**: `docker-compose up -d`
2. **Backend**: `cd raspberry-pi && npm install && npm start` (Port 3000)
3. **Frontend**: `cd webapp && npm install && npm start` (Port 5173)

### Key Files & Directories
```
PlanetPlant/
├── raspberry-pi/
│   ├── .env                    # Environment variables (copy from .env.example)
│   ├── package.json           # Fixed versions for backend dependencies
│   ├── src/app.js             # Main server entry point (dotenv config at top!)
│   ├── src/services/          # Core services (MQTT, InfluxDB, Plant, Automation)
│   └── ecosystem.config.js    # PM2 configuration
├── webapp/
│   ├── package.json          # Fixed versions for frontend dependencies  
│   ├── src/App.jsx           # Main React app entry
│   └── src/components/       # Reusable UI components
├── config/
│   └── mosquitto.conf        # Minimal MQTT broker config
└── docker-compose.yml        # Infrastructure services
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
- `GET /api/plants` - List all plants
- `GET /api/plants/:id/current` - Current sensor data
- `GET /api/plants/:id/history` - Historical data  
- `POST /api/plants/:id/water` - Manual watering
- `PUT /api/plants/:id/config` - Update plant settings

### System
- `GET /api/system/status` - System health
- `GET /api/system/stats` - System statistics

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

### Common Commands
```bash
# Backend
cd raspberry-pi
npm run dev          # Development with nodemon
npm run lint         # Check code style
npm run test         # Run tests

# Frontend  
cd webapp
npm run dev          # Vite dev server
npm run build        # Production build
npm run preview      # Preview production build

# Infrastructure
docker-compose up -d              # Start services
docker-compose logs mosquitto     # Check MQTT logs
docker-compose restart influxdb   # Restart InfluxDB
```

## 📝 Notes for Claude Code
- Environment loading order is critical in app.js
- Mosquitto requires minimal config for local development
- React dependencies need careful version management
- InfluxDB token must be available at service initialization
- Use TodoWrite for complex multi-step tasks
- Test each component separately before integration