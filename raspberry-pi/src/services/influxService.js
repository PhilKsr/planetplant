import { InfluxDB, Point } from '@influxdata/influxdb-client';
import { logger } from '../utils/logger.js';

class InfluxService {
  constructor() {
    this.client = null;
    this.writeApi = null;
    this.queryApi = null;
    this.isConnected = false;
    this.config = null;
  }

  async initialize() {
    try {
      this.config = {
        url: process.env.INFLUXDB_URL || 'http://localhost:8086',
        token: process.env.INFLUXDB_TOKEN,
        org: process.env.INFLUXDB_ORG || 'plantplant',
        bucket: process.env.INFLUXDB_BUCKET || 'sensors'
      };
      
      logger.info('📊 InfluxDB Config:', { 
        url: this.config.url, 
        org: this.config.org, 
        bucket: this.config.bucket,
        hasToken: !!this.config.token 
      });
      
      this.client = new InfluxDB({
        url: this.config.url,
        token: this.config.token
      });

      this.writeApi = this.client.getWriteApi(this.config.org, this.config.bucket, 's');
      this.queryApi = this.client.getQueryApi(this.config.org);
      
      // Configure write options
      this.writeApi.useDefaultTags({
        service: 'planetplant-server',
        version: process.env.npm_package_version || '1.0.0'
      });

      // Test connection
      await this.testConnection();
      
      this.isConnected = true;
      logger.info('📊 InfluxDB connection established');
      
    } catch (error) {
      logger.error('📊 Failed to initialize InfluxDB:', error);
      throw error;
    }
  }

  async testConnection() {
    try {
      const query = `buckets() |> filter(fn: (r) => r.name == "${this.config.bucket}") |> limit(n: 1)`;
      const result = await this.queryApi.collectRows(query);
      
      if (result.length === 0) {
        throw new Error(`Bucket "${this.config.bucket}" not found`);
      }
      
      logger.info(`📊 Connected to InfluxDB bucket: ${this.config.bucket}`);
    } catch (error) {
      throw new Error(`InfluxDB connection test failed: ${error.message}`);
    }
  }

  async writeSensorData(plantId, sensorData) {
    if (!this.isConnected) {
      throw new Error('InfluxDB not connected');
    }

    try {
      const timestamp = new Date();
      const points = [];

      // Create points for each sensor reading
      if (typeof sensorData.temperature === 'number') {
        points.push(
          new Point('sensor_data')
            .tag('plant_id', plantId)
            .tag('sensor_type', 'temperature')
            .floatField('value', sensorData.temperature)
            .stringField('unit', '°C')
            .timestamp(timestamp)
        );
      }

      if (typeof sensorData.humidity === 'number') {
        points.push(
          new Point('sensor_data')
            .tag('plant_id', plantId)
            .tag('sensor_type', 'humidity')
            .floatField('value', sensorData.humidity)
            .stringField('unit', '%')
            .timestamp(timestamp)
        );
      }

      if (typeof sensorData.moisture === 'number') {
        points.push(
          new Point('sensor_data')
            .tag('plant_id', plantId)
            .tag('sensor_type', 'moisture')
            .floatField('value', sensorData.moisture)
            .stringField('unit', '%')
            .timestamp(timestamp)
        );
      }

      if (typeof sensorData.light === 'number') {
        points.push(
          new Point('sensor_data')
            .tag('plant_id', plantId)
            .tag('sensor_type', 'light')
            .floatField('value', sensorData.light)
            .stringField('unit', 'lux')
            .timestamp(timestamp)
        );
      }

      // Write all points
      this.writeApi.writePoints(points);
      
      // Force flush to ensure data is written
      await this.writeApi.flush();
      
      logger.debug(`📊 Sensor data written for plant ${plantId}:`, sensorData);
      
    } catch (error) {
      logger.error(`📊 Failed to write sensor data for plant ${plantId}:`, error);
      throw error;
    }
  }

