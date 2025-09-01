# 🌱 PlanetPlant - Smart Plant Monitoring System

**Intelligentes IoT-Pflanzenbewässerungssystem für Raspberry Pi 5**

PlanetPlant ist ein vollständiges IoT-System zur automatischen Überwachung und Bewässerung von Pflanzen. Das System kombiniert ESP32-Sensoren, eine Raspberry Pi 5-Zentrale und eine moderne React-PWA für die Benutzeroberfläche.

## 📋 Übersicht

```
┌─────────────────┐    MQTT     ┌─────────────────┐    HTTP/WS    ┌─────────────────┐
│     ESP32       │◄────────────┤  Raspberry Pi 5 │◄──────────────┤   React PWA     │
│   Sensoren &    │             │                 │               │   Dashboard     │
│   Wasserpumpe   │             │  InfluxDB       │               │                 │
└─────────────────┘             │  Mosquitto MQTT │               └─────────────────┘
                                │  Redis Cache    │
                                │  Node.js API    │
                                │  Grafana        │
                                └─────────────────┘
```

**Datenfluss:** ESP32 → MQTT → Backend → InfluxDB → Grafana & Web-Dashboard

## 🚀 Quick Start (5 Minuten)

### Voraussetzungen
- **Raspberry Pi 5** (oder Pi 4) mit min. 4GB RAM
- **Docker & Docker Compose** installiert
- **10GB freier Speicherplatz**
- **Internetverbindung** für Initial-Setup

### Installation

```bash
# 1. Repository klonen
git clone https://github.com/PhilKsr/planetplant.git
cd planetplant

# 2. Environment konfigurieren
cp .env.example .env
nano .env  # WiFi & MQTT Einstellungen anpassen

# 3. Raspberry Pi 5 setup (einmalig)
make setup-pi

# 4. Services starten
make up

# 5. System testen
make test
```

**Fertig!** 🎉 Zugriff auf:
- **Frontend:** http://`<PI-IP>`
- **Grafana:** http://`<PI-IP>`:3001 (admin/plantplant123)
- **InfluxDB:** http://`<PI-IP>`:8086

## 🏗️ Architektur & Services

| Service | Port | Beschreibung | Credentials | Speicher |
|---------|------|--------------|-------------|----------|
| **Frontend** | 80 | React PWA Dashboard | - | 512MB |
| **Backend API** | 3001 | Node.js REST API | - | 2GB |
| **Grafana** | 3001 | Datenvisualisierung | admin/plantplant123 | 1GB |
| **InfluxDB** | 8086 | Zeitserien-Datenbank | admin/plantplant123 | 2GB |
| **MQTT Broker** | 1883 | Message Broker | - | 512MB |
| **Redis** | 6379 | Cache & Sessions | plantplant123 | 1GB |
| **Nginx** | 80 | Reverse Proxy | - | 256MB |

### 🎯 **Optimiert für Raspberry Pi 5 (8GB RAM)**
- **ARM64 native** Container-Images
- **Ressourcen-Limits** angepasst für 8GB RAM
- **Restart-Policies** für hohe Verfügbarkeit
- **Health-Checks** für alle Services
- **Persistent Volumes** unter `/opt/planetplant/`

## 🔧 Hardware Setup

### ESP32 Komponenten
- **ESP32 DevKit v1**
- **Kapazitive Bodenfeuchte-Sensoren**
- **DHT22** (Temperatur/Luftfeuchtigkeit)
- **5V Wasserpumpe** mit Relais
- **Optional:** LDR Lichtsensor

### Verkabelung ESP32
```
ESP32 DevKit v1        Komponente
================      =============
GPIO 4           ──── DHT22 Data
A0 (GPIO 36)     ──── Moisture Sensor Analog
GPIO 5           ──── Pump Relay IN
A3 (GPIO 39)     ──── Light Sensor (Optional)
GPIO 2           ──── Status LED (Built-in)
GPIO 0           ──── Manual Button (Built-in)
3.3V             ──── Sensor VCC
GND              ──── Sensor & Relay GND
5V               ──── Pump & Relay VCC
```

