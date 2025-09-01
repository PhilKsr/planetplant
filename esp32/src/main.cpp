/*
 * PlanetPlant ESP32 Controller
 * Smart IoT Plant Watering System
 * 
 * Hardware:
 * - ESP32 DevKit v1
 * - Capacitive soil moisture sensor
 * - DHT22 temperature/humidity sensor
 * - Water pump with relay
 * - Optional: Light sensor (LDR)
 */

#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <ArduinoJson.h>
#include <WiFiManager.h>
#include "config.h"

// Pin Definitions
#define DHT_PIN 4
#define MOISTURE_PIN A0
#define PUMP_RELAY_PIN 5
#define LIGHT_SENSOR_PIN A3
#define LED_PIN 2
#define BUTTON_PIN 0

// Sensor Configuration
#define DHT_TYPE DHT22
#define MOISTURE_SAMPLES 10
#define SENSOR_READ_INTERVAL 60000  // 1 minute
#define HEARTBEAT_INTERVAL 300000   // 5 minutes

// WiFi and MQTT
WiFiClient espClient;
PubSubClient client(espClient);
DHT dht(DHT_PIN, DHT_TYPE);

// Device Configuration
String deviceId = "esp32_" + String((uint32_t)ESP.getEfuseMac(), HEX);
String mqttClientId = "plantplant_" + deviceId;

// Timing variables
unsigned long lastSensorReading = 0;
unsigned long lastHeartbeat = 0;
unsigned long pumpStartTime = 0;
bool pumpActive = false;

// Sensor data structure
struct SensorData {
  float temperature;
  float humidity;
  int moisture;
  int lightLevel;
  bool isValid;
};

