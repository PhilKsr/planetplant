import { logger } from './logger.js';

// Time utility functions
export const parseTimeRange = (timeRange) => {
  const units = {
    's': 1000,
    'm': 60 * 1000,
    'h': 60 * 60 * 1000,
    'd': 24 * 60 * 60 * 1000
  };
  
  const match = timeRange.match(/^(\d+)([smhd])$/);
  if (!match) {
    throw new Error(`Invalid time range format: ${timeRange}`);
  }
  
  const [, value, unit] = match;
  return parseInt(value) * units[unit];
};

export const formatDuration = (milliseconds) => {
  const seconds = Math.floor(milliseconds / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  
  if (days > 0) {
    return `${days}d ${hours % 24}h ${minutes % 60}m`;
  } else if (hours > 0) {
    return `${hours}h ${minutes % 60}m`;
  } else if (minutes > 0) {
    return `${minutes}m ${seconds % 60}s`;
  } else {
    return `${seconds}s`;
  }
};

export const isInQuietHours = (quietStart, quietEnd) => {
  const now = new Date();
  const currentHour = now.getHours();
  const currentMinute = now.getMinutes();
  const currentTime = currentHour * 60 + currentMinute;
  
  const [startHour, startMinute] = quietStart.split(':').map(Number);
  const [endHour, endMinute] = quietEnd.split(':').map(Number);
  
  const startTime = startHour * 60 + startMinute;
  const endTime = endHour * 60 + endMinute;
  
  // Handle overnight quiet hours (e.g., 22:00 to 06:00)
  if (startTime > endTime) {
    return currentTime >= startTime || currentTime <= endTime;
  } else {
    return currentTime >= startTime && currentTime <= endTime;
  }
};

// Data processing utilities
export const calculateAverage = (values) => {
  if (!values || values.length === 0) return 0;
  const sum = values.reduce((acc, val) => acc + val, 0);
  return sum / values.length;
};

export const calculateMedian = (values) => {
  if (!values || values.length === 0) return 0;
  
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  
  if (sorted.length % 2 === 0) {
    return (sorted[middle - 1] + sorted[middle]) / 2;
  } else {
    return sorted[middle];
  }
};

export const smoothData = (data, windowSize = 5) => {
  if (!data || data.length < windowSize) return data;
  
  const smoothed = [];
  
  for (let i = 0; i < data.length; i++) {
    const start = Math.max(0, i - Math.floor(windowSize / 2));
    const end = Math.min(data.length, start + windowSize);
    const window = data.slice(start, end);
    
    const average = calculateAverage(window.map(item => item.value));
    
    smoothed.push({
      ...data[i],
      value: average,
      originalValue: data[i].value
    });
  }
  
  return smoothed;
};

// Validation utilities
export const isValidPlantId = (plantId) => {
  return /^[a-zA-Z0-9_-]+$/.test(plantId) && plantId.length >= 3 && plantId.length <= 50;
};

export const isValidSensorValue = (value, type) => {
  if (typeof value !== 'number' || isNaN(value)) return false;
  
  switch (type) {
    case 'temperature':
      return value >= -50 && value <= 100;
    case 'humidity':
    case 'moisture':
      return value >= 0 && value <= 100;
    case 'light':
      return value >= 0 && value <= 100000;
    case 'batteryLevel':
      return value >= 0 && value <= 100;
    case 'wifiStrength':
      return value >= -100 && value <= 0;
    default:
      return false;
  }
};

// System utilities
export const getSystemLoad = () => {
  const loadAvg = require('os').loadavg();
  const cpuCount = require('os').cpus().length;
  
  return {
    '1min': (loadAvg[0] / cpuCount * 100).toFixed(2),
    '5min': (loadAvg[1] / cpuCount * 100).toFixed(2),
    '15min': (loadAvg[2] / cpuCount * 100).toFixed(2)
  };
};

export const getMemoryUsage = () => {
  const process = require('process');
  const os = require('os');
  
  const processMemory = process.memoryUsage();
  const totalMemory = os.totalmem();
  const freeMemory = os.freemem();
  const usedMemory = totalMemory - freeMemory;
  
  return {
    system: {
      total: Math.round(totalMemory / 1024 / 1024),
      used: Math.round(usedMemory / 1024 / 1024),
      free: Math.round(freeMemory / 1024 / 1024),
      usage: ((usedMemory / totalMemory) * 100).toFixed(2)
    },
    process: {
      rss: Math.round(processMemory.rss / 1024 / 1024),
      heapUsed: Math.round(processMemory.heapUsed / 1024 / 1024),
      heapTotal: Math.round(processMemory.heapTotal / 1024 / 1024),
      external: Math.round(processMemory.external / 1024 / 1024)
    }
  };
};

// Async utilities
export const delay = (milliseconds) => {
  return new Promise(resolve => setTimeout(resolve, milliseconds));
};

export const retry = async (fn, maxAttempts = 3, delayMs = 1000) => {
  let lastError;
  
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      
      if (attempt === maxAttempts) {
        logger.error(`Retry failed after ${maxAttempts} attempts:`, error);
        throw error;
      }
      
      logger.warn(`Attempt ${attempt}/${maxAttempts} failed, retrying in ${delayMs}ms:`, error.message);
      await delay(delayMs);
    }
  }
  
  throw lastError;
};

