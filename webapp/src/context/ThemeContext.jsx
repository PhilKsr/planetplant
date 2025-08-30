import React, { createContext, useContext, useEffect, useState } from 'react';

const ThemeContext = createContext();

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};

export const ThemeProvider = ({ children }) => {
  const [isDark, setIsDark] = useState(() => {
    // Check localStorage first
    const stored = localStorage.getItem('planetplant-theme');
    if (stored) {
      return stored === 'dark';
    }

    // Fall back to system preference
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
  });

  useEffect(() => {
    const root = window.document.documentElement;

    if (isDark) {
      root.classList.add('dark');
    } else {
      root.classList.remove('dark');
    }

    // Store preference
    localStorage.setItem('planetplant-theme', isDark ? 'dark' : 'light');
  }, [isDark]);

  const toggleTheme = () => {
    setIsDark(prev => !prev);
  };

  const value = {
    isDark,
    toggleTheme,
    theme: isDark ? 'dark' : 'light',
  };

  return (
    <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
  );
};
