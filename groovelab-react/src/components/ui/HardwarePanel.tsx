import { cn } from '@/lib/utils'
import type { ReactNode } from 'react'

interface HardwarePanelProps {
  children: ReactNode
  title?: string
  className?: string
  variant?: 'rack' | 'screen'
}

export function HardwarePanel({
  children, title, className, variant = 'rack',
}: HardwarePanelProps) {
  return (
    <div
      className={cn(
        'relative rounded-lg overflow-hidden',
        variant === 'rack'
          ? 'bg-studio-800 shadow-metal-raised border border-studio-600/50'
          : 'bg-display-screen shadow-display border border-studio-600/30',
        className,
      )}
    >
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />
      {title && (
        <div className="px-3 pt-2">
          <span className="hw-label">{title}</span>
        </div>
      )}
      {children}
    </div>
  )
}