## 📡 ESP32 Konfiguration

### Firmware Upload
```bash
# Mit PlatformIO
cd esp32
pio run --target upload

# Mit Arduino IDE
# Öffne esp32/src/main.cpp und upload direkt
```

### WiFi Setup
1. **Erste Verbindung:** ESP32 erstellt WiFi "PlanetPlant-Setup"
2. **Verbinden:** Passwort "plantplant123"
3. **Konfigurieren:** Web-Portal öffnet sich automatisch
4. **MQTT Setup:** Raspberry Pi IP-Adresse eingeben

### MQTT Topics
```bash
# ESP32 → Server (Published)
sensors/{device_id}/data        # Sensor-Daten alle 60s
sensors/{device_id}/status      # Device-Status Updates  
sensors/{device_id}/pump        # Pump-Activity
devices/{device_id}/heartbeat   # Keep-Alive alle 5min

# Server → ESP32 (Subscribed)
commands/{device_id}/water      # Bewässerungs-Befehle
commands/{device_id}/config     # Konfigurations-Updates
```

## 🛠️ Entwicklung

### Lokale Entwicklung (Mac/Linux)
```bash
# Development Environment starten
make dev

# Frontend Development Server
make frontend-dev    # http://localhost:5173

# Backend Development
make backend-dev     # http://localhost:3001

# Logs verfolgen
make logs

# Services testen
make test
```

### Code-Qualität
```bash
# Linting
make lint

# Dependencies prüfen
make check-deps

# Security Scan
make security-scan
```

### Neue Features entwickeln
1. **Branch erstellen:** `git checkout -b feature/new-feature`
2. **Code ändern** in `raspberry-pi/` oder `webapp/`
3. **Tests laufen lassen:** `make test`
4. **Linting prüfen:** `make lint`
5. **Pull Request** erstellen

## 📊 Monitoring & Dashboards

### Grafana Dashboards
- **Plant Overview:** Alle Pflanzen auf einen Blick
- **Sensor History:** Historische Daten und Trends
- **System Health:** Performance und Fehler-Monitoring
- **Automation Logs:** Bewässerungs-Historie

### Automatische Alerts
- 🚨 **Niedrige Bodenfeuchtigkeit** (< 30%)
- 🚨 **Sensor-Ausfall** (keine Daten > 10min)
- 🚨 **System-Fehler** (Service down)
- 🚨 **Hohe Systemlast** (> 80% RAM/CPU)

### Alert-Konfiguration
```bash
# In .env konfigurieren:
EMAIL_ENABLED=true
ALERT_RECIPIENTS=your-email@example.com
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
```

## 🐛 Troubleshooting

### Services neustarten
```bash
make down && make up      # Alles neu starten
make rebuild              # Force rebuild
make clean                # Aufräumen + neu starten
```

### Logs analysieren
```bash
make logs                 # Alle Services
make logs-backend         # Nur Backend
make logs-influxdb        # Nur InfluxDB
```

### Status prüfen
```bash
make status               # Detaillierter Status
make health               # Schneller Health-Check
docker-compose ps         # Container-Status
```

### Häufige Probleme

| Problem | Ursache | Lösung |
|---------|---------|---------|
| ❌ InfluxDB startet nicht | Falsche Permissions | `sudo chown -R $USER /opt/planetplant` |
| ❌ MQTT Verbindung fehlschlägt | Firewall blockiert | `sudo ufw allow 1883` |
| ❌ Frontend nicht erreichbar | Nginx-Config Fehler | `make logs-frontend` |
| ❌ Hohe RAM-Nutzung | Resource Limits | `docker stats` → Limits anpassen |
| ❌ ESP32 verbindet nicht | WiFi-Probleme | Reset-Button halten beim Start |

