/**
 * MixerPanel — Full mixer matching the exact HTML source gl-mixer
 *
 * Contains: scrollable channel strips with group separators,
 * side action panel (MIX/MUTE/ROUTE/GRP/TPL), and MASTER channel.
 */
import { useRef, useCallback } from 'react'
import type { PlaybackTrack } from '../types'
import { volumeToDb, CHANNEL_GROUPS } from '../constants'

interface MixerPanelProps {
  tracks: PlaybackTrack[]
  masterVolume: number
  hasSolo?: boolean
  getVULevel: (trackId: string) => number
  onSetFader: (id: string, val: number) => void
  onToggleMute: (id: string) => void
  onToggleSolo: (id: string) => void
  onSetMasterVolume: (val: number) => void
}

/** Get CSS channel color variable name from track type */
function getChannelColorVar(type: string): string {
  const map: Record<string, string> = {
    click: 'var(--ch-click)',
    guide: 'var(--ch-guide)',
    drums: 'var(--ch-drums)',
    loop: 'var(--ch-loop)',
    bass: 'var(--ch-bass)',
    'bass-synth': 'var(--ch-bass-synth)',
    'guitar-electric': 'var(--ch-guitar)',
    guitar: 'var(--ch-guitar)',
    keys: 'var(--ch-keys)',
    synth: 'var(--ch-synth)',
    vocals: 'var(--ch-vocals)',
    choir: 'var(--ch-choir)',
    pad: 'var(--ch-pad)',
    fx: 'var(--ch-fx)',
  }
  return map[type] ?? 'var(--gl-text-tertiary)'
}

/** Format pan value to display string */
function formatPan(pan: number): string {
  if (Math.abs(pan) < 0.01) return 'C'
  if (pan < 0) return `L${Math.round(Math.abs(pan) * 100)}`
  return `R${Math.round(pan * 100)}`
}

/** Vertical fader with drag support */
function Fader({
  value,
  onChange,
  isMaster,
}: {
  value: number
  onChange: (val: number) => void
  isMaster?: boolean
}) {
  const faderRef = useRef<HTMLDivElement>(null)
  const percent = value / 100

  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    e.preventDefault()
    const fader = faderRef.current
    if (!fader) return

    const updateValue = (clientY: number) => {
      const rect = fader.getBoundingClientRect()
      const ratio = 1 - Math.max(0, Math.min(1, (clientY - rect.top) / rect.height))
      onChange(Math.round(ratio * 100))
    }

    updateValue(e.clientY)

    const onMove = (ev: MouseEvent) => updateValue(ev.clientY)
    const onUp = () => {
      document.removeEventListener('mousemove', onMove)
      document.removeEventListener('mouseup', onUp)
    }
    document.addEventListener('mousemove', onMove)
    document.addEventListener('mouseup', onUp)
  }, [onChange])

  return (
    <div className="ch-fader" ref={faderRef} onMouseDown={handleMouseDown} style={isMaster ? { flex: 1 } : undefined}>
      <div className="ch-fader-track">
        <div className="ch-fader-fill" style={{ height: `${percent * 100}%` }} />
      </div>
      <div
        className="ch-fader-thumb"
        style={{
          bottom: `${percent * 100}%`,
          ...(isMaster ? { width: '40px', height: '20px' } : {}),
        }}
      />
    </div>
  )
}

/** VU Meter — 16 segments: 10 green, 2 amber, 4 red */
function VUMeter({ level, muted }: { level: number; muted?: boolean }) {
  const totalSegs = 16
  const litCount = Math.round(level * totalSegs)

  return (
    <div className="ch-meter">
      {Array.from({ length: totalSegs }, (_, i) => {
        const isLit = i < litCount
        let colorClass = 'green'
        if (i >= 12) colorClass = 'red'
        else if (i >= 10) colorClass = 'amber'
        return (
          <div
            key={i}
            className={`ch-meter-seg ${colorClass}${isLit && !muted ? ' on' : ''}`}
          />
        )
      })}
    </div>
  )
}

