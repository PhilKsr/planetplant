import { motion } from 'framer-motion';
import React from 'react';

const StatusBadge = ({ status, size = 'sm', showIcon = true }) => {
  const configs = {
    online: {
      bg: 'bg-green-100 dark:bg-green-900/30',
      text: 'text-green-800 dark:text-green-200',
      border: 'border-green-200 dark:border-green-800',
      dot: 'bg-green-500',
      label: 'Online',
    },
    offline: {
      bg: 'bg-red-100 dark:bg-red-900/30',
      text: 'text-red-800 dark:text-red-200',
      border: 'border-red-200 dark:border-red-800',
      dot: 'bg-red-500',
      label: 'Offline',
    },
    warning: {
      bg: 'bg-yellow-100 dark:bg-yellow-900/30',
      text: 'text-yellow-800 dark:text-yellow-200',
      border: 'border-yellow-200 dark:border-yellow-800',
      dot: 'bg-yellow-500',
      label: 'Warning',
    },
    loading: {
      bg: 'bg-gray-100 dark:bg-gray-800',
      text: 'text-gray-600 dark:text-gray-400',
      border: 'border-gray-200 dark:border-gray-700',
      dot: 'bg-gray-400',
      label: 'Loading',
    },
  };

  const config = configs[status] || configs.offline;

  const sizeClasses = {
    xs: 'px-2 py-0.5 text-xs',
    sm: 'px-2.5 py-0.5 text-xs',
    md: 'px-3 py-1 text-sm',
    lg: 'px-4 py-1.5 text-sm',
  };

  const dotSizes = {
    xs: 'w-1.5 h-1.5',
    sm: 'w-2 h-2',
    md: 'w-2.5 h-2.5',
    lg: 'w-3 h-3',
  };

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.8 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.2 }}
      className={`inline-flex items-center space-x-1.5 rounded-full border font-medium ${config.bg} ${config.text} ${config.border} ${sizeClasses[size]} `}
    >
      {showIcon && (
        <motion.div
          className={`${dotSizes[size]} ${config.dot} rounded-full`}
          animate={
            status === 'online'
              ? {
                  scale: [1, 1.2, 1],
                  transition: { repeat: Infinity, duration: 2 },
                }
              : {}
          }
        />
      )}
      <span>{config.label}</span>
    </motion.div>
  );
};

export default StatusBadge;
