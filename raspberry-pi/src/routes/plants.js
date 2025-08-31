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
    range = '24h',
    interval = '5m'
  } = req.query;
  
  await plantService.getPlantById(id);
  
  const history = await influxService.getHistoricalData(id, range, interval);
  
  res.json({
    success: true,
    data: {
      plantId: id,
      range,
      interval,
      sensors: history
    },
    timestamp: new Date().toISOString()
  });
}));

// GET /api/plants/:id/watering/history - Get watering history
router.get('/:id/watering/history', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { range = '7d' } = req.query;
  
  await plantService.getPlantById(id);
  
  const wateringHistory = await influxService.getWateringHistory(id, range);
  
  res.json({
    success: true,
    data: {
      plantId: id,
      range,
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
  
  // Record watering event to InfluxDB
  influxService.writeWateringEvent(id, 'esp32-001', 'manual', duration, duration * 0.005, true, reason);
  
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

// GET /api/alerts/active - Get active alerts
router.get('/alerts/active', asyncHandler(async (req, res) => {
  const alerts = await influxService.getActiveAlerts();
  
  res.json({
    success: true,
    data: {
      alerts,
      count: alerts.length,
      timestamp: new Date().toISOString()
    }
  });
}));

// GET /api/plants/:id/anomalies - Get anomaly detection results
router.get('/:id/anomalies', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { sensor_type = 'moisture', hours = 24 } = req.query;
  
  await plantService.getPlantById(id);
  
  const anomalies = await influxService.detectAnomalies(id, sensor_type, hours);
  
  res.json({
    success: true,
    data: {
      plantId: id,
      sensorType: sensor_type,
      hours: parseInt(hours),
      anomalies,
      count: anomalies.length
    },
    timestamp: new Date().toISOString()
  });
}));

// GET /api/plants/:id/aggregates - Get daily aggregated data
router.get('/:id/aggregates', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { days = 7 } = req.query;
  
  await plantService.getPlantById(id);
  
  const aggregates = await influxService.getDailyAggregates(id, days);
  
  res.json({
    success: true,
    data: {
      plantId: id,
      days: parseInt(days),
      aggregates
    },
    timestamp: new Date().toISOString()
  });
}));

export default router;