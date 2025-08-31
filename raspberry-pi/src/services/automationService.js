import cron from 'node-cron';
import { logger, createTimer } from '../utils/logger.js';
import { plantService } from './plantService.js';
import { mqttClient } from './mqttClient.js';
import { influxService } from './influxService.js';

class AutomationService {
  constructor() {
    this.isRunning = false;
    this.scheduledJobs = new Map();
    this.automationStats = {
      totalAutomaticWaterings: 0,
      lastAutomaticWatering: null,
      skippedWaterings: 0,
      errors: 0
    };
  }

  start() {
    if (this.isRunning) {
      logger.warn('🤖 Automation Service is already running');
      return;
    }

    if (process.env.ENABLE_SCHEDULER !== 'true') {
      logger.info('🤖 Automation Service disabled via configuration');
      return;
    }

    try {
      this.setupScheduledJobs();
      this.isRunning = true;
      logger.info('🤖 Automation Service started');
      
    } catch (error) {
      logger.error('❌ Failed to start Automation Service:', error);
      throw error;
    }
  }

  stop() {
    if (!this.isRunning) {
      return;
    }

    // Stop all scheduled jobs
    this.scheduledJobs.forEach((job, name) => {
      job.stop();
      logger.info(`🛑 Stopped scheduled job: ${name}`);
    });

    this.scheduledJobs.clear();
    this.isRunning = false;
    
    logger.info('🤖 Automation Service stopped');
  }

  setupScheduledJobs() {
    // Check for automatic watering every 5 minutes
    const wateringJob = cron.schedule('*/5 * * * *', () => {
      this.checkAutomaticWatering();
    }, {
      name: 'automatic-watering',
      scheduled: true,
      timezone: process.env.TIMEZONE || 'Europe/Berlin'
    });

    this.scheduledJobs.set('automatic-watering', wateringJob);
    logger.info('📅 Scheduled automatic watering checks every 5 minutes');

    // Health monitoring every minute
    const healthJob = cron.schedule('* * * * *', () => {
      this.performHealthChecks();
    }, {
      name: 'health-monitoring',
      scheduled: true
    });

    this.scheduledJobs.set('health-monitoring', healthJob);
    logger.info('📅 Scheduled health monitoring every minute');

    // Daily data cleanup at 2:00 AM
    const cleanupJob = cron.schedule('0 2 * * *', () => {
      this.performDailyCleanup();
    }, {
      name: 'daily-cleanup',
      scheduled: true,
      timezone: process.env.TIMEZONE || 'Europe/Berlin'
    });

    this.scheduledJobs.set('daily-cleanup', cleanupJob);
    logger.info('📅 Scheduled daily cleanup at 2:00 AM');

    // Statistics update every hour
    const statsJob = cron.schedule('0 * * * *', () => {
      this.updateStatistics();
    }, {
      name: 'statistics-update',
      scheduled: true
    });

    this.scheduledJobs.set('statistics-update', statsJob);
    logger.info('📅 Scheduled statistics update every hour');
  }

  async checkAutomaticWatering() {
    const timer = createTimer('automation.checkAutomaticWatering');
    
    try {
      logger.debug('🤖 Checking automatic watering conditions...');
      
      const plants = await plantService.getAllPlants();
      let wateringActions = 0;
      
      for (const plant of plants) {
        if (!plant.status.isOnline) {
          logger.debug(`🌱 Skipping offline plant: ${plant.name} (${plant.id})`);
          continue;
        }

        if (!plantService.needsWatering(plant)) {
          logger.debug(`🌱 Plant ${plant.name} doesn't need watering (moisture: ${plant.currentData.moisture}%)`);
          continue;
        }

        const { canWater, reason } = plantService.canWater(plant);
        
        if (!canWater) {
          logger.info(`🌱 Cannot water plant ${plant.name}: ${reason}`);
          this.automationStats.skippedWaterings++;
          continue;
        }

        // Perform automatic watering
        await this.performAutomaticWatering(plant);
        wateringActions++;
      }
      
      timer.end({ 
        plantsChecked: plants.length, 
        wateringActions 
      });
      
    } catch (error) {
      this.automationStats.errors++;
      timer.end({ error: error.message });
      logger.error('❌ Automatic watering check failed:', error);
    }
  }

