import express from 'express';
import { asyncHandler } from '../middleware/errorHandler.js';
import { plantService } from '../services/plantService.js';
import { mqttClient } from '../services/mqttClient.js';
import { influxService } from '../services/influxService.js';
import { logger } from '../utils/logger.js';

const router = express.Router();

// GET /api/plants - Get all plants
router.get('/', asyncHandler(async (req, res) => {
  const plants = await plantService.getAllPlants();
  
  res.json({
    success: true,
    data: plants,
    count: plants.length,
    timestamp: new Date().toISOString()
  });
}));

// GET /api/plants/summary - Get plants summary
router.get('/summary', asyncHandler(async (req, res) => {
  const summary = plantService.getPlantSummary();
  
  res.json({
    success: true,
    data: summary,
    timestamp: new Date().toISOString()
  });
}));

// GET /api/plants/:id - Get specific plant
router.get('/:id', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const plant = await plantService.getPlantById(id);
  
  res.json({
    success: true,
    data: plant,
    timestamp: new Date().toISOString()
  });
}));

// GET /api/plants/:id/current - Get current sensor values
router.get('/:id/current', asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Ensure plant exists
  await plantService.getPlantById(id);
  
  const currentData = await influxService.getCurrentSensorData(id);
  
  res.json({
    success: true,
    data: {
      plantId: id,
      sensors: currentData,
      timestamp: new Date().toISOString()
    }
  });
}));

// GET /api/plants/:id/history - Get historical sensor data
router.get('/:id/history', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { 
    timeRange = '24h',
    sensors = 'all',
    limit = 1000
  } = req.query;
  
  // Validate time range
  const validTimeRanges = ['1h', '6h', '12h', '24h', '7d', '30d'];
  if (!validTimeRanges.includes(timeRange)) {
    return res.status(400).json({
      success: false,
      error: {
        message: 'Invalid time range',
        validValues: validTimeRanges
      }
    });
  }
  
  const history = await plantService.getPlantHistory(id, timeRange);
  
  // Filter sensors if specified
  if (sensors !== 'all') {
    const requestedSensors = sensors.split(',');
    const filteredData = {};
    
    requestedSensors.forEach(sensor => {
      if (history.sensorData[sensor]) {
        filteredData[sensor] = history.sensorData[sensor];
      }
    });
    
    history.sensorData = filteredData;
  }
  
  // Limit data points if specified
  if (limit && limit < 10000) {
    Object.keys(history.sensorData).forEach(sensorType => {
      if (history.sensorData[sensorType].length > limit) {
        // Take evenly spaced samples
        const step = Math.ceil(history.sensorData[sensorType].length / limit);
        history.sensorData[sensorType] = history.sensorData[sensorType]
          .filter((_, index) => index % step === 0);
      }
    });
  }
  
  res.json({
    success: true,
    data: history,
    meta: {
      timeRange,
      requestedSensors: sensors,
      limit: parseInt(limit)
    }
  });
}));

// GET /api/plants/:id/watering/history - Get watering history
router.get('/:id/watering/history', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { timeRange = '7d' } = req.query;
  
  // Ensure plant exists
  await plantService.getPlantById(id);
  
  const wateringHistory = await influxService.getWateringHistory(id, `-${timeRange}`);
  
  res.json({
    success: true,
    data: {
      plantId: id,
      timeRange,
      events: wateringHistory,
      count: wateringHistory.length
    }
  });
}));

// POST /api/plants/:id/water - Manual watering
router.post('/:id/water', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { 
    duration = 5000,
    reason = 'manual'
  } = req.body;
  
  // Validate duration
  if (duration < 1000 || duration > 30000) {
    return res.status(400).json({
      success: false,
      error: {
        message: 'Duration must be between 1000ms and 30000ms'
      }
    });
  }
  
  const plant = await plantService.getPlantById(id);
  
  // Check if watering is allowed
  const { canWater, reason: cantWaterReason } = plantService.canWater(plant);
  
  if (!canWater) {
    return res.status(409).json({
      success: false,
      error: {
        message: 'Watering not allowed',
        reason: cantWaterReason
      }
    });
  }
  
  // Send MQTT command to ESP32
  const success = mqttClient.publishWateringCommand(id, duration);
  
  if (!success) {
    return res.status(503).json({
      success: false,
      error: {
        message: 'Failed to send watering command',
        reason: 'mqtt_not_connected'
      }
    });
  }
  
  // Record watering event
  const eventData = {
    duration,
    triggerType: 'manual',
    reason,
    success: true
  };
  
  await plantService.recordWateringEvent(id, eventData);
  
  logger.info(`💧 Manual watering initiated for plant ${plant.name} (${id})`);
  
  res.json({
    success: true,
    data: {
      plantId: id,
      duration,
      reason,
      timestamp: new Date().toISOString(),
      message: 'Watering command sent successfully'
    }
  });
}));