### Performance-Optimierung
```bash
# System-Ressourcen prüfen
free -h                   # RAM-Verbrauch
df -h                     # Disk-Space
docker stats --no-stream # Container-Ressourcen

# Logs rotieren
sudo logrotate -f /etc/logrotate.d/planetplant

# Alte Backups löschen
find /opt/planetplant/backups -name "*.tar.gz" -mtime +30 -delete
```

## 🔐 Sicherheit & Best Practices

### Erste Schritte nach Installation
1. **Passwörter ändern** in `.env`:
   ```bash
   JWT_SECRET=your-secure-secret-min-32-chars
   INFLUXDB_PASSWORD=secure-password
   REDIS_PASSWORD=secure-password
   GRAFANA_ADMIN_PASSWORD=secure-password
   ```

2. **Firewall konfigurieren:**
   ```bash
   sudo ufw enable
   sudo ufw allow ssh
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 1883/tcp  # MQTT
   ```

3. **Tailscale für Remote-Zugriff:**
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```

### Backup-Strategie
```bash
# Automatisches Backup (täglich um 2:00 Uhr)
echo "0 2 * * * cd /home/pi/planetplant && make backup" | crontab -

# Manuelles Backup
make backup

# Backup wiederherstellen
make restore file=/opt/planetplant/backups/planetplant_backup_20240101_120000.tar.gz
```

## 📝 API Dokumentierung

### Plant Management
```bash
GET    /api/plants                    # Alle Pflanzen
GET    /api/plants/:id                # Spezifische Pflanze
GET    /api/plants/:id/current        # Aktuelle Sensor-Daten
GET    /api/plants/:id/history        # Historische Daten
POST   /api/plants/:id/water          # Manuelle Bewässerung
PUT    /api/plants/:id/config         # Pflanze konfigurieren
```

### System & Monitoring
```bash
GET    /api/system/status             # System-Status
GET    /api/system/stats              # Performance-Metriken
GET    /api/alerts/active             # Aktive Alerts
```

### Beispiel API-Aufruf
```bash
# Aktuelle Sensor-Daten abrufen
curl -X GET "http://localhost/api/plants/esp32_abc123/current" \
     -H "Content-Type: application/json"

# Manuelle Bewässerung
curl -X POST "http://localhost/api/plants/esp32_abc123/water" \
     -H "Content-Type: application/json" \
     -d '{"duration": 5000, "reason": "manual"}'
```

## 🔄 Wartung & Updates

### System Updates
```bash
# PlanetPlant updaten
git pull origin main
make update

# System-Pakete updaten (Raspberry Pi)
sudo apt update && sudo apt upgrade -y

# Dependencies updaten
make update-deps
```

### Backup & Restore
```bash
# Backup erstellen
make backup

# Verfügbare Backups anzeigen
ls -lah /opt/planetplant/backups/

# System wiederherstellen
make restore file=backup_file.tar.gz
```

## 🤝 Contributing

### Development Setup
```bash
# Abhängigkeiten installieren
make install

# Development starten
make dev

# Tests laufen lassen
make test