  async performAutomaticWatering(plant) {
    const timer = createTimer('automation.performAutomaticWatering');
    
    try {
      const duration = plant.config.wateringConfig.duration;
      const plantId = plant.id;
      
      logger.info(`💧 Starting automatic watering for ${plant.name} (${plantId})`);
      
      // Send watering command via MQTT
      const success = mqttClient.publishWateringCommand(plantId, duration);
      
      if (!success) {
        throw new Error('Failed to send MQTT watering command');
      }
      
      // Record watering event
      await plantService.recordWateringEvent(plantId, {
        duration,
        triggerType: 'automatic',
        reason: `Low moisture: ${plant.currentData.moisture}%`,
        success: true
      });
      
      // Update automation stats
      this.automationStats.totalAutomaticWaterings++;
      this.automationStats.lastAutomaticWatering = new Date().toISOString();
      
      // Broadcast to WebSocket clients
      if (global.io) {
        global.io.emit('automaticWateringStarted', {
          plantId,
          plantName: plant.name,
          duration,
          moistureLevel: plant.currentData.moisture,
          timestamp: new Date().toISOString()
        });
      }
      
      // Record system event in InfluxDB
      influxService.writeWateringEvent(plantId, plant.deviceId, 'automatic', 
        duration, duration * 0.005, true, `Low moisture: ${plant.currentData.moisture}%`);
      
      timer.end({ plantId, duration });
      
    } catch (error) {
      this.automationStats.errors++;
      timer.end({ plantId: plant.id, error: error.message });
      
      logger.error(`❌ Automatic watering failed for plant ${plant.name}:`, error);
      
      // Record failed watering event
      await plantService.recordWateringEvent(plant.id, {
        duration: 0,
        triggerType: 'automatic',
        reason: 'Error: ' + error.message,
        success: false
      });
    }
  }

  async performHealthChecks() {
    try {
      // This will be implemented by healthService
      // For now, just log that we're checking
      logger.debug('💊 Performing automated health checks...');
      
      // Check if any plants need attention
      const plants = await plantService.getAllPlants();
      const offlinePlants = plants.filter(p => !p.status.isOnline);
      
      if (offlinePlants.length > 0) {
        logger.warn(`💊 Health check: ${offlinePlants.length} plants are offline`);
        
        // Log warning for offline plants
        logger.warn(`💊 Health check warning: ${offlinePlants.length} plants offline`, {
          offlinePlantIds: offlinePlants.map(p => p.id)
        });
      }
      
    } catch (error) {
      logger.error('❌ Health check failed:', error);
    }
  }

  async performDailyCleanup() {
    const timer = createTimer('automation.performDailyCleanup');
    
    try {
      logger.info('🧹 Performing daily cleanup...');
      
      // InfluxDB handles data retention automatically via bucket policies
      const retentionPeriod = process.env.SENSOR_DATA_RETENTION || '30d';
      logger.info(`📊 Data retention policy: ${retentionPeriod} (handled by InfluxDB)`);
      
      // Reset daily statistics
      this.resetDailyStats();
      
      // Log cleanup completion
      logger.info('✅ Daily cleanup completed', { retentionPeriod });
      
      timer.end();
      logger.info('✅ Daily cleanup completed');
      
    } catch (error) {
      timer.end({ error: error.message });
      logger.error('❌ Daily cleanup failed:', error);
    }
  }

  async updateStatistics() {
    const timer = createTimer('automation.updateStatistics');
    
    try {
      logger.debug('📊 Updating automation statistics...');
      
      // Update plant statistics
      const plants = await plantService.getAllPlants();
      
      for (const plant of plants) {
        // Calculate average moisture for the last 24 hours
        try {
          const history = await plantService.getPlantHistory(plant.id, '24h');
          if (history.sensorData.moisture && history.sensorData.moisture.length > 0) {
            const moistureValues = history.sensorData.moisture.map(reading => reading.value);
            const avgMoisture = moistureValues.reduce((sum, val) => sum + val, 0) / moistureValues.length;
            plant.stats.avgMoisture = Math.round(avgMoisture * 10) / 10; // Round to 1 decimal
          }
        } catch (error) {
          logger.warn(`Failed to calculate stats for plant ${plant.id}:`, error.message);
        }
      }
      
      // Log automation statistics
      logger.info('📊 Automation statistics update', {
        ...this.automationStats,
        activePlants: plants.length,
        onlinePlants: plants.filter(p => p.status.isOnline).length
      });
      
      timer.end({ plantsUpdated: plants.length });
      
    } catch (error) {
      timer.end({ error: error.message });
      logger.error('❌ Statistics update failed:', error);
    }
  }

  resetDailyStats() {
    // Reset counters that should be tracked per day
    // This could be expanded based on requirements
    logger.debug('📊 Resetting daily statistics');
  }

  getAutomationStatus() {
    return {
      isRunning: this.isRunning,
      scheduledJobs: Array.from(this.scheduledJobs.keys()),
      stats: { ...this.automationStats },
      uptime: this.isRunning ? process.uptime() : 0,
      lastCheck: new Date().toISOString()
    };
  }

  // Manual trigger for testing
  async triggerWateringCheck() {
    logger.info('🧪 Manually triggered watering check');
    await this.checkAutomaticWatering();
  }

  async triggerHealthCheck() {
    logger.info('🧪 Manually triggered health check');
    await this.performHealthChecks();
  }
}

// Export singleton instance
export const automationService = new AutomationService();

export { AutomationService };