import express from 'express';
import { asyncHandler } from '../middleware/errorHandler.js';
import { healthService } from '../services/healthService.js';
import { mqttClient } from '../services/mqttClient.js';
import { influxService } from '../services/influxService.js';
import { plantService } from '../services/plantService.js';
import { logger } from '../utils/logger.js';
import os from 'os';
import process from 'process';

const router = express.Router();

// GET /api/system/status - Get complete system health status
router.get('/status', asyncHandler(async (req, res) => {
  const status = await healthService.getSystemStatus();
  
  res.json({
    success: true,
    data: status,
    timestamp: new Date().toISOString()
  });
}));

// GET /api/system/info - Get system information
router.get('/info', asyncHandler(async (req, res) => {
  const systemInfo = {
    application: {
      name: 'PlanetPlant Server',
      version: process.env.npm_package_version || '1.0.0',
      nodeVersion: process.version,
      platform: process.platform,
      arch: process.arch,
      environment: process.env.NODE_ENV || 'development'
    },
    system: {
      hostname: os.hostname(),
      uptime: Math.floor(os.uptime()),
      loadAverage: os.loadavg(),
      totalMemory: os.totalmem(),
      freeMemory: os.freemem(),
      cpus: os.cpus().length,
      networkInterfaces: Object.keys(os.networkInterfaces())
    },
    process: {
      pid: process.pid,
      uptime: Math.floor(process.uptime()),
      memoryUsage: process.memoryUsage(),
      cpuUsage: process.cpuUsage()
    },
    services: {
      mqtt: mqttClient.getConnectionStatus(),
      influxdb: influxService.getConnectionStatus()
    }
  };

  res.json({
    success: true,
    data: systemInfo,
    timestamp: new Date().toISOString()
  });
}));

// GET /api/system/metrics - Get system metrics
router.get('/metrics', asyncHandler(async (req, res) => {
  const { timeRange = '1h' } = req.query;
  
  const metrics = await influxService.getSystemMetrics(`-${timeRange}`);
  const plantsSummary = plantService.getPlantSummary();
  
  const systemMetrics = {
    plants: plantsSummary,
    events: metrics,
    system: {
      memoryUsage: process.memoryUsage(),
      cpuUsage: process.cpuUsage(),
      uptime: process.uptime(),
      loadAverage: os.loadavg()[0] // 1-minute load average
    },
    timestamp: new Date().toISOString()
  };

  res.json({
    success: true,
    data: systemMetrics,
    meta: {
      timeRange
    }
  });
}));

// GET /api/system/logs - Get recent logs
router.get('/logs', asyncHandler(async (req, res) => {
  const { 
    level = 'info',
    limit = 100,
    service = null
  } = req.query;
  
  // This would require implementing a log retrieval mechanism
  // For now, return a simple response
  const logs = {
    message: 'Log retrieval not yet implemented',
    suggestion: 'Use PM2 logs or check log files directly',
    logLocations: [
      '/home/pi/PlanetPlant/raspberry-pi/logs/',
      'pm2 logs plantplant-server'
    ]
  };

  res.json({
    success: true,
    data: logs,
    meta: {
      level,
      limit,
      service
    }
  });
}));

// POST /api/system/restart - Restart services
router.post('/restart', asyncHandler(async (req, res) => {
  const { service = 'all' } = req.body;
  
  logger.warn(`🔄 System restart requested for: ${service}`);
  
  const restartCommands = {
    mqtt: async () => {
      await mqttClient.disconnect();
      await mqttClient.initialize();
      return 'MQTT service restarted';
    },
    influxdb: async () => {
      await influxService.close();
      await influxService.initialize();
      return 'InfluxDB service restarted';
    },
    all: async () => {
      // This would trigger a full application restart
      // For safety, we'll just restart connections
      await mqttClient.disconnect();
      await influxService.close();
      
      await mqttClient.initialize();
      await influxService.initialize();
      
      return 'All services restarted';
    }
  };
  
  if (!restartCommands[service]) {
    return res.status(400).json({
      success: false,
      error: {
        message: 'Invalid service',
        validServices: Object.keys(restartCommands)
      }
    });
  }
  
  try {
    const message = await restartCommands[service]();
    
    logger.info(`✅ ${message}`);
    
    res.json({
      success: true,
      data: {
        service,
        message,
        timestamp: new Date().toISOString()
      }
    });
    
  } catch (error) {
    logger.error(`❌ Failed to restart ${service}:`, error);
    
    res.status(500).json({
      success: false,
      error: {
        message: `Failed to restart ${service}`,
        details: error.message
      }
    });
  }
}));

