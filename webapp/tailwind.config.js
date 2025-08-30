/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f0fdf4',
          100: '#dcfce7',
          200: '#bbf7d0',
          300: '#86efac',
          400: '#4ade80',
          500: '#22c55e',
          600: '#16a34a',
          700: '#15803d',
          800: '#166534',
          900: '#14532d',
          950: '#052e16',
        },
        plant: {
          leaf: '#10b981',
          stem: '#059669',
          earth: '#92400e',
          water: '#0891b2',
          sun: '#f59e0b'
        },
        sensor: {
          moisture: '#3b82f6',
          temperature: '#ef4444',
          humidity: '#06b6d4',
          light: '#f59e0b'
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      animation: {
        'fade-in': 'fadeIn 0.5s ease-in-out',
        'slide-up': 'slideUp 0.3s ease-out',
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'bounce-gentle': 'bounceGentle 2s ease-in-out infinite',
        'gauge-fill': 'gaugeFill 1.5s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0', transform: 'translateY(10px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(20px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        bounceGentle: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-5px)' },
        },
        gaugeFill: {
          '0%': { transform: 'rotate(-90deg)' },
          '100%': { transform: 'rotate(0deg)' },
        }
      },
      boxShadow: {
        'plant': '0 4px 6px -1px rgba(16, 185, 129, 0.1), 0 2px 4px -1px rgba(16, 185, 129, 0.06)',
        'plant-lg': '0 10px 15px -3px rgba(16, 185, 129, 0.1), 0 4px 6px -2px rgba(16, 185, 129, 0.05)',
      },
      backdropBlur: {
        xs: '2px',
      },
      spacing: {
        '18': '4.5rem',
        '88': '22rem',
      },
      maxWidth: {
        '8xl': '88rem',
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    // Custom plant theme plugin
    function({ addUtilities, theme }) {
      const newUtilities = {
        '.text-gradient-plant': {
          background: `linear-gradient(135deg, ${theme('colors.plant.leaf')}, ${theme('colors.plant.stem')})`,
          '-webkit-background-clip': 'text',
          '-webkit-text-fill-color': 'transparent',
          'background-clip': 'text',
        },
        '.bg-gradient-plant': {
          background: `linear-gradient(135deg, ${theme('colors.plant.leaf')}, ${theme('colors.plant.stem')})`,
        },
        '.bg-gradient-earth': {
          background: `linear-gradient(180deg, ${theme('colors.plant.earth')}, ${theme('colors.amber.800')})`,
        },
        '.shadow-plant-glow': {
          'box-shadow': `0 0 20px ${theme('colors.plant.leaf')}40`,
        }
      }
      addUtilities(newUtilities)
    }
  ],
}