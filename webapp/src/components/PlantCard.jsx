import {
  IconAlertTriangle,
  IconBattery,
  IconDroplet,
  IconTemperature,
  IconWifi,
} from '@tabler/icons-react';
import { motion } from 'framer-motion';
import React from 'react';
import { Link } from 'react-router-dom';

import SensorGauge from './ui/SensorGauge';
import StatusBadge from './ui/StatusBadge';
import WateringButton from './ui/WateringButton';

const PlantCard = ({ plant }) => {
  const { id, name, type, location, status, currentData, config, stats } =
    plant;

  // Calculate time since last watering
  const getTimeSinceLastWatering = () => {
    if (!stats?.lastWatering) return 'Never';

    const lastWatering = new Date(stats.lastWatering);
    const now = new Date();
    const diffHours = Math.floor((now - lastWatering) / (1000 * 60 * 60));

    if (diffHours < 1) return 'Just now';
    if (diffHours < 24) return `${diffHours}h ago`;

    const diffDays = Math.floor(diffHours / 24);
    return `${diffDays}d ago`;
  };

  // Determine plant health status
  const getPlantHealth = () => {
    if (!status?.isOnline) return 'offline';

    const moisture = currentData?.moisture;
    const temperature = currentData?.temperature;
    const minMoisture = config?.moistureThresholds?.min || 30;
    const maxTemp = config?.temperatureThresholds?.max || 35;

    if (moisture !== null && moisture < minMoisture) return 'needs-water';
    if (temperature !== null && temperature > maxTemp) return 'too-hot';

    return 'healthy';
  };

  const health = getPlantHealth();
  const needsAttention = ['needs-water', 'too-hot', 'offline'].includes(health);

  return (
    <motion.div
      whileHover={{ y: -2, scale: 1.02 }}
      transition={{ duration: 0.2 }}
      className="group"
    >
      <Link to={`/plants/${id}`}>
        <div
          className={`card card-hover h-full p-6 ${
            needsAttention ? 'ring-2 ring-yellow-400 dark:ring-yellow-500' : ''
          }`}
        >
          {/* Header */}
          <div className="mb-4 flex items-start justify-between">
            <div className="min-w-0 flex-1">
              <h3 className="truncate text-lg font-semibold text-gray-900 dark:text-white">
                {name}
              </h3>
              <div className="mt-1 flex items-center space-x-2">
                <span className="text-sm capitalize text-gray-500 dark:text-gray-400">
                  {type}
                </span>
                {location && (
                  <>
                    <span className="text-gray-300">•</span>
                    <span className="text-sm text-gray-500 dark:text-gray-400">
                      {location}
                    </span>
                  </>
                )}
              </div>
            </div>

            <StatusBadge status={status?.isOnline ? 'online' : 'offline'} />
          </div>

          {/* Attention Alert */}
          {needsAttention && (
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="mb-4 rounded-lg border border-yellow-200 bg-yellow-50 p-3 dark:border-yellow-800 dark:bg-yellow-900/20"
            >
              <div className="flex items-center space-x-2">
                <IconAlertTriangle className="h-5 w-5 text-yellow-600 dark:text-yellow-400" />
                <span className="text-sm font-medium text-yellow-800 dark:text-yellow-200">
                  {health === 'needs-water' && 'Needs watering'}
                  {health === 'too-hot' && 'Temperature too high'}
                  {health === 'offline' && 'Device offline'}
                </span>
              </div>
            </motion.div>
          )}

          {/* Main Sensors */}
          <div className="mb-6 grid grid-cols-2 gap-4">
            {/* Moisture Gauge */}
            <div className="text-center">
              <SensorGauge
                value={currentData?.moisture || 0}
                max={100}
                size={80}
                thickness={8}
                color={
                  currentData?.moisture <
                  (config?.moistureThresholds?.min || 30)
                    ? '#ef4444'
                    : '#3b82f6'
                }
                label="Moisture"
                unit="%"
              />
            </div>

            {/* Temperature & Humidity */}
            <div className="space-y-3">
              <div className="flex items-center space-x-2">
                <IconTemperature className="h-5 w-5 text-red-500" />
                <div className="flex-1">
                  <div className="flex items-baseline space-x-1">
                    <span className="text-lg font-semibold text-gray-900 dark:text-white">
                      {currentData?.temperature?.toFixed(1) || '--'}
                    </span>
                    <span className="text-sm text-gray-500 dark:text-gray-400">
                      °C
                    </span>
                  </div>
                  <div className="text-xs text-gray-500 dark:text-gray-400">
                    Temperature
                  </div>
                </div>
              </div>

              <div className="flex items-center space-x-2">
                <IconDroplet className="h-5 w-5 text-blue-500" />
                <div className="flex-1">
                  <div className="flex items-baseline space-x-1">
                    <span className="text-lg font-semibold text-gray-900 dark:text-white">
                      {currentData?.humidity?.toFixed(1) || '--'}
                    </span>
                    <span className="text-sm text-gray-500 dark:text-gray-400">
                      %
                    </span>
                  </div>
                  <div className="text-xs text-gray-500 dark:text-gray-400">
                    Humidity
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Device Status */}
          {status?.isOnline && (
            <div className="mb-4 flex items-center justify-between text-xs text-gray-500 dark:text-gray-400">
              <div className="flex items-center space-x-4">
                {status.wifiStrength !== null && (
                  <div className="flex items-center space-x-1">
                    <IconWifi className="h-4 w-4" />
                    <span>{status.wifiStrength}dBm</span>
                  </div>
                )}

                {status.batteryLevel !== null && (
                  <div className="flex items-center space-x-1">
                    <IconBattery className="h-4 w-4" />
                    <span>{status.batteryLevel}%</span>
                  </div>
                )}
              </div>

              {currentData?.lastUpdate && (
                <div className="text-right">
                  <div>Last update</div>
                  <div className="font-mono">
                    {new Date(currentData.lastUpdate).toLocaleTimeString()}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Last Watering Info */}
          <div className="mb-4 flex items-center justify-between text-sm text-gray-600 dark:text-gray-400">
            <span>Last watered:</span>
            <span className="font-medium">{getTimeSinceLastWatering()}</span>
          </div>

          {/* Actions */}
          <div className="flex items-center space-x-2">
            <WateringButton
              plantId={id}
              plantName={name}
              disabled={!status?.isOnline}
              size="sm"
              className="flex-1"
            />

            <Link
              to={`/plants/${id}`}
              className="rounded-lg bg-gray-100 px-3 py-2 text-sm font-medium text-gray-700 transition-colors duration-200 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
            >
              Details
            </Link>
          </div>

          {/* Progress Bars for Thresholds */}
          <div className="mt-4 space-y-2">
            <div>
              <div className="mb-1 flex justify-between text-xs text-gray-500 dark:text-gray-400">
                <span>Moisture Level</span>
                <span>{currentData?.moisture?.toFixed(1) || '--'}%</span>
              </div>
              <div className="h-2 w-full rounded-full bg-gray-200 dark:bg-gray-700">
                <motion.div
                  className={`h-2 rounded-full transition-all duration-1000 ${
                    (currentData?.moisture || 0) <
                    (config?.moistureThresholds?.min || 30)
                      ? 'bg-red-500'
                      : 'bg-blue-500'
                  }`}
                  initial={{ width: 0 }}
                  animate={{ width: `${currentData?.moisture || 0}%` }}
                  transition={{ duration: 1, ease: 'easeOut' }}
                />
              </div>
            </div>
          </div>
        </div>
      </Link>
    </motion.div>
  );
};

export default PlantCard;