  async writeWateringEvent(plantId, eventData) {
    if (!this.isConnected) {
      throw new Error('InfluxDB not connected');
    }

    try {
      const point = new Point('watering_events')
        .tag('plant_id', plantId)
        .tag('trigger_type', eventData.triggerType || 'manual')
        .intField('duration_ms', eventData.duration)
        .floatField('volume_ml', eventData.volume || 0)
        .booleanField('success', eventData.success !== false)
        .stringField('reason', eventData.reason || '')
        .timestamp(new Date());

      this.writeApi.writePoint(point);
      await this.writeApi.flush();
      
      logger.info(`📊 Watering event recorded for plant ${plantId}:`, eventData);
      
    } catch (error) {
      logger.error(`📊 Failed to write watering event for plant ${plantId}:`, error);
      throw error;
    }
  }

  async writeSystemEvent(eventType, eventData) {
    if (!this.isConnected) {
      throw new Error('InfluxDB not connected');
    }

    try {
      const point = new Point('system_events')
        .tag('event_type', eventType)
        .tag('severity', eventData.severity || 'info')
        .stringField('message', eventData.message || '')
        .stringField('details', JSON.stringify(eventData.details || {}))
        .timestamp(new Date());

      this.writeApi.writePoint(point);
      await this.writeApi.flush();
      
      logger.debug(`📊 System event recorded: ${eventType}`);
      
    } catch (error) {
      logger.error(`📊 Failed to write system event ${eventType}:`, error);
      throw error;
    }
  }

  async getCurrentSensorData(plantId) {
    if (!this.isConnected) {
      throw new Error('InfluxDB not connected');
    }

    try {
      const query = `
        from(bucket: "${this.config.bucket}")
          |> range(start: -1h)
          |> filter(fn: (r) => r._measurement == "sensor_data")
          |> filter(fn: (r) => r.plant_id == "${plantId}")
          |> group(columns: ["sensor_type"])
          |> last()
          |> yield(name: "current")
      `;

      const rows = await this.queryApi.collectRows(query);
      
      const currentData = {};
      rows.forEach(row => {
        currentData[row.sensor_type] = {
          value: row._value,
          unit: row.unit,
          timestamp: row._time
        };
      });

      return currentData;
      
    } catch (error) {
      logger.error(`📊 Failed to get current sensor data for plant ${plantId}:`, error);
      throw error;
    }
  }

  async getHistoricalSensorData(plantId, startTime = '-24h', endTime = 'now()') {
    if (!this.isConnected) {
      throw new Error('InfluxDB not connected');
    }

    try {
      const query = `
        from(bucket: "${this.config.bucket}")
          |> range(start: ${startTime}, stop: ${endTime})
          |> filter(fn: (r) => r._measurement == "sensor_data")
          |> filter(fn: (r) => r.plant_id == "${plantId}")
          |> group(columns: ["sensor_type"])
          |> sort(columns: ["_time"])
          |> yield(name: "historical")
      `;

      const rows = await this.queryApi.collectRows(query);
      
      const historicalData = {};
      rows.forEach(row => {
        if (!historicalData[row.sensor_type]) {
          historicalData[row.sensor_type] = [];
        }
        
        historicalData[row.sensor_type].push({
          value: row._value,
          unit: row.unit,
          timestamp: row._time
        });
      });

      return historicalData;
      
    } catch (error) {
      logger.error(`📊 Failed to get historical data for plant ${plantId}:`, error);
      throw error;
    }
  }

