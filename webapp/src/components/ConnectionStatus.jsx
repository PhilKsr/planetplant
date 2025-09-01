import { AnimatePresence, motion } from 'framer-motion';
import { AlertTriangle, Wifi, X } from 'lucide-react';
import React from 'react';

import { useWebSocket } from '../context/WebSocketContext';

const ConnectionStatus = () => {
  const { connectionStatus } = useWebSocket();

  const getStatusConfig = () => {
    switch (connectionStatus) {
      case 'connected':
        return {
          show: false, // Don't show when connected
          color: 'bg-green-500',
          icon: Wifi,
          message: 'Connected',
        };
      case 'reconnecting':
        return {
          show: true,
          color: 'bg-yellow-500',
          icon: AlertTriangle,
          message: 'Reconnecting...',
        };
      case 'disconnected':
      case 'error':
      case 'failed':
        return {
          show: true,
          color: 'bg-red-500',
          icon: X,
          message: 'Connection Lost',
        };
      default:
        return {
          show: false,
          color: 'bg-gray-500',
          icon: Wifi,
          message: 'Unknown',
        };
    }
  };

  const config = getStatusConfig();

  return (
    <AnimatePresence>
      {config.show && (
        <motion.div
          initial={{ opacity: 0, y: 50 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: 50 }}
          className="fixed bottom-4 right-4 z-50 lg:bottom-6 lg:right-6"
        >
          <div
            className={`flex items-center space-x-2 rounded-full px-4 py-2 text-white shadow-lg ${config.color} backdrop-blur-sm`}
          >
            <config.icon className="h-4 w-4" />
            <span className="text-sm font-medium">{config.message}</span>

            {connectionStatus === 'reconnecting' && (
              <div className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
            )}
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

export default ConnectionStatus;
