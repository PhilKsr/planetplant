import { AlertTriangle, RotateCcw } from 'lucide-react';
import { motion } from 'framer-motion';
import React from 'react';

const ErrorState = ({
  title = 'Something went wrong',
  message = 'An error occurred. Please try again.',
  onRetry,
  showRetry = true,
  className = '',
}) => {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      className={`flex flex-col items-center justify-center p-8 text-center ${className}`}
    >
      <motion.div
        initial={{ scale: 0.8 }}
        animate={{ scale: 1 }}
        transition={{ delay: 0.1, duration: 0.3 }}
        className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30"
      >
        <AlertTriangle className="h-8 w-8 text-red-600 dark:text-red-400" />
      </motion.div>

      <motion.h3
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.2, duration: 0.3 }}
        className="mb-2 text-lg font-semibold text-gray-900 dark:text-white"
      >
        {title}
      </motion.h3>

      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.3, duration: 0.3 }}
        className="mb-6 max-w-md text-gray-600 dark:text-gray-400"
      >
        {message}
      </motion.p>

      {showRetry && onRetry && (
        <motion.button
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.4, duration: 0.3 }}
          onClick={onRetry}
          className="btn-primary inline-flex items-center space-x-2"
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
        >
          <RotateCcw className="h-5 w-5" />
          <span>Try Again</span>
        </motion.button>
      )}
    </motion.div>
  );
};

export default ErrorState;
