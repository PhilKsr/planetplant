import {
  Clock,
  Cpu,
  Database,
  MemoryStick,
  Wifi,
} from 'lucide-react';
import { useQuery } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import React from 'react';

import ErrorState from '../components/ui/ErrorState';
import LoadingSpinner from '../components/ui/LoadingSpinner';
import StatusBadge from '../components/ui/StatusBadge';
import { systemApi } from '../services/api';

const System = () => {
  const {
    data: statusData,
    isLoading: statusLoading,
    error: statusError,
    refetch: refetchStatus,
  } = useQuery({
    queryKey: ['system-status'],
    queryFn: async () => {
      const response = await systemApi.getStatus();
      return response.data;
    },
    refetchInterval: 30000, // Refetch every 30 seconds
  });

  const {
    data: infoData,
    isLoading: infoLoading,
    error: infoError,
    refetch: refetchInfo,
  } = useQuery({
    queryKey: ['system-info'],
    queryFn: async () => {
      const response = await systemApi.getInfo();
      return response.data;
    },
  });

  if (statusLoading || infoLoading) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <LoadingSpinner size="lg" message="Loading system information..." />
      </div>
    );
  }

  if (statusError || infoError) {
    return (
      <ErrorState
        title="Failed to load system information"
        message="Unable to fetch system status and information."
        onRetry={() => {
          refetchStatus();
          refetchInfo();
        }}
      />
    );
  }

  const systemStatus = statusData?.data;
  const systemInfo = infoData?.data;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      className="space-y-6"
    >
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
          System Status
        </h1>
        <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
          Monitor your PlanetPlant system health and performance
        </p>
      </div>

      {/* Overall Status */}
      <div className="card p-6">
        <div className="mb-6 flex items-center justify-between">
          <h2 className="text-xl font-semibold text-gray-900 dark:text-white">
            System Health
          </h2>
          <StatusBadge
            status={systemStatus?.overall === 'healthy' ? 'online' : 'warning'}
            size="md"
          />
        </div>

        {/* Service Status Grid */}
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
          {systemStatus?.components &&
            Object.entries(systemStatus.components).map(([service, health]) => (
              <motion.div
                key={service}
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: 0.1 }}
                className="rounded-lg bg-gray-50 p-4 dark:bg-gray-700/50"
              >
                <div className="flex items-center space-x-3">
                  <div
                    className={`rounded-lg p-2 ${
                      health.status === 'healthy'
                        ? 'bg-green-100 dark:bg-green-900/30'
                        : 'bg-red-100 dark:bg-red-900/30'
                    }`}
                  >
                    {service === 'mqtt' && (
                      <Wifi className="h-5 w-5 text-green-600 dark:text-green-400" />
                    )}
                    {service === 'influxdb' && (
                      <Database className="h-5 w-5 text-blue-600 dark:text-blue-400" />
                    )}
                    {service === 'automation' && (
                      <Cpu className="h-5 w-5 text-purple-600 dark:text-purple-400" />
                    )}
                    {service === 'plants' && (
                      <span className="h-5 w-5 text-lg">🌱</span>
                    )}
                  </div>

                  <div className="flex-1">
                    <div className="font-medium capitalize text-gray-900 dark:text-white">
                      {service}
                    </div>
                    <div
                      className={`text-sm ${
                        health.status === 'healthy'
                          ? 'text-green-600 dark:text-green-400'
                          : 'text-red-600 dark:text-red-400'
                      }`}
                    >
                      {health.status}
                    </div>
                  </div>
                </div>

                {health.warnings?.length > 0 && (
                  <div className="mt-2 text-xs text-yellow-600 dark:text-yellow-400">
                    {health.warnings[0]}
                  </div>
                )}
              </motion.div>
            ))}
        </div>
      </div>

      {/* System Resources */}
      {systemStatus?.system && (
        <div className="card p-6">
          <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
            System Resources
          </h3>

          <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
            {/* Memory Usage */}
            <div>
              <div className="mb-3 flex items-center space-x-2">
                <MemoryStick className="h-5 w-5 text-blue-600 dark:text-blue-400" />
                <span className="font-medium text-gray-900 dark:text-white">
                  Memory
                </span>
              </div>
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600 dark:text-gray-400">
                    Usage
                  </span>
                  <span className="font-medium">
                    {systemStatus.system.memory?.usage}
                  </span>
                </div>
                <div className="h-2 w-full rounded-full bg-gray-200 dark:bg-gray-700">
                  <motion.div
                    className="h-2 rounded-full bg-blue-500"
                    initial={{ width: 0 }}
                    animate={{
                      width: systemStatus.system.memory?.usage || '0%',
                    }}
                    transition={{ duration: 1, ease: 'easeOut' }}
                  />
                </div>
                <div className="text-xs text-gray-500 dark:text-gray-400">
                  {systemStatus.system.memory?.used}MB /{' '}
                  {systemStatus.system.memory?.total}MB
                </div>
              </div>
            </div>

            {/* CPU Load */}
            <div>
              <div className="mb-3 flex items-center space-x-2">
                <Cpu className="h-5 w-5 text-green-600 dark:text-green-400" />
                <span className="font-medium text-gray-900 dark:text-white">
                  CPU
                </span>
              </div>
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600 dark:text-gray-400">Load</span>
                  <span className="font-medium">
                    {systemStatus.system.cpu?.load}
                  </span>
                </div>
                <div className="h-2 w-full rounded-full bg-gray-200 dark:bg-gray-700">
                  <motion.div
                    className="h-2 rounded-full bg-green-500"
                    initial={{ width: 0 }}
                    animate={{ width: systemStatus.system.cpu?.load || '0%' }}
                    transition={{ duration: 1, ease: 'easeOut' }}
                  />
                </div>
                <div className="text-xs text-gray-500 dark:text-gray-400">
                  {systemStatus.system.cpu?.cores} cores
                </div>
              </div>
            </div>

            {/* Uptime */}
            <div>
              <div className="mb-3 flex items-center space-x-2">
                <Clock className="h-5 w-5 text-purple-600 dark:text-purple-400" />
                <span className="font-medium text-gray-900 dark:text-white">
                  Uptime
                </span>
              </div>
              <div className="space-y-2">
                <div className="text-lg font-bold text-gray-900 dark:text-white">
                  {Math.floor(systemStatus.system.uptime?.process / 3600)}h{' '}
                  {Math.floor(
                    (systemStatus.system.uptime?.process % 3600) / 60
                  )}
                  m
                </div>
                <div className="text-xs text-gray-500 dark:text-gray-400">
                  System:{' '}
                  {Math.floor(systemStatus.system.uptime?.system / 3600)}h{' '}
                  {Math.floor((systemStatus.system.uptime?.system % 3600) / 60)}
                  m
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Application Information */}
      {systemInfo?.application && (
        <div className="card p-6">
          <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
            Application Information
          </h3>

          <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
            <div className="space-y-3">
              <div className="flex justify-between">
                <span className="text-gray-600 dark:text-gray-400">
                  Version
                </span>
                <span className="font-medium text-gray-900 dark:text-white">
                  {systemInfo.application.version}
                </span>
              </div>

              <div className="flex justify-between">
                <span className="text-gray-600 dark:text-gray-400">
                  Node.js
                </span>
                <span className="font-mono text-sm text-gray-900 dark:text-white">
                  {systemInfo.application.nodeVersion}
                </span>
              </div>

              <div className="flex justify-between">
                <span className="text-gray-600 dark:text-gray-400">
                  Platform
                </span>
                <span className="font-medium text-gray-900 dark:text-white">
                  {systemInfo.application.platform}{' '}
                  {systemInfo.application.arch}
                </span>
              </div>
            </div>

            <div className="space-y-3">
              <div className="flex justify-between">
                <span className="text-gray-600 dark:text-gray-400">
                  Hostname
                </span>
                <span className="font-medium text-gray-900 dark:text-white">
                  {systemInfo.system?.hostname}
                </span>
              </div>

              <div className="flex justify-between">
                <span className="text-gray-600 dark:text-gray-400">
                  CPU Cores
                </span>
                <span className="font-medium text-gray-900 dark:text-white">
                  {systemInfo.system?.cpus}
                </span>
              </div>

              <div className="flex justify-between">
                <span className="text-gray-600 dark:text-gray-400">
                  Total Memory
                </span>
                <span className="font-medium text-gray-900 dark:text-white">
                  {Math.round(systemInfo.system?.totalMemory / 1024 / 1024)}MB
                </span>
              </div>
            </div>

            <div className="space-y-3">
              <div className="flex justify-between">
                <span className="text-gray-600 dark:text-gray-400">
                  Environment
                </span>
                <span
                  className={`rounded px-2 py-1 text-xs font-medium ${
                    systemInfo.application.environment === 'production'
                      ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-200'
                      : 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-200'
                  }`}
                >
                  {systemInfo.application.environment}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* System Alerts */}
      {systemStatus?.alerts?.length > 0 && (
        <div className="card p-6">
          <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
            System Alerts
          </h3>

          <div className="space-y-3">
            {systemStatus.alerts.map((alert, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.05 }}
                className={`rounded-lg border-l-4 p-4 ${
                  alert.severity === 'critical'
                    ? 'border-red-500 bg-red-50 dark:bg-red-900/20'
                    : 'border-yellow-500 bg-yellow-50 dark:bg-yellow-900/20'
                }`}
              >
                <div className="flex items-start space-x-3">
                  <div
                    className={`mt-1 h-2 w-2 rounded-full ${
                      alert.severity === 'critical'
                        ? 'bg-red-500'
                        : 'bg-yellow-500'
                    }`}
                  />

                  <div className="flex-1">
                    <div className="font-medium text-gray-900 dark:text-white">
                      {alert.message}
                    </div>
                    {alert.details && (
                      <div className="mt-1 text-sm text-gray-600 dark:text-gray-400">
                        {alert.details}
                      </div>
                    )}
                    <div className="mt-2 text-xs text-gray-500 dark:text-gray-400">
                      Component: {alert.component}
                    </div>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      )}

      {/* Mobile spacing */}
      <div className="h-20 lg:h-0" />
    </motion.div>
  );
};

export default System;
