import { useRef, useCallback } from 'react'
import { cn } from '@/lib/utils'

interface RotaryKnobProps {
  value: number
  onChange: (v: number) => void
  label?: string
  size?: 'sm' | 'md' | 'lg'
  variant?: 'silver' | 'black' | 'gold'
  disabled?: boolean
  className?: string
}

const sizes = {
  sm: { outer: 32, line: { w: 2, h: 7, top: 3 } },
  md: { outer: 48, line: { w: 2.5, h: 10, top: 4 } },
  lg: { outer: 64, line: { w: 3, h: 14, top: 5 } },
}

const variantBg = {
  silver: 'bg-knob-silver',
  black: 'bg-knob-black',
  gold: 'bg-knob-gold',
}

export function RotaryKnob({
  value, onChange, label,
  size = 'md', variant = 'silver',
  disabled = false, className,
}: RotaryKnobProps) {
  const s = sizes[size]
  const rotation = value * 270 - 135
  const isDragging = useRef(false)
  const startY = useRef(0)
  const startVal = useRef(0)

  const onPointerDown = useCallback((e: React.PointerEvent) => {
    if (disabled) return
    isDragging.current = true
    startY.current = e.clientY
    startVal.current = value
    ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
    e.preventDefault()
  }, [disabled, value])

  const onPointerMove = useCallback((e: React.PointerEvent) => {
    if (!isDragging.current) return
    const delta = (startY.current - e.clientY) * 0.004
    onChange(Math.max(0, Math.min(1, startVal.current + delta)))
  }, [onChange])

  const onPointerUp = useCallback(() => {
    isDragging.current = false
  }, [])

  return (
    <div className={cn('flex flex-col items-center gap-1 no-select', className)}>
      <div
        className="relative rounded-full flex items-center justify-center"
        style={{
          width: s.outer + 8,
          height: s.outer + 8,
          background: 'radial-gradient(circle at 50% 30%, #383838, #101010)',
          boxShadow: 'inset 0 2px 4px rgba(0,0,0,0.8), 0 1px 0 rgba(255,255,255,0.05)',
        }}
      >
        <div
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          className={cn(
            'relative rounded-full',
            variantBg[variant],
            disabled ? 'opacity-40 cursor-not-allowed' : 'cursor-grab active:cursor-grabbing',
          )}
          style={{
            width: s.outer, height: s.outer,
            transform: `rotate(${rotation}deg)`,
            transition: isDragging.current ? 'none' : 'transform 0.05s ease-out',
            boxShadow: 'inset 0 1px 1px rgba(255,255,255,0.18), inset 0 -1px 2px rgba(0,0,0,0.5), 0 3px 8px rgba(0,0,0,0.7)',
          }}
        >
          <div
            className="absolute left-1/2 bg-white rounded-full -translate-x-1/2"
            style={{
              width: s.line.w, height: s.line.h,
              top: s.line.top,
              boxShadow: '0 0 3px rgba(255,255,255,0.8)',
            }}
          />
        </div>
      </div>
      {label && <span className="hw-label">{label}</span>}
    </div>
  )
}