void setup() {
  Serial.begin(115200);
  Serial.println("🌱 PlanetPlant ESP32 Controller Starting...");
  
  // Initialize pins
  pinMode(PUMP_RELAY_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  digitalWrite(PUMP_RELAY_PIN, LOW);
  
  // Initialize sensors
  dht.begin();
  
  // Initialize WiFi with WiFiManager
  setupWiFi();
  
  // Initialize MQTT
  setupMQTT();
  
  Serial.println("✅ ESP32 Controller initialized successfully!");
  Serial.printf("📱 Device ID: %s\n", deviceId.c_str());
}

void loop() {
  // Maintain MQTT connection
  if (!client.connected()) {
    reconnectMQTT();
  }
  client.loop();
  
  // Handle pump timeout
  if (pumpActive && (millis() - pumpStartTime > WATERING_DURATION)) {
    stopPump();
  }
  
  // Read sensors periodically
  if (millis() - lastSensorReading > SENSOR_READ_INTERVAL) {
    SensorData data = readSensors();
    if (data.isValid) {
      publishSensorData(data);
    }
    lastSensorReading = millis();
  }
  
  // Send heartbeat
  if (millis() - lastHeartbeat > HEARTBEAT_INTERVAL) {
    publishHeartbeat();
    lastHeartbeat = millis();
  }
  
  // Handle manual button press
  if (digitalRead(BUTTON_PIN) == LOW) {
    delay(50); // Debounce
    if (digitalRead(BUTTON_PIN) == LOW) {
      manualWatering();
      while (digitalRead(BUTTON_PIN) == LOW) delay(10);
    }
  }
  
  delay(100);
}

void setupWiFi() {
  WiFiManager wm;
  
  // LED indicates WiFi setup mode
  digitalWrite(LED_PIN, HIGH);
  
  // Reset settings for testing (comment out for production)
  // wm.resetSettings();
  
  Serial.println("🔌 Setting up WiFi connection...");
  
  // Set custom parameters
  wm.setAPName("PlanetPlant-Setup");
  wm.setAPPassword("plantplant123");
  wm.setConfigPortalTimeout(300); // 5 minutes timeout
  
  // Add custom parameters
  WiFiManagerParameter custom_mqtt_server("server", "MQTT Server", MQTT_SERVER, 40);
  WiFiManagerParameter custom_device_name("device", "Device Name", "PlanetPlant ESP32", 32);
  
  wm.addParameter(&custom_mqtt_server);
  wm.addParameter(&custom_device_name);
  
  // Attempt to connect
  if (!wm.autoConnect()) {
    Serial.println("❌ Failed to connect to WiFi, restarting...");
    ESP.restart();
  }
  
  digitalWrite(LED_PIN, LOW);
  Serial.println("✅ WiFi connected!");
  Serial.printf("📶 IP Address: %s\n", WiFi.localIP().toString().c_str());
}

void setupMQTT() {
  client.setServer(MQTT_SERVER, MQTT_PORT);
  client.setCallback(mqttCallback);
  client.setKeepAlive(60);
  client.setSocketTimeout(30);
  
  Serial.printf("🔗 MQTT Server: %s:%d\n", MQTT_SERVER, MQTT_PORT);
}

void reconnectMQTT() {
  int retryCount = 0;
  while (!client.connected() && retryCount < 5) {
    Serial.printf("🔄 Attempting MQTT connection (attempt %d)...\n", retryCount + 1);
    
    if (client.connect(mqttClientId.c_str(), MQTT_USER, MQTT_PASS)) {
      Serial.println("✅ MQTT connected!");
      
      // Subscribe to command topics
      String waterTopic = "commands/" + deviceId + "/water";
      String configTopic = "commands/" + deviceId + "/config";
      
      client.subscribe(waterTopic.c_str());
      client.subscribe(configTopic.c_str());
      
      Serial.printf("📡 Subscribed to: %s\n", waterTopic.c_str());
      Serial.printf("📡 Subscribed to: %s\n", configTopic.c_str());
      
      // Publish online status
      publishStatus("online");
      
    } else {
      Serial.printf("❌ MQTT connection failed, rc=%d\n", client.state());
      retryCount++;
      delay(5000);
    }
  }
  
  if (!client.connected()) {
    Serial.println("🔄 MQTT connection failed, continuing without MQTT...");
  }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  Serial.printf("📨 Received: %s -> %s\n", topic, message.c_str());
  
  String topicStr = String(topic);
  
  // Handle watering commands
  if (topicStr.indexOf("/water") > 0) {
    DynamicJsonDocument doc(256);
    deserializeJson(doc, message);
    
    if (doc["action"] == "start") {
      int duration = doc["duration"] | WATERING_DURATION;
      startPump(duration);
    } else if (doc["action"] == "stop") {
      stopPump();
    }
  }
  
  // Handle configuration updates
  if (topicStr.indexOf("/config") > 0) {
    // Handle configuration updates here
    Serial.println("📝 Configuration update received");
  }
}

SensorData readSensors() {
  SensorData data;
  data.isValid = true;
  
  // Read DHT22 sensor
  data.temperature = dht.readTemperature();
  data.humidity = dht.readHumidity();
  
  // Validate DHT readings
  if (isnan(data.temperature) || isnan(data.humidity)) {
    Serial.println("❌ Failed to read DHT sensor!");
    data.isValid = false;
  }
  
  // Read moisture sensor (average of multiple readings)
  long moistureSum = 0;
  for (int i = 0; i < MOISTURE_SAMPLES; i++) {
    moistureSum += analogRead(MOISTURE_PIN);
    delay(10);
  }
  int rawMoisture = moistureSum / MOISTURE_SAMPLES;
  
  // Convert to percentage (calibrate these values for your sensor)
  data.moisture = map(rawMoisture, MOISTURE_DRY, MOISTURE_WET, 0, 100);
  data.moisture = constrain(data.moisture, 0, 100);
  
  // Read light sensor
  data.lightLevel = analogRead(LIGHT_SENSOR_PIN);
  data.lightLevel = map(data.lightLevel, 0, 4095, 0, 100);
  
  return data;
}

void publishSensorData(SensorData data) {
  DynamicJsonDocument doc(512);
  
  doc["device_id"] = deviceId;
  doc["timestamp"] = millis();
  doc["sensors"]["temperature"] = data.temperature;
  doc["sensors"]["humidity"] = data.humidity;
  doc["sensors"]["moisture"] = data.moisture;
  doc["sensors"]["light"] = data.lightLevel;
  doc["sensors"]["pump_active"] = pumpActive;
  doc["status"]["wifi_rssi"] = WiFi.RSSI();
  doc["status"]["free_heap"] = ESP.getFreeHeap();
  doc["status"]["uptime"] = millis();
  
  String payload;
  serializeJson(doc, payload);
  
  String topic = "sensors/" + deviceId + "/data";
  
  if (client.connected()) {
    if (client.publish(topic.c_str(), payload.c_str())) {
      Serial.printf("📊 Sensor data published: T=%.1f°C, H=%.1f%%, M=%d%%, L=%d%%\n", 
                   data.temperature, data.humidity, data.moisture, data.lightLevel);
      blinkLED(1, 100);
    } else {
      Serial.println("❌ Failed to publish sensor data");
    }
  } else {
    Serial.println("📡 MQTT not connected, sensor data not published");
  }
}

void publishHeartbeat() {
  DynamicJsonDocument doc(256);
  
  doc["device_id"] = deviceId;
  doc["timestamp"] = millis();
  doc["status"] = "online";
  doc["wifi_rssi"] = WiFi.RSSI();
  doc["free_heap"] = ESP.getFreeHeap();
  doc["uptime"] = millis();
  
  String payload;
  serializeJson(doc, payload);
  
  String topic = "devices/" + deviceId + "/heartbeat";
  
  if (client.connected()) {
    client.publish(topic.c_str(), payload.c_str());
    Serial.println("💓 Heartbeat sent");
  }
}

void publishStatus(String status) {
  DynamicJsonDocument doc(256);
  
  doc["device_id"] = deviceId;
  doc["timestamp"] = millis();
  doc["status"] = status;
  doc["ip_address"] = WiFi.localIP().toString();
  doc["wifi_rssi"] = WiFi.RSSI();
  
  String payload;
  serializeJson(doc, payload);
  
  String topic = "sensors/" + deviceId + "/status";
  
  if (client.connected()) {
    client.publish(topic.c_str(), payload.c_str());
    Serial.printf("📡 Status published: %s\n", status.c_str());
  }
}

void startPump(int duration) {
  if (pumpActive) {
    Serial.println("⚠️  Pump already active, ignoring command");
    return;
  }
  
  Serial.printf("💧 Starting pump for %d ms\n", duration);
  digitalWrite(PUMP_RELAY_PIN, HIGH);
  digitalWrite(LED_PIN, HIGH);
  pumpActive = true;
  pumpStartTime = millis();
  
  // Update watering duration if provided
  if (duration > 0 && duration <= 30000) { // Max 30 seconds
    // This would normally update a global variable, but we'll use the parameter
  }
  
  // Publish pump status
  publishPumpStatus("started", duration);
}

void stopPump() {
  if (!pumpActive) {
    return;
  }
  
  int actualDuration = millis() - pumpStartTime;
  Serial.printf("💧 Stopping pump after %d ms\n", actualDuration);
  
  digitalWrite(PUMP_RELAY_PIN, LOW);
  digitalWrite(LED_PIN, LOW);
  pumpActive = false;
  
  // Publish pump status
  publishPumpStatus("stopped", actualDuration);
}

void publishPumpStatus(String action, int duration) {
  DynamicJsonDocument doc(256);
  
  doc["device_id"] = deviceId;
  doc["timestamp"] = millis();
  doc["action"] = action;
  doc["duration"] = duration;
  doc["pump_active"] = pumpActive;
  
  String payload;
  serializeJson(doc, payload);
  
  String topic = "sensors/" + deviceId + "/pump";
  
  if (client.connected()) {
    client.publish(topic.c_str(), payload.c_str());
    Serial.printf("💧 Pump status published: %s (%dms)\n", action.c_str(), duration);
  }
}

void manualWatering() {
  Serial.println("🔘 Manual watering button pressed");
  startPump(WATERING_DURATION);
  blinkLED(3, 200);
}

void blinkLED(int times, int delayMs) {
  for (int i = 0; i < times; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(delayMs);
    digitalWrite(LED_PIN, LOW);
    delay(delayMs);
  }
}