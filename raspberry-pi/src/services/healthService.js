import os from 'os';
import { logger, createTimer } from '../utils/logger.js';
import { mqttClient } from './mqttClient.js';
import { sqliteService } from './sqliteService.js';
import { plantService } from './plantService.js';
import { automationService } from './automationService.js';

class HealthService {
  constructor() {
    this.isMonitoring = false;
    this.healthCheckInterval = null;
    this.healthHistory = [];
    this.maxHistoryLength = 100;
    
    this.thresholds = {
      memoryUsage: 90, // Percentage
      diskUsage: 85,   // Percentage
      cpuLoad: 80,     // Percentage
      temperature: 75, // Celsius (for Raspberry Pi)
      responseTime: 2000 // Milliseconds
    };
  }

  start() {
    if (this.isMonitoring) {
      logger.warn('💊 Health Service is already running');
      return;
    }

    try {
      this.healthCheckInterval = setInterval(() => {
        this.performHealthCheck();
      }, 60000); // Check every minute

      this.isMonitoring = true;
      logger.info('💊 Health Service started');
      
    } catch (error) {
      logger.error('❌ Failed to start Health Service:', error);
      throw error;
    }
  }

  stop() {
    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval);
      this.healthCheckInterval = null;
    }

    this.isMonitoring = false;
    logger.info('💊 Health Service stopped');
  }

  async performHealthCheck() {
    const timer = createTimer('health.performHealthCheck');
    
    try {
      const healthStatus = {
        timestamp: new Date().toISOString(),
        overall: 'healthy',
        components: {},
        system: {},
        alerts: []
      };

      // Check system components
      healthStatus.components.mqtt = await this.checkMQTTHealth();
      healthStatus.components.database = await this.checkDatabaseHealth();
      healthStatus.components.automation = this.checkAutomationHealth();
      healthStatus.components.plants = await this.checkPlantsHealth();

      // Check system resources
      healthStatus.system = await this.checkSystemResources();

      // Determine overall health
      const componentStatuses = Object.values(healthStatus.components);
      const systemHealth = healthStatus.system.status;
      
      if (componentStatuses.some(comp => comp.status === 'unhealthy') || systemHealth === 'unhealthy') {
        healthStatus.overall = 'unhealthy';
      } else if (componentStatuses.some(comp => comp.status === 'degraded') || systemHealth === 'degraded') {
        healthStatus.overall = 'degraded';
      }

      // Generate alerts
      healthStatus.alerts = this.generateAlerts(healthStatus);

      // Store in history
      this.addToHealthHistory(healthStatus);

      // Log health status
      logger.logHealth('system', healthStatus.overall, {
        components: Object.keys(healthStatus.components).length,
        alerts: healthStatus.alerts.length
      });

      timer.end({ 
        status: healthStatus.overall,
        alerts: healthStatus.alerts.length 
      });
      
      return healthStatus;
      
    } catch (error) {
      timer.end({ error: error.message });
      logger.error('❌ Health check failed:', error);
      
      return {
        timestamp: new Date().toISOString(),
        overall: 'unhealthy',
        error: error.message
      };
    }
  }

  async checkMQTTHealth() {
    const timer = createTimer('health.checkMQTTHealth');
    
    try {
      const mqttStatus = mqttClient.getConnectionStatus();
      
      const health = {
        status: mqttStatus.connected ? 'healthy' : 'unhealthy',
        connected: mqttStatus.connected,
        clientId: mqttStatus.clientId,
        reconnectAttempts: mqttStatus.reconnectAttempts,
        lastCheck: new Date().toISOString()
      };

      timer.end({ status: health.status });
      return health;
      
    } catch (error) {
      timer.end({ error: error.message });
      return {
        status: 'unhealthy',
        error: error.message,
        lastCheck: new Date().toISOString()
      };
    }
  }

  async checkDatabaseHealth() {
    const timer = createTimer('health.checkDatabaseHealth');
    
    try {
      const databaseStatus = sqliteService.getConnectionStatus();
      
      // Test database with a simple query
      const startTime = Date.now();
      const stats = sqliteService.getStats();
      const responseTime = Date.now() - startTime;

      const health = {
        status: databaseStatus.connected ? 'healthy' : 'unhealthy',
        connected: databaseStatus.connected,
        responseTime: `${responseTime}ms`,
        path: databaseStatus.path,
        type: databaseStatus.type,
        stats,
        lastCheck: new Date().toISOString()
      };

      // Check response time
      if (responseTime > this.thresholds.responseTime) {
        health.status = 'degraded';
        health.warning = 'High response time';
      }

      timer.end({ status: health.status, responseTime });
      return health;
      
    } catch (error) {
      timer.end({ error: error.message });
      return {
        status: 'unhealthy',
        error: error.message,
        lastCheck: new Date().toISOString()
      };
    }
  }

  checkAutomationHealth() {
    try {
      const automationStatus = automationService.getAutomationStatus();
      
      return {
        status: automationStatus.isRunning ? 'healthy' : 'unhealthy',
        running: automationStatus.isRunning,
        scheduledJobs: automationStatus.scheduledJobs.length,
        stats: automationStatus.stats,
        lastCheck: new Date().toISOString()
      };
      
    } catch (error) {
      return {
        status: 'unhealthy',
        error: error.message,
        lastCheck: new Date().toISOString()
      };
    }
  }

  async checkPlantsHealth() {
    const timer = createTimer('health.checkPlantsHealth');
    
    try {
      const plantsSummary = plantService.getPlantSummary();
      const plants = await plantService.getAllPlants();
      
      const offlinePlants = plants.filter(p => !p.status.isOnline).length;
      const plantsNeedingWater = plants.filter(p => plantService.needsWatering(p)).length;
      
      let status = 'healthy';
      const warnings = [];
      
      if (offlinePlants > 0) {
        status = 'degraded';
        warnings.push(`${offlinePlants} plants offline`);
      }
      
      if (plantsNeedingWater > plants.length * 0.5) {
        status = 'degraded';
        warnings.push(`${plantsNeedingWater} plants need watering`);
      }

      const health = {
        status,
        totalPlants: plantsSummary.totalPlants,
        onlinePlants: plantsSummary.onlinePlants,
        plantsNeedingWater: plantsSummary.plantsNeedingWater,
        warnings,
        lastCheck: new Date().toISOString()
      };

      timer.end({ status, totalPlants: plantsSummary.totalPlants });
      return health;
      
    } catch (error) {
      timer.end({ error: error.message });
      return {
        status: 'unhealthy',
        error: error.message,
        lastCheck: new Date().toISOString()
      };
    }
  }

  async checkSystemResources() {
    const timer = createTimer('health.checkSystemResources');
    
    try {
      const memoryUsage = process.memoryUsage();
      const totalMemory = os.totalmem();
      const freeMemory = os.freemem();
      const usedMemory = totalMemory - freeMemory;
      const memoryUsagePercent = (usedMemory / totalMemory) * 100;
      
      const loadAverage = os.loadavg();
      const cpuCount = os.cpus().length;
      const cpuLoadPercent = (loadAverage[0] / cpuCount) * 100;
      
      let status = 'healthy';
      const warnings = [];
      
      if (memoryUsagePercent > this.thresholds.memoryUsage) {
        status = 'unhealthy';
        warnings.push(`High memory usage: ${memoryUsagePercent.toFixed(1)}%`);
      } else if (memoryUsagePercent > this.thresholds.memoryUsage * 0.8) {
        status = 'degraded';
        warnings.push(`Elevated memory usage: ${memoryUsagePercent.toFixed(1)}%`);
      }
      
      if (cpuLoadPercent > this.thresholds.cpuLoad) {
        status = 'unhealthy';
        warnings.push(`High CPU load: ${cpuLoadPercent.toFixed(1)}%`);
      } else if (cpuLoadPercent > this.thresholds.cpuLoad * 0.8) {
        status = 'degraded';
        warnings.push(`Elevated CPU load: ${cpuLoadPercent.toFixed(1)}%`);
      }

      const systemHealth = {
        status,
        warnings,
        memory: {
          usage: `${memoryUsagePercent.toFixed(1)}%`,
          used: Math.round(usedMemory / 1024 / 1024),
          total: Math.round(totalMemory / 1024 / 1024),
          process: {
            rss: Math.round(memoryUsage.rss / 1024 / 1024),
            heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024),
            heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024)
          }
        },
        cpu: {
          load: `${cpuLoadPercent.toFixed(1)}%`,
          loadAverage: loadAverage.map(avg => avg.toFixed(2)),
          cores: cpuCount
        },
        uptime: {
          system: Math.floor(os.uptime()),
          process: Math.floor(process.uptime())
        },
        lastCheck: new Date().toISOString()
      };

      timer.end({ status });
      return systemHealth;
      
    } catch (error) {
      timer.end({ error: error.message });
      return {
        status: 'unhealthy',
        error: error.message,
        lastCheck: new Date().toISOString()
      };
    }
  }

  generateAlerts(healthStatus) {
    const alerts = [];
    
    // Component alerts
    Object.entries(healthStatus.components).forEach(([component, health]) => {
      if (health.status === 'unhealthy') {
        alerts.push({
          type: 'component',
          severity: 'critical',
          component,
          message: `${component} service is unhealthy`,
          details: health.error || 'Service not responding'
        });
      } else if (health.status === 'degraded') {
        alerts.push({
          type: 'component',
          severity: 'warning',
          component,
          message: `${component} service is degraded`,
          details: health.warning || 'Performance issues detected'
        });
      }
    });

    // System resource alerts
    if (healthStatus.system.warnings) {
      healthStatus.system.warnings.forEach(warning => {
        alerts.push({
          type: 'system',
          severity: healthStatus.system.status === 'unhealthy' ? 'critical' : 'warning',
          component: 'system',
          message: warning,
          details: 'System resource usage is high'
        });
      });
    }

    // Plant-specific alerts
    if (healthStatus.components.plants?.warnings) {
      healthStatus.components.plants.warnings.forEach(warning => {
        alerts.push({
          type: 'plants',
          severity: 'warning',
          component: 'plants',
          message: warning,
          details: 'Plant monitoring issue detected'
        });
      });
    }

    return alerts;
  }

  addToHealthHistory(healthStatus) {
    this.healthHistory.push({
      timestamp: healthStatus.timestamp,
      overall: healthStatus.overall,
      alertCount: healthStatus.alerts.length
    });

    // Trim history to max length
    if (this.healthHistory.length > this.maxHistoryLength) {
      this.healthHistory = this.healthHistory.slice(-this.maxHistoryLength);
    }
  }

  async getSystemStatus() {
    return await this.performHealthCheck();
  }

  getHealthHistory() {
    return {
      history: this.healthHistory,
      count: this.healthHistory.length,
      period: `${this.maxHistoryLength} minutes`,
      generatedAt: new Date().toISOString()
    };
  }

  // Get specific component health
  async getComponentHealth(componentName) {
    const timer = createTimer(`health.getComponentHealth.${componentName}`);
    
    try {
      let health;
      
      switch (componentName) {
        case 'mqtt':
          health = await this.checkMQTTHealth();
          break;
        case 'database':
          health = await this.checkDatabaseHealth();
          break;
        case 'automation':
          health = this.checkAutomationHealth();
          break;
        case 'plants':
          health = await this.checkPlantsHealth();
          break;
        case 'system':
          health = await this.checkSystemResources();
          break;
        default:
          throw new Error(`Unknown component: ${componentName}`);
      }
      
      timer.end({ component: componentName, status: health.status });
      return health;
      
    } catch (error) {
      timer.end({ component: componentName, error: error.message });
      throw error;
    }
  }

  // Get system diagnostics
  async getDiagnostics() {
    const timer = createTimer('health.getDiagnostics');
    
    try {
      const diagnostics = {
        timestamp: new Date().toISOString(),
        system: {
          platform: os.platform(),
          release: os.release(),
          arch: os.arch(),
          hostname: os.hostname(),
          uptime: os.uptime(),
          loadavg: os.loadavg(),
          totalmem: os.totalmem(),
          freemem: os.freemem(),
          cpus: os.cpus().map(cpu => ({
            model: cpu.model,
            speed: cpu.speed
          }))
        },
        process: {
          pid: process.pid,
          uptime: process.uptime(),
          memoryUsage: process.memoryUsage(),
          cpuUsage: process.cpuUsage(),
          version: process.version,
          versions: process.versions
        },
        environment: {
          nodeEnv: process.env.NODE_ENV,
          timezone: process.env.TZ || Intl.DateTimeFormat().resolvedOptions().timeZone,
          locale: Intl.DateTimeFormat().resolvedOptions().locale
        },
        services: {
          mqtt: mqttClient.getConnectionStatus(),
          database: sqliteService.getConnectionStatus(),
          automation: automationService.getAutomationStatus()
        }
      };

      timer.end();
      return diagnostics;
      
    } catch (error) {
      timer.end({ error: error.message });
      throw error;
    }
  }

  // Check if system is ready to serve requests
  async isSystemReady() {
    try {
      const mqttStatus = mqttClient.getConnectionStatus();
      const databaseStatus = sqliteService.getConnectionStatus();
      
      return {
        ready: mqttStatus.connected && databaseStatus.connected,
        components: {
          mqtt: mqttStatus.connected,
          database: databaseStatus.connected
        },
        timestamp: new Date().toISOString()
      };
      
    } catch (error) {
      return {
        ready: false,
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  }

  getMonitoringStatus() {
    return {
      isMonitoring: this.isMonitoring,
      historyLength: this.healthHistory.length,
      thresholds: this.thresholds,
      lastCheck: this.healthHistory.length > 0 ? 
        this.healthHistory[this.healthHistory.length - 1].timestamp : null
    };
  }
}

// Export singleton instance
export const healthService = new HealthService();

export { HealthService };