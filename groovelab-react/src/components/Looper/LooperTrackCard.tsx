import { useRef, useEffect } from 'react'
import { cn } from '@/lib/utils'

type TrackState = 'empty' | 'armed' | 'recording' | 'playing' | 'muted' | 'overdub'

interface LooperTrackCardProps {
  index: number
  state: TrackState
  progress: number
  volume: number
  onTap: () => void
  onVolumeChange: (v: number) => void
  onMute: () => void
}

const STATE_STYLE: Record<TrackState, { bg: string; border: string; label: string }> = {
  empty:     { bg: '#161616', border: '#2A2A2A', label: 'TAP TO RECORD' },
  armed:     { bg: '#1A0800', border: '#FF3B30', label: 'COUNT IN...' },
  recording: { bg: '#200000', border: '#FF0000', label: '\u25CF REC' },
  playing:   { bg: '#001800', border: '#00FF44', label: '\u25B6 PLAY' },
  muted:     { bg: '#0F0F0F', border: '#333333', label: 'MUTED' },
  overdub:   { bg: '#1A0800', border: '#FFAA00', label: '\u25CF OVERDUB' },
}

export function LooperTrackCard({
  index, state, progress, volume, onTap, onVolumeChange, onMute,
}: LooperTrackCardProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const cfg = STATE_STYLE[state]

  useEffect(() => {
    const c = canvasRef.current
    if (!c) return
    const ctx = c.getContext('2d')!
    ctx.clearRect(0, 0, c.width, c.height)
    if (state === 'empty') return
    const color =
      state === 'recording' ? '#FF000070'
      : state === 'overdub' ? '#FFAA0070'
      : state === 'playing' ? '#00FF4470'
      : '#50505070'
    ctx.strokeStyle = color
    ctx.lineWidth = 1.5
    ctx.beginPath()
    for (let x = 0; x < c.width; x++) {
      const t = (x / c.width) * Math.PI * 18
      const a = (c.height * 0.3) * (0.5 + 0.5 * Math.sin(x * 0.25))
      const y = c.height / 2 + a * Math.sin(t)
      x === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
    }
    ctx.stroke()
  }, [state])

  return (
    <div
      className="relative rounded-pad overflow-hidden cursor-pointer no-select"
      style={{
        background: cfg.bg,
        border: `1px solid ${cfg.border}`,
        boxShadow: state === 'recording'
          ? `0 0 0 1px ${cfg.border}, 0 0 18px rgba(255,0,0,0.2)`
          : state === 'playing'
            ? `0 0 0 1px ${cfg.border}, 0 0 18px rgba(0,255,68,0.12)`
            : 'none',
        transition: 'box-shadow 0.2s, border-color 0.2s',
      }}
      onClick={onTap}
    >
      {(state === 'playing' || state === 'overdub') && (
        <div className="absolute inset-x-0 top-0 h-0.5">
          <div className="h-full" style={{
            width: `${progress * 100}%`,
            backgroundColor: cfg.border,
            boxShadow: `0 0 4px ${cfg.border}`,
          }} />
        </div>
      )}

      <div className="flex items-center justify-between px-3 py-2">
        <span className="numeric text-studio-400 text-xs">
          {(index + 1).toString().padStart(2, '0')}
        </span>
        <span className="hw-label" style={{ color: cfg.border }}>{cfg.label}</span>
        <div className="w-2 h-2 rounded-full" style={{
          backgroundColor: state !== 'empty' ? cfg.border : '#252525',
          boxShadow: state === 'recording' || state === 'playing' ? `0 0 6px ${cfg.border}` : 'none',
        }} />
      </div>

      <canvas ref={canvasRef} className="w-full block" height={44} />

      <div className="flex items-center gap-2 px-3 py-2" onClick={e => e.stopPropagation()}>
        <input type="range" min={0} max={1} step={0.01} value={volume}
          onChange={e => onVolumeChange(+e.target.value)}
          className="flex-1 h-1 accent-accent" />
        <button onClick={onMute}
          className={cn(
            'hw-label px-2 py-0.5 rounded border transition-colors',
            state === 'muted'
              ? 'border-led-amber text-led-amber'
              : 'border-studio-600 text-studio-500 hover:border-studio-400',
          )}>
          M
        </button>
      </div>
    </div>
  )
}