// PUT /api/plants/:id/config - Update plant configuration
router.put('/:id/config', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const configUpdate = req.body;
  
  const updatedPlant = await plantService.updatePlantConfig(id, configUpdate);
  
  // Send config update to ESP32
  mqttClient.publishConfigUpdate(id, updatedPlant.config);
  
  logger.info(`⚙️ Configuration updated for plant ${updatedPlant.name} (${id})`);
  
  res.json({
    success: true,
    data: updatedPlant,
    message: 'Plant configuration updated successfully'
  });
}));

// PUT /api/plants/:id - Update plant details
router.put('/:id', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { name, type, location } = req.body;
  
  const plant = await plantService.getPlantById(id);
  
  // Update basic plant information
  if (name !== undefined) plant.name = name;
  if (type !== undefined) plant.type = type;
  if (location !== undefined) plant.location = location;
  
  plant.updated = new Date().toISOString();
  
  logger.info(`🌱 Plant details updated for ${plant.name} (${id})`);
  
  res.json({
    success: true,
    data: plant,
    message: 'Plant updated successfully'
  });
}));

// POST /api/plants/:id/calibrate - Calibrate sensors
router.post('/:id/calibrate', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { sensor, calibrationType } = req.body;
  
  // Validate input
  const validSensors = ['moisture', 'temperature', 'humidity'];
  const validCalibrationTypes = ['dry', 'wet', 'zero', 'span'];
  
  if (!validSensors.includes(sensor)) {
    return res.status(400).json({
      success: false,
      error: {
        message: 'Invalid sensor type',
        validValues: validSensors
      }
    });
  }
  
  if (!validCalibrationTypes.includes(calibrationType)) {
    return res.status(400).json({
      success: false,
      error: {
        message: 'Invalid calibration type',
        validValues: validCalibrationTypes
      }
    });
  }
  
  // Ensure plant exists
  await plantService.getPlantById(id);
  
  // Send calibration command via MQTT
  const calibrationCommand = {
    command: 'calibrate',
    sensor,
    type: calibrationType,
    timestamp: new Date().toISOString()
  };
  
  const success = mqttClient.publish(`commands/${id}/calibrate`, calibrationCommand, 1);
  
  if (!success) {
    return res.status(503).json({
      success: false,
      error: {
        message: 'Failed to send calibration command',
        reason: 'mqtt_not_connected'
      }
    });
  }
  
  logger.info(`🔧 Calibration command sent for ${sensor} sensor on plant ${id}`);
  
  res.json({
    success: true,
    data: {
      plantId: id,
      sensor,
      calibrationType,
      timestamp: new Date().toISOString()
    },
    message: 'Calibration command sent successfully'
  });
}));

// GET /api/plants/:id/recommendations - Get care recommendations
router.get('/:id/recommendations', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const plant = await plantService.getPlantById(id);
  
  const recommendations = [];
  const currentData = plant.currentData;
  const config = plant.config;
  
  // Moisture recommendations
  if (currentData.moisture !== null) {
    if (currentData.moisture < config.moistureThresholds.min) {
      recommendations.push({
        type: 'watering',
        priority: 'high',
        message: 'Soil moisture is low. Plant needs watering.',
        action: 'water',
        currentValue: currentData.moisture,
        threshold: config.moistureThresholds.min
      });
    } else if (currentData.moisture > config.moistureThresholds.max) {
      recommendations.push({
        type: 'watering',
        priority: 'medium',
        message: 'Soil moisture is high. Reduce watering frequency.',
        action: 'reduce_watering',
        currentValue: currentData.moisture,
        threshold: config.moistureThresholds.max
      });
    }
  }
  
  // Temperature recommendations
  if (currentData.temperature !== null) {
    if (currentData.temperature < config.temperatureThresholds.min) {
      recommendations.push({
        type: 'environment',
        priority: 'medium',
        message: 'Temperature is too low for optimal growth.',
        action: 'increase_temperature',
        currentValue: currentData.temperature,
        threshold: config.temperatureThresholds.min
      });
    } else if (currentData.temperature > config.temperatureThresholds.max) {
      recommendations.push({
        type: 'environment',
        priority: 'medium',
        message: 'Temperature is too high. Provide shade or ventilation.',
        action: 'decrease_temperature',
        currentValue: currentData.temperature,
        threshold: config.temperatureThresholds.max
      });
    }
  }
  
  // Device health recommendations
  if (!plant.status.isOnline) {
    recommendations.push({
      type: 'device',
      priority: 'high',
      message: 'Plant sensor is offline. Check device connection.',
      action: 'check_device',
      lastSeen: plant.status.lastSeen
    });
  }
  
  if (plant.status.batteryLevel !== null && plant.status.batteryLevel < 20) {
    recommendations.push({
      type: 'device',
      priority: 'medium',
      message: 'Device battery is low.',
      action: 'charge_battery',
      batteryLevel: plant.status.batteryLevel
    });
  }
  
  res.json({
    success: true,
    data: {
      plantId: id,
      plantName: plant.name,
      recommendations,
      count: recommendations.length,
      generatedAt: new Date().toISOString()
    }
  });
}));

export default router;