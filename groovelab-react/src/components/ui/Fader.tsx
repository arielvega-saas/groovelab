import { cn } from '@/lib/cn'

interface FaderProps {
  value: number
  min?: number
  max?: number
  step?: number
  onChange: (v: number) => void
  label?: string
  color?: string
  vertical?: boolean
  className?: string
}

export function Fader({
  value, min = 0, max = 1, step = 0.01, onChange,
  label, color = '#00E5FF', vertical = false, className,
}: FaderProps) {
  const pct = ((value - min) / (max - min)) * 100

  return (
    <div className={cn(
      'flex gap-1',
      vertical ? 'flex-col items-center' : 'flex-row items-center',
      className
    )}>
      {label && <span className="text-[10px] text-gl-muted uppercase tracking-wider min-w-[28px]">{label}</span>}
      <div className="relative flex-1">
        <input
          type="range"
          min={min} max={max} step={step} value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          className={cn(
            'w-full appearance-none bg-transparent cursor-pointer',
            vertical && 'writing-mode-vertical'
          )}
          style={{
            accentColor: color,
            ...(vertical ? { writingMode: 'vertical-lr' as never, direction: 'rtl' as never, height: 80 } : {}),
          }}
          aria-label={label}
        />
        {!vertical && (
          <div
            className="absolute bottom-0 left-0 h-[2px] rounded-full pointer-events-none"
            style={{ width: `${pct}%`, backgroundColor: color, boxShadow: `0 0 6px ${color}80` }}
          />
        )}
      </div>
    </div>
  )
}
