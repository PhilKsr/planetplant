import winston from 'winston';
import DailyRotateFile from 'winston-daily-rotate-file';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const LOG_DIR = process.env.LOG_DIR || '/app/logs';
const FILE_LOGGING = String(process.env.BACKEND_FILE_LOGGING || 'true') === 'true';
const CONSOLE_LOGGING = String(process.env.BACKEND_CONSOLE_LOGGING || 'true') === 'true';

const logFormat = winston.format.combine(
  winston.format.timestamp({
    format: 'YYYY-MM-DD HH:mm:ss'
  }),
  winston.format.errors({ stack: true }),
  winston.format.json()
);

const consoleFormat = winston.format.combine(
  winston.format.timestamp({
    format: 'HH:mm:ss'
  }),
  winston.format.colorize(),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    let msg = `${timestamp} [${level}] ${message}`;
    
    if (Object.keys(meta).length > 0) {
      msg += ` ${JSON.stringify(meta, null, 2)}`;
    }
    
    return msg;
  })
);

import fs from 'fs';

// Create initial transports array with console only
const transports = [];

// Console transport
if (CONSOLE_LOGGING) {
  transports.push(
    new winston.transports.Console({
      format: consoleFormat,
      level: process.env.LOG_LEVEL || 'info'
    })
  );
}

let fileTransportsEnabled = false;
let fileTransportAttempted = false;

function ensureLogDirSafe(dir) {
  try {
    fs.mkdirSync(dir, { recursive: true });
  } catch (e) {
    return false;
  }
  return true;
}

// Create logger first
const baseLogger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  transports,
  exitOnError: false
});

// Lazy function to add file transports when first log message is written
function ensureFileTransports() {
  if (!FILE_LOGGING || fileTransportAttempted) return;
  fileTransportAttempted = true;

  if (!ensureLogDirSafe(LOG_DIR)) {
    console.warn('Could not create log directory, using console logging only');
    return;
  }

  try {
    // Test write access
    const testFile = path.join(LOG_DIR, '.write-test');
    fs.writeFileSync(testFile, 'test');
    fs.unlinkSync(testFile);

    // Add file transports
    baseLogger.add(
      new DailyRotateFile({
        filename: path.join(LOG_DIR, 'plantplant-%DATE%.log'),
        datePattern: 'YYYY-MM-DD',
        maxSize: process.env.LOG_MAX_SIZE || '20m',
        maxFiles: process.env.LOG_MAX_FILES || '14d',
        format: logFormat,
        level: process.env.LOG_LEVEL || 'info'
      })
    );

    baseLogger.add(
      new DailyRotateFile({
        filename: path.join(LOG_DIR, 'error-%DATE%.log'),
        datePattern: 'YYYY-MM-DD',
        maxSize: process.env.LOG_MAX_SIZE || '20m',
        maxFiles: process.env.LOG_MAX_FILES || '30d',
        format: logFormat,
        level: 'error'
      })
    );

    if (process.env.NODE_ENV === 'development' || process.env.DEBUG_LOGGING === 'true') {
      baseLogger.add(
        new DailyRotateFile({
          filename: path.join(LOG_DIR, 'debug-%DATE%.log'),
          datePattern: 'YYYY-MM-DD',
          maxSize: process.env.LOG_MAX_SIZE || '20m',
          maxFiles: '7d',
          format: logFormat,
          level: 'debug'
        })
      );
    }

    // Add exception handlers
    baseLogger.exceptions.handle(
      new winston.transports.File({ filename: path.join(LOG_DIR, 'exceptions.log') })
    );
    
    // Add rejection handlers
    baseLogger.rejections.handle(
      new winston.transports.File({ filename: path.join(LOG_DIR, 'rejections.log') })
    );

    fileTransportsEnabled = true;
    console.log('File logging enabled:', LOG_DIR);
  } catch (e) {
    console.warn('Could not set up file logging, using console only:', e.message);
  }
}

// Create proxy logger that ensures file transports before logging
const logger = new Proxy(baseLogger, {
  get(target, prop) {
    // Intercept logging methods to ensure file transports
    if (typeof target[prop] === 'function' && ['log', 'info', 'warn', 'error', 'debug'].includes(prop)) {
      return function(...args) {
        ensureFileTransports();
        return target[prop].apply(target, args);
      };
    }
    return target[prop];
  }
});

// Add request logging helper
logger.logRequest = (req, res, responseTime) => {
  const logData = {
    method: req.method,
    url: req.url,
    statusCode: res.statusCode,
    responseTime: `${responseTime}ms`,
    userAgent: req.get('User-Agent'),
    ip: req.ip || req.connection.remoteAddress,
    contentLength: res.get('Content-Length')
  };

  if (res.statusCode >= 400) {
    logger.warn('HTTP Request Error', logData);
  } else {
    logger.info('HTTP Request', logData);
  }
};

// Add MQTT logging helper
logger.logMQTT = (direction, topic, payload, qos = 0) => {
  const logData = {
    direction, // 'incoming' or 'outgoing'
    topic,
    qos,
    payloadSize: typeof payload === 'string' ? payload.length : JSON.stringify(payload).length
  };

  // Don't log full payload for privacy/performance, just metadata
  if (process.env.MQTT_VERBOSE_LOGGING === 'true') {
    logData.payload = payload;
  }

  logger.debug('MQTT Message', logData);
};

// Add sensor data logging helper
logger.logSensorData = (plantId, sensorData, source = 'mqtt') => {
  const logData = {
    plantId,
    source,
    sensors: Object.keys(sensorData),
    timestamp: new Date().toISOString()
  };

  if (process.env.SENSOR_VERBOSE_LOGGING === 'true') {
    logData.data = sensorData;
  }

  logger.info('Sensor Data Received', logData);
};

// Add watering event logging helper
logger.logWateringEvent = (plantId, eventData) => {
  const logData = {
    plantId,
    ...eventData,
    timestamp: new Date().toISOString()
  };

  logger.info('Watering Event', logData);
};

// Add system health logging helper
logger.logHealth = (component, status, metrics = {}) => {
  const logData = {
    component,
    status,
    ...metrics,
    timestamp: new Date().toISOString()
  };

  if (status === 'healthy') {
    logger.debug('Health Check', logData);
  } else {
    logger.warn('Health Check Issue', logData);
  }
};

// Performance monitoring helper
logger.logPerformance = (operation, duration, metadata = {}) => {
  const logData = {
    operation,
    duration: `${duration}ms`,
    ...metadata,
    timestamp: new Date().toISOString()
  };

  if (duration > 1000) {
    logger.warn('Slow Operation', logData);
  } else {
    logger.debug('Performance', logData);
  }
};


// Log startup information
logger.info('Logger initialized', {
  logLevel: process.env.LOG_LEVEL || 'info',
  logDir: LOG_DIR,
  nodeEnv: process.env.NODE_ENV,
  consoleLogging: CONSOLE_LOGGING,
  fileLogging: FILE_LOGGING,
  note: 'File logging will be enabled after directory setup'
});

export { logger };

// Export helper function for creating child loggers
export const createChildLogger = (service) => {
  return logger.child({ service });
};

// Export performance timer utility
export const createTimer = (operation) => {
  const start = Date.now();
  
  return {
    end: (metadata = {}) => {
      const duration = Date.now() - start;
      logger.logPerformance(operation, duration, metadata);
      return duration;
    }
  };
};