/** Single channel strip */
function ChannelStrip({
  track,
  vuLevel,
  onSetFader,
  onToggleMute,
  onToggleSolo,
}: {
  track: PlaybackTrack
  vuLevel: number
  onSetFader: (id: string, val: number) => void
  onToggleMute: (id: string) => void
  onToggleSolo: (id: string) => void
}) {
  const chColor = getChannelColorVar(track.type)
  const classes = [
    'mx-ch',
    track.muted ? 'muted' : '',
    track.soloed ? 'soloed' : '',
  ].filter(Boolean).join(' ')

  return (
    <div
      className={classes}
      style={{ '--ch-color': chColor } as React.CSSProperties}
    >
      {/* M/S buttons */}
      <div className="ch-buttons">
        <button
          className={`ch-btn-mute${track.muted ? ' on' : ''}`}
          onClick={() => onToggleMute(track.id)}
        >
          M
        </button>
        <button
          className={`ch-btn-solo${track.soloed ? ' on' : ''}`}
          onClick={() => onToggleSolo(track.id)}
        >
          S
        </button>
      </div>

      {/* dB display */}
      <div className="ch-db">{volumeToDb(track.volume)}</div>

      {/* Fader assembly: meter + fader + meter */}
      <div className="ch-fader-assembly">
        <VUMeter level={vuLevel} muted={track.muted} />
        <Fader
          value={track.volume}
          onChange={(val) => onSetFader(track.id, val)}
        />
        <VUMeter level={vuLevel * 0.95} muted={track.muted} />
      </div>

      {/* Pan */}
      <div className="ch-pan">{formatPan(track.pan)}</div>

      {/* Name */}
      <div className="ch-name">{track.name}</div>
    </div>
  )
}

export function MixerPanel({
  tracks,
  masterVolume,
  hasSolo: _hasSolo,
  getVULevel,
  onSetFader,
  onToggleMute,
  onToggleSolo,
  onSetMasterVolume,
}: MixerPanelProps) {
  // Build channel list with group separators
  const channelElements: React.ReactNode[] = []

  tracks.forEach((track) => {
    channelElements.push(
      <ChannelStrip
        key={track.id}
        track={track}
        vuLevel={getVULevel(track.id)}
        onSetFader={onSetFader}
        onToggleMute={onToggleMute}
        onToggleSolo={onToggleSolo}
      />
    )

    // Check if group separator needed after this track
    const group = CHANNEL_GROUPS.find(g => g.afterTrackId === track.id)
    if (group) {
      channelElements.push(
        <div key={`sep-${group.id}`} className="mx-group-sep">
          <span className="mx-group-label">{group.label}</span>
        </div>
      )
    }
  })

  const masterVU = getVULevel('master')

  return (
    <div className="gl-mixer">
      {/* Scrollable channels */}
      <div className="mx-channels-wrap">
        <div className="mx-channels">
          {channelElements}
        </div>
      </div>

      {/* Side panel */}
      <div className="mx-side">
        <button className="mx-side-btn active" data-action="mix" title="Mix Settings">
          <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
            <path d="M2 4h3m3 0h6M2 8h7m3 0h2M2 12h5m3 0h4" />
            <circle cx="7" cy="4" r="1.5" fill="currentColor" />
            <circle cx="11" cy="8" r="1.5" fill="currentColor" />
            <circle cx="9" cy="12" r="1.5" fill="currentColor" />
          </svg>
          MIX
        </button>
        <button className="mx-side-btn" data-action="mute-midi" title="MIDI Mute Map">
          <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
            <path d="M8 2a6 6 0 100 12A6 6 0 008 2zM4 8h8" />
          </svg>
          MUTE
        </button>
        <button className="mx-side-btn" data-action="routing" title="Audio Routing">
          <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
            <path d="M2 4h4l4 8h4M2 12h4l4-8h4" />
          </svg>
          ROUTE
        </button>
        <div className="mx-side-sep" />
        <button className="mx-side-btn" data-action="groups" title="Channel Groups">
          <svg viewBox="0 0 16 16" fill="currentColor">
            <rect x="1" y="2" width="5" height="5" rx="1" />
            <rect x="10" y="2" width="5" height="5" rx="1" />
            <rect x="5.5" y="9" width="5" height="5" rx="1" />
          </svg>
          GRP
        </button>
        <button className="mx-side-btn" data-action="template" title="Save Template">
          <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
            <path d="M4 2h8v12H4zM7 5h2M7 7h2M7 9h2" />
          </svg>
          TPL
        </button>
      </div>

      {/* Master channel */}
      <div className="mx-master">
        <div className="ch-buttons">
          <button className="ch-btn-mute">M</button>
          <button className="ch-btn-solo">S</button>
        </div>
        <div className="ch-db" style={{ color: 'var(--gl-text-primary)', fontSize: '11px' }}>
          {volumeToDb(masterVolume)}
        </div>
        <div className="ch-fader-assembly">
          <div className="ch-meter-stereo" style={{ display: 'flex', gap: '2px' }}>
            <VUMeter level={masterVU} />
            <VUMeter level={masterVU * 0.97} />
          </div>
          <Fader
            value={masterVolume}
            onChange={onSetMasterVolume}
            isMaster
          />
          <div className="ch-meter-stereo" style={{ display: 'flex', gap: '2px' }}>
            <VUMeter level={masterVU * 0.98} />
            <VUMeter level={masterVU * 0.95} />
          </div>
        </div>
        <div className="ch-pan">C</div>
        <div className="ch-name" style={{
          color: 'var(--gl-accent)', fontSize: '10px',
          fontWeight: 800, letterSpacing: '1px',
        }}>
          MASTER
        </div>
      </div>
    </div>
  )
}
