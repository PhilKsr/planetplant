import { logger } from '../utils/logger.js';
import { plantService } from '../services/plantService.js';
import { mqttClient } from '../services/mqttClient.js';
import { healthService } from '../services/healthService.js';
import { setIO } from '../services/mqttClient.js';

export const setupWebSocket = (io) => {
  setIO(io);
  
  const connectedClients = new Map();
  
  io.on('connection', (socket) => {
    const clientId = socket.id;
    const clientInfo = {
      id: clientId,
      ip: socket.handshake.address,
      userAgent: socket.handshake.headers['user-agent'],
      connectedAt: new Date().toISOString()
    };
    
    connectedClients.set(clientId, clientInfo);
    
    logger.info(`🔌 WebSocket client connected: ${clientId}`);
    
    // Send initial data to new client
    socket.emit('connectionEstablished', {
      clientId,
      serverTime: new Date().toISOString(),
      message: 'Connected to PlanetPlant server'
    });

    // Send current plants data
    plantService.getAllPlants()
      .then(plants => {
        socket.emit('plantsData', {
          plants,
          timestamp: new Date().toISOString()
        });
      })
      .catch(error => {
        logger.error('Failed to send initial plants data:', error);
      });

    // Send system status
    healthService.getSystemStatus()
      .then(status => {
        socket.emit('systemStatus', status);
      })
      .catch(error => {
        logger.error('Failed to send initial system status:', error);
      });

    // Handle manual watering requests via WebSocket
    socket.on('requestWatering', async (data) => {
      try {
        const { plantId, duration = 5000, reason = 'manual_websocket' } = data;
        
        logger.info(`💧 WebSocket watering request for plant ${plantId}`);
        
        const plant = await plantService.getPlantById(plantId);
        
        // Check if watering is allowed
        const { canWater, reason: cantWaterReason } = plantService.canWater(plant);
        
        if (!canWater) {
          socket.emit('wateringResponse', {
            success: false,
            plantId,
            error: 'Watering not allowed',
            reason: cantWaterReason,
            timestamp: new Date().toISOString()
          });
          return;
        }
        
        // Send MQTT command
        const success = mqttClient.publishWateringCommand(plantId, duration);
        
        if (success) {
          // Record watering event
          await plantService.recordWateringEvent(plantId, {
            duration,
            triggerType: 'manual',
            reason,
            success: true
          });
          
          // Broadcast to all clients
          io.emit('wateringStarted', {
            plantId,
            duration,
            reason,
            timestamp: new Date().toISOString()
          });
          
          socket.emit('wateringResponse', {
            success: true,
            plantId,
            duration,
            message: 'Watering command sent',
            timestamp: new Date().toISOString()
          });
        } else {
          socket.emit('wateringResponse', {
            success: false,
            plantId,
            error: 'Failed to send watering command',
            reason: 'mqtt_error',
            timestamp: new Date().toISOString()
          });
        }
        
      } catch (error) {
        logger.error('WebSocket watering request failed:', error);
        socket.emit('wateringResponse', {
          success: false,
          error: error.message,
          timestamp: new Date().toISOString()
        });
      }
    });

    // Handle configuration updates via WebSocket
    socket.on('updateConfig', async (data) => {
      try {
        const { plantId, config } = data;
        
        logger.info(`⚙️ WebSocket config update for plant ${plantId}`);
        
        const updatedPlant = await plantService.updatePlantConfig(plantId, config);
        
        // Send config to ESP32
        mqttClient.publishConfigUpdate(plantId, updatedPlant.config);
        
        // Broadcast to all clients
        io.emit('configUpdated', {
          plantId,
          config: updatedPlant.config,
          timestamp: new Date().toISOString()
        });
        
        socket.emit('configResponse', {
          success: true,
          plantId,
          config: updatedPlant.config,
          timestamp: new Date().toISOString()
        });
        
      } catch (error) {
        logger.error('WebSocket config update failed:', error);
        socket.emit('configResponse', {
          success: false,
          error: error.message,
          timestamp: new Date().toISOString()
        });
      }
    });

    // Handle system commands via WebSocket
    socket.on('systemCommand', async (data) => {
      try {
        const { command, parameters = {} } = data;
        
        logger.info(`🔧 WebSocket system command: ${command}`);
        
        let result = {};
        
        switch (command) {
          case 'getStatus':
            result = await healthService.getSystemStatus();
            break;
            
          case 'getPlants':
            result = await plantService.getAllPlants();
            break;
            
          case 'refreshData':
            // Trigger data refresh for all plants
            result = await plantService.getAllPlants();
            io.emit('plantsData', {
              plants: result,
              timestamp: new Date().toISOString()
            });
            break;
            
          default:
            throw new Error(`Unknown system command: ${command}`);
        }
        
        socket.emit('systemCommandResponse', {
          success: true,
          command,
          data: result,
          timestamp: new Date().toISOString()
        });
        
      } catch (error) {
        logger.error('WebSocket system command failed:', error);
        socket.emit('systemCommandResponse', {
          success: false,
          command: data.command,
          error: error.message,
          timestamp: new Date().toISOString()
        });
      }
    });

    // Handle client heartbeat
    socket.on('ping', (data) => {
      socket.emit('pong', {
        ...data,
        serverTime: new Date().toISOString()
      });
    });

    // Handle disconnection
    socket.on('disconnect', (reason) => {
      connectedClients.delete(clientId);
      logger.info(`🔌 WebSocket client disconnected: ${clientId} (${reason})`);
    });

    // Handle connection errors
    socket.on('error', (error) => {
      logger.error(`🔌 WebSocket error for client ${clientId}:`, error);
    });
  });

  // Broadcast system status updates every 30 seconds
  setInterval(async () => {
    try {
      const status = await healthService.getSystemStatus();
      io.emit('systemStatusUpdate', status);
    } catch (error) {
      logger.error('Failed to broadcast system status:', error);
    }
  }, 30000);

  // Broadcast plants summary every 60 seconds
  setInterval(async () => {
    try {
      const summary = plantService.getPlantSummary();
      io.emit('plantsSummaryUpdate', summary);
    } catch (error) {
      logger.error('Failed to broadcast plants summary:', error);
    }
  }, 60000);

  logger.info('🔌 WebSocket server configured with real-time updates');
  
  return {
    getConnectedClients: () => Array.from(connectedClients.values()),
    getClientCount: () => connectedClients.size,
    broadcastToAll: (event, data) => {
      io.emit(event, {
        ...data,
        timestamp: new Date().toISOString()
      });
    }
  };
};