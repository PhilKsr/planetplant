import { BarChart3, TrendingUp } from 'lucide-react';
import React from 'react';
import { useTranslation } from 'react-i18next';

import ErrorState from '../components/ui/ErrorState';

const Analytics = () => {
  const { t } = useTranslation();
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <div className="flex items-center space-x-3">
          <BarChart3 className="h-8 w-8 text-primary-600" />
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
            {t('analytics.title')}
          </h1>
        </div>
        <p className="mt-2 text-gray-600 dark:text-gray-400">
          {t('analytics.description')}
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <div className="card p-6">
          <div className="mb-4 flex items-center space-x-2">
            <TrendingUp className="h-5 w-5 text-green-600" />
            <h2 className="text-lg font-semibold text-gray-900 dark:text-white">
              {t('analytics.comingSoon')}
            </h2>
          </div>
          <p className="text-gray-600 dark:text-gray-400">
            {t('analytics.devMessage')}
          </p>
        </div>
      </div>
    </div>
  );
};

export default Analytics;