import {
  IconAlertTriangle,
  IconDroplet,
  IconHome,
  IconWifi,
} from '@tabler/icons-react';
import { motion } from 'framer-motion';
import React from 'react';

import { usePlants } from '../context/PlantContext';

const DashboardStats = () => {
  const { getPlantsSummary } = usePlants();
  const summary = getPlantsSummary();

  const stats = [
    {
      label: 'Total Plants',
      value: summary.total,
      icon: IconHome,
      color: 'text-blue-600 dark:text-blue-400',
      bg: 'bg-blue-100 dark:bg-blue-900/30',
    },
    {
      label: 'Online',
      value: summary.online,
      icon: IconWifi,
      color: 'text-green-600 dark:text-green-400',
      bg: 'bg-green-100 dark:bg-green-900/30',
    },
    {
      label: 'Need Water',
      value: summary.needingWater,
      icon: IconDroplet,
      color: 'text-blue-600 dark:text-blue-400',
      bg: 'bg-blue-100 dark:bg-blue-900/30',
    },
    {
      label: 'Offline',
      value: summary.offline,
      icon: IconAlertTriangle,
      color: 'text-red-600 dark:text-red-400',
      bg: 'bg-red-100 dark:bg-red-900/30',
    },
  ];

  return (
    <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
      {stats.map((stat, index) => (
        <motion.div
          key={stat.label}
          initial={{ opacity: 0, y: 20, scale: 0.95 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{
            delay: index * 0.1,
            duration: 0.3,
            ease: 'easeOut',
          }}
          whileHover={{ y: -2, scale: 1.02 }}
          className="card p-4"
        >
          <div className="flex items-center space-x-3">
            <div className={`rounded-lg p-3 ${stat.bg}`}>
              <stat.icon className={`h-6 w-6 ${stat.color}`} />
            </div>

            <div className="min-w-0 flex-1">
              <motion.div
                initial={{ scale: 0.8 }}
                animate={{ scale: 1 }}
                transition={{
                  delay: index * 0.1 + 0.2,
                  duration: 0.4,
                  type: 'spring',
                }}
                className="text-2xl font-bold text-gray-900 dark:text-white"
              >
                {stat.value}
              </motion.div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                {stat.label}
              </div>
            </div>
          </div>
        </motion.div>
      ))}
    </div>
  );
};

export default DashboardStats;
