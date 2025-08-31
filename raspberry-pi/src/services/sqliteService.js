import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import { logger } from '../utils/logger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

class SqliteService {
  constructor() {
    this.db = null;
    this.isConnected = false;
    this.dbPath = null;
    this.statements = {};
  }

  async initialize() {
    try {
      this.dbPath = process.env.DB_PATH || path.join(__dirname, '../../../data/plantdata.db');
      
      const dbDir = path.dirname(this.dbPath);
      if (!fs.existsSync(dbDir)) {
        fs.mkdirSync(dbDir, { recursive: true });
      }

      this.db = new Database(this.dbPath);
      this.db.pragma('journal_mode = WAL');
      this.db.pragma('synchronous = NORMAL');
      this.db.pragma('cache_size = 10000');
      this.db.pragma('temp_store = memory');

      this.createTables();
      this.prepareStatements();
      
      this.isConnected = true;
      logger.info(`📊 SQLite database initialized at: ${this.dbPath}`);
      
    } catch (error) {
      logger.error('📊 Failed to initialize SQLite:', error);
      throw error;
    }
  }

  createTables() {
    const sensorDataTable = `
      CREATE TABLE IF NOT EXISTS sensor_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        device TEXT NOT NULL,
        location TEXT,
        plant_id TEXT NOT NULL,
        sensor_type TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT NOT NULL,
        created_at INTEGER DEFAULT (unixepoch() * 1000)
      )
    `;

    const wateringEventsTable = `
      CREATE TABLE IF NOT EXISTS watering_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        plant_id TEXT NOT NULL,
        trigger_type TEXT NOT NULL DEFAULT 'manual',
        duration_ms INTEGER NOT NULL,
        volume_ml REAL DEFAULT 0,
        success INTEGER DEFAULT 1,
        reason TEXT,
        created_at INTEGER DEFAULT (unixepoch() * 1000)
      )
    `;

    const systemEventsTable = `
      CREATE TABLE IF NOT EXISTS system_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        severity TEXT DEFAULT 'info',
        message TEXT,
        details TEXT,
        created_at INTEGER DEFAULT (unixepoch() * 1000)
      )
    `;

    this.db.exec(sensorDataTable);
    this.db.exec(wateringEventsTable);
    this.db.exec(systemEventsTable);

    this.db.exec('CREATE INDEX IF NOT EXISTS idx_sensor_data_timestamp ON sensor_data(timestamp)');
    this.db.exec('CREATE INDEX IF NOT EXISTS idx_sensor_data_plant_id ON sensor_data(plant_id)');
    this.db.exec('CREATE INDEX IF NOT EXISTS idx_sensor_data_type ON sensor_data(sensor_type)');
    this.db.exec('CREATE INDEX IF NOT EXISTS idx_watering_plant_id ON watering_events(plant_id)');
    this.db.exec('CREATE INDEX IF NOT EXISTS idx_watering_timestamp ON watering_events(timestamp)');
    this.db.exec('CREATE INDEX IF NOT EXISTS idx_system_events_type ON system_events(event_type)');
  }

