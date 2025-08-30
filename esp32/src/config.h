/**
 * PlanetPlant ESP32 Configuration
 * Hardware and Software Configuration Settings
 */

#ifndef CONFIG_H
#define CONFIG_H

// Hardware Pin Definitions
#define MOISTURE_SENSOR_PIN     A0      // Analog pin for soil moisture sensor
#define DHT_SENSOR_PIN          4       // Digital pin for DHT22 temperature/humidity sensor
#define WATER_PUMP_PIN          2       // Digital pin for water pump relay
#define STATUS_LED_PIN          16      // Built-in LED for status indication
#define POWER_LED_PIN           17      // External power indicator LED

// Sensor Configuration
#define DHT_TYPE                DHT22   // DHT sensor type (DHT22 or DHT11)
#define MOISTURE_READING_DELAY  2000    // Delay between moisture readings (ms)
#define DHT_READING_DELAY       5000    // Delay between DHT readings (ms)
#define SENSOR_READINGS_COUNT   5       // Number of readings to average

// Moisture Sensor Calibration Values
#define MOISTURE_DRY_VALUE      1023    // Sensor value in completely dry soil
#define MOISTURE_WET_VALUE      0       // Sensor value in completely wet soil

// Water Pump Settings
#define PUMP_MAX_DURATION       10000   // Maximum pump run time in milliseconds (10 seconds)
#define PUMP_COOLDOWN_TIME      300000  // Minimum time between pump activations (5 minutes)
#define PUMP_FLOW_RATE          5       // ml per second (for volume calculations)

// WiFi Configuration
#define WIFI_CONNECT_TIMEOUT    30000   // WiFi connection timeout (30 seconds)
#define WIFI_RECONNECT_INTERVAL 60000   // WiFi reconnection attempt interval (1 minute)
#define WIFI_MAX_RETRY_COUNT    5       // Maximum WiFi connection retries

// MQTT Configuration
#define MQTT_PORT               1883
#define MQTT_KEEPALIVE          60
#define MQTT_CONNECT_TIMEOUT    10000   // MQTT connection timeout (10 seconds)
#define MQTT_RECONNECT_INTERVAL 5000    // MQTT reconnection interval (5 seconds)
#define MQTT_MAX_RETRY_COUNT    10      // Maximum MQTT connection retries
#define MQTT_QOS                1       // Quality of Service level

// MQTT Topics
#define MQTT_TOPIC_MOISTURE     "plantplant/sensors/moisture"
#define MQTT_TOPIC_TEMPERATURE  "plantplant/sensors/temperature"
#define MQTT_TOPIC_HUMIDITY     "plantplant/sensors/humidity"
#define MQTT_TOPIC_PUMP_CONTROL "plantplant/control/pump"
#define MQTT_TOPIC_STATUS       "plantplant/status/device"
#define MQTT_TOPIC_CONFIG       "plantplant/config/device"
#define MQTT_TOPIC_HEARTBEAT    "plantplant/heartbeat"

// Data Transmission Settings
#define DATA_SEND_INTERVAL      60000   // Send sensor data every 60 seconds
#define HEARTBEAT_INTERVAL      30000   // Send heartbeat every 30 seconds
#define STATUS_UPDATE_INTERVAL  300000  // Send status update every 5 minutes

// Power Management
#define DEEP_SLEEP_ENABLED      false   // Enable deep sleep mode (disable for always-on operation)
#define SLEEP_DURATION          300     // Deep sleep duration in seconds (5 minutes)
#define WAKE_UP_PIN             GPIO_NUM_0  // Pin to wake up from deep sleep

// System Settings
#define SERIAL_BAUD_RATE        115200
#define DEVICE_ID_PREFIX        "PlanetPlant_"
#define FIRMWARE_VERSION        "1.0.0"
#define HARDWARE_VERSION        "1.0"

// Watchdog Timer
#define WATCHDOG_TIMEOUT        30000   // Watchdog timeout in milliseconds (30 seconds)
#define WATCHDOG_ENABLED        true

// OTA Update Settings
#define OTA_ENABLED             true
#define OTA_PASSWORD            "plantplant123"  // Change this in production!
#define OTA_PORT                8266

// Web Server Settings (for configuration interface)
#define WEB_SERVER_ENABLED      true
#define WEB_SERVER_PORT         80
#define CONFIG_PORTAL_TIMEOUT   180     // Configuration portal timeout (3 minutes)

// Error Handling
#define MAX_CONSECUTIVE_ERRORS  5       // Maximum consecutive errors before restart
#define ERROR_RECOVERY_DELAY    10000   // Delay before attempting recovery (10 seconds)

// Debug Settings
#ifdef DEBUG
    #define DEBUG_PRINT(x)      Serial.print(x)
    #define DEBUG_PRINTLN(x)    Serial.println(x)
    #define DEBUG_PRINTF(...)   Serial.printf(__VA_ARGS__)
#else
    #define DEBUG_PRINT(x)
    #define DEBUG_PRINTLN(x)
    #define DEBUG_PRINTF(...)
#endif

// Default Configuration Values
#define DEFAULT_MOISTURE_THRESHOLD_MIN  30  // Minimum moisture percentage for watering
#define DEFAULT_MOISTURE_THRESHOLD_MAX  80  // Maximum moisture percentage to stop watering
#define DEFAULT_TEMPERATURE_MIN         15  // Minimum temperature for operation
#define DEFAULT_TEMPERATURE_MAX         35  // Maximum temperature for operation

// JSON Buffer Sizes
#define JSON_BUFFER_SIZE        512
#define CONFIG_JSON_SIZE        1024

// Memory Management
#define HEAP_WARNING_THRESHOLD  10000   // Warn if free heap falls below this value

#endif // CONFIG_H