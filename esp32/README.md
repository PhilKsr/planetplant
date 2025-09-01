# ESP32 Controller for PlanetPlant

This directory contains the firmware for the ESP32 controller that manages sensors and watering pumps.

## Hardware Requirements

- **ESP32 DevKit v1** (or compatible)
- **DHT22** temperature/humidity sensor
- **Capacitive soil moisture sensor**
- **5V water pump with relay module**
- **Breadboard and jumper wires**
- **Optional**: LDR light sensor

## Pin Configuration

| Component | ESP32 Pin | Description |
|-----------|-----------|-------------|
| DHT22 | GPIO 4 | Temperature/humidity sensor |
| Moisture Sensor | A0 | Analog soil moisture reading |
| Pump Relay | GPIO 5 | Water pump control |
| Light Sensor | A3 | Optional light level sensor |
| Status LED | GPIO 2 | Built-in LED for status |
| Manual Button | GPIO 0 | Manual watering button |

## Development Setup

### Prerequisites
- **PlatformIO** IDE or **Arduino IDE**
- **ESP32 board package** installed

### Configuration

1. Copy `src/config.h.example` to `src/config.h`
2. Update WiFi and MQTT settings in `config.h`
3. Calibrate sensor values for your specific hardware

### Building and Uploading

```bash
# Using PlatformIO
pio run --target upload

# Using Arduino IDE
# Open esp32/src/main.cpp and upload directly
```

## MQTT Topics

### Published Topics (ESP32 → Server)
- `sensors/{device_id}/data` - Sensor readings every minute
- `sensors/{device_id}/status` - Device status updates
- `sensors/{device_id}/pump` - Pump activity notifications
- `devices/{device_id}/heartbeat` - Keep-alive every 5 minutes

### Subscribed Topics (Server → ESP32)
- `commands/{device_id}/water` - Watering commands
- `commands/{device_id}/config` - Configuration updates

## Features

- **WiFiManager**: Easy WiFi setup via web portal
- **Automatic reconnection** to WiFi and MQTT
- **Manual watering button** with LED feedback
- **Sensor averaging** for accurate moisture readings
- **Pump safety timeout** to prevent overwatering
- **Heartbeat monitoring** for connection health
- **Over-the-air configuration** via MQTT

## Troubleshooting

### WiFi Connection Issues
1. Hold the manual button during startup to reset WiFi settings
2. Connect to "PlanetPlant-Setup" WiFi network
3. Configure your WiFi credentials in the web portal

### MQTT Connection Issues
1. Verify MQTT server settings in `config.h`
2. Check that the Raspberry Pi MQTT broker is running
3. Monitor serial output for connection status

### Sensor Issues
1. Check wiring connections
2. Calibrate moisture sensor values in `config.h`
3. Verify 3.3V power supply to sensors

### Pump Issues
1. Ensure relay is wired correctly (VCC, GND, IN pin)
2. Check that pump power supply is adequate
3. Verify pump safety timeout is working

## Calibration

### Moisture Sensor
1. Take reading in dry air → `MOISTURE_DRY`
2. Take reading in water → `MOISTURE_WET`
3. Update values in `config.h`

### Light Sensor (Optional)
1. Take reading in darkness → minimum value
2. Take reading in bright light → maximum value
3. Adjust mapping in code as needed