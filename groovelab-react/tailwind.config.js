/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        gl: {
          deepest: '#0A0A0A',
          dark: '#121212',
          panel: '#1A1A1A',
          surface: '#212121',
          elevated: '#2A2A2A',
          border: '#333333',
          accent: '#00E5FF',
          green: '#00FF11',
          warm: '#FF9500',
          danger: '#FF3B30',
          purple: '#BF5AF2',
          text: '#FFFFFF',
          muted: '#8E8E93',
          dim: '#636366',
        },
      },
      fontFamily: {
        display: ["'Outfit'", 'system-ui', 'sans-serif'],
        mono: ["'JetBrains Mono'", 'ui-monospace', 'monospace'],
      },
      animation: {
        'beat': 'beat-pulse 0.15s ease-out',
        'pad-hit': 'pad-hit 0.2s ease-out',
      },
      keyframes: {
        'beat-pulse': {
          '0%, 100%': { transform: 'scale(1)' },
          '10%': { transform: 'scale(1.08)' },
        },
        'pad-hit': {
          '0%': { transform: 'scale(1)' },
          '15%': { transform: 'scale(0.92)' },
          '40%': { transform: 'scale(1.02)' },
          '100%': { transform: 'scale(1)' },
        },
      },
    },
  },
  plugins: [],
}
