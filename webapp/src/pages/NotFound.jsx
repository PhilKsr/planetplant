import { Home } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';

export default function NotFound() {
  const { t } = useTranslation();
  return (
    <div className="flex min-h-screen flex-col justify-center bg-gray-50 py-12 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <div className="text-center">
          <div className="mb-4 text-6xl text-green-500">🌱</div>
          <h1 className="mb-4 text-4xl font-bold text-gray-900">404</h1>
          <h2 className="mb-4 text-2xl font-semibold text-gray-700">
            {t('notFound.title')}
          </h2>
          <p className="mb-8 text-gray-500">
            {t('notFound.message')}
          </p>
          <Link
            to="/"
            className="inline-flex items-center rounded-md border border-transparent bg-green-600 px-4 py-2 text-base font-medium text-white transition-colors duration-200 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2"
          >
            <Home className="mr-2 h-5 w-5" />
            {t('notFound.backToDashboard')}
          </Link>
        </div>
      </div>
    </div>
  );
}