# Code-Qualität prüfen
make lint
```

### Code-Standards
- **ESLint** für JavaScript/React
- **Prettier** für Code-Formatierung
- **Conventional Commits** für Commit-Messages
- **Tests** für neue Features

## 🏷️ Technologie-Stack

### Backend
- **Node.js 20** mit Express.js
- **InfluxDB 2.7** für Zeitserien-Daten
- **Redis 7.2** für Caching
- **Mosquitto MQTT 2.0** für IoT-Kommunikation
- **PM2** für Process Management

### Frontend
- **React 18.3** mit Vite 5.4
- **Tailwind CSS 3.4** für Styling
- **Recharts** für Datenvisualisierung
- **PWA** mit Service Worker
- **i18next** für Mehrsprachigkeit

### Infrastructure
- **Docker Compose** für Service-Orchestrierung
- **Nginx** als Reverse Proxy
- **Grafana 10.2** für Advanced Monitoring
- **ARM64** optimierte Container

## 📊 System-Anforderungen

### Raspberry Pi 5 (Empfohlen)
- **8GB RAM:** Optimal für alle Services
- **64GB+ SD-Karte:** Class 10 oder besser
- **Netzwerk:** Ethernet oder WiFi 6
- **Kühlung:** Aktiver Lüfter empfohlen

### Raspberry Pi 4 (Minimum)
- **4GB RAM:** Funktional, Grafana optional
- **32GB+ SD-Karte:** Class 10
- **Resource Limits** müssen angepasst werden

## 🔧 Konfiguration

### Environment Variablen (.env)
```bash
# Wichtigste Einstellungen
NODE_ENV=production
INFLUXDB_PASSWORD=secure-password-here
GRAFANA_ADMIN_PASSWORD=secure-password-here
JWT_SECRET=your-secure-jwt-secret-32-chars
MQTT_BROKER_URL=mqtt://localhost:1883

# Automatisierung
MOISTURE_THRESHOLD=30          # Bewässerung bei < 30%
WATERING_DURATION=5000         # 5 Sekunden pumpen
MAX_WATERING_PER_DAY=3         # Max 3x täglich
```

## 🐛 Troubleshooting

### Services neustarten
```bash
make down && make up      # Alles neu starten
make rebuild              # Force rebuild
make clean                # Aufräumen + neu starten
```

### Logs analysieren
```bash
make logs                 # Alle Services
make logs-backend         # Nur Backend
make logs-influxdb        # Nur InfluxDB
```

### Häufige Probleme

| Problem | Ursache | Lösung |
|---------|---------|---------|
| ❌ InfluxDB startet nicht | Falsche Permissions | `sudo chown -R $USER /opt/planetplant` |
| ❌ MQTT Verbindung fehlschlägt | Firewall blockiert | `sudo ufw allow 1883` |
| ❌ Frontend nicht erreichbar | Nginx-Config Fehler | `make logs-frontend` |
| ❌ Hohe RAM-Nutzung | Resource Limits | `docker stats` → Limits anpassen |
| ❌ ESP32 verbindet nicht | WiFi-Probleme | Reset-Button halten beim Start |

## 📝 API Dokumentierung

### Plant Management
```bash
GET    /api/plants                    # Alle Pflanzen
GET    /api/plants/:id                # Spezifische Pflanze
GET    /api/plants/:id/current        # Aktuelle Sensor-Daten
POST   /api/plants/:id/water          # Manuelle Bewässerung
PUT    /api/plants/:id/config         # Pflanze konfigurieren
```

### System & Monitoring
```bash
GET    /api/system/status             # System-Status
GET    /api/system/stats              # Performance-Metriken
GET    /api/alerts/active             # Aktive Alerts
```

## 🤝 Contributing

### Development Setup
```bash
# Abhängigkeiten installieren
make install

# Development starten
make dev

# Tests laufen lassen
make test

# Code-Qualität prüfen
make lint
```

## 🏷️ Technologie-Stack

### Backend
- **Node.js 20** mit Express.js
- **InfluxDB 2.7** für Zeitserien-Daten
- **Redis 7.2** für Caching
- **Mosquitto MQTT 2.0** für IoT-Kommunikation

### Frontend
- **React 18.3** mit Vite 5.4
- **Tailwind CSS 3.4** für Styling
- **Recharts** für Datenvisualisierung
- **PWA** mit Service Worker

### Infrastructure
- **Docker Compose** für Service-Orchestrierung
- **Nginx** als Reverse Proxy
- **Grafana 10.2** für Advanced Monitoring
- **ARM64** optimierte Container

## 📄 Lizenz

MIT License

---

**Made with 💚 for plants and IoT enthusiasts**

*PlanetPlant - Because every plant deserves smart care! 🌱*