// POST /api/system/cleanup - Clean up old data
router.post('/cleanup', asyncHandler(async (req, res) => {
  const { 
    retentionPeriod = '30d',
    dryRun = false
  } = req.body;
  
  logger.info(`🧹 Data cleanup ${dryRun ? 'simulation' : 'execution'} started`);
  
  try {
    if (!dryRun) {
      await influxService.deleteOldData(retentionPeriod);
    }
    
    // Get cleanup statistics
    const stats = {
      retentionPeriod,
      dryRun,
      timestamp: new Date().toISOString(),
      message: dryRun ? 'Cleanup simulation completed' : 'Data cleanup completed'
    };
    
    logger.info(`✅ Data cleanup completed`);
    
    res.json({
      success: true,
      data: stats
    });
    
  } catch (error) {
    logger.error('❌ Data cleanup failed:', error);
    
    res.status(500).json({
      success: false,
      error: {
        message: 'Data cleanup failed',
        details: error.message
      }
    });
  }
}));

// GET /api/system/config - Get system configuration
router.get('/config', asyncHandler(async (req, res) => {
  const config = {
    mqtt: {
      host: process.env.MQTT_HOST,
      port: process.env.MQTT_PORT,
      connected: mqttClient.getConnectionStatus().connected
    },
    influxdb: {
      url: process.env.INFLUXDB_URL,
      bucket: process.env.INFLUXDB_BUCKET,
      org: process.env.INFLUXDB_ORG,
      connected: influxService.getConnectionStatus().connected
    },
    watering: {
      enabled: process.env.ENABLE_AUTO_WATERING !== 'false',
      maxDuration: process.env.PUMP_MAX_DURATION_MS || 10000,
      cooldown: process.env.PUMP_COOLDOWN_MS || 300000
    },
    alerts: {
      email: process.env.EMAIL_ENABLED === 'true',
      notifications: process.env.ENABLE_PUSH_NOTIFICATIONS === 'true'
    },
    features: {
      scheduler: process.env.ENABLE_SCHEDULER === 'true',
      weatherIntegration: process.env.ENABLE_WEATHER_INTEGRATION === 'true',
      autoWatering: process.env.ENABLE_AUTO_WATERING !== 'false'
    }
  };

  res.json({
    success: true,
    data: config,
    timestamp: new Date().toISOString()
  });
}));

// POST /api/system/test - Run system tests
router.post('/test', asyncHandler(async (req, res) => {
  const { component = 'all' } = req.body;
  
  const testResults = {
    mqtt: null,
    influxdb: null,
    redis: null,
    overall: null
  };
  
  try {
    if (component === 'all' || component === 'mqtt') {
      testResults.mqtt = {
        connected: mqttClient.getConnectionStatus().connected,
        status: mqttClient.getConnectionStatus().connected ? 'healthy' : 'unhealthy'
      };
    }
    
    if (component === 'all' || component === 'influxdb') {
      try {
        await influxService.testConnection();
        testResults.influxdb = {
          connected: true,
          status: 'healthy'
        };
      } catch (error) {
        testResults.influxdb = {
          connected: false,
          status: 'unhealthy',
          error: error.message
        };
      }
    }
    
    // Determine overall status
    const allTests = Object.values(testResults).filter(test => test !== null);
    const healthyCount = allTests.filter(test => test.status === 'healthy').length;
    
    testResults.overall = {
      status: healthyCount === allTests.length ? 'healthy' : 'unhealthy',
      healthyServices: healthyCount,
      totalServices: allTests.length,
      timestamp: new Date().toISOString()
    };
    
    logger.info('🔍 System tests completed', testResults.overall);
    
    res.json({
      success: true,
      data: testResults
    });
    
  } catch (error) {
    logger.error('❌ System tests failed:', error);
    
    res.status(500).json({
      success: false,
      error: {
        message: 'System tests failed',
        details: error.message
      }
    });
  }
}));

export default router;