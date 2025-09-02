import dotenv from 'dotenv';


dotenv.config();

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { createServer } from 'http';
import { Server } from 'socket.io';

import { logger } from './utils/logger.js';
import { mqttClient } from './services/mqttClient.js';
import { influxService } from './services/influxService.js';
import { plantService } from './services/plantService.js';
import { automationService } from './services/automationService.js';
import { healthService } from './services/healthService.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';
import { requestLogger } from './middleware/requestLogger.js';

import plantsRouter from './routes/plants.js';
import systemRouter from './routes/system.js';
import { setupWebSocket } from './websocket/socketHandler.js';

const app = express();
const server = createServer(app);
const io = new Server(server, {
  cors: {
    origin: process.env.CORS_ORIGINS?.split(',') || ['http://localhost:3001', 'http://localhost:5173'],
    credentials: true
  }
});

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

app.use(helmet({
  contentSecurityPolicy: false, // Disable for API
}));

app.use(compression());

const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX) || 100,
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(limiter);

app.use(cors({
  origin: process.env.CORS_ORIGINS?.split(',') || ['http://localhost:3001', 'http://localhost:5173'],
  credentials: true
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.use(requestLogger);

app.use('/api/plants', plantsRouter);
app.use('/api/system', systemRouter);

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

app.get('/', (req, res) => {
  res.json({
    name: 'PlanetPlant API',
    version: process.env.npm_package_version || '1.0.0',
    description: 'Smart Plant Watering System API',
    endpoints: {
      plants: '/api/plants',
      system: '/api/system',
      health: '/health'
    }
  });
});

app.use(notFoundHandler);
app.use(errorHandler);

setupWebSocket(io);

const startServer = async () => {
  try {
    logger.info('🌱 Starting PlanetPlant Server...');
    logger.info(`📍 Environment: ${process.env.NODE_ENV}`);
    logger.info(`🔧 Port: ${PORT}, Host: ${HOST}`);
    
    // Start HTTP server first to accept health checks
    server.listen(PORT, HOST, () => {
      logger.info(`🚀 Server running on http://${HOST}:${PORT}`);
    });
    
    // Initialize services with retry logic
    const initWithRetry = async (name, initFn, maxRetries = 3) => {
      for (let i = 0; i < maxRetries; i++) {
        try {
          logger.info(`📊 ${name} - Attempt ${i + 1}/${maxRetries}`);
          await initFn();
          logger.info(`✅ ${name} initialized successfully`);
          return;
        } catch (error) {
          logger.warn(`⚠️ ${name} failed (${i + 1}/${maxRetries}):`, error.message);
          if (i === maxRetries - 1) throw error;
          await new Promise(resolve => setTimeout(resolve, 2000 * (i + 1))); // Exponential backoff
        }
      }
    };
    
    // Initialize services with retry logic
    await initWithRetry('InfluxDB Connection', () => influxService.initialize());
    await initWithRetry('MQTT Broker Connection', () => mqttClient.initialize());
    await initWithRetry('Plant Service', () => plantService.initialize());
    
    // Start optional services (don't fail startup if these fail)
    try {
      logger.info('🤖 Starting Automation Service...');
      automationService.start();
      logger.info('✅ Automation Service started');
    } catch (error) {
      logger.warn('⚠️ Automation Service failed to start:', error.message);
    }
    
    try {
      logger.info('💊 Starting Health Monitoring...');
      healthService.start();
      logger.info('✅ Health Monitoring started');
    } catch (error) {
      logger.warn('⚠️ Health Monitoring failed to start:', error.message);
    }
    
    logger.info(`📡 WebSocket server ready for real-time updates`);
    logger.info(`🌱 PlanetPlant is ready to grow!`);
    
  } catch (error) {
    logger.error('❌ Failed to start server:', error);
    logger.error('🔄 Server will restart automatically...');
    process.exit(1);
  }
};

const gracefulShutdown = async (signal) => {
  logger.info(`📵 Received ${signal}. Shutting down gracefully...`);
  
  server.close(async () => {
    try {
      logger.info('🔌 Closing HTTP server...');
      
      logger.info('🛑 Stopping Automation Service...');
      automationService.stop();
      
      logger.info('💊 Stopping Health Service...');
      healthService.stop();
      
      logger.info('📡 Disconnecting MQTT Client...');
      await mqttClient.disconnect();
      
      logger.info('📊 Closing InfluxDB connection...');
      await influxService.close();
      
      logger.info('✅ Graceful shutdown completed');
      process.exit(0);
    } catch (error) {
      logger.error('❌ Error during shutdown:', error);
      process.exit(1);
    }
  });
  
  setTimeout(() => {
    logger.error('⏰ Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

process.on('uncaughtException', (error) => {
  logger.error('🚨 Uncaught Exception:', error);
  gracefulShutdown('uncaughtException');
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('🚨 Unhandled Rejection at:', promise, 'reason:', reason);
  gracefulShutdown('unhandledRejection');
});

if (process.env.NODE_ENV !== 'test') {
  startServer();
}

export { app, server, io };