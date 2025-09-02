import React, {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
} from 'react';
import toast from 'react-hot-toast';
import { io } from 'socket.io-client';

const WebSocketContext = createContext();

export const useWebSocket = () => {
  const context = useContext(WebSocketContext);
  if (!context) {
    throw new Error('useWebSocket must be used within a WebSocketProvider');
  }
  return context;
};

export const WebSocketProvider = ({ children }) => {
  const [socket, setSocket] = useState(null);
  const [isConnected, setIsConnected] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState('disconnected');
  const [lastMessage, setLastMessage] = useState(null);
  const reconnectAttempts = useRef(0);
  const maxReconnectAttempts = 5;

  useEffect(() => {
    const serverUrl = import.meta.env.VITE_WS_URL || import.meta.env.VITE_API_URL?.replace('/api', '') || 'http://localhost:3001';

    const socketInstance = io(serverUrl, {
      transports: ['websocket'],
      upgrade: true,
      autoConnect: true,
      reconnection: true,
      reconnectionAttempts: maxReconnectAttempts,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      timeout: 5000,
    });

    // Connection event handlers
    socketInstance.on('connect', () => {
      setIsConnected(true);
      setConnectionStatus('connected');
      reconnectAttempts.current = 0;

      console.log('🔌 WebSocket connected');
      toast.success('Connected to PlanetPlant server');
    });

    socketInstance.on('disconnect', reason => {
      setIsConnected(false);
      setConnectionStatus('disconnected');

      console.log('🔌 WebSocket disconnected:', reason);

      if (reason === 'io server disconnect') {
        // Server initiated disconnect, try to reconnect
        socketInstance.connect();
      }
    });

    socketInstance.on('connect_error', error => {
      setConnectionStatus('error');
      reconnectAttempts.current++;

      console.error('🔌 WebSocket connection error:', error);

      if (reconnectAttempts.current >= maxReconnectAttempts) {
        toast.error('Failed to connect to server');
      }
    });

    socketInstance.on('reconnect', attemptNumber => {
      setIsConnected(true);
      setConnectionStatus('connected');
      reconnectAttempts.current = 0;

      console.log(`🔌 WebSocket reconnected after ${attemptNumber} attempts`);
      toast.success('Reconnected to server');
    });

    socketInstance.on('reconnect_attempt', attemptNumber => {
      setConnectionStatus('reconnecting');
      console.log(`🔌 WebSocket reconnect attempt ${attemptNumber}`);
    });

    socketInstance.on('reconnect_failed', () => {
      setConnectionStatus('failed');
      console.error('🔌 WebSocket reconnection failed');
      toast.error('Connection failed. Please refresh the page.');
    });

    // Server message handlers
    socketInstance.on('connectionEstablished', data => {
      console.log('🌱 Server connection established:', data);
    });

    socketInstance.on('sensorData', data => {
      setLastMessage({ type: 'sensorData', data, timestamp: Date.now() });
      console.log('📊 Sensor data received:', data);
    });

    socketInstance.on('plantStatus', data => {
      setLastMessage({ type: 'plantStatus', data, timestamp: Date.now() });
      console.log('🌱 Plant status update:', data);
    });

    socketInstance.on('wateringStarted', data => {
      setLastMessage({ type: 'wateringStarted', data, timestamp: Date.now() });
      toast.success(
        `💧 Watering started for ${data.plantName || `Plant ${data.plantId}`}`
      );
    });

    socketInstance.on('automaticWateringStarted', data => {
      setLastMessage({
        type: 'automaticWateringStarted',
        data,
        timestamp: Date.now(),
      });
      toast.info(
        `🤖 Auto-watering: ${data.plantName} (${data.moistureLevel}% moisture)`
      );
    });

    socketInstance.on('configUpdated', data => {
      setLastMessage({ type: 'configUpdated', data, timestamp: Date.now() });
      toast.success(`⚙️ Configuration updated for Plant ${data.plantId}`);
    });

    socketInstance.on('systemStatusUpdate', data => {
      setLastMessage({ type: 'systemStatus', data, timestamp: Date.now() });

      // Show alerts for critical system issues
      if (data.overall === 'unhealthy' && data.alerts?.length > 0) {
        const criticalAlerts = data.alerts.filter(
          alert => alert.severity === 'critical'
        );
        if (criticalAlerts.length > 0) {
          toast.error(`🚨 System Alert: ${criticalAlerts[0].message}`);
        }
      }
    });

    // Keep connection alive with ping/pong
    const pingInterval = setInterval(() => {
      if (socketInstance.connected) {
        socketInstance.emit('ping', { timestamp: Date.now() });
      }
    }, 30000);

    setSocket(socketInstance);

    // Cleanup on unmount
    return () => {
      clearInterval(pingInterval);
      socketInstance.disconnect();
    };
  }, []);

  // WebSocket utility functions
  const requestWatering = (plantId, duration = 5000, reason = 'manual') => {
    if (!socket || !isConnected) {
      toast.error('Not connected to server');
      return false;
    }

    socket.emit('requestWatering', {
      plantId,
      duration,
      reason,
    });

    return true;
  };

  const updateConfig = (plantId, config) => {
    if (!socket || !isConnected) {
      toast.error('Not connected to server');
      return false;
    }

    socket.emit('updateConfig', {
      plantId,
      config,
    });

    return true;
  };

  const sendSystemCommand = (command, parameters = {}) => {
    if (!socket || !isConnected) {
      toast.error('Not connected to server');
      return false;
    }

    socket.emit('systemCommand', {
      command,
      parameters,
    });

    return true;
  };

  // Subscribe to specific events
  const subscribe = (eventName, handler) => {
    if (!socket) return null;

    socket.on(eventName, handler);

    // Return unsubscribe function
    return () => {
      socket.off(eventName, handler);
    };
  };

  const value = {
    socket,
    isConnected,
    connectionStatus,
    lastMessage,
    reconnectAttempts: reconnectAttempts.current,

    // Actions
    requestWatering,
    updateConfig,
    sendSystemCommand,
    subscribe,
  };

  return (
    <WebSocketContext.Provider value={value}>
      {children}
    </WebSocketContext.Provider>
  );
};
