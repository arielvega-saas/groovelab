import { cn } from '@/lib/cn'

interface LEDBarProps {
  count: number
  activeIndex: number
  accentIndices?: number[]
  color?: string
  accentColor?: string
  className?: string
}

export function LEDBar({
  count, activeIndex, accentIndices = [0],
  color = '#00E5FF', accentColor = '#FF9500',
  className,
}: LEDBarProps) {
  return (
    <div className={cn('flex gap-1.5 justify-center', className)}>
      {Array.from({ length: count }, (_, i) => {
        const isActive = i === activeIndex
        const isAccent = accentIndices.includes(i)
        const ledColor = isAccent ? accentColor : color
        return (
          <div
            key={i}
            className={cn(
              'w-3 h-3 rounded-full transition-all duration-75',
              isActive ? 'scale-125' : 'scale-100'
            )}
            style={{
              backgroundColor: isActive ? ledColor : '#2A2A2A',
              boxShadow: isActive ? `0 0 10px ${ledColor}, 0 0 20px ${ledColor}60` : 'none',
            }}
          />
        )
      })}
    </div>
  )
}
