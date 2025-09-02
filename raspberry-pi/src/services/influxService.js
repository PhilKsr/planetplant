import { InfluxDB, Point, flux } from '@influxdata/influxdb-client';
import { logger } from '../utils/logger.js';

class InfluxService {
  constructor() {
    this.client = null;
    this.writeApi = null;
    this.queryApi = null;
    this.writeBuffer = [];
    this.batchInterval = null;
    this.retryQueue = [];
    this.isConnected = false;
    this.config = null;
    this.maxRetries = 3;
    this.batchSize = 100;
    this.flushInterval = 5000;
  }

  async initialize() {
    try {
      this.config = {
        url: process.env.INFLUXDB_URL || 'http://localhost:8086',
        token: process.env.INFLUXDB_TOKEN,
        org: process.env.INFLUXDB_ORG || 'planetplant',
        bucket: process.env.INFLUXDB_BUCKET || 'sensor-data'
      };

      if (!this.config.token) {
        throw new Error('INFLUXDB_TOKEN environment variable is required');
      }
      
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

      this.writeApi = this.client.getWriteApi(this.config.org, this.config.bucket, 'ms');
      this.queryApi = this.client.getQueryApi(this.config.org);
      
      this.writeApi.useDefaultTags({
        service: 'planetplant-server',
        version: process.env.npm_package_version || '1.0.0'
      });

      await this.testConnection();
      this.startBatchProcessor();
      
      this.isConnected = true;
      logger.info('✅ InfluxDB service initialized successfully');
      
    } catch (error) {
      logger.error('📊 Failed to initialize InfluxDB:', error);
      throw error;
    }
  }

  async testConnection() {
    try {
      // Test connection by trying to get bucket info
      const queryApi = this.client.getQueryApi(this.config.org);
      await new Promise((resolve, reject) => {
        queryApi.queryRows('buckets()', {
          next() {},
          error(error) { reject(error); },
          complete() { resolve(); }
        });
      });
      logger.info('🏓 InfluxDB connection test successful');
    } catch (error) {
      logger.error('❌ InfluxDB connection test failed:', error);
      throw error;
    }
  }

  startBatchProcessor() {
    this.batchInterval = setInterval(() => {
      this.flushBuffer();
    }, this.flushInterval);

    logger.info(`🔄 Started batch processor (${this.flushInterval}ms interval)`);
  }

  async flushBuffer() {
    if (this.writeBuffer.length === 0) return;

    const points = this.writeBuffer.splice(0, this.batchSize);
    
    try {
      points.forEach(point => this.writeApi.writePoint(point));
      await this.writeApi.flush();
      
      logger.debug(`📊 Flushed ${points.length} points to InfluxDB`);
    } catch (error) {
      logger.error('❌ Failed to flush points to InfluxDB:', error);
      
      this.retryQueue.push(...points.map(point => ({
        point,
        retryCount: 0,
        timestamp: Date.now()
      })));
      
      this.processRetryQueue();
    }
  }

  async processRetryQueue() {
    const now = Date.now();
    const retryableItems = this.retryQueue.filter(item => 
      item.retryCount < this.maxRetries && 
      (now - item.timestamp) > 1000 * Math.pow(2, item.retryCount)
    );

    for (const item of retryableItems) {
      try {
        this.writeApi.writePoint(item.point);
        await this.writeApi.flush();
        
        const index = this.retryQueue.indexOf(item);
        this.retryQueue.splice(index, 1);
        
        logger.debug('✅ Retry successful for point');
      } catch (error) {
        item.retryCount++;
        logger.warn(`⚠️ Retry ${item.retryCount}/${this.maxRetries} failed:`, error);
        
        if (item.retryCount >= this.maxRetries) {
          const index = this.retryQueue.indexOf(item);
          this.retryQueue.splice(index, 1);
          logger.error('❌ Max retries exceeded, dropping point');
        }
      }
    }
  }

