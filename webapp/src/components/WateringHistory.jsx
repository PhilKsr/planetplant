import {
  IconCircleCheck,
  IconCircleX,
  IconClock,
  IconDroplet,
} from '@tabler/icons-react';
import { useQuery } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import React from 'react';
import { useTranslation } from 'react-i18next';

import { plantsApi } from '../services/api';
import ErrorState from './ui/ErrorState';
import LoadingSpinner from './ui/LoadingSpinner';

const WateringHistory = ({ plantId }) => {
  const { t } = useTranslation();
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['watering-history', plantId],
    queryFn: async () => {
      const response = await plantsApi.getWateringHistory(plantId, {
        timeRange: '30d',
      });
      return response.data;
    },
    enabled: !!plantId,
  });

  const formatDuration = durationMs => {
    const seconds = Math.floor(durationMs / 1000);
    return `${seconds}s`;
  };

  const getTimeAgo = timestamp => {
    const now = new Date();
    const eventTime = new Date(timestamp);
    const diffMs = now - eventTime;

    const diffMinutes = Math.floor(diffMs / (1000 * 60));
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    if (diffDays > 0) return `${diffDays}d ago`;
    if (diffHours > 0) return `${diffHours}h ago`;
    if (diffMinutes > 0) return `${diffMinutes}m ago`;
    return t('time.justNow');
  };

  const getTriggerTypeLabel = type => {
    switch (type) {
      case 'automatic':
        return t('watering.triggerTypes.auto');
      case 'manual':
        return t('watering.triggerTypes.manual');
      case 'scheduled':
        return t('watering.triggerTypes.scheduled');
      default:
        return type;
    }
  };

  const getTriggerTypeColor = type => {
    switch (type) {
      case 'automatic':
        return 'text-blue-600 dark:text-blue-400 bg-blue-100 dark:bg-blue-900/30';
      case 'manual':
        return 'text-green-600 dark:text-green-400 bg-green-100 dark:bg-green-900/30';
      case 'scheduled':
        return 'text-purple-600 dark:text-purple-400 bg-purple-100 dark:bg-purple-900/30';
      default:
        return 'text-gray-600 dark:text-gray-400 bg-gray-100 dark:bg-gray-800';
    }
  };

  if (isLoading) {
    return (
      <div className="flex justify-center py-12">
        <LoadingSpinner message={t('loading.wateringHistory')} />
      </div>
    );
  }

  if (error) {
    return (
      <ErrorState
        title={t('errors.loadWateringHistory')}
        message={t('errors.loadWateringHistoryDetails')}
        onRetry={refetch}
      />
    );
  }

  const events = data?.data?.events || [];

  if (events.length === 0) {
    return (
      <div className="py-12 text-center">
        <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800">
          <IconDroplet className="h-8 w-8 text-gray-400" />
        </div>
        <h3 className="mb-2 text-lg font-medium text-gray-900 dark:text-white">
          {t('watering.noHistory')}
        </h3>
        <p className="text-gray-600 dark:text-gray-400">
          {t('watering.notWateredYet')}
        </p>
      </div>
    );
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.3 }}
      className="space-y-4"
    >
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
          {t('watering.history')}
        </h3>
        <span className="text-sm text-gray-500 dark:text-gray-400">
          Last 30 days • {events.length} events
        </span>
      </div>

      <div className="space-y-3">
        {events.map((event, index) => (
          <motion.div
            key={`${event.timestamp}-${index}`}
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: index * 0.05, duration: 0.3 }}
            className="card p-4 transition-shadow duration-200 hover:shadow-md"
          >
            <div className="flex items-center space-x-4">
              {/* Icon */}
              <div
                className={`rounded-lg p-2 ${
                  event.success
                    ? 'bg-green-100 dark:bg-green-900/30'
                    : 'bg-red-100 dark:bg-red-900/30'
                }`}
              >
                {event.success ? (
                  <IconCircleCheck className="h-6 w-6 text-green-600 dark:text-green-400" />
                ) : (
                  <IconCircleX className="h-6 w-6 text-red-600 dark:text-red-400" />
                )}
              </div>

              {/* Content */}
              <div className="min-w-0 flex-1">
                <div className="mb-1 flex items-center space-x-3">
                  <span
                    className={`rounded-full px-2 py-1 text-xs font-medium ${getTriggerTypeColor(event.triggerType)}`}
                  >
                    {getTriggerTypeLabel(event.triggerType)}
                  </span>

                  <span className="text-sm text-gray-600 dark:text-gray-400">
                    {formatDuration(event.duration)}
                  </span>

                  {event.volume && (
                    <span className="text-sm text-gray-600 dark:text-gray-400">
                      {event.volume}ml
                    </span>
                  )}
                </div>

                <div className="flex items-center space-x-2 text-sm text-gray-500 dark:text-gray-400">
                  <IconClock className="h-4 w-4" />
                  <span>{getTimeAgo(event.timestamp)}</span>
                  <span>•</span>
                  <span>{new Date(event.timestamp).toLocaleString()}</span>
                </div>

                {event.reason && (
                  <div className="mt-2 text-sm text-gray-600 dark:text-gray-400">
                    {event.reason}
                  </div>
                )}
              </div>

              {/* Status */}
              <div className="text-right">
                <div
                  className={`text-sm font-medium ${
                    event.success
                      ? 'text-green-600 dark:text-green-400'
                      : 'text-red-600 dark:text-red-400'
                  }`}
                >
                  {event.success ? t('watering.status.success') : t('watering.status.failed')}
                </div>
              </div>
            </div>
          </motion.div>
        ))}
      </div>

      {/* Load more button if there are many events */}
      {events.length >= 20 && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.5 }}
          className="pt-4 text-center"
        >
          <button className="btn-secondary">Load More Events</button>
        </motion.div>
      )}
    </motion.div>
  );
};

export default WateringHistory;
