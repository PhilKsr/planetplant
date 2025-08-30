import {
  Bell,
  Phone,
  Info,
  Server,
  ShieldCheck,
} from 'lucide-react';
import { useQuery } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import React, { useState } from 'react';

import ErrorState from '../components/ui/ErrorState';
import LoadingSpinner from '../components/ui/LoadingSpinner';
import { useNotifications } from '../context/NotificationContext';
import { useTheme } from '../context/ThemeContext';
import { systemApi } from '../services/api';

const Settings = () => {
  const { isDark, toggleTheme } = useTheme();
  const {
    isSupported: notificationsSupported,
    permission: notificationPermission,
    isSubscribed,
    preferences: notificationPreferences,
    enableNotifications,
    disableNotifications,
    updatePreferences,
    sendTestNotification,
  } = useNotifications();

  // Fetch system configuration
  const {
    data: configData,
    isLoading: configLoading,
    error: configError,
    refetch: refetchConfig,
  } = useQuery({
    queryKey: ['system-config'],
    queryFn: async () => {
      const response = await systemApi.getConfig();
      return response.data;
    },
  });

  const settingsSections = [
    {
      id: 'appearance',
      title: 'Appearance',
      icon: Phone,
      description: 'Customize the look and feel',
    },
    {
      id: 'notifications',
      title: 'Notifications',
      icon: Bell,
      description: 'Configure alerts and notifications',
    },
    {
      id: 'system',
      title: 'System',
      icon: Server,
      description: 'System settings and information',
    },
    {
      id: 'security',
      title: 'Security',
      icon: ShieldCheck,
      description: 'Privacy and security settings',
    },
    {
      id: 'about',
      title: 'About',
      icon: Info,
      description: 'App information and support',
    },
  ];

  const [activeSection, setActiveSection] = useState('appearance');

  const renderAppearanceSettings = () => (
    <motion.div
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.3 }}
      className="space-y-6"
    >
      <div className="card p-6">
        <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
          Theme Preferences
        </h3>

        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <div className="font-medium text-gray-900 dark:text-white">
                Dark Mode
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                Switch between light and dark themes
              </div>
            </div>
            <label className="relative inline-flex cursor-pointer items-center">
              <input
                type="checkbox"
                checked={isDark}
                onChange={toggleTheme}
                className="peer sr-only"
              />
              <div className="peer h-6 w-11 rounded-full bg-gray-200 after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:bg-white after:transition-all after:content-[''] peer-checked:bg-primary-600 peer-checked:after:translate-x-full peer-checked:after:border-white peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-primary-300 dark:border-gray-600 dark:bg-gray-700 dark:peer-focus:ring-primary-800"></div>
            </label>
          </div>
        </div>
      </div>
    </motion.div>
  );

  const renderNotificationSettings = () => (
    <motion.div
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.3 }}
      className="space-y-6"
    >
      {/* Notification Permission Status */}
      <div className="card p-6">
        <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
          Notification Status
        </h3>

        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <div className="font-medium text-gray-900 dark:text-white">
                Browser Support
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                Push notifications compatibility
              </div>
            </div>
            <span
              className={`rounded-full px-2 py-1 text-xs font-medium ${
                notificationsSupported
                  ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-200'
                  : 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-200'
              }`}
            >
              {notificationsSupported ? 'Supported' : 'Not Supported'}
            </span>
          </div>

          <div className="flex items-center justify-between">
            <div>
              <div className="font-medium text-gray-900 dark:text-white">
                Permission Status
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                Current notification permission
              </div>
            </div>
            <span
              className={`rounded-full px-2 py-1 text-xs font-medium ${
                notificationPermission === 'granted'
                  ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-200'
                  : notificationPermission === 'denied'
                    ? 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-200'
                    : 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-200'
              }`}
            >
              {notificationPermission}
            </span>
          </div>

          <div className="flex items-center justify-between">
            <div>
              <div className="font-medium text-gray-900 dark:text-white">
                Push Subscription
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                Real-time notifications from server
              </div>
            </div>
            <div className="flex items-center space-x-2">
              <span
                className={`rounded-full px-2 py-1 text-xs font-medium ${
                  isSubscribed
                    ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-200'
                    : 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-200'
                }`}
              >
                {isSubscribed ? 'Active' : 'Inactive'}
              </span>

              {notificationsSupported && (
                <button
                  onClick={
                    isSubscribed ? disableNotifications : enableNotifications
                  }
                  className={`rounded px-3 py-1 text-xs font-medium ${
                    isSubscribed
                      ? 'bg-red-100 text-red-700 hover:bg-red-200 dark:bg-red-900/30 dark:text-red-300'
                      : 'bg-primary-100 text-primary-700 hover:bg-primary-200 dark:bg-primary-900/30 dark:text-primary-300'
                  }`}
                >
                  {isSubscribed ? 'Disable' : 'Enable'}
                </button>
              )}
            </div>
          </div>
        </div>

        {notificationsSupported && isSubscribed && (
          <button onClick={sendTestNotification} className="btn-secondary mt-4">
            Send Test Notification
          </button>
        )}
      </div>

      {/* Notification Preferences */}
      <div className="card p-6">
        <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
          Notification Preferences
        </h3>

        <div className="space-y-4">
          {Object.entries(notificationPreferences).map(([key, enabled]) => (
            <div key={key} className="flex items-center justify-between">
              <div>
                <div className="font-medium capitalize text-gray-900 dark:text-white">
                  {key.replace(/([A-Z])/g, ' $1').trim()}
                </div>
                <div className="text-sm text-gray-600 dark:text-gray-400">
                  {key === 'lowMoisture' && 'Alert when plants need watering'}
                  {key === 'deviceOffline' && 'Alert when devices go offline'}
                  {key === 'systemAlerts' && 'System health and error alerts'}
                  {key === 'dailyReport' && 'Daily summary of plant status'}
                  {key === 'criticalOnly' && 'Only show critical alerts'}
                </div>
              </div>
              <label className="relative inline-flex cursor-pointer items-center">
                <input
                  type="checkbox"
                  checked={enabled}
                  onChange={e =>
                    updatePreferences({
                      ...notificationPreferences,
                      [key]: e.target.checked,
                    })
                  }
                  className="peer sr-only"
                  disabled={!notificationsSupported}
                />
                <div
                  className={`peer h-6 w-11 rounded-full bg-gray-200 after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:bg-white after:transition-all after:content-[''] peer-checked:bg-primary-600 peer-checked:after:translate-x-full peer-checked:after:border-white peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-primary-300 dark:border-gray-600 dark:bg-gray-700 dark:peer-focus:ring-primary-800 ${
                    !notificationsSupported
                      ? 'cursor-not-allowed opacity-50'
                      : ''
                  }`}
                ></div>
              </label>
            </div>
          ))}
        </div>
      </div>
    </motion.div>
  );

  const renderSystemSettings = () => (
    <motion.div
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.3 }}
      className="space-y-6"
    >
      {configLoading ? (
        <div className="flex justify-center py-12">
          <LoadingSpinner message="Loading system configuration..." />
        </div>
      ) : configError ? (
        <ErrorState
          title="Failed to load system config"
          onRetry={refetchConfig}
        />
      ) : (
        <div className="space-y-4">
          <div className="card p-6">
            <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
              System Configuration
            </h3>

            <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-gray-600 dark:text-gray-400">
                    MQTT Broker
                  </span>
                  <span
                    className={`text-sm font-medium ${
                      configData?.data?.mqtt?.connected
                        ? 'text-green-600'
                        : 'text-red-600'
                    }`}
                  >
                    {configData?.data?.mqtt?.connected
                      ? 'Connected'
                      : 'Disconnected'}
                  </span>
                </div>

                <div className="flex justify-between">
                  <span className="text-gray-600 dark:text-gray-400">
                    InfluxDB
                  </span>
                  <span
                    className={`text-sm font-medium ${
                      configData?.data?.influxdb?.connected
                        ? 'text-green-600'
                        : 'text-red-600'
                    }`}
                  >
                    {configData?.data?.influxdb?.connected
                      ? 'Connected'
                      : 'Disconnected'}
                  </span>
                </div>

                <div className="flex justify-between">
                  <span className="text-gray-600 dark:text-gray-400">
                    Auto Watering
                  </span>
                  <span
                    className={`text-sm font-medium ${
                      configData?.data?.watering?.enabled
                        ? 'text-green-600'
                        : 'text-red-600'
                    }`}
                  >
                    {configData?.data?.watering?.enabled
                      ? 'Enabled'
                      : 'Disabled'}
                  </span>
                </div>
              </div>

              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-gray-600 dark:text-gray-400">
                    Email Alerts
                  </span>
                  <span
                    className={`text-sm font-medium ${
                      configData?.data?.alerts?.email
                        ? 'text-green-600'
                        : 'text-gray-400'
                    }`}
                  >
                    {configData?.data?.alerts?.email ? 'Enabled' : 'Disabled'}
                  </span>
                </div>

                <div className="flex justify-between">
                  <span className="text-gray-600 dark:text-gray-400">
                    Scheduler
                  </span>
                  <span
                    className={`text-sm font-medium ${
                      configData?.data?.features?.scheduler
                        ? 'text-green-600'
                        : 'text-gray-400'
                    }`}
                  >
                    {configData?.data?.features?.scheduler
                      ? 'Active'
                      : 'Inactive'}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </motion.div>
  );

  const renderAboutSettings = () => (
    <motion.div
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.3 }}
      className="space-y-6"
    >
      <div className="card p-6">
        <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
          About PlanetPlant
        </h3>

        <div className="space-y-4">
          <div className="flex justify-between">
            <span className="text-gray-600 dark:text-gray-400">Version</span>
            <span className="font-medium text-gray-900 dark:text-white">
              1.0.0
            </span>
          </div>

          <div className="flex justify-between">
            <span className="text-gray-600 dark:text-gray-400">Build</span>
            <span className="font-mono text-sm text-gray-900 dark:text-white">
              {import.meta.env.VITE_BUILD_HASH || 'development'}
            </span>
          </div>

          <div className="flex justify-between">
            <span className="text-gray-600 dark:text-gray-400">
              Environment
            </span>
            <span className="font-medium text-gray-900 dark:text-white">
              {import.meta.env.MODE}
            </span>
          </div>
        </div>

        <div className="mt-6 border-t border-gray-200 pt-6 dark:border-gray-700">
          <div className="space-y-2 text-sm text-gray-600 dark:text-gray-400">
            <p>
              PlanetPlant is an open-source smart plant watering system built
              with IoT sensors and modern web technologies.
            </p>
            <div className="flex space-x-4">
              <a
                href="https://github.com/yourusername/PlanetPlant"
                target="_blank"
                rel="noopener noreferrer"
                className="text-primary-600 hover:text-primary-700 dark:text-primary-400"
              >
                GitHub Repository
              </a>
              <a
                href="https://github.com/yourusername/PlanetPlant/issues"
                target="_blank"
                rel="noopener noreferrer"
                className="text-primary-600 hover:text-primary-700 dark:text-primary-400"
              >
                Report Issues
              </a>
            </div>
          </div>
        </div>
      </div>
    </motion.div>
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
          Settings
        </h1>
        <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
          Configure your PlanetPlant system
        </p>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-4">
        {/* Settings Navigation */}
        <div className="lg:col-span-1">
          <nav className="space-y-1">
            {settingsSections.map(section => (
              <button
                key={section.id}
                onClick={() => setActiveSection(section.id)}
                className={`flex w-full items-start space-x-3 rounded-lg px-3 py-3 text-left transition-colors duration-200 ${
                  activeSection === section.id
                    ? 'bg-primary-50 text-primary-700 dark:bg-primary-900/30 dark:text-primary-300'
                    : 'text-gray-600 hover:bg-gray-50 dark:text-gray-400 dark:hover:bg-gray-800'
                }`}
              >
                <section.icon className="mt-0.5 h-5 w-5 flex-shrink-0" />
                <div className="min-w-0">
                  <div className="font-medium">{section.title}</div>
                  <div className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                    {section.description}
                  </div>
                </div>
              </button>
            ))}
          </nav>
        </div>

        {/* Settings Content */}
        <div className="lg:col-span-3">
          {activeSection === 'appearance' && renderAppearanceSettings()}
          {activeSection === 'notifications' && renderNotificationSettings()}
          {activeSection === 'system' && renderSystemSettings()}
          {activeSection === 'security' && (
            <motion.div
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              className="card p-6"
            >
              <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
                Security Settings
              </h3>
              <p className="text-gray-600 dark:text-gray-400">
                Security settings will be implemented in a future version.
              </p>
            </motion.div>
          )}
          {activeSection === 'about' && renderAboutSettings()}
        </div>
      </div>

      {/* Mobile spacing */}
      <div className="h-20 lg:h-0" />
    </div>
  );
};

export default Settings;