  writeSensorData(deviceId, plantId, location, sensorType, value, unit, quality = 'good') {
    const point = new Point('sensor_data')
      .tag('device_id', deviceId)
      .tag('plant_id', plantId)
      .tag('location', location || 'unknown')
      .tag('sensor_type', sensorType)
      .floatField('value', parseFloat(value))
      .stringField('unit', unit)
      .stringField('quality', quality)
      .timestamp(new Date());

    this.writeBuffer.push(point);
    
    if (this.writeBuffer.length >= this.batchSize) {
      this.flushBuffer();
    }
    
    logger.debug(`📊 Queued sensor data: ${sensorType}=${value}${unit} for ${plantId}`);
  }

  writeWateringEvent(plantId, deviceId, triggerType, durationMs, volumeMl, success, reason) {
    const point = new Point('watering_events')
      .tag('plant_id', plantId)
      .tag('device_id', deviceId)
      .tag('trigger_type', triggerType)
      .intField('duration_ms', durationMs)
      .floatField('volume_ml', volumeMl || 0)
      .booleanField('success', success)
      .stringField('reason', reason || '')
      .timestamp(new Date());

    this.writeBuffer.push(point);
    logger.info(`💧 Queued watering event for ${plantId}: ${durationMs}ms, success=${success}`);
  }

  writeSystemStats(cpuUsage, memoryUsage, diskUsage, temperature) {
    const point = new Point('system_stats')
      .tag('host', process.env.DEVICE_ID || 'unknown')
      .floatField('cpu_usage', cpuUsage)
      .floatField('memory_usage', memoryUsage)
      .floatField('disk_usage', diskUsage)
      .floatField('temperature', temperature)
      .timestamp(new Date());

    this.writeBuffer.push(point);
  }

  async getCurrentSensorData(plantId) {
    const fluxQuery = flux`
      from(bucket: "${this.config.bucket}")
        |> range(start: -1h)
        |> filter(fn: (r) => r["_measurement"] == "sensor_data")
        |> filter(fn: (r) => r["plant_id"] == "${plantId}")
        |> group(columns: ["sensor_type"])
        |> last()
        |> yield(name: "last")
    `;

    try {
      const result = [];
      await new Promise((resolve, reject) => {
        this.queryApi.queryRows(fluxQuery, {
          next(row, tableMeta) {
            const o = tableMeta.toObject(row);
            result.push({
              sensor_type: o.sensor_type,
              value: o._value,
              unit: o.unit,
              timestamp: o._time,
              quality: o.quality || 'good'
            });
          },
          error(error) {
            logger.error('❌ Query error:', error);
            reject(error);
          },
          complete() {
            resolve();
          }
        });
      });

      return result;
    } catch (error) {
      logger.error('❌ Failed to get current sensor data:', error);
      throw error;
    }
  }

  async getHistoricalData(plantId, range = '24h', interval = '5m') {
    const fluxQuery = `
      from(bucket: "${this.config.bucket}")
        |> range(start: -${range})
        |> filter(fn: (r) => r["_measurement"] == "sensor_data")
        |> filter(fn: (r) => r["plant_id"] == "${plantId}")
        |> aggregateWindow(every: ${interval}, fn: mean, createEmpty: false)
        |> yield(name: "mean")
    `;

    try {
      const result = {};
      await new Promise((resolve, reject) => {
        this.queryApi.queryRows(fluxQuery, {
          next(row, tableMeta) {
            const o = tableMeta.toObject(row);
            if (!result[o.sensor_type]) {
              result[o.sensor_type] = [];
            }
            result[o.sensor_type].push({
              timestamp: o._time,
              value: o._value,
              unit: o.unit
            });
          },
          error(error) {
            logger.error('❌ Historical query error:', error);
            reject(error);
          },
          complete() {
            resolve();
          }
        });
      });

      return result;
    } catch (error) {
      logger.error('❌ Failed to get historical data:', error);
      throw error;
    }
  }

