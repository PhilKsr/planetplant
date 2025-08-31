import { logger, createTimer } from '../utils/logger.js';
import { sqliteService } from './sqliteService.js';
import { NotFoundError, ValidationError } from '../middleware/errorHandler.js';

class PlantService {
  constructor() {
    this.plants = new Map();
    this.deviceStatus = new Map();
    this.defaultConfig = {
      moistureThresholds: {
        min: parseInt(process.env.MOISTURE_THRESHOLD_MIN) || 30,
        max: parseInt(process.env.MOISTURE_THRESHOLD_MAX) || 80
      },
      temperatureThresholds: {
        min: parseInt(process.env.TEMPERATURE_MIN) || 15,
        max: parseInt(process.env.TEMPERATURE_MAX) || 35
      },
      wateringConfig: {
        duration: parseInt(process.env.PUMP_MAX_DURATION_MS) || 10000,
        maxDailyWaterings: 3,
        quietHours: {
          start: '22:00',
          end: '06:00'
        },
        cooldownMs: parseInt(process.env.PUMP_COOLDOWN_MS) || 300000
      },
      alertConfig: {
        lowMoisture: true,
        highTemperature: true,
        deviceOffline: true,
        wateringFailed: true
      }
    };
  }

  async initialize() {
    try {
      const timer = createTimer('plantService.initialize');
      
      logger.info('🌱 Initializing Plant Service...');
      
      // Load plants from configuration or create default plant
      await this.loadPlants();
      
      // Initialize device status tracking
      this.initializeDeviceTracking();
      
      timer.end();
      logger.info('🌱 Plant Service initialized successfully');
      
    } catch (error) {
      logger.error('Failed to initialize Plant Service:', error);
      throw error;
    }
  }

  async loadPlants() {
    // For now, create a default plant configuration
    // In a full implementation, this would load from a database or config file
    const defaultPlant = {
      id: 'plant-001',
      name: 'My Plant',
      type: 'houseplant',
      location: 'Living Room',
      deviceId: 'esp32-001',
      config: { ...this.defaultConfig },
      status: {
        isOnline: false,
        lastSeen: null,
        batteryLevel: null,
        wifiStrength: null
      },
      currentData: {
        temperature: null,
        humidity: null,
        moisture: null,
        light: null,
        lastUpdate: null
      },
      stats: {
        totalWaterings: 0,
        lastWatering: null,
        avgMoisture: null,
        alertsCount: 0
      },
      created: new Date().toISOString(),
      updated: new Date().toISOString()
    };

    this.plants.set(defaultPlant.id, defaultPlant);
    logger.info(`🌱 Loaded plant: ${defaultPlant.name} (${defaultPlant.id})`);
  }

  initializeDeviceTracking() {
    // Set up periodic device health checks
    setInterval(() => {
      this.checkDevicesHealth();
    }, 60000); // Check every minute
  }

  async checkDevicesHealth() {
    const now = Date.now();
    const offlineThreshold = 5 * 60 * 1000; // 5 minutes

    for (const [plantId, plant] of this.plants) {
      if (plant.status.lastSeen) {
        const lastSeenMs = new Date(plant.status.lastSeen).getTime();
        const isOffline = (now - lastSeenMs) > offlineThreshold;
        
        if (plant.status.isOnline && isOffline) {
          plant.status.isOnline = false;
          logger.warn(`🌱 Plant ${plant.name} (${plantId}) went offline`);
          
          // Broadcast status change
          if (global.io) {
            global.io.emit('plantStatus', {
              plantId,
              status: 'offline',
              timestamp: new Date().toISOString()
            });
          }
        }
      }
    }
  }

  async getAllPlants() {
    const timer = createTimer('plantService.getAllPlants');
    
    try {
      const plants = Array.from(this.plants.values());
      
      // Enrich with current sensor data from InfluxDB
      for (const plant of plants) {
        try {
          const currentData = await sqliteService.getCurrentSensorData(plant.id);
          if (Object.keys(currentData).length > 0) {
            plant.currentData = {
              ...plant.currentData,
              ...currentData,
              lastUpdate: new Date().toISOString()
            };
          }
        } catch (error) {
          logger.warn(`Failed to get current data for plant ${plant.id}:`, error.message);
        }
      }
      
      timer.end({ plantsCount: plants.length });
      return plants;
      
    } catch (error) {
      timer.end({ error: error.message });
      throw error;
    }
  }