  prepareStatements() {
    this.statements.insertSensorData = this.db.prepare(`
      INSERT INTO sensor_data (timestamp, device, location, plant_id, sensor_type, value, unit)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    this.statements.insertWateringEvent = this.db.prepare(`
      INSERT INTO watering_events (timestamp, plant_id, trigger_type, duration_ms, volume_ml, success, reason)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    this.statements.insertSystemEvent = this.db.prepare(`
      INSERT INTO system_events (timestamp, event_type, severity, message, details)
      VALUES (?, ?, ?, ?, ?)
    `);

    this.statements.getCurrentSensorData = this.db.prepare(`
      SELECT sensor_type, value, unit, timestamp, MAX(timestamp) as latest
      FROM sensor_data
      WHERE plant_id = ? AND timestamp > ?
      GROUP BY sensor_type
    `);

    this.statements.getHistoricalSensorData = this.db.prepare(`
      SELECT sensor_type, value, unit, timestamp
      FROM sensor_data
      WHERE plant_id = ? AND timestamp BETWEEN ? AND ?
      ORDER BY timestamp ASC
    `);

    this.statements.getWateringHistory = this.db.prepare(`
      SELECT timestamp, duration_ms, volume_ml, trigger_type, success, reason
      FROM watering_events
      WHERE plant_id = ? AND timestamp BETWEEN ? AND ?
      ORDER BY timestamp DESC
    `);

    this.statements.getAllPlantsCurrentData = this.db.prepare(`
      SELECT plant_id, sensor_type, value, unit, timestamp
      FROM sensor_data s1
      WHERE timestamp = (
        SELECT MAX(timestamp)
        FROM sensor_data s2
        WHERE s2.plant_id = s1.plant_id AND s2.sensor_type = s1.sensor_type
        AND s2.timestamp > ?
      )
    `);

    this.statements.deleteOldData = this.db.prepare(`
      DELETE FROM sensor_data WHERE timestamp < ?
    `);

    this.statements.getSystemMetrics = this.db.prepare(`
      SELECT event_type, COUNT(*) as count
      FROM system_events
      WHERE timestamp > ?
      GROUP BY event_type
    `);
  }

  async writeSensorData(plantId, sensorData) {
    if (!this.isConnected) {
      throw new Error('SQLite not connected');
    }

    try {
      const timestamp = Date.now();
      const device = sensorData.device || 'esp32';
      const location = sensorData.location || null;

      const insertMany = this.db.transaction((data) => {
        for (const [sensorType, value] of Object.entries(data)) {
          if (typeof value === 'number') {
            let unit;
            switch (sensorType) {
              case 'temperature': unit = '°C'; break;
              case 'humidity': unit = '%'; break;
              case 'moisture': unit = '%'; break;
              case 'light': unit = 'lux'; break;
              case 'soil_temp': unit = '°C'; break;
              default: unit = '';
            }
            
            this.statements.insertSensorData.run(
              timestamp, device, location, plantId, sensorType, value, unit
            );
          }
        }
      });

      insertMany(sensorData);
      
      logger.debug(`📊 Sensor data written for plant ${plantId}:`, sensorData);
      
    } catch (error) {
      logger.error(`📊 Failed to write sensor data for plant ${plantId}:`, error);
      throw error;
    }
  }

  async writeWateringEvent(plantId, eventData) {
    if (!this.isConnected) {
      throw new Error('SQLite not connected');
    }

    try {
      const timestamp = Date.now();
      
      this.statements.insertWateringEvent.run(
        timestamp,
        plantId,
        eventData.triggerType || 'manual',
        eventData.duration,
        eventData.volume || 0,
        eventData.success !== false ? 1 : 0,
        eventData.reason || ''
      );
      
      logger.info(`📊 Watering event recorded for plant ${plantId}:`, eventData);
      
    } catch (error) {
      logger.error(`📊 Failed to write watering event for plant ${plantId}:`, error);
      throw error;
    }
  }

  async writeSystemEvent(eventType, eventData) {
    if (!this.isConnected) {
      throw new Error('SQLite not connected');
    }

    try {
      const timestamp = Date.now();
      
      this.statements.insertSystemEvent.run(
        timestamp,
        eventType,
        eventData.severity || 'info',
        eventData.message || '',
        JSON.stringify(eventData.details || {})
      );
      
      logger.debug(`📊 System event recorded: ${eventType}`);
      
    } catch (error) {
      logger.error(`📊 Failed to write system event ${eventType}:`, error);
      throw error;
    }
  }

  async getCurrentSensorData(plantId) {
    if (!this.isConnected) {
      throw new Error('SQLite not connected');
    }

    try {
      const oneHourAgo = Date.now() - (60 * 60 * 1000);
      const rows = this.statements.getCurrentSensorData.all(plantId, oneHourAgo);
      
      const currentData = {};
      rows.forEach(row => {
        currentData[row.sensor_type] = {
          value: row.value,
          unit: row.unit,
          timestamp: new Date(row.timestamp).toISOString()
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
      throw new Error('SQLite not connected');
    }

    try {
      const start = this.parseTimeRange(startTime);
      const end = endTime === 'now()' ? Date.now() : this.parseTimeRange(endTime);
      
      const rows = this.statements.getHistoricalSensorData.all(plantId, start, end);
      
      const historicalData = {};
      rows.forEach(row => {
        if (!historicalData[row.sensor_type]) {
          historicalData[row.sensor_type] = [];
        }
        
        historicalData[row.sensor_type].push({
          value: row.value,
          unit: row.unit,
          timestamp: new Date(row.timestamp).toISOString()
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
      throw new Error('SQLite not connected');
    }

    try {
      const start = this.parseTimeRange(startTime);
      const end = endTime === 'now()' ? Date.now() : this.parseTimeRange(endTime);
      
      const rows = this.statements.getWateringHistory.all(plantId, start, end);
      
      return rows.map(row => ({
        timestamp: new Date(row.timestamp).toISOString(),
        duration: row.duration_ms,
        volume: row.volume_ml,
        triggerType: row.trigger_type,
        success: !!row.success,
        reason: row.reason
      }));
      
    } catch (error) {
      logger.error(`📊 Failed to get watering history for plant ${plantId}:`, error);
      throw error;
    }
  }

  async getSystemMetrics(startTime = '-1h') {
    if (!this.isConnected) {
      throw new Error('SQLite not connected');
    }

    try {
      const start = this.parseTimeRange(startTime);
      const rows = this.statements.getSystemMetrics.all(start);
      
      const metrics = {};
      rows.forEach(row => {
        metrics[row.event_type] = row.count;
      });

      return metrics;
      
    } catch (error) {
      logger.error('📊 Failed to get system metrics:', error);
      throw error;
    }
  }

  async getAllPlantsCurrentData() {
    if (!this.isConnected) {
      throw new Error('SQLite not connected');
    }

    try {
      const oneHourAgo = Date.now() - (60 * 60 * 1000);
      const rows = this.statements.getAllPlantsCurrentData.all(oneHourAgo);
      
      const plantsData = {};
      rows.forEach(row => {
        if (!plantsData[row.plant_id]) {
          plantsData[row.plant_id] = {};
        }
        
        plantsData[row.plant_id][row.sensor_type] = {
          value: row.value,
          unit: row.unit,
          timestamp: new Date(row.timestamp).toISOString()
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
      throw new Error('SQLite not connected');
    }

    try {
      const cutoffTime = Date.now() - this.parseDuration(retentionPeriod);
      
      const result = this.statements.deleteOldData.run(cutoffTime);
      
      logger.info(`📊 Deleted ${result.changes} sensor data records older than ${retentionPeriod}`);
      
    } catch (error) {
      logger.error(`📊 Failed to delete old data:`, error);
      throw error;
    }
  }

  parseTimeRange(timeStr) {
    if (timeStr === 'now()') {
      return Date.now();
    }
    
    if (timeStr.startsWith('-')) {
      const duration = timeStr.substring(1);
      return Date.now() - this.parseDuration(duration);
    }
    
    return new Date(timeStr).getTime();
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
    if (this.db) {
      try {
        this.db.close();
        logger.info('📊 SQLite database closed');
      } catch (error) {
        logger.error('📊 Error closing SQLite database:', error);
      }
    }
    
    this.isConnected = false;
  }

  getConnectionStatus() {
    return {
      connected: this.isConnected,
      path: this.dbPath,
      type: 'SQLite'
    };
  }

  vacuum() {
    if (this.isConnected) {
      this.db.exec('VACUUM');
      logger.info('📊 SQLite database vacuum completed');
    }
  }

  getStats() {
    if (!this.isConnected) return null;

    try {
      const sensorCount = this.db.prepare('SELECT COUNT(*) as count FROM sensor_data').get();
      const wateringCount = this.db.prepare('SELECT COUNT(*) as count FROM watering_events').get();
      const systemCount = this.db.prepare('SELECT COUNT(*) as count FROM system_events').get();
      const dbSize = fs.statSync(this.dbPath).size;

      return {
        sensor_records: sensorCount.count,
        watering_records: wateringCount.count,
        system_records: systemCount.count,
        database_size_bytes: dbSize,
        database_size_mb: (dbSize / 1024 / 1024).toFixed(2)
      };
    } catch (error) {
      logger.error('📊 Failed to get database stats:', error);
      return null;
    }
  }
}

export const sqliteService = new SqliteService();
export { SqliteService };