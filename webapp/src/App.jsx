import React, { Suspense } from 'react';
import { ErrorBoundary } from 'react-error-boundary';
import { Navigate, Route, Routes } from 'react-router-dom';

import Layout from './components/Layout';
import ErrorFallback from './components/ui/ErrorFallback';
import LoadingSpinner from './components/ui/LoadingSpinner';

// Lazy load pages for better performance
const Dashboard = React.lazy(() => import('./pages/Dashboard'));
const Analytics = React.lazy(() => import('./pages/Analytics'));
const PlantDetail = React.lazy(() => import('./pages/PlantDetail'));
const Settings = React.lazy(() => import('./pages/Settings'));
const System = React.lazy(() => import('./pages/System'));
const NotFound = React.lazy(() => import('./pages/NotFound'));

function App() {
  return (
    <ErrorBoundary
      FallbackComponent={ErrorFallback}
      onError={(error, errorInfo) => {
        console.error('🌱 App Error:', error, errorInfo);

        // In production, you might want to send this to an error reporting service
        if (import.meta.env.PROD) {
          // Example: Sentry.captureException(error);
        }
      }}
    >
      <div className="min-h-screen transition-colors duration-200">
        <Routes>
          <Route path="/" element={<Layout />}>
            <Route
              index
              element={
                <Suspense fallback={<LoadingSpinner />}>
                  <Dashboard />
                </Suspense>
              }
            />

            <Route
              path="analytics"
              element={
                <Suspense fallback={<LoadingSpinner />}>
                  <Analytics />
                </Suspense>
              }
            />

            <Route
              path="plants/:plantId"
              element={
                <Suspense fallback={<LoadingSpinner />}>
                  <PlantDetail />
                </Suspense>
              }
            />

            <Route
              path="settings"
              element={
                <Suspense fallback={<LoadingSpinner />}>
                  <Settings />
                </Suspense>
              }
            />

            <Route
              path="system"
              element={
                <Suspense fallback={<LoadingSpinner />}>
                  <System />
                </Suspense>
              }
            />

            <Route
              path="404"
              element={
                <Suspense fallback={<LoadingSpinner />}>
                  <NotFound />
                </Suspense>
              }
            />

            <Route path="*" element={<Navigate to="/404" replace />} />
          </Route>
        </Routes>
      </div>
    </ErrorBoundary>
  );
}

export default App;
