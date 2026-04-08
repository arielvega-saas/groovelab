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
    <section
      className={cn(
        'relative rounded-xl overflow-hidden',
        variant === 'rack'
          ? 'bg-studio-800 shadow-metal-raised border border-studio-600/50'
          : 'bg-display-screen shadow-display border border-studio-600/30',
        className,
      )}
      aria-label={title}
      role="region"
    >
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />
      {title && (
        <div className="px-3 pt-2">
          <span className="hw-label">{title}</span>
        </div>
      )}
      {children}
    </section>
  )
}
