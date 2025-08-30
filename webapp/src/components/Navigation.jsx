import {
  BarChart3,
  Monitor,
  Home,
  Settings,
} from 'lucide-react';
import React from 'react';
import { NavLink } from 'react-router-dom';
import { useTranslation } from 'react-i18next';

const Navigation = () => {
  const { t } = useTranslation();
  const navItems = [
    {
      name: t('navigation.dashboard'),
      path: '/',
      icon: Home,
      activeIcon: Home,
      exact: true,
    },
    {
      name: t('navigation.analytics'),
      path: '/analytics',
      icon: BarChart3,
      activeIcon: BarChart3,
    },
    {
      name: t('navigation.system'),
      path: '/system',
      icon: Monitor,
      activeIcon: Monitor,
    },
    {
      name: t('navigation.settings'),
      path: '/settings',
      icon: Settings,
      activeIcon: Settings,
    },
  ];

  return (
    <>
      {/* Desktop Navigation */}
      <nav className="fixed left-0 top-16 z-30 hidden h-full w-64 border-r border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-800 lg:block">
        <div className="p-4">
          <div className="space-y-1">
            {navItems.map(item => (
              <NavLink
                key={item.path}
                to={item.path}
                end={item.exact}
                className={({ isActive }) =>
                  `group flex items-center space-x-3 rounded-lg px-3 py-3 text-sm font-medium transition-all duration-200 ${
                    isActive
                      ? 'border-l-4 border-primary-600 bg-primary-50 text-primary-700 dark:bg-primary-900 dark:text-primary-300'
                      : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200'
                  }`
                }
              >
                {({ isActive }) => (
                  <>
                    {React.createElement(
                      isActive ? item.activeIcon : item.icon,
                      {
                        className: `w-5 h-5 transition-colors duration-200 ${
                          isActive
                            ? 'text-primary-600 dark:text-primary-400'
                            : 'group-hover:text-gray-700 dark:group-hover:text-gray-300'
                        }`,
                      }
                    )}
                    <span>{item.name}</span>
                  </>
                )}
              </NavLink>
            ))}
          </div>

          {/* Quick Stats */}
          <div className="dark:bg-gray-750 mt-8 rounded-lg bg-gray-50 p-4">
            <h3 className="mb-3 text-sm font-semibold text-gray-700 dark:text-gray-300">
              {t('navigation.quickOverview')}
            </h3>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-500 dark:text-gray-400">{t('dashboard.plants')}</span>
                <span className="font-medium">3</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500 dark:text-gray-400">{t('dashboard.online')}</span>
                <span className="font-medium text-green-600">2</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500 dark:text-gray-400">
                  {t('dashboard.needWater')}
                </span>
                <span className="font-medium text-blue-600">1</span>
              </div>
            </div>
          </div>
        </div>
      </nav>

      {/* Mobile Navigation */}
      <nav className="fixed bottom-0 left-0 right-0 z-50 border-t border-gray-200 bg-white backdrop-blur-sm dark:border-gray-700 dark:bg-gray-800 lg:hidden">
        <div className="flex">
          {navItems.map(item => (
            <NavLink
              key={item.path}
              to={item.path}
              end={item.exact}
              className={({ isActive }) =>
                `flex flex-1 flex-col items-center justify-center px-1 py-2 text-xs font-medium transition-all duration-200 ${
                  isActive
                    ? 'bg-primary-50 text-primary-600 dark:bg-primary-900 dark:text-primary-400'
                    : 'text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300'
                }`
              }
            >
              {({ isActive }) => (
                <>
                  {React.createElement(isActive ? item.activeIcon : item.icon, {
                    className: 'w-6 h-6 mb-1',
                  })}
                  <span>{item.name}</span>
                </>
              )}
            </NavLink>
          ))}
        </div>
      </nav>
    </>
  );
};

export default Navigation;