export const timeout = (promise, ms, errorMessage = 'Operation timed out') => {
  return Promise.race([
    promise,
    new Promise((_, reject) => 
      setTimeout(() => reject(new Error(errorMessage)), ms)
    )
  ]);
};

// Data transformation utilities
export const transformSensorDataForChart = (sensorData, sensorType) => {
  if (!sensorData[sensorType] || !Array.isArray(sensorData[sensorType])) {
    return [];
  }
  
  return sensorData[sensorType].map(reading => ({
    timestamp: new Date(reading.timestamp).getTime(),
    value: reading.value,
    unit: reading.unit
  }));
};

export const groupDataByTimeInterval = (data, intervalMinutes = 60) => {
  if (!data || data.length === 0) return [];
  
  const intervalMs = intervalMinutes * 60 * 1000;
  const grouped = new Map();
  
  data.forEach(item => {
    const timestamp = new Date(item.timestamp).getTime();
    const intervalKey = Math.floor(timestamp / intervalMs) * intervalMs;
    
    if (!grouped.has(intervalKey)) {
      grouped.set(intervalKey, []);
    }
    
    grouped.get(intervalKey).push(item);
  });
  
  // Calculate averages for each interval
  return Array.from(grouped.entries()).map(([intervalStart, items]) => ({
    timestamp: intervalStart,
    value: calculateAverage(items.map(item => item.value)),
    count: items.length,
    min: Math.min(...items.map(item => item.value)),
    max: Math.max(...items.map(item => item.value))
  })).sort((a, b) => a.timestamp - b.timestamp);
};

// Configuration utilities
export const loadConfig = (configPath) => {
  try {
    const config = JSON.parse(require('fs').readFileSync(configPath, 'utf8'));
    return config;
  } catch (error) {
    logger.warn(`Failed to load config from ${configPath}:`, error.message);
    return {};
  }
};

export const mergeConfigs = (...configs) => {
  return configs.reduce((merged, config) => {
    return { ...merged, ...config };
  }, {});
};

// Error utilities
export const createError = (message, statusCode = 500, details = null) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  error.details = details;
  return error;
};

export const isOperationalError = (error) => {
  return error.isOperational === true;
};

// Device utilities
export const generateDeviceId = (prefix = 'device') => {
  const timestamp = Date.now().toString(36);
  const randomStr = Math.random().toString(36).substring(2, 8);
  return `${prefix}-${timestamp}-${randomStr}`;
};

export const parseDeviceId = (deviceId) => {
  const parts = deviceId.split('-');
  return {
    prefix: parts[0],
    timestamp: parts[1] ? parseInt(parts[1], 36) : null,
    random: parts[2] || null
  };
};

// Network utilities
export const getLocalIPAddress = () => {
  const { networkInterfaces } = require('os');
  const interfaces = networkInterfaces();
  
  for (const name of Object.keys(interfaces)) {
    for (const networkInterface of interfaces[name]) {
      // Skip internal and non-IPv4 addresses
      if (networkInterface.family === 'IPv4' && !networkInterface.internal) {
        return networkInterface.address;
      }
    }
  }
  
  return '127.0.0.1';
};

// String utilities
export const sanitizeInput = (input) => {
  if (typeof input !== 'string') return input;
  
  return input
    .replace(/[<>]/g, '') // Remove potential HTML tags
    .trim()
    .substring(0, 1000); // Limit length
};

export const generateRandomString = (length = 16) => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  
  return result;
};

// Date utilities
export const formatTimestamp = (timestamp, timezone = 'UTC') => {
  return new Date(timestamp).toLocaleString('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  });
};

export const getStartOfDay = (date = new Date()) => {
  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);
  return startOfDay;
};

export const getEndOfDay = (date = new Date()) => {
  const endOfDay = new Date(date);
  endOfDay.setHours(23, 59, 59, 999);
  return endOfDay;
};