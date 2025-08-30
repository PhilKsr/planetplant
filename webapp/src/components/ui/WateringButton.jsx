import { IconDroplet } from '@tabler/icons-react';
import { motion } from 'framer-motion';
import React, { useState } from 'react';
import toast from 'react-hot-toast';

import { useWebSocket } from '../../context/WebSocketContext';

const WateringButton = ({
  plantId,
  plantName = 'Plant',
  duration = 5000,
  disabled = false,
  size = 'md',
  className = '',
}) => {
  const [isWatering, setIsWatering] = useState(false);
  const { requestWatering, isConnected } = useWebSocket();

  const handleWatering = async e => {
    e.preventDefault(); // Prevent navigation if inside Link
    e.stopPropagation();

    if (!isConnected) {
      toast.error('Not connected to server');
      return;
    }

    if (disabled) {
      toast.error('Plant is offline');
      return;
    }

    setIsWatering(true);

    try {
      const success = requestWatering(plantId, duration, 'manual_button');

      if (success) {
        toast.loading(`Watering ${plantName}...`, {
          duration: duration + 1000,
          id: `watering-${plantId}`,
        });

        // Reset button state after watering duration
        setTimeout(() => {
          setIsWatering(false);
          toast.success(`${plantName} watered successfully!`, {
            id: `watering-${plantId}`,
          });
        }, duration);
      } else {
        setIsWatering(false);
        toast.error('Failed to send watering command');
      }
    } catch (error) {
      setIsWatering(false);
      toast.error('Watering failed: ' + error.message);
    }
  };

  const sizeClasses = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-sm',
    lg: 'px-6 py-3 text-base',
  };

  const iconSizes = {
    sm: 'w-4 h-4',
    md: 'w-5 h-5',
    lg: 'w-6 h-6',
  };

  return (
    <motion.button
      onClick={handleWatering}
      disabled={disabled || isWatering || !isConnected}
      whileHover={disabled ? {} : { scale: 1.05 }}
      whileTap={disabled ? {} : { scale: 0.95 }}
      className={`inline-flex items-center justify-center space-x-2 rounded-lg font-medium transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 ${sizeClasses[size]} ${
        disabled || !isConnected
          ? 'cursor-not-allowed bg-gray-100 text-gray-400 dark:bg-gray-700'
          : isWatering
            ? 'cursor-wait bg-blue-600 text-white'
            : 'bg-blue-500 text-white shadow-sm hover:bg-blue-600 hover:shadow focus:ring-blue-500'
      } ${className} `}
    >
      <motion.div
        animate={
          isWatering
            ? {
                y: [0, -2, 0],
                transition: { repeat: Infinity, duration: 0.6 },
              }
            : {}
        }
      >
        <IconDroplet
          className={`${iconSizes[size]} ${isWatering ? 'text-blue-200' : ''}`}
        />
      </motion.div>

      <span>{isWatering ? 'Watering...' : 'Water'}</span>

      {isWatering && (
        <motion.div
          className="h-4 w-4 rounded-full border-2 border-white border-t-transparent"
          animate={{ rotate: 360 }}
          transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
        />
      )}
    </motion.button>
  );
};

export default WateringButton;
