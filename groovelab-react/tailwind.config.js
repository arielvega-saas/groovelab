/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: ['./index.html', './src/**/*.{ts,tsx,js,jsx}'],
  theme: {
    screens: {
      'xs': '480px',
      'sm': '640px',
      'md': '768px',
      'lg': '1024px',
      'xl': '1280px',
      '2xl': '1536px',
    },
    extend: {
      colors: {
        studio: {
          950: '#080808',
          900: '#0F0F0F',
          850: '#141414',
          800: '#1A1A1A',
          750: '#202020',
          700: '#2A2A2A',
          600: '#383838',
          500: '#505050',
          400: '#707070',
          300: '#909090',
          200: '#B0B0B0',
          100: '#D0D0D0',
          50:  '#F0F0F0',
        },
        // Keep existing gl-* colors for backward compatibility
        'gl-deepest': '#0A0A0A',
        'gl-dark': '#121212',
        'gl-panel': '#1A1A1A',
        'gl-surface': '#212121',
        'gl-elevated': '#2A2A2A',
        'gl-border': '#333333',
        metal: {
          chrome:  '#C8D0D8',
          silver:  '#A0A8B0',
          brushed: '#787E84',
          dark:    '#404850',
          screw:   '#5A5A5A',
        },
        led: {
          red:         '#FF0000',
          'red-glow':   'rgba(255,0,0,0.35)',
          green:       '#00FF44',
          'green-glow': 'rgba(0,255,68,0.35)',
          amber:       '#FFAA00',
          'amber-glow': 'rgba(255,170,0,0.35)',
          blue:        '#00AAFF',
          'blue-glow':  'rgba(0,170,255,0.35)',
          white:       '#FFFFFF',
          off:         '#1A1A1A',
        },
        accent: {
          DEFAULT: '#04C5F7',
          dim:     'rgba(4,197,247,0.15)',
          glow:    'rgba(4,197,247,0.4)',
          800:     '#023A4A',
        },
        // Keep existing accent for backward compat
        'gl-accent': '#00E5FF',
        'gl-green': '#00FF11',
        'gl-warm': '#FF9500',
        'gl-danger': '#FF3B30',
        'gl-purple': '#BF5AF2',
        'gl-text': '#E5E5EA',
        'gl-muted': '#8E8E93',
        'gl-dim': '#636366',
        pedal: {
          distortion: '#CC3300',
          overdrive:  '#3D6E2A',
          delay:      '#1A3A6E',
          reverb:     '#3D2070',
          chorus:     '#1A5A7A',
          compressor: '#505A60',
          eq:         '#1E1E1E',
          gate:       '#5A1010',
          phaser:     '#6E3A1A',
          flanger:    '#1A4A3A',
        },
        success: '#22C55E',
        warning: '#F59E0B',
        error:   '#EF4444',
        info:    '#3B82F6',
      },
      fontFamily: {
        display: ['Audiowide', 'Orbitron', 'Outfit', 'sans-serif'],
        body:    ['Inter', 'system-ui', 'sans-serif'],
        mono:    ['JetBrains Mono', 'Roboto Mono', 'monospace'],
        tech:    ['Orbitron', 'sans-serif'],
      },
      boxShadow: {
        'knob':
          'inset 0 1px 1px rgba(255,255,255,0.15), inset 0 -1px 2px rgba(0,0,0,0.5), 0 3px 8px rgba(0,0,0,0.7)',
        'knob-active':
          'inset 0 1px 1px rgba(255,255,255,0.2), inset 0 -1px 2px rgba(0,0,0,0.5), 0 3px 8px rgba(0,0,0,0.7), 0 0 12px rgba(4,197,247,0.4)',
        'pedal':
          '0 1px 0 #555, 0 2px 0 #444, 0 3px 0 #333, 0 4px 0 #222, 0 8px 20px rgba(0,0,0,0.6), inset 0 1px 0 rgba(255,255,255,0.08)',
        'pedal-stomp':
          '0 1px 0 #222, 0 2px 4px rgba(0,0,0,0.6), inset 0 2px 4px rgba(0,0,0,0.5)',
        'led-red':   '0 0 4px #FF0000, 0 0 10px #FF0000, 0 0 20px rgba(255,0,0,0.5)',
        'led-green': '0 0 4px #00FF44, 0 0 10px #00FF44, 0 0 20px rgba(0,255,68,0.5)',
        'led-amber': '0 0 4px #FFAA00, 0 0 10px #FFAA00, 0 0 20px rgba(255,170,0,0.5)',
        'led-blue':  '0 0 4px #00AAFF, 0 0 10px #00AAFF, 0 0 20px rgba(0,170,255,0.5)',
        'led-off':   'inset 0 1px 2px rgba(0,0,0,0.6)',
        'metal-raised':
          'inset 0 1px 0 rgba(255,255,255,0.12), 0 2px 6px rgba(0,0,0,0.5)',
        'metal-inset':
          'inset 0 2px 4px rgba(0,0,0,0.6), inset 0 1px 1px rgba(0,0,0,0.4)',
        'glow-accent': '0 0 20px rgba(4,197,247,0.3), 0 0 40px rgba(4,197,247,0.15)',
        'display':
          'inset 0 2px 6px rgba(0,0,0,0.8), inset 0 1px 1px rgba(0,0,0,0.5)',
        'pad':
          '6px 6px 12px rgba(0,0,0,0.5), -3px -3px 8px rgba(60,60,60,0.15)',
        'pad-hit':
          'inset 4px 4px 8px rgba(0,0,0,0.5), inset -2px -2px 6px rgba(60,60,60,0.1)',
      },
      backgroundImage: {
        'brushed-metal': "repeating-linear-gradient(to right, rgba(255,255,255,0) 0%, rgba(255,255,255,0) 5%, rgba(255,255,255,0.04) 6%, rgba(255,255,255,0) 7%), linear-gradient(180deg, hsl(210,8%,28%) 0%, hsl(210,8%,35%) 45%, hsl(210,8%,28%) 55%, hsl(210,8%,22%) 100%)",
        'panel-dark': "linear-gradient(180deg, rgba(255,255,255,0.04) 0%, rgba(255,255,255,0) 30%, rgba(0,0,0,0.1) 100%), #1A1A1A",
        'knob-silver': "conic-gradient(from 45deg, #181818,#3A3A3A,#707070,#B0B0B0, #D8D8D8,#B0B0B0,#707070,#3A3A3A, #181818,#3A3A3A,#707070,#B0B0B0, #D8D8D8,#B0B0B0,#707070,#3A3A3A,#181818)",
        'knob-black': "conic-gradient(from 45deg, #080808,#1A1A1A,#2E2E2E,#3A3A3A, #444444,#3A3A3A,#2E2E2E,#1A1A1A,#080808)",
        'knob-gold': "conic-gradient(from 45deg, #3A2800,#6E4E00,#B08800,#D4AA40, #F0CC60,#D4AA40,#B08800,#6E4E00,#3A2800)",
        'display-screen': "linear-gradient(135deg, rgba(0,0,0,0.9) 0%, rgba(10,20,10,0.95) 100%)",
        'tolex': "radial-gradient(ellipse 3px 3px at 2px 2px, rgba(0,0,0,0.3) 0%, transparent 100%), radial-gradient(ellipse 3px 3px at 5px 5px, rgba(255,255,255,0.02) 0%, transparent 100%), #1A1A1A",
      },
      animation: {
        'led-pulse':   'ledPulse 2s ease-in-out infinite',
        'led-flash':   'ledFlash 0.1s ease-out',
        'beat-flash':  'beatFlash 0.08s ease-out',
        'cymbal-vibe': 'cymbalVibrate 0.6s ease-out',
        'spin-slow':   'spin 8s linear infinite',
        'fade-in':     'fadeIn 0.2s ease',
        // Keep existing
        'beat': 'beat 0.15s ease-out',
        'pad-hit': 'pad-hit 0.2s cubic-bezier(0.34, 1.56, 0.64, 1)',
      },
      keyframes: {
        ledPulse: {
          '0%,100%': { filter: 'brightness(1)' },
          '50%':     { filter: 'brightness(1.4)' },
        },
        ledFlash: {
          '0%':   { filter: 'brightness(2.5)', transform: 'scale(1.3)' },
          '100%': { filter: 'brightness(1)',   transform: 'scale(1)' },
        },
        beatFlash: {
          '0%':   { opacity: '1',   transform: 'scale(1.15)' },
          '100%': { opacity: '0.6', transform: 'scale(1)' },
        },
        cymbalVibrate: {
          '0%,100%': { transform: 'translate(0,0) rotate(0deg)' },
          '8%':  { transform: 'translate(-2px,0) rotate(-0.8deg)' },
          '16%': { transform: 'translate(1.5px,0) rotate(0.6deg)' },
          '24%': { transform: 'translate(-1px,0) rotate(-0.4deg)' },
          '32%': { transform: 'translate(0.7px,0) rotate(0.3deg)' },
          '48%': { transform: 'translate(-0.3px,0) rotate(-0.1deg)' },
          '64%': { transform: 'translate(0,0) rotate(0deg)' },
        },
        fadeIn: {
          '0%':   { opacity: '0', transform: 'translateY(4px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        beat: {
          '0%':   { transform: 'scale(1.1)', opacity: '0.9' },
          '100%': { transform: 'scale(1)', opacity: '1' },
        },
        'pad-hit': {
          '0%':   { transform: 'scale(0.95)' },
          '50%':  { transform: 'scale(1.02)' },
          '100%': { transform: 'scale(1)' },
        },
      },
      spacing: {
        'touch':    '44px',
        'touch-lg': '64px',
        'touch-xl': '80px',
      },
      borderRadius: {
        'pedal': '12px',
        'pad':   '16px',
        'panel': '12px',
        'card':  '12px',
        'btn':   '8px',
      },
    },
  },
  plugins: [],
}
