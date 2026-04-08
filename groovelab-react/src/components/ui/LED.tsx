import { cn } from '@/lib/utils'

type LEDColor = 'red' | 'green' | 'amber' | 'blue' | 'white'
type LEDState = 'off' | 'on' | 'pulse' | 'flash'

interface LEDProps {
  color?: LEDColor
  state?: LEDState
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

const colorMap: Record<LEDColor, { on: string; glow: string; off: string }> = {
  red:   { on: '#FF0000', glow: '0 0 6px #FF0000, 0 0 14px rgba(255,0,0,0.5)',   off: '#330000' },
  green: { on: '#00FF44', glow: '0 0 6px #00FF44, 0 0 14px rgba(0,255,68,0.5)',   off: '#003311' },
  amber: { on: '#FFAA00', glow: '0 0 6px #FFAA00, 0 0 14px rgba(255,170,0,0.5)',  off: '#332200' },
  blue:  { on: '#00AAFF', glow: '0 0 6px #00AAFF, 0 0 14px rgba(0,170,255,0.5)', off: '#001133' },
  white: { on: '#FFFFFF', glow: '0 0 6px #FFF, 0 0 14px rgba(255,255,255,0.5)',   off: '#111111' },
}

const sizeMap = { sm: 'w-2 h-2', md: 'w-3 h-3', lg: 'w-4 h-4' }

export function LED({
  color = 'green', state = 'off', size = 'md', className,
}: LEDProps) {
  const c = colorMap[color]
  const isOn = state !== 'off'
  return (
    <div
      role="status"
      aria-label={`${color} LED ${isOn ? state : 'off'}`}
      className={cn(
        'rounded-full transition-all duration-150',
        sizeMap[size],
        state === 'pulse' && 'animate-led-pulse',
        state === 'flash' && 'animate-led-flash',
        className,
      )}
      style={{
        background: isOn
          ? `radial-gradient(circle at 35% 35%, ${c.on}FF, ${c.on}AA)`
          : `radial-gradient(circle at 35% 35%, ${c.off}88, ${c.off}44)`,
        boxShadow: isOn ? c.glow : 'inset 0 1px 2px rgba(0,0,0,0.7)',
      }}
    />
  )
}
