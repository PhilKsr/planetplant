import mqtt from 'mqtt';
import { logger } from '../utils/logger.js';
import { sqliteService } from './sqliteService.js';
import { plantService } from './plantService.js';
import { io } from '../app.js';

class MQTTClient {
  constructor() {
    this.client = null;
    this.isConnected = false;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = parseInt(process.env.MQTT_MAX_RETRY_COUNT) || 10;
    this.reconnectInterval = parseInt(process.env.MQTT_RECONNECT_INTERVAL) || 5000;
    
    this.topics = {
      // Incoming sensor data
      sensorData: 'sensors/+/data',
      sensorStatus: 'sensors/+/status',
      deviceHeartbeat: 'devices/+/heartbeat',
      
      // Outgoing commands
      waterCommand: 'commands/{plant_id}/water',
      configCommand: 'commands/{plant_id}/config',
      systemCommand: 'commands/system'
    };
  }

  async initialize() {
    const brokerUrl = `mqtt://${process.env.MQTT_HOST || 'localhost'}:${process.env.MQTT_PORT || 1883}`;
    
    const options = {
      clientId: process.env.MQTT_CLIENT_ID || `plantplant-server-${Date.now()}`,
      username: process.env.MQTT_USERNAME,
      password: process.env.MQTT_PASSWORD,
      keepalive: parseInt(process.env.MQTT_KEEPALIVE) || 60,
      connectTimeout: parseInt(process.env.MQTT_CONNECT_TIMEOUT) || 10000,
      reconnectPeriod: this.reconnectInterval,
      clean: true,
      will: {
        topic: 'server/status',
        payload: JSON.stringify({
          status: 'offline',
          timestamp: new Date().toISOString()
        }),
        qos: 1,
        retain: true
      }
    };

    try {
      this.client = mqtt.connect(brokerUrl, options);
      
      this.client.on('connect', this.onConnect.bind(this));
      this.client.on('message', this.onMessage.bind(this));
      this.client.on('error', this.onError.bind(this));
      this.client.on('close', this.onClose.bind(this));
      this.client.on('reconnect', this.onReconnect.bind(this));
      
      return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          reject(new Error('MQTT connection timeout'));
        }, options.connectTimeout);
        
        this.client.once('connect', () => {
          clearTimeout(timeout);
          resolve();
        });
        
