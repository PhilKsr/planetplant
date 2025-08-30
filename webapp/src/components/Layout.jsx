import React from 'react';
import { Outlet } from 'react-router-dom';

import ConnectionStatus from './ConnectionStatus';
import Header from './Header';
import Navigation from './Navigation';

const Layout = () => {
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
      <Header />

      <div className="flex">
        <Navigation />

        <main className="ml-0 flex-1 p-4 pb-20 lg:ml-64 lg:p-6 lg:pb-6">
          <div className="mx-auto max-w-8xl">
            <Outlet />
          </div>
        </main>
      </div>

      <ConnectionStatus />
    </div>
  );
};

export default Layout;
