# 🌱 PlanetPlant - Smart Plant Watering System

Ein intelligentes Pflanzenbewässerungssystem basierend auf IoT-Technologien mit automatischer Bewässerung, Web-Dashboard und historischer Datenerfassung.

## 🏗️ Architektur

Das System besteht aus drei Hauptkomponenten:

- **Raspberry Pi Zero 2 W**: Server mit Node.js/Express API, MQTT Broker Integration und InfluxDB Datenbank
- **ESP32 Mikrocontroller**: Sensor-Controller für Bodenfeuchtigkeit, Temperatur und Luftfeuchtigkeit
- **React PWA**: Web-Dashboard für Monitoring und Steuerung

## 📁 Projektstruktur

```
PlanetPlant/
├── raspberry-pi/          # Server-Code (Node.js, Express, MQTT)
│   ├── src/              # Hauptanwendungscode
│   ├── config/           # Server-Konfigurationsdateien
│   └── logs/             # Log-Dateien
├── esp32/                # Mikrocontroller-Code (Arduino/C++)
│   └── src/              # ESP32 Sensor-Code
├── webapp/               # Frontend (React PWA)
│   ├── src/              # React Komponenten
│   └── public/           # Statische Assets
├── docs/                 # Dokumentation
├── config/               # Globale Konfigurationsdateien
└── scripts/              # Installations- und Utility-Skripte
```

## ✨ Features

### Sensordaten-Erfassung
- **Bodenfeuchtigkeit**: Automatische Messung der Bodenfeuchtigkeit
- **Temperatur**: Umgebungstemperatur-Monitoring
- **Luftfeuchtigkeit**: Luftfeuchtigkeits-Überwachung
- **Echtzeit-Übertragung**: MQTT-basierte Kommunikation

### Automatische Bewässerung
- Schwellwert-basierte Bewässerung
- Konfigurierbare Bewässerungsintervalle
- Überlaufschutz und Sicherheitsmechanismen
- Manuelle Override-Möglichkeiten

### Web-Dashboard
- **Echtzeit-Monitoring**: Live-Anzeige aller Sensordaten
- **Historische Daten**: Zeitreihen-Visualisierung
- **Mobile-First**: Responsive PWA-Design
- **Offline-Fähigkeiten**: Service Worker Integration

### Datenmanagement
- **InfluxDB**: Time-series Datenbank für Sensordaten
- **Datenretention**: Konfigurierbare Datenaufbewahrung
- **Export-Funktionen**: CSV/JSON Datenexport
- **Backup-Strategien**: Automatische Datensicherung

## 🚀 Quick Start

### Voraussetzungen
- Raspberry Pi Zero 2 W mit Raspbian OS
- ESP32 Development Board
- Docker & Docker Compose
- Node.js 18+ (für lokale Entwicklung)
- Arduino IDE oder PlatformIO

### Installation

1. **Repository klonen**
   ```bash
   git clone https://github.com/yourusername/PlanetPlant.git
   cd PlanetPlant
   ```

2. **Services starten**
   ```bash
   docker-compose up -d
   ```

3. **Raspberry Pi Server einrichten**
   ```bash
   cd raspberry-pi
   npm install
   npm start
   ```

4. **ESP32 programmieren**
   - ESP32 Code mit Arduino IDE oder PlatformIO flashen
   - WLAN-Credentials konfigurieren

5. **Web-App starten**
   ```bash
   cd webapp
   npm install
   npm start
   ```

## 🔧 Konfiguration

### MQTT Settings
- **Broker**: Mosquitto (Port 1883)
- **Topics**: 
  - `plantplant/sensors/+` - Sensordaten
  - `plantplant/control/+` - Steuerungskommandos

### InfluxDB Setup
- **Database**: plantplant_db
- **Retention**: 30 Tage (konfigurierbar)
- **Measurements**: sensors, watering_events

### Hardware Verkabelung

#### ESP32 Pinout
- **Bodenfeuchtigkeit**: A0 (Analogeingang)
- **DHT22 Sensor**: GPIO 4 (Digital)
- **Wasserpumpe**: GPIO 2 (Digital Output)
- **Status LED**: GPIO 16 (Digital Output)

## 🌐 Remote Access

Das System nutzt **Tailscale VPN** für sicheren Remote-Zugriff:

1. Tailscale auf Raspberry Pi installieren
2. Device autorisieren
3. Von überall auf das Dashboard zugreifen

## 📊 Monitoring & Alerts

- **Sensor-Status**: Überwachung der Sensor-Verfügbarkeit
- **Wasserpegel**: Low-Water Alerts
- **System-Health**: CPU, Memory, Disk Usage
- **Email/Push-Notifications**: Konfigurierbare Benachrichtigungen

## 🛠️ Entwicklung

### API Endpoints
```
GET /api/sensors/latest     # Aktuelle Sensordaten
GET /api/sensors/history    # Historische Daten
POST /api/watering/manual   # Manuelle Bewässerung
GET /api/config             # System-Konfiguration
```

### MQTT Topics
```
plantplant/sensors/moisture    # Bodenfeuchtigkeit
plantplant/sensors/temperature # Temperatur
plantplant/sensors/humidity    # Luftfeuchtigkeit
plantplant/control/pump        # Pumpen-Steuerung
```

## 🐳 Docker Services

- **InfluxDB**: Time-series Datenbank
- **Mosquitto**: MQTT Broker
- **Grafana**: Erweiterte Datenvisualisierung (optional)

## 📝 Lizenz

MIT License - siehe [LICENSE](LICENSE) file.

## 🤝 Contributing

1. Fork das Repository
2. Feature Branch erstellen (`git checkout -b feature/AmazingFeature`)
3. Changes committen (`git commit -m 'Add some AmazingFeature'`)
4. Branch pushen (`git push origin feature/AmazingFeature`)
5. Pull Request öffnen

## 📞 Support

Bei Fragen oder Problemen erstellen Sie bitte ein [Issue](https://github.com/yourusername/PlanetPlant/issues).

---

Made with 🌱 for sustainable gardening