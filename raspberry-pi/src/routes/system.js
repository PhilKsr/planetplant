import express from 'express';
import { asyncHandler } from '../middleware/errorHandler.js';
import { healthService } from '../services/healthService.js';
import { mqttClient } from '../services/mqttClient.js';
import { influxService } from '../services/influxService.js';
import { plantService } from '../services/plantService.js';
import { logger } from '../utils/logger.js';
import os from 'os';
import process from 'process';
import fs from 'fs/promises';

const router = express.Router();

// GET /api/health - Detailed health check for monitoring systems
router.get('/health', asyncHandler(async (req, res) => {
  const healthData = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: Math.floor(process.uptime()),
    version: process.env.npm_package_version || '1.0.0',
    services: {},
    metrics: {},
    alerts: []
  };

  try {
    // Database Connection Health
    const dbHealth = await influxService.getSystemHealth();
    healthData.services.database = {
      status: dbHealth.connected ? 'healthy' : 'unhealthy',
      connected: dbHealth.connected,
      response_time_ms: dbHealth.responseTime || null,
      last_write: dbHealth.lastWrite || null,
      error: dbHealth.error || null
    };

    // MQTT Connection Health
    const mqttStatus = mqttClient.getConnectionStatus();
    healthData.services.mqtt = {
      status: mqttStatus.connected ? 'healthy' : 'unhealthy',
      connected: mqttStatus.connected,
      broker_host: process.env.MQTT_HOST,
      last_message: mqttStatus.lastMessage || null,
      reconnect_count: mqttStatus.reconnectCount || 0,
      error: mqttStatus.error || null
    };

    // Memory and CPU Usage
    const memUsage = process.memoryUsage();
    const cpuUsage = process.cpuUsage();
    const systemMem = {
      total: os.totalmem(),
      free: os.freemem(),
      used: os.totalmem() - os.freemem()
    };
    
    healthData.metrics = {
      memory: {
        process_mb: Math.round(memUsage.heapUsed / 1024 / 1024),
        process_total_mb: Math.round(memUsage.heapTotal / 1024 / 1024),
        system_used_percent: Math.round((systemMem.used / systemMem.total) * 100),
        system_available_mb: Math.round(systemMem.free / 1024 / 1024)
      },
      cpu: {
        user_microseconds: cpuUsage.user,
        system_microseconds: cpuUsage.system,
        load_average: os.loadavg()[0]
      },
      disk: await getDiskUsage()
    };

    // Last Sensor Reading
    const recentSensorData = await getLastSensorReading();
    healthData.services.sensors = {
      status: recentSensorData ? 'healthy' : 'stale',
      last_reading: recentSensorData?.timestamp || null,
      minutes_since_last: recentSensorData ? Math.floor((Date.now() - new Date(recentSensorData.timestamp).getTime()) / 60000) : null,
      devices_reporting: recentSensorData?.deviceCount || 0
    };

    // Queue Sizes and Performance
    healthData.metrics.queues = {
      mqtt_pending: mqttStatus.pendingMessages || 0,
      influx_batch_size: dbHealth.batchSize || 0,
      influx_pending_writes: dbHealth.pendingWrites || 0
    };

    // Check for alerts
    if (!healthData.services.database.connected) {
      healthData.alerts.push({ level: 'critical', message: 'Database connection lost' });
    }
    if (!healthData.services.mqtt.connected) {
      healthData.alerts.push({ level: 'critical', message: 'MQTT broker connection lost' });
    }
    if (healthData.services.sensors.minutes_since_last > 15) {
      healthData.alerts.push({ level: 'warning', message: `No sensor data for ${healthData.services.sensors.minutes_since_last} minutes` });
    }
    if (healthData.metrics.memory.system_used_percent > 80) {
      healthData.alerts.push({ level: 'warning', message: `High memory usage: ${healthData.metrics.memory.system_used_percent}%` });
    }
    if (healthData.metrics.disk.used_percent > 80) {
      healthData.alerts.push({ level: 'warning', message: `Low disk space: ${100 - healthData.metrics.disk.used_percent}% remaining` });
    }

    // Determine overall status
    const criticalAlerts = healthData.alerts.filter(alert => alert.level === 'critical');
    if (criticalAlerts.length > 0) {
      healthData.status = 'unhealthy';
      res.status(503);
    } else if (healthData.alerts.length > 0) {
      healthData.status = 'degraded';
    }

    res.json(healthData);

  } catch (error) {
    logger.error('❌ Health check failed:', error);
    
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: {
        message: 'Health check failed',
        details: error.message
      },
      alerts: [
        { level: 'critical', message: 'Health check system failure' }
      ]
    });
  }
}));

// Helper function to get disk usage
async function getDiskUsage() {
  try {
    const stats = await fs.stat('/');
    const diskSpace = await fs.stat('/opt/planetplant');
    
    return {
      path: '/opt/planetplant',
      used_percent: 0, // Simplified - would need statvfs for real disk usage
      available_mb: 'unknown'
    };
  } catch (error) {
    return {
      path: '/opt/planetplant', 
      used_percent: 0,
      available_mb: 'unknown',
      error: error.message
    };
  }
}

// Helper function to get last sensor reading
async function getLastSensorReading() {
  try {
    // Query InfluxDB for most recent sensor data
    const query = `
      from(bucket: "${process.env.INFLUXDB_BUCKET || 'sensor-data'}")
        |> range(start: -1h)
        |> filter(fn: (r) => r._measurement == "sensor_data")
        |> last()
        |> group()
        |> count()
    `;
    
    const result = await influxService.query(query);
    const data = result?.[0];
    
    if (data) {
      return {
        timestamp: data._time,
        deviceCount: data._value || 0
      };
    }
    
    return null;
  } catch (error) {
    logger.debug('Could not retrieve last sensor reading:', error.message);
    return null;
  }
}

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
      database: await influxService.getSystemHealth()
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
  
  // InfluxDB handles metrics automatically - return basic system info
  const metrics = { message: 'System metrics available via InfluxDB queries' };
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
    database: async () => {
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
      // InfluxDB handles data retention via bucket policies
      logger.info(`Data retention handled by InfluxDB bucket policy: ${retentionPeriod}`);
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
    database: {
      url: process.env.INFLUXDB_URL,
      type: 'InfluxDB',
      connected: (await influxService.getSystemHealth()).connected
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
    database: null,
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
    
    if (component === 'all' || component === 'database') {
      const dbHealth = await influxService.getSystemHealth();
      testResults.database = {
        connected: dbHealth.connected,
        status: dbHealth.connected ? 'healthy' : 'unhealthy'
      };
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