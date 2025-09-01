import { motion } from 'framer-motion';
import { AlertTriangle, Bug, RotateCcw } from 'lucide-react';
import React from 'react';

const ErrorFallback = ({ error, resetErrorBoundary }) => {
  const isDevelopment = import.meta.env.DEV;

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50 p-4 dark:bg-gray-900">
      <motion.div
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.3 }}
        className="w-full max-w-md"
      >
        <div className="card p-8 text-center">
          <motion.div
            initial={{ scale: 0.8, rotate: -10 }}
            animate={{ scale: 1, rotate: 0 }}
            transition={{ delay: 0.1, duration: 0.4, type: 'spring' }}
            className="mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30"
          >
            <AlertTriangle className="h-10 w-10 text-red-600 dark:text-red-400" />
          </motion.div>

          <motion.h1
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2, duration: 0.3 }}
            className="mb-3 text-2xl font-bold text-gray-900 dark:text-white"
          >
            Oops! Something went wrong
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3, duration: 0.3 }}
            className="mb-6 text-gray-600 dark:text-gray-400"
          >
            PlanetPlant encountered an unexpected error. Don&apos;t worry, your
            plants are still safe!
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4, duration: 0.3 }}
            className="space-y-3"
          >
            <button
              onClick={resetErrorBoundary}
              className="btn-primary inline-flex w-full items-center justify-center space-x-2"
            >
              <RotateCcw className="h-5 w-5" />
              <span>Try Again</span>
            </button>

            <button
              onClick={() => window.location.reload()}
              className="btn-secondary w-full"
            >
              Refresh Page
            </button>
          </motion.div>

          {/* Development Error Details */}
          {isDevelopment && error && (
            <motion.details
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              transition={{ delay: 0.5, duration: 0.3 }}
              className="mt-6 text-left"
            >
              <summary className="flex cursor-pointer items-center space-x-2 text-sm font-medium text-gray-700 hover:text-gray-900 dark:text-gray-300 dark:hover:text-gray-100">
                <Bug className="h-4 w-4" />
                <span>Error Details (Development)</span>
              </summary>

              <div className="mt-3 max-h-40 overflow-auto rounded-lg bg-gray-100 p-4 font-mono text-xs text-gray-800 dark:bg-gray-800 dark:text-gray-200">
                <div className="mb-2">
                  <strong>Error:</strong> {error.message}
                </div>
                {error.stack && (
                  <div>
                    <strong>Stack:</strong>
                    <pre className="mt-1 whitespace-pre-wrap">
                      {error.stack}
                    </pre>
                  </div>
                )}
              </div>
            </motion.details>
          )}

          {/* Contact Support */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.6, duration: 0.3 }}
            className="mt-6 border-t border-gray-200 pt-6 dark:border-gray-700"
          >
            <p className="text-xs text-gray-500 dark:text-gray-400">
              If this problem persists, please{' '}
              <a
                href="https://github.com/yourusername/PlanetPlant/issues"
                target="_blank"
                rel="noopener noreferrer"
                className="text-primary-600 underline hover:text-primary-700 dark:text-primary-400 dark:hover:text-primary-300"
              >
                report this issue
              </a>{' '}
              on GitHub.
            </p>
          </motion.div>
        </div>
      </motion.div>
    </div>
  );
};

export default ErrorFallback;
