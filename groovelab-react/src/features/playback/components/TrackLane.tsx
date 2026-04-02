/**
 * TrackLane — Single track row in the timeline area
 *
 * Shows track label, M/S buttons on left, waveform with section coloring,
 * and markers overlay. Matches the exact design layout.
 */
import { useMemo } from 'react'
import { cn } from '@/lib/cn'
import type { PlaybackTrack, Section } from '../types'
import { TrackWaveform } from './TrackWaveform'
import { generateFakeWaveform } from '../constants'

interface TrackLaneProps {
  track: PlaybackTrack
  index: number
  sections: Section[]
  progress: number
  hasSolo: boolean
  onToggleMute: (id: string) => void
  onToggleSolo: (id: string) => void
  onTimelineClick: (ratio: number) => void
}

export function TrackLane({
  track,
  index,
  sections,
  progress,
  hasSolo,
  onToggleMute,
  onToggleSolo,
  onTimelineClick,
}: TrackLaneProps) {
  const isMutedVisual = track.muted || (hasSolo && !track.soloed)

  const waveform = useMemo(() => {
    if (track.waveformData) return Array.from(track.waveformData)
    return generateFakeWaveform(index * 7 + track.id.charCodeAt(0))
  }, [track.waveformData, track.id, index])

  const handleClick = (e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect()
    const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width))
    onTimelineClick(ratio)
  }

  return (
    <div className="h-10 flex border-b border-studio-800/60 hover:bg-studio-800/20 transition-colors relative group">
      {/* Track label + M/S buttons */}
      <div className="w-14 flex-shrink-0 bg-studio-800 border-r border-studio-600/40 sticky left-0 z-[5] flex items-center px-1 gap-0.5">
        {/* M/S column */}
        <div className="flex flex-col gap-px flex-shrink-0">
          <button
            onClick={(e) => { e.stopPropagation(); onToggleMute(track.id) }}
            className={cn(
              'w-[14px] h-[12px] rounded-[2px] text-[6px] font-bold flex items-center justify-center leading-none transition-all',
              track.muted
                ? 'bg-led-amber text-studio-900'
                : 'bg-studio-700 text-studio-500 hover:bg-studio-600',
            )}
          >
            M
          </button>
          <button
            onClick={(e) => { e.stopPropagation(); onToggleSolo(track.id) }}
            className={cn(
              'w-[14px] h-[12px] rounded-[2px] text-[6px] font-bold flex items-center justify-center leading-none transition-all',
              track.soloed
                ? 'bg-led-green text-studio-900'
                : 'bg-studio-700 text-studio-500 hover:bg-studio-600',
            )}
          >
            S
          </button>
        </div>
        {/* Track name + color */}
        <div className="flex flex-col items-center gap-0.5 flex-1 min-w-0">
          <div className="w-4 h-0.5 rounded-full" style={{ background: track.color }} />
          <span className="text-[7px] font-semibold text-studio-300 leading-tight text-center truncate w-full">
            {track.shortName}
          </span>
        </div>
      </div>

      {/* Waveform area */}
      <div
        className="flex-1 relative overflow-hidden cursor-pointer"
        style={{ opacity: isMutedVisual ? 0.3 : 1 }}
        onClick={handleClick}
      >
        {/* Section color blocks (subtle background) */}
        <div className="absolute inset-0 flex pointer-events-none">
          {sections.map(s => (
            <div
              key={s.id}
              className="h-full"
              style={{
                width: `${(s.end - s.start) * 100}%`,
                backgroundColor: s.color + '08',
              }}
            />
          ))}
        </div>

        {/* Waveform canvas */}
        <div className="absolute inset-0">
          <TrackWaveform
            peaks={waveform}
            baseColor={track.color}
            sections={sections}
            progress={progress}
            muted={isMutedVisual}
          />
        </div>
      </div>

      {/* Playhead line overlay */}
      <div
        className="absolute top-0 bottom-0 w-px pointer-events-none z-10"
        style={{
          left: `calc(56px + (100% - 56px) * ${progress})`,
          background: 'rgba(255,255,255,0.7)',
          boxShadow: '0 0 4px rgba(255,255,255,0.4)',
        }}
      />
    </div>
  )
}
