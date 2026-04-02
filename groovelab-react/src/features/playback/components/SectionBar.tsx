/**
 * SectionBar — Colored section segments along the top of the timeline
 *
 * Displays sections like INTRO, VERSE 1, PRE, CHORUS, BRIDGE, OUTRO
 * with matching colors. Active section is highlighted with glow.
 */
import { cn } from '@/lib/cn'
import type { Section } from '../types'

interface SectionBarProps {
  sections: Section[]
  progress: number     // 0–1
  onClick: (position: number) => void
}

export function SectionBar({ sections, progress, onClick }: SectionBarProps) {
  const handleClick = (e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect()
    const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width))
    onClick(ratio)
  }

  return (
    <div
      className="h-6 flex-shrink-0 flex cursor-pointer relative"
      onClick={handleClick}
    >
      {sections.map((section) => {
        const width = (section.end - section.start) * 100
        const isActive = progress >= section.start && progress < section.end
        return (
          <div
            key={section.id}
            className={cn(
              'h-full flex items-center justify-center border-r border-black/30 transition-all overflow-hidden',
              isActive && 'z-10',
            )}
            style={{
              width: `${width}%`,
              backgroundColor: section.color + (isActive ? 'E0' : '40'),
              boxShadow: isActive ? `inset 0 0 12px ${section.color}40, 0 0 8px ${section.color}30` : undefined,
            }}
          >
            <span className={cn(
              'text-[9px] font-bold tracking-wider text-white/90 whitespace-nowrap px-1',
              isActive && 'text-white',
            )}>
              {section.label}
            </span>
          </div>
        )
      })}
      {/* Playhead marker on section bar */}
      <div
        className="absolute top-0 bottom-0 w-0.5 bg-white z-20 pointer-events-none"
        style={{
          left: `${progress * 100}%`,
          boxShadow: '0 0 4px rgba(255,255,255,0.6)',
        }}
      />
    </div>
  )
}
