/**
 * MiniVU — Compact LED-style VU meter for mixer channels
 *
 * 12-segment vertical meter with green → orange → red color progression.
 */
import { memo } from 'react'

interface MiniVUProps {
  level: number   // 0–1
  color: string   // Track color for green segments
}

const SEGMENTS = 12

export const MiniVU = memo(function MiniVU({ level, color }: MiniVUProps) {
  return (
    <div className="flex flex-col-reverse gap-px w-1.5" style={{ height: 60 }}>
      {Array.from({ length: SEGMENTS }).map((_, i) => {
        const threshold = i / SEGMENTS
        const active = level >= threshold
        const ratio = i / SEGMENTS
        const bg = ratio >= 0.85 ? '#FF3B30' : ratio >= 0.65 ? '#FF9500' : color
        return (
          <div
            key={i}
            className="flex-1 rounded-[1px]"
            style={{
              background: active ? bg : '#1A1A1A',
              opacity: active ? 1 : 0.2,
            }}
          />
        )
      })}
    </div>
  )
})