  async getWateringHistory(plantId, range = '7d') {
    const fluxQuery = flux`
      from(bucket: "${this.config.bucket}")
        |> range(start: -${range})
        |> filter(fn: (r) => r["_measurement"] == "watering_events")
        |> filter(fn: (r) => r["plant_id"] == "${plantId}")
        |> sort(columns: ["_time"], desc: true)
        |> yield(name: "watering_history")
    `;

    try {
      const result = [];
      await new Promise((resolve, reject) => {
        this.queryApi.queryRows(fluxQuery, {
          next(row, tableMeta) {
            const o = tableMeta.toObject(row);
            if (o._field === 'duration_ms') {
              result.push({
                timestamp: o._time,
                duration_ms: o._value,
                volume_ml: 0,
                trigger_type: o.trigger_type,
                success: true,
                reason: o.reason || ''
              });
            }
          },
          error(error) {
            logger.error('❌ Watering history query error:', error);
            reject(error);
          },
          complete() {
            resolve();
          }
        });
      });

      return result;
    } catch (error) {
      logger.error('❌ Failed to get watering history:', error);
      throw error;
    }
  }

  async detectAnomalies(plantId, sensorType, hours = 24) {
    const fluxQuery = flux`
      from(bucket: "${this.config.bucket}")
        |> range(start: -${hours}h)
        |> filter(fn: (r) => r["_measurement"] == "sensor_data")
        |> filter(fn: (r) => r["plant_id"] == "${plantId}")
        |> filter(fn: (r) => r["sensor_type"] == "${sensorType}")
        |> aggregateWindow(every: 1h, fn: mean)
        |> movingAverage(n: 6)
        |> map(fn: (r) => ({ r with anomaly: if r._value > r._value_ma * 1.5 or r._value < r._value_ma * 0.5 
          then "high" else "normal" }))
        |> filter(fn: (r) => r.anomaly == "high")
        |> yield(name: "anomalies")
    `;

    try {
      const anomalies = [];
      await new Promise((resolve, reject) => {
        this.queryApi.queryRows(fluxQuery, {
          next(row, tableMeta) {
            const o = tableMeta.toObject(row);
            anomalies.push({
              timestamp: o._time,
              sensor_type: sensorType,
              value: o._value,
              severity: o.anomaly,
              message: `Unusual ${sensorType} reading detected`
            });
          },
          error(error) {
            logger.error('❌ Anomaly detection query error:', error);
            reject(error);
          },
          complete() {
            resolve();
          }
        });
      });

      return anomalies;
    } catch (error) {
      logger.error('❌ Failed to detect anomalies:', error);
      return [];
    }
  }

  async getDailyAggregates(plantId, days = 7) {
    const fluxQuery = flux`
      from(bucket: "${this.config.bucket}")
        |> range(start: -${days}d)
        |> filter(fn: (r) => r["_measurement"] == "sensor_data")
        |> filter(fn: (r) => r["plant_id"] == "${plantId}")
        |> aggregateWindow(every: 1d, fn: mean, createEmpty: false)
        |> group(columns: ["sensor_type"])
        |> yield(name: "daily_averages")
    `;

    try {
      const aggregates = {};
      await new Promise((resolve, reject) => {
        this.queryApi.queryRows(fluxQuery, {
          next(row, tableMeta) {
            const o = tableMeta.toObject(row);
            if (!aggregates[o.sensor_type]) {
              aggregates[o.sensor_type] = [];
            }
            aggregates[o.sensor_type].push({
              date: o._time.toISOString().split('T')[0],
              avg: o._value,
              unit: o.unit
            });
          },
          error(error) {
            logger.error('❌ Daily aggregates query error:', error);
            reject(error);
          },
          complete() {
            resolve();
          }
        });
      });

      return aggregates;
    } catch (error) {
      logger.error('❌ Failed to get daily aggregates:', error);
      throw error;
    }
  }