  async getWateringHistory(plantId, startTime = '-7d', endTime = 'now()') {
    if (!this.isConnected) {
      throw new Error('InfluxDB not connected');
    }

    try {
      const query = `
        from(bucket: "${this.config.bucket}")
          |> range(start: ${startTime}, stop: ${endTime})
          |> filter(fn: (r) => r._measurement == "watering_events")
          |> filter(fn: (r) => r.plant_id == "${plantId}")
          |> sort(columns: ["_time"], desc: true)
          |> yield(name: "watering_history")
      `;

      const rows = await this.queryApi.collectRows(query);
      
      return rows.map(row => ({
        timestamp: row._time,
        duration: row.duration_ms,
        volume: row.volume_ml,
        triggerType: row.trigger_type,
        success: row.success,
        reason: row.reason
      }));
      
    } catch (error) {
      logger.error(`📊 Failed to get watering history for plant ${plantId}:`, error);
      throw error;
    }
  }

  async getSystemMetrics(startTime = '-1h') {
    if (!this.isConnected) {
      throw new Error('InfluxDB not connected');
    }

    try {
      const query = `
        from(bucket: "${this.config.bucket}")
          |> range(start: ${startTime})
          |> filter(fn: (r) => r._measurement == "system_events")
          |> group(columns: ["event_type"])
          |> count()
          |> yield(name: "metrics")
      `;

      const rows = await this.queryApi.collectRows(query);
      
      const metrics = {};
      rows.forEach(row => {
        metrics[row.event_type] = row._value;
      });

      return metrics;
      
    } catch (error) {
      logger.error('📊 Failed to get system metrics:', error);
      throw error;
    }
  }

  async getAllPlantsCurrentData() {
    if (!this.isConnected) {
      throw new Error('InfluxDB not connected');
    }

    try {
      const query = `
        from(bucket: "${this.config.bucket}")
          |> range(start: -1h)
          |> filter(fn: (r) => r._measurement == "sensor_data")
          |> group(columns: ["plant_id", "sensor_type"])
          |> last()
          |> yield(name: "all_current")
      `;

      const rows = await this.queryApi.collectRows(query);
      
      const plantsData = {};
      rows.forEach(row => {
        if (!plantsData[row.plant_id]) {
          plantsData[row.plant_id] = {};
        }
        
        plantsData[row.plant_id][row.sensor_type] = {
          value: row._value,
          unit: row.unit,
          timestamp: row._time
        };
      });

      return plantsData;
      
    } catch (error) {
      logger.error('📊 Failed to get all plants current data:', error);
      throw error;
    }
  }

  async deleteOldData(retentionPeriod = '30d') {
    if (!this.isConnected) {
      throw new Error('InfluxDB not connected');
    }

    try {
      const deleteApi = this.client.getDeleteAPI();
      const start = new Date(Date.now() - this.parseDuration(retentionPeriod));
      const stop = new Date('1970-01-01'); // Delete everything older than retention period
      
      await deleteApi.postDelete({
        org: this.config.org,
        bucket: this.config.bucket,
        body: {
          start: stop.toISOString(),
          stop: start.toISOString(),
          predicate: '_measurement="sensor_data"'
        }
      });
      
      logger.info(`📊 Deleted sensor data older than ${retentionPeriod}`);
      
    } catch (error) {
      logger.error(`📊 Failed to delete old data:`, error);
      throw error;
    }
  }

  parseDuration(duration) {
    const units = {
      's': 1000,
      'm': 60 * 1000,
      'h': 60 * 60 * 1000,
      'd': 24 * 60 * 60 * 1000
    };
    
    const match = duration.match(/^(\d+)([smhd])$/);
    if (!match) {
      throw new Error(`Invalid duration format: ${duration}`);
    }
    
    const [, value, unit] = match;
    return parseInt(value) * units[unit];
  }

  async close() {
    if (this.writeApi) {
      try {
        await this.writeApi.close();
        logger.info('📊 InfluxDB write API closed');
      } catch (error) {
        logger.error('📊 Error closing InfluxDB write API:', error);
      }
    }
    
    this.isConnected = false;
  }

  getConnectionStatus() {
    return {
      connected: this.isConnected,
      url: this.config.url,
      bucket: this.config.bucket,
      org: this.config.org
    };
  }
}

// Export singleton instance
export const influxService = new InfluxService();

export { InfluxService };