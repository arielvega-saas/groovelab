import { useRef, useCallback, type PointerEvent, type KeyboardEvent } from 'react'
import { cn } from '@/lib/cn'

interface KnobProps {
  value: number
  min: number
  max: number
  onChange: (v: number) => void
  size?: number
  label?: string
  color?: string
  showValue?: boolean
  valueFormatter?: (v: number) => string
  className?: string
}

export function Knob({
  value, min, max, onChange, size = 80, label,
  color = '#00E5FF', showValue = true, valueFormatter,
  className,
}: KnobProps) {
  const ref = useRef<HTMLDivElement>(null)
  const startY = useRef(0)
  const startVal = useRef(0)

  const angle = ((value - min) / (max - min)) * 270 - 135

  const onPointerDown = useCallback((e: PointerEvent) => {
    e.preventDefault()
    startY.current = e.clientY
    startVal.current = value
    const el = e.currentTarget as HTMLElement
    el.setPointerCapture(e.pointerId)
  }, [value])

  const onPointerMove = useCallback((e: PointerEvent) => {
    if (!e.buttons) return
    const delta = (startY.current - e.clientY) * ((max - min) / 200)
    const newVal = Math.round(Math.max(min, Math.min(max, startVal.current + delta)))
    if (newVal !== value) onChange(newVal)
  }, [min, max, onChange, value])

  const onKeyDown = useCallback((e: KeyboardEvent) => {
    const step = e.shiftKey ? Math.ceil((max - min) / 10) : 1
    if (e.key === 'ArrowUp' || e.key === 'ArrowRight') {
      e.preventDefault()
      onChange(Math.min(max, value + step))
    } else if (e.key === 'ArrowDown' || e.key === 'ArrowLeft') {
      e.preventDefault()
      onChange(Math.max(min, value - step))
    } else if (e.key === 'Home') {
      e.preventDefault()
      onChange(min)
    } else if (e.key === 'End') {
      e.preventDefault()
      onChange(max)
    }
  }, [min, max, value, onChange])

  return (
    <div className={cn('flex flex-col items-center gap-1', className)}>
      <div
        ref={ref}
        className="relative cursor-grab active:cursor-grabbing select-none focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-gl-accent/50 rounded-full"
        style={{ width: size, height: size }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onKeyDown={onKeyDown}
        role="slider"
        aria-valuenow={value}
        aria-valuemin={min}
        aria-valuemax={max}
        aria-label={label}
        tabIndex={0}
      >
        {/* Track ring */}
        <svg viewBox="0 0 100 100" className="absolute inset-0">
          <circle
            cx="50" cy="50" r="42"
            fill="none" stroke="#2A2A2A" strokeWidth="6"
            strokeLinecap="round"
            strokeDasharray="198"
            strokeDashoffset="50"
            transform="rotate(135 50 50)"
          />
          <circle
            cx="50" cy="50" r="42"
            fill="none" stroke={color} strokeWidth="6"
            strokeLinecap="round"
            strokeDasharray="198"
            strokeDashoffset={198 - ((value - min) / (max - min)) * 148}
            transform="rotate(135 50 50)"
            style={{ filter: `drop-shadow(0 0 4px ${color}80)` }}
          />
        </svg>
        {/* Inner circle + indicator */}
        <div
          className="absolute inset-[14%] rounded-full bg-gl-panel neu-raised flex items-center justify-center"
          style={{ transform: `rotate(${angle}deg)` }}
        >
          <div
            className="absolute top-[8%] w-[3px] h-[18%] rounded-full"
            style={{ backgroundColor: color }}
          />
        </div>
      </div>
      {showValue && (
        <span className="font-mono text-sm" style={{ color }}>
          {valueFormatter ? valueFormatter(value) : value}
        </span>
      )}
      {label && <span className="text-[10px] text-gl-muted uppercase tracking-wider">{label}</span>}
    </div>
  )
}
