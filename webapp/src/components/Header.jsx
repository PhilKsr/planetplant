import { Bell, Moon, Settings, Sun } from 'lucide-react';
import React from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router-dom';

import { usePlants } from '../context/PlantContext';
import { useTheme } from '../context/ThemeContext';
import LanguageToggle from './LanguageToggle';

const Header = () => {
  const { isDark, toggleTheme } = useTheme();
  const { getPlantsSummary } = usePlants();
  const { t } = useTranslation();
  const summary = getPlantsSummary();

  return (
    <header className="border-b border-gray-200 bg-white shadow-sm backdrop-blur-sm dark:border-gray-700 dark:bg-gray-800">
      <div className="mx-auto max-w-8xl px-4 sm:px-6 lg:px-8">
        <div className="flex h-16 items-center justify-between">
          {/* Logo and Title */}
          <div className="flex items-center">
            <Link
              to="/"
              className="flex items-center space-x-3 transition-opacity hover:opacity-80"
            >
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-gradient-plant">
                <span className="text-xl font-bold text-white">🌱</span>
              </div>
              <div>
                <h1 className="text-xl font-bold text-gradient-plant">
                  PlanetPlant
                </h1>
                <p className="text-xs text-gray-500 dark:text-gray-400">
                  Smart Plant Care
                </p>
              </div>
            </Link>
          </div>

          {/* Status Summary */}
          <div className="hidden items-center space-x-6 md:flex">
            <div className="flex items-center space-x-4 text-sm">
              <div className="flex items-center space-x-2">
                <div className="h-2 w-2 animate-pulse rounded-full bg-green-500"></div>
                <span className="text-gray-600 dark:text-gray-400">
                  {summary.online}/{summary.total} {t('dashboard.plants')}{' '}
                  {t('dashboard.online')}
                </span>
              </div>

              {summary.needingWater > 0 && (
                <div className="flex items-center space-x-2">
                  <div className="h-2 w-2 rounded-full bg-blue-500"></div>
                  <span className="text-gray-600 dark:text-gray-400">
                    {summary.needingWater} {t('dashboard.needWater')}
                  </span>
                </div>
              )}
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center space-x-3">
            {/* Notifications */}
            <button
              className="relative rounded-lg p-2 text-gray-500 transition-colors duration-200 hover:bg-gray-100 hover:text-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200"
              title={t('settings.notifications')}
            >
              <Bell className="h-6 w-6" />
              {summary.needingWater > 0 && (
                <span className="absolute -right-1 -top-1 flex h-5 w-5 animate-pulse items-center justify-center rounded-full bg-red-500 text-xs text-white">
                  {summary.needingWater}
                </span>
              )}
            </button>

            {/* Language Toggle */}
            <LanguageToggle />

            {/* Settings */}
            <Link
              to="/settings"
              className="rounded-lg p-2 text-gray-500 transition-colors duration-200 hover:bg-gray-100 hover:text-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200"
              title={t('navigation.settings')}
            >
              <Settings className="h-6 w-6" />
            </Link>

            {/* Theme Toggle */}
            <button
              onClick={toggleTheme}
              className="rounded-lg p-2 text-gray-500 transition-colors duration-200 hover:bg-gray-100 hover:text-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200"
              title={isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode'}
            >
              {isDark ? (
                <Sun className="h-6 w-6" />
              ) : (
                <Moon className="h-6 w-6" />
              )}
            </button>
          </div>
        </div>
      </div>
    </header>
  );
};

export default Header;
