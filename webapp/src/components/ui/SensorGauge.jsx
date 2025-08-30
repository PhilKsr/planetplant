import { motion } from 'framer-motion';
import React from 'react';

const SensorGauge = ({
  value = 0,
  max = 100,
  min = 0,
  size = 120,
  thickness = 12,
  color = '#3b82f6',
  backgroundColor = '#e5e7eb',
  label,
  unit,
  showValue = true,
  animationDuration = 1,
}) => {
  const radius = (size - thickness) / 2;
  const circumference = radius * 2 * Math.PI;
  const normalizedValue = Math.max(min, Math.min(max, value));
  const percentage = ((normalizedValue - min) / (max - min)) * 100;
  const strokeDashoffset = circumference - (percentage / 100) * circumference;

  // Determine color based on value for moisture sensor
  const getColor = () => {
    if (label === 'Moisture') {
      if (percentage < 30) return '#ef4444'; // Red for low moisture
      if (percentage < 60) return '#f59e0b'; // Yellow/orange for medium
      return '#10b981'; // Green for good moisture
    }
    return color;
  };

  const gaugeColor = getColor();

  return (
    <div className="flex flex-col items-center">
      <div className="relative">
        <svg width={size} height={size} className="-rotate-90 transform">
          {/* Background circle */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            stroke={backgroundColor}
            strokeWidth={thickness}
            fill="transparent"
            className="dark:stroke-gray-600"
          />

          {/* Progress circle */}
          <motion.circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            stroke={gaugeColor}
            strokeWidth={thickness}
            fill="transparent"
            strokeLinecap="round"
            strokeDasharray={circumference}
            initial={{ strokeDashoffset: circumference }}
            animate={{ strokeDashoffset }}
            transition={{
              duration: animationDuration,
              ease: 'easeOut',
              delay: 0.2,
            }}
            className="drop-shadow-sm filter"
          />
        </svg>

        {/* Center content */}
        {showValue && (
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <motion.div
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: 0.5, duration: 0.3 }}
              className="text-center"
            >
              <div className="text-xl font-bold text-gray-900 dark:text-white">
                {normalizedValue.toFixed(1)}
              </div>
              {unit && (
                <div className="text-sm text-gray-500 dark:text-gray-400">
                  {unit}
                </div>
              )}
            </motion.div>
          </div>
        )}
      </div>

      {/* Label */}
      {label && (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.7, duration: 0.3 }}
          className="mt-2 text-sm font-medium text-gray-700 dark:text-gray-300"
        >
          {label}
        </motion.div>
      )}
    </div>
  );
};

export default SensorGauge;