        this.client.once('error', (error) => {
          clearTimeout(timeout);
          reject(error);
        });
      });
      
    } catch (error) {
      logger.error('MQTT initialization failed:', error);
      throw error;
    }
  }

  onConnect() {
    this.isConnected = true;
    this.reconnectAttempts = 0;
    logger.info('📡 MQTT Client connected to broker');
    
    this.subscribeToTopics();
    
    this.publishStatus('online');
  }

  subscribeToTopics() {
    const subscriptions = [
      { topic: this.topics.sensorData, qos: 1 },
      { topic: this.topics.sensorStatus, qos: 1 },
      { topic: this.topics.deviceHeartbeat, qos: 0 }
    ];

    subscriptions.forEach(({ topic, qos }) => {
      this.client.subscribe(topic, { qos }, (error) => {
        if (error) {
          logger.error(`Failed to subscribe to ${topic}:`, error);
        } else {
          logger.info(`📡 Subscribed to: ${topic}`);
        }
      });
    });
  }

  async onMessage(topic, message) {
    try {
      const payload = JSON.parse(message.toString());
      const topicParts = topic.split('/');
      
      logger.debug(`📡 MQTT Message received on ${topic}:`, payload);
      
      switch (true) {
        case topic.startsWith('sensors/') && topic.endsWith('/data'):
          await this.handleSensorData(topicParts[1], payload);
          break;
          
        case topic.startsWith('sensors/') && topic.endsWith('/status'):
          await this.handleSensorStatus(topicParts[1], payload);
          break;
          
        case topic.startsWith('devices/') && topic.endsWith('/heartbeat'):
          await this.handleDeviceHeartbeat(topicParts[1], payload);
          break;
          
        default:
          logger.warn(`📡 Unhandled MQTT topic: ${topic}`);
      }
      
    } catch (error) {
      logger.error(`📡 Error processing MQTT message on ${topic}:`, error);
    }
  }

  async handleSensorData(plantId, data) {
    try {
      // Validate sensor data
      if (!this.validateSensorData(data)) {
        logger.warn(`📡 Invalid sensor data for plant ${plantId}:`, data);
        return;
      }

      // Store in InfluxDB
      await sqliteService.writeSensorData(plantId, data);
      
      // Update plant service
      await plantService.updateSensorData(plantId, data);
      
      // Broadcast to WebSocket clients
      if (global.io) {
        global.io.emit('sensorData', {
          plantId,
          data,
          timestamp: new Date().toISOString()
        });
      }
      
      logger.debug(`📊 Processed sensor data for plant ${plantId}`);
      
    } catch (error) {
      logger.error(`📡 Error handling sensor data for plant ${plantId}:`, error);
    }
  }

  async handleSensorStatus(plantId, status) {
    try {
      // Update plant status
      await plantService.updatePlantStatus(plantId, status);
      
      // Broadcast status update
      if (global.io) {
        global.io.emit('plantStatus', {
          plantId,
          status,
          timestamp: new Date().toISOString()
        });
      }
      
      logger.info(`📡 Plant ${plantId} status updated:`, status);
      
    } catch (error) {
      logger.error(`📡 Error handling sensor status for plant ${plantId}:`, error);
    }
  }

  async handleDeviceHeartbeat(deviceId, heartbeat) {
    try {
      // Log heartbeat for monitoring
      logger.debug(`💓 Heartbeat from device ${deviceId}:`, heartbeat);
      
      // Update device last seen timestamp
      await plantService.updateDeviceHeartbeat(deviceId, heartbeat);
      
    } catch (error) {
      logger.error(`📡 Error handling device heartbeat for ${deviceId}:`, error);
    }
  }

  validateSensorData(data) {
    const requiredFields = ['temperature', 'humidity', 'moisture'];
    const numericFields = ['temperature', 'humidity', 'moisture'];
    
    // Check if all required fields are present
    for (const field of requiredFields) {
      if (!(field in data)) {
        return false;
      }
    }
    
    // Check if numeric fields are valid numbers
    for (const field of numericFields) {
      if (typeof data[field] !== 'number' || isNaN(data[field])) {
        return false;
      }
    }
    
    // Validate ranges
    if (data.temperature < -50 || data.temperature > 100) return false;
    if (data.humidity < 0 || data.humidity > 100) return false;
    if (data.moisture < 0 || data.moisture > 100) return false;
    
    return true;
  }

  publishWateringCommand(plantId, duration = 5000) {
    const topic = this.topics.waterCommand.replace('{plant_id}', plantId);
    const payload = {
      command: 'water',
      duration,
      timestamp: new Date().toISOString()
    };
    
    this.publish(topic, payload, 1);
    logger.info(`💧 Sent watering command to plant ${plantId} for ${duration}ms`);
  }

  publishConfigUpdate(plantId, config) {
    const topic = this.topics.configCommand.replace('{plant_id}', plantId);
    const payload = {
      command: 'config',
      config,
      timestamp: new Date().toISOString()
    };
    
    this.publish(topic, payload, 1);
    logger.info(`⚙️ Sent config update to plant ${plantId}:`, config);
  }

  publishSystemCommand(command, data = {}) {
    const payload = {
      command,
      data,
      timestamp: new Date().toISOString()
    };
    
    this.publish(this.topics.systemCommand, payload, 1);
    logger.info(`🔧 Sent system command: ${command}`, data);
  }

  publish(topic, payload, qos = 0) {
    if (!this.isConnected) {
      logger.error('📡 Cannot publish: MQTT client not connected');
      return false;
    }
    
    try {
      const message = typeof payload === 'string' ? payload : JSON.stringify(payload);
      
      this.client.publish(topic, message, { qos, retain: false }, (error) => {
        if (error) {
          logger.error(`📡 Failed to publish to ${topic}:`, error);
        } else {
          logger.debug(`📡 Published to ${topic}:`, payload);
        }
      });
      
      return true;
    } catch (error) {
      logger.error(`📡 Error publishing to ${topic}:`, error);
      return false;
    }
  }

  publishStatus(status) {
    const payload = {
      status,
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage()
    };
    
    this.publish('server/status', payload, 1);
  }

  onError(error) {
    logger.error('📡 MQTT Client error:', error);
    this.isConnected = false;
  }

  onClose() {
    logger.warn('📡 MQTT Client disconnected');
    this.isConnected = false;
  }

  onReconnect() {
    this.reconnectAttempts++;
    logger.info(`📡 MQTT Client reconnecting... (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);
    
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      logger.error('📡 Max reconnect attempts reached. Giving up.');
      this.client.end();
    }
  }

  async disconnect() {
    if (this.client) {
      this.publishStatus('offline');
      
      return new Promise((resolve) => {
        this.client.end(false, () => {
          logger.info('📡 MQTT Client disconnected gracefully');
          resolve();
        });
      });
    }
  }

  getConnectionStatus() {
    return {
      connected: this.isConnected,
      reconnectAttempts: this.reconnectAttempts,
      clientId: this.client?.options?.clientId || null
    };
  }
}

// Export singleton instance
export const mqttClient = new MQTTClient();

// Make io available globally for MQTT service
let ioInstance = null;

export const setIO = (io) => {
  ioInstance = io;
  global.io = io;
};

export { MQTTClient };