  async getSystemHealth() {
    try {
      const bufferSize = this.writeBuffer.length;
      const retryQueueSize = this.retryQueue.length;

      return {
        connected: this.isConnected,
        buffer_size: bufferSize,
        retry_queue_size: retryQueueSize,
        url: this.config.url,
        org: this.config.org,
        bucket: this.config.bucket
      };
    } catch (error) {
      logger.error('❌ InfluxDB health check failed:', error);
      return {
        connected: false,
        error: error.message
      };
    }
  }

  getGrafanaQueries() {
    return {
      moistureHistory: `from(bucket: "sensor-data")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "sensor_data")
  |> filter(fn: (r) => r["sensor_type"] == "moisture")
  |> aggregateWindow(every: 5m, fn: mean, createEmpty: false)`,

      temperatureHumidity: `from(bucket: "sensor-data")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "sensor_data")
  |> filter(fn: (r) => r["sensor_type"] == "temperature" or r["sensor_type"] == "humidity")
  |> aggregateWindow(every: 10m, fn: mean, createEmpty: false)`,

      wateringEfficiency: `from(bucket: "sensor-data")
  |> range(start: -7d)
  |> filter(fn: (r) => r["_measurement"] == "watering_events")
  |> filter(fn: (r) => r["_field"] == "success")
  |> aggregateWindow(every: 1d, fn: sum, createEmpty: false)`,

      sensorComparison: `from(bucket: "sensor-data")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "sensor_data")
  |> group(columns: ["plant_id", "sensor_type"])
  |> last()`,

      trendAnalysis: `from(bucket: "sensor-data")
  |> range(start: -30d)
  |> filter(fn: (r) => r["_measurement"] == "sensor_data")
  |> filter(fn: (r) => r["sensor_type"] == "moisture")
  |> aggregateWindow(every: 1d, fn: mean, createEmpty: false)
  |> derivative(unit: 1d, nonNegative: false)
  |> yield(name: "moisture_trend")`
    };
  }

  async getActiveAlerts() {
    const fluxQuery = flux`
      from(bucket: "${this.config.bucket}")
        |> range(start: -1h)
        |> filter(fn: (r) => r["_measurement"] == "sensor_data")
        |> group(columns: ["plant_id", "sensor_type"])
        |> last()
        |> map(fn: (r) => ({ r with 
          alert_type: if r.sensor_type == "moisture" and r._value < 20.0 then "low_moisture"
                     else if r.sensor_type == "temperature" and r._value > 35.0 then "high_temperature"
                     else if r.sensor_type == "temperature" and r._value < 10.0 then "low_temperature"
                     else "normal"
        }))
        |> filter(fn: (r) => r.alert_type != "normal")
        |> yield(name: "alerts")
    `;

    try {
      const alerts = [];
      await new Promise((resolve, reject) => {
        this.queryApi.queryRows(fluxQuery, {
          next(row, tableMeta) {
            const o = tableMeta.toObject(row);
            alerts.push({
              plant_id: o.plant_id,
              sensor_type: o.sensor_type,
              value: o._value,
              unit: o.unit,
              alert_type: o.alert_type,
              timestamp: o._time,
              severity: o.alert_type.includes('low') ? 'warning' : 'critical'
            });
          },
          error(error) {
            logger.error('❌ Alerts query error:', error);
            reject(error);
          },
          complete() {
            resolve();
          }
        });
      });

      return alerts;
    } catch (error) {
      logger.error('❌ Failed to get active alerts:', error);
      return [];
    }
  }

  async close() {
    try {
      if (this.batchInterval) {
        clearInterval(this.batchInterval);
      }

      await this.flushBuffer();

      if (this.writeApi) {
        await this.writeApi.close();
      }

      this.isConnected = false;
      logger.info('🔌 InfluxDB service closed');
    } catch (error) {
      logger.error('❌ Error closing InfluxDB service:', error);
    }
  }
}

// Export singleton instance
export const influxService = new InfluxService();

export { InfluxService };