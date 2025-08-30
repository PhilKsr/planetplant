import winston from 'winston';
import DailyRotateFile from 'winston-daily-rotate-file';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const logDir = path.join(__dirname, '../../logs');

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

// Create transports array
const transports = [];

// Console transport (always enabled in development)
if (process.env.NODE_ENV !== 'production' || process.env.LOG_TO_CONSOLE === 'true') {
  transports.push(
    new winston.transports.Console({
      format: consoleFormat,
      level: process.env.LOG_LEVEL || 'info'
    })
  );
}

// File transports
if (process.env.LOG_TO_FILE !== 'false') {
  // General log file with rotation
  transports.push(
    new DailyRotateFile({
      filename: path.join(logDir, 'plantplant-%DATE%.log'),
      datePattern: 'YYYY-MM-DD',
      maxSize: process.env.LOG_MAX_SIZE || '20m',
      maxFiles: process.env.LOG_MAX_FILES || '14d',
      format: logFormat,
      level: process.env.LOG_LEVEL || 'info'
    })
  );

  // Error-only log file
  transports.push(
    new DailyRotateFile({
      filename: path.join(logDir, 'error-%DATE%.log'),
      datePattern: 'YYYY-MM-DD',
      maxSize: process.env.LOG_MAX_SIZE || '20m',
      maxFiles: process.env.LOG_MAX_FILES || '30d',
      format: logFormat,
      level: 'error'
    })
  );

  // Debug log file (only in development or when explicitly enabled)
  if (process.env.NODE_ENV === 'development' || process.env.DEBUG_LOGGING === 'true') {
    transports.push(
      new DailyRotateFile({
        filename: path.join(logDir, 'debug-%DATE%.log'),
        datePattern: 'YYYY-MM-DD',
        maxSize: process.env.LOG_MAX_SIZE || '20m',
        maxFiles: '7d',
        format: logFormat,
        level: 'debug'
      })
    );
  }
}

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  transports,
  // Don't exit on handled exceptions
  exitOnError: false,
  
  // Handle uncaught exceptions
  exceptionHandlers: [
    new winston.transports.File({ filename: path.join(logDir, 'exceptions.log') })
  ],
  
  // Handle unhandled promise rejections
  rejectionHandlers: [
    new winston.transports.File({ filename: path.join(logDir, 'rejections.log') })
  ]
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

// Create logs directory if it doesn't exist
import { mkdirSync } from 'fs';
try {
  mkdirSync(logDir, { recursive: true });
} catch (error) {
  console.error('Failed to create logs directory:', error);
}

// Log startup information
logger.info('Logger initialized', {
  logLevel: process.env.LOG_LEVEL || 'info',
  logDir,
  nodeEnv: process.env.NODE_ENV,
  consoleLogging: transports.some(t => t.name === 'console'),
  fileLogging: transports.some(t => t.filename)
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