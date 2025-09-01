import { useQuery } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import {
  ArrowLeft,
  BarChart3,
  Cloud,
  Flask,
  Settings,
  Sun,
  Thermometer,
} from 'lucide-react';
import React, { useState } from 'react';
import { Link, useParams } from 'react-router-dom';

import SensorChart from '../components/charts/SensorChart';
import PlantSettings from '../components/PlantSettings';
import ErrorState from '../components/ui/ErrorState';
import LoadingSpinner from '../components/ui/LoadingSpinner';
import SensorGauge from '../components/ui/SensorGauge';
import StatusBadge from '../components/ui/StatusBadge';
import WateringButton from '../components/ui/WateringButton';
import WateringHistory from '../components/WateringHistory';
import { usePlants } from '../context/PlantContext';
import { plantsApi } from '../services/api';

const PlantDetail = () => {
  const { plantId } = useParams();
  const { getPlantById } = usePlants();
  const [activeTab, setActiveTab] = useState('overview');
  const [timeRange, setTimeRange] = useState('24h');

  const plant = getPlantById(plantId);

  // Fetch plant details
  const {
    data: plantData,
    isLoading: plantLoading,
    error: plantError,
    refetch: refetchPlant,
  } = useQuery({
    queryKey: ['plant', plantId],
    queryFn: async () => {
      const response = await plantsApi.getById(plantId);
      return response.data;
    },
    enabled: !!plantId,
  });

  // Fetch historical data
  const {
    data: historyData,
    isLoading: historyLoading,
    error: historyError,
    refetch: refetchHistory,
  } = useQuery({
    queryKey: ['plant-history', plantId, timeRange],
    queryFn: async () => {
      const response = await plantsApi.getHistory(plantId, { timeRange });
      return response.data;
    },
    enabled: !!plantId && activeTab === 'charts',
  });

  const tabs = [
    { id: 'overview', label: 'Overview', icon: BarChart3 },
    { id: 'charts', label: 'Charts', icon: BarChart3 },
    { id: 'history', label: 'History', icon: Flask },
    { id: 'settings', label: 'Settings', icon: Settings },
  ];

  const timeRangeOptions = [
    { value: '1h', label: '1 Hour' },
    { value: '6h', label: '6 Hours' },
    { value: '24h', label: '24 Hours' },
    { value: '7d', label: '7 Days' },
    { value: '30d', label: '30 Days' },
  ];

  if (plantLoading) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <LoadingSpinner size="lg" message="Loading plant details..." />
      </div>
    );
  }

  if (plantError || !plant) {
    return (
      <ErrorState
        title="Plant not found"
        message="The requested plant could not be found."
        onRetry={refetchPlant}
      />
    );
  }

  const currentPlant = plantData?.data || plant;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      className="space-y-6"
    >
      {/* Header */}
      <div className="flex items-center space-x-4">
        <Link
          to="/"
          className="rounded-lg p-2 transition-colors hover:bg-gray-100 dark:hover:bg-gray-800"
        >
          <ArrowLeft className="h-6 w-6 text-gray-600 dark:text-gray-400" />
        </Link>

        <div className="flex-1">
          <div className="flex items-center space-x-3">
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
              {currentPlant.name}
            </h1>
            <StatusBadge
              status={currentPlant.status?.isOnline ? 'online' : 'offline'}
            />
          </div>

          <div className="mt-1 flex items-center space-x-2 text-sm text-gray-600 dark:text-gray-400">
            <span className="capitalize">{currentPlant.type}</span>
            {currentPlant.location && (
              <>
                <span>•</span>
                <span>{currentPlant.location}</span>
              </>
            )}
          </div>
        </div>

        <WateringButton
          plantId={plantId}
          plantName={currentPlant.name}
          disabled={!currentPlant.status?.isOnline}
          size="lg"
        />
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.1 }}
          className="card p-4"
        >
          <div className="text-center">
            <SensorGauge
              value={currentPlant.currentData?.moisture || 0}
              max={100}
              size={80}
              thickness={8}
              color="#3b82f6"
              label="Moisture"
              unit="%"
            />
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.2 }}
          className="card p-4"
        >
          <div className="flex items-center space-x-3">
            <div className="rounded-lg bg-red-100 p-3 dark:bg-red-900/30">
              <Thermometer className="h-6 w-6 text-red-600 dark:text-red-400" />
            </div>
            <div>
              <div className="text-2xl font-bold text-gray-900 dark:text-white">
                {currentPlant.currentData?.temperature?.toFixed(1) || '--'}
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400">°C</div>
            </div>
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.3 }}
          className="card p-4"
        >
          <div className="flex items-center space-x-3">
            <div className="rounded-lg bg-blue-100 p-3 dark:bg-blue-900/30">
              <Cloud className="h-6 w-6 text-blue-600 dark:text-blue-400" />
            </div>
            <div>
              <div className="text-2xl font-bold text-gray-900 dark:text-white">
                {currentPlant.currentData?.humidity?.toFixed(1) || '--'}
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400">%</div>
            </div>
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.4 }}
          className="card p-4"
        >
          <div className="flex items-center space-x-3">
            <div className="rounded-lg bg-yellow-100 p-3 dark:bg-yellow-900/30">
              <Sun className="h-6 w-6 text-yellow-600 dark:text-yellow-400" />
            </div>
            <div>
              <div className="text-2xl font-bold text-gray-900 dark:text-white">
                {currentPlant.currentData?.light?.toFixed(0) || '--'}
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                lux
              </div>
            </div>
          </div>
        </motion.div>
      </div>

      {/* Tabs */}
      <div className="card overflow-hidden p-0">
        <div className="border-b border-gray-200 dark:border-gray-700">
          <nav className="flex space-x-8 px-6" aria-label="Tabs">
            {tabs.map(tab => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`flex items-center space-x-2 border-b-2 px-1 py-4 text-sm font-medium transition-colors duration-200 ${
                  activeTab === tab.id
                    ? 'border-primary-500 text-primary-600 dark:text-primary-400'
                    : 'border-transparent text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300'
                }`}
              >
                <tab.icon className="h-5 w-5" />
                <span>{tab.label}</span>
              </button>
            ))}
          </nav>
        </div>

        {/* Tab Content */}
        <div className="p-6">
          {activeTab === 'overview' && (
            <motion.div
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.3 }}
              className="space-y-6"
            >
              {/* Current Status */}
              <div>
                <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
                  Current Status
                </h3>
                <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <span className="text-gray-600 dark:text-gray-400">
                        Device Status
                      </span>
                      <StatusBadge
                        status={
                          currentPlant.status?.isOnline ? 'online' : 'offline'
                        }
                      />
                    </div>

                    <div className="flex items-center justify-between">
                      <span className="text-gray-600 dark:text-gray-400">
                        Last Seen
                      </span>
                      <span className="font-medium text-gray-900 dark:text-white">
                        {currentPlant.status?.lastSeen
                          ? new Date(
                              currentPlant.status.lastSeen
                            ).toLocaleString()
                          : 'Never'}
                      </span>
                    </div>

                    <div className="flex items-center justify-between">
                      <span className="text-gray-600 dark:text-gray-400">
                        Total Waterings
                      </span>
                      <span className="font-medium text-gray-900 dark:text-white">
                        {currentPlant.stats?.totalWaterings || 0}
                      </span>
                    </div>
                  </div>

                  <div className="space-y-4">
                    {currentPlant.status?.batteryLevel !== null && (
                      <div className="flex items-center justify-between">
                        <span className="text-gray-600 dark:text-gray-400">
                          Battery Level
                        </span>
                        <span className="font-medium text-gray-900 dark:text-white">
                          {currentPlant.status.batteryLevel}%
                        </span>
                      </div>
                    )}

                    {currentPlant.status?.wifiStrength !== null && (
                      <div className="flex items-center justify-between">
                        <span className="text-gray-600 dark:text-gray-400">
                          WiFi Signal
                        </span>
                        <span className="font-medium text-gray-900 dark:text-white">
                          {currentPlant.status.wifiStrength} dBm
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </motion.div>
          )}

          {activeTab === 'charts' && (
            <motion.div
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.3 }}
              className="space-y-6"
            >
              {/* Time Range Selector */}
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                  Sensor Charts
                </h3>

                <select
                  value={timeRange}
                  onChange={e => setTimeRange(e.target.value)}
                  className="input-field w-auto"
                >
                  {timeRangeOptions.map(option => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </div>

              {/* Charts */}
              {historyLoading ? (
                <div className="flex justify-center py-12">
                  <LoadingSpinner message="Loading chart data..." />
                </div>
              ) : historyError ? (
                <ErrorState
                  title="Failed to load chart data"
                  message="Unable to fetch historical sensor data."
                  onRetry={refetchHistory}
                />
              ) : (
                <div className="space-y-8">
                  {/* Moisture Chart */}
                  {historyData?.data?.sensorData?.moisture && (
                    <div>
                      <h4 className="text-md mb-4 flex items-center space-x-2 font-medium text-gray-900 dark:text-white">
                        <Flask className="h-5 w-5 text-blue-500" />
                        <span>Soil Moisture</span>
                      </h4>
                      <div className="card p-4">
                        <SensorChart
                          data={historyData.data.sensorData.moisture}
                          sensorType="moisture"
                          timeRange={timeRange}
                          height={300}
                          showArea={true}
                        />
                      </div>
                    </div>
                  )}

                  {/* Temperature Chart */}
                  {historyData?.data?.sensorData?.temperature && (
                    <div>
                      <h4 className="text-md mb-4 flex items-center space-x-2 font-medium text-gray-900 dark:text-white">
                        <Thermometer className="h-5 w-5 text-red-500" />
                        <span>Temperature</span>
                      </h4>
                      <div className="card p-4">
                        <SensorChart
                          data={historyData.data.sensorData.temperature}
                          sensorType="temperature"
                          timeRange={timeRange}
                          height={300}
                        />
                      </div>
                    </div>
                  )}

                  {/* Humidity Chart */}
                  {historyData?.data?.sensorData?.humidity && (
                    <div>
                      <h4 className="text-md mb-4 flex items-center space-x-2 font-medium text-gray-900 dark:text-white">
                        <Cloud className="h-5 w-5 text-blue-500" />
                        <span>Air Humidity</span>
                      </h4>
                      <div className="card p-4">
                        <SensorChart
                          data={historyData.data.sensorData.humidity}
                          sensorType="humidity"
                          timeRange={timeRange}
                          height={300}
                        />
                      </div>
                    </div>
                  )}
                </div>
              )}
            </motion.div>
          )}

          {activeTab === 'history' && (
            <motion.div
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.3 }}
            >
              <WateringHistory plantId={plantId} />
            </motion.div>
          )}

          {activeTab === 'settings' && (
            <motion.div
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.3 }}
            >
              <PlantSettings plant={currentPlant} />
            </motion.div>
          )}
        </div>
      </div>

      {/* Mobile spacing */}
      <div className="h-20 lg:h-0" />
    </motion.div>
  );
};

export default PlantDetail;