  async getPlantById(plantId) {
    const timer = createTimer('plantService.getPlantById');
    
    try {
      const plant = this.plants.get(plantId);
      if (!plant) {
        throw new NotFoundError(`Plant with ID ${plantId} not found`);
      }

      // Get current sensor data
      try {
        const currentData = await sqliteService.getCurrentSensorData(plantId);
        if (Object.keys(currentData).length > 0) {
          plant.currentData = {
            ...plant.currentData,
            ...currentData,
            lastUpdate: new Date().toISOString()
          };
        }
      } catch (error) {
        logger.warn(`Failed to get current data for plant ${plantId}:`, error.message);
      }

      timer.end({ plantId });
      return { ...plant };
      
    } catch (error) {
      timer.end({ plantId, error: error.message });
      throw error;
    }
  }

  async updateSensorData(plantId, sensorData) {
    const timer = createTimer('plantService.updateSensorData');
    
    try {
      const plant = this.plants.get(plantId);
      if (!plant) {
        // Create new plant if it doesn't exist
        await this.createPlantFromSensorData(plantId, sensorData);
        timer.end({ plantId, created: true });
        return;
      }

      // Update current data
      plant.currentData = {
        ...plant.currentData,
        temperature: sensorData.temperature,
        humidity: sensorData.humidity,
        moisture: sensorData.moisture,
        light: sensorData.light || plant.currentData.light,
        lastUpdate: new Date().toISOString()
      };

      // Update plant status
      plant.status.lastSeen = new Date().toISOString();
      plant.status.isOnline = true;
      plant.updated = new Date().toISOString();

      // Log sensor data
      logger.logSensorData(plantId, sensorData);

      timer.end({ plantId });
      
    } catch (error) {
      timer.end({ plantId, error: error.message });
      throw error;
    }
  }

  async createPlantFromSensorData(plantId, sensorData) {
    const newPlant = {
      id: plantId,
      name: `Plant ${plantId}`,
      type: 'unknown',
      location: 'Unknown',
      deviceId: plantId,
      config: { ...this.defaultConfig },
      status: {
        isOnline: true,
        lastSeen: new Date().toISOString(),
        batteryLevel: null,
        wifiStrength: null
      },
      currentData: {
        temperature: sensorData.temperature,
        humidity: sensorData.humidity,
        moisture: sensorData.moisture,
        light: sensorData.light || null,
        lastUpdate: new Date().toISOString()
      },
      stats: {
        totalWaterings: 0,
        lastWatering: null,
        avgMoisture: null,
        alertsCount: 0
      },
      created: new Date().toISOString(),
      updated: new Date().toISOString()
    };

    this.plants.set(plantId, newPlant);
    logger.info(`🌱 Auto-created new plant: ${newPlant.name} (${plantId})`);
  }

  async updatePlantStatus(plantId, status) {
    const timer = createTimer('plantService.updatePlantStatus');
    
    try {
      const plant = this.plants.get(plantId);
      if (!plant) {
        logger.warn(`Received status update for unknown plant: ${plantId}`);
        return;
      }

      // Update status fields
      plant.status = {
        ...plant.status,
        ...status,
        lastSeen: new Date().toISOString(),
        isOnline: true
      };

      plant.updated = new Date().toISOString();

      logger.info(`🌱 Updated status for plant ${plant.name} (${plantId})`);
      timer.end({ plantId });
      
    } catch (error) {
      timer.end({ plantId, error: error.message });
      throw error;
    }
  }

  async updateDeviceHeartbeat(deviceId, heartbeat) {
    try {
      // Find plant by device ID
      const plant = Array.from(this.plants.values()).find(p => p.deviceId === deviceId);
      if (!plant) {
        return;
      }

      plant.status.lastSeen = new Date().toISOString();
      plant.status.isOnline = true;
      
      if (heartbeat.batteryLevel !== undefined) {
        plant.status.batteryLevel = heartbeat.batteryLevel;
      }
      
      if (heartbeat.wifiStrength !== undefined) {
        plant.status.wifiStrength = heartbeat.wifiStrength;
      }

    } catch (error) {
      logger.error(`Failed to update device heartbeat for ${deviceId}:`, error);
    }
  }

  async updatePlantConfig(plantId, configUpdate) {
    const timer = createTimer('plantService.updatePlantConfig');
    
    try {
      const plant = this.plants.get(plantId);
      if (!plant) {
        throw new NotFoundError(`Plant with ID ${plantId} not found`);
      }

      // Validate config update
      this.validateConfigUpdate(configUpdate);

      // Update configuration
      plant.config = {
        ...plant.config,
        ...configUpdate
      };

      plant.updated = new Date().toISOString();

      logger.info(`🌱 Updated config for plant ${plant.name} (${plantId})`);
      timer.end({ plantId });
      
      return { ...plant };
      
    } catch (error) {
      timer.end({ plantId, error: error.message });
      throw error;
    }
  }

