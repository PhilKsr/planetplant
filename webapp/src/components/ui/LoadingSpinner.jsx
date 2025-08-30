import { motion } from 'framer-motion';
import React from 'react';

const LoadingSpinner = ({ size = 'md', message, className = '' }) => {
  const sizeClasses = {
    xs: 'w-4 h-4',
    sm: 'w-6 h-6',
    md: 'w-8 h-8',
    lg: 'w-12 h-12',
    xl: 'w-16 h-16',
  };

  return (
    <div className={`flex flex-col items-center justify-center ${className}`}>
      <motion.div
        className={`${sizeClasses[size]} rounded-full border-4 border-gray-200 border-t-primary-600 dark:border-gray-700`}
        animate={{ rotate: 360 }}
        transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
      />

      {message && (
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.5 }}
          className="mt-3 text-center text-sm text-gray-600 dark:text-gray-400"
        >
          {message}
        </motion.p>
      )}
    </div>
  );
};

export default LoadingSpinner;
