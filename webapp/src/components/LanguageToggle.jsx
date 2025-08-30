import React from 'react';
import { useTranslation } from 'react-i18next';

const LanguageToggle = () => {
  const { i18n } = useTranslation();

  const toggleLanguage = () => {
    const newLang = i18n.language === 'en' ? 'de' : 'en';
    i18n.changeLanguage(newLang);
  };

  return (
    <button
      onClick={toggleLanguage}
      className="rounded-lg px-3 py-1 text-sm font-medium text-gray-500 transition-colors duration-200 hover:bg-gray-100 hover:text-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200"
      title={`Switch to ${i18n.language === 'en' ? 'Deutsch' : 'English'}`}
    >
      {i18n.language.toUpperCase()}
    </button>
  );
};

export default LanguageToggle;