  validateConfigUpdate(config) {
    const errors = [];

    if (config.moistureThresholds) {
      const { min, max } = config.moistureThresholds;
      if (min !== undefined && (min < 0 || min > 100)) {
        errors.push('Moisture threshold min must be between 0 and 100');
      }
      if (max !== undefined && (max < 0 || max > 100)) {
        errors.push('Moisture threshold max must be between 0 and 100');
      }
      if (min !== undefined && max !== undefined && min >= max) {
        errors.push('Moisture threshold min must be less than max');
      }
    }

    if (config.temperatureThresholds) {
      const { min, max } = config.temperatureThresholds;
      if (min !== undefined && (min < -50 || min > 100)) {
        errors.push('Temperature threshold min must be between -50 and 100');
      }
      if (max !== undefined && (max < -50 || max > 100)) {
        errors.push('Temperature threshold max must be between -50 and 100');
      }
      if (min !== undefined && max !== undefined && min >= max) {
        errors.push('Temperature threshold min must be less than max');
      }
    }

    if (config.wateringConfig?.duration !== undefined) {
      const duration = config.wateringConfig.duration;
      if (duration < 1000 || duration > 30000) {
        errors.push('Watering duration must be between 1000ms and 30000ms');
      }
    }

    if (errors.length > 0) {
      throw new ValidationError('Config validation failed', errors);
    }
  }

  async getPlantHistory(plantId, timeRange = '24h') {
    const timer = createTimer('plantService.getPlantHistory');
    
    try {
      const plant = this.plants.get(plantId);
      if (!plant) {
        throw new NotFoundError(`Plant with ID ${plantId} not found`);
      }

      const startTime = `-${timeRange}`;
      
      // Get sensor data history
      const sensorHistory = await sqliteService.getHistoricalSensorData(plantId, startTime);
      
      // Get watering history
      const wateringHistory = await sqliteService.getWateringHistory(plantId, startTime);

      const result = {
        plantId,
        timeRange,
        sensorData: sensorHistory,
        wateringEvents: wateringHistory,
        generatedAt: new Date().toISOString()
      };

      timer.end({ plantId, timeRange });
      return result;
      
    } catch (error) {
      timer.end({ plantId, timeRange, error: error.message });
      throw error;
    }
  }

  async recordWateringEvent(plantId, eventData) {
    const timer = createTimer('plantService.recordWateringEvent');
    
    try {
      const plant = this.plants.get(plantId);
      if (!plant) {
        throw new NotFoundError(`Plant with ID ${plantId} not found`);
      }

      // Update plant stats
      plant.stats.totalWaterings += 1;
      plant.stats.lastWatering = new Date().toISOString();
      plant.updated = new Date().toISOString();

      // Record in InfluxDB
      await sqliteService.writeWateringEvent(plantId, eventData);

      // Log the event
      logger.logWateringEvent(plantId, eventData);

      timer.end({ plantId });
      
    } catch (error) {
      timer.end({ plantId, error: error.message });
      throw error;
    }
  }

  needsWatering(plant) {
    if (!plant.currentData.moisture || typeof plant.currentData.moisture !== 'number') {
      return false;
    }

    const moistureLevel = plant.currentData.moisture;
    const threshold = plant.config.moistureThresholds.min;

    return moistureLevel < threshold;
  }

  canWater(plant) {
    const now = new Date();
    const hour = now.getHours();
    
    // Check quiet hours
    const quietStart = parseInt(plant.config.wateringConfig.quietHours.start.split(':')[0]);
    const quietEnd = parseInt(plant.config.wateringConfig.quietHours.end.split(':')[0]);
    
    if (hour >= quietStart || hour < quietEnd) {
      return { canWater: false, reason: 'quiet_hours' };
    }

    // Check daily watering limit
    const today = now.toISOString().split('T')[0];
    // This would need to query InfluxDB for today's watering count
    // For now, we'll assume it's okay
    
    // Check cooldown period
    if (plant.stats.lastWatering) {
      const lastWateringTime = new Date(plant.stats.lastWatering).getTime();
      const cooldownMs = plant.config.wateringConfig.cooldownMs;
      
      if (now.getTime() - lastWateringTime < cooldownMs) {
        return { canWater: false, reason: 'cooldown' };
      }
    }

    return { canWater: true, reason: null };
  }

  getPlantSummary() {
    const plants = Array.from(this.plants.values());
    
    return {
      totalPlants: plants.length,
      onlinePlants: plants.filter(p => p.status.isOnline).length,
      plantsNeedingWater: plants.filter(p => this.needsWatering(p)).length,
      totalWaterings: plants.reduce((sum, p) => sum + p.stats.totalWaterings, 0),
      lastUpdate: new Date().toISOString()
    };
  }
}

// Export singleton instance
export const plantService = new PlantService();

export { PlantService };