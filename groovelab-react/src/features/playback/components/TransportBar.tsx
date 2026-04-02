/**
 * TransportBar — Top bar matching the exact PlayBack source HTML
 *
 * Layout: Song info | Bar·Beat + Time | BPM + Time Sig | Beat dots |
 * Controls (stop, rewind, play, forward, PAD) | Mode (ENSAYO, VIVO) |
 * Actions (EDITAR, show-mode, settings, menu)
 */
import type { PlaybackMode, PlaybackSong } from '../types'
// constants used via CSS variables

interface TransportBarProps {
  activeSong: PlaybackSong | null
  currentTime: number
  duration: number
  isPlaying: boolean
  mode: PlaybackMode
  currentBar: number
  currentBeat: number
  onTogglePlay: () => void
  onStop: () => void
  onNext: () => void
  onPrev: () => void
  onModeChange: (mode: PlaybackMode) => void
}

function fmt(s: number): string {
  const m = Math.floor(s / 60).toString().padStart(2, '0')
  const sec = Math.floor(s % 60).toString().padStart(2, '0')
  return `${m}:${sec}`
}

function fmtTotal(s: number): string {
  const m = Math.floor(s / 60)
  const sec = Math.floor(s % 60).toString().padStart(2, '0')
  return `${m}:${sec}`
}

export function TransportBar({
  activeSong,
  currentTime,
  duration,
  isPlaying,
  mode,
  currentBar,
  currentBeat,
  onTogglePlay,
  onStop,
  onNext,
  onPrev,
  onModeChange,
}: TransportBarProps) {
  const bpm = activeSong?.bpm ?? 120

  return (
    <div className="gl-transport">
      {/* Song Info */}
      <div className="tr-song-info">
        <div
          className="tr-song-status"
          data-state={isPlaying ? 'playing' : 'paused'}
        />
        <span className="tr-song-name">
          {activeSong?.name ?? 'Sin canción'}
        </span>
        {activeSong && (
          <span className="tr-song-key">{activeSong.key}</span>
        )}
      </div>

      {/* Time Display */}
      <div className="tr-time-display">
        <div style={{
          display: 'flex', flexDirection: 'column', alignItems: 'center',
          padding: '0 10px', borderRight: '1px solid rgba(255,255,255,0.06)',
          marginRight: '4px',
        }}>
          <span style={{
            fontFamily: 'var(--font-mono)', fontSize: '15px', fontWeight: 700,
            color: 'var(--gl-text-bright)', letterSpacing: '-0.3px',
          }}>
            {currentBar} . {currentBeat}
          </span>
          <span style={{
            fontSize: '7px', color: 'var(--gl-text-muted)',
            letterSpacing: '1px', textTransform: 'uppercase' as const,
          }}>
            BAR . BEAT
          </span>
        </div>
        <span className="tr-time-current">{fmt(currentTime)}</span>
        <span className="tr-time-sep">/</span>
        <span className="tr-time-total">{fmtTotal(duration)}</span>
      </div>

      {/* BPM & Meter */}
      <div className="tr-tempo-meter">
        <div className="tr-bpm-box">
          <span className="tr-bpm-val">{bpm}</span>
          <span className="tr-bpm-label">BPM</span>
        </div>
        <div className="tr-meter-box">
          <span className="tr-meter-val">4/4</span>
          <span className="tr-meter-label">TIME</span>
        </div>
      </div>

      {/* Beat dots */}
      <div className="tr-beat-dots">
        {[1, 2, 3, 4].map(b => (
          <div
            key={b}
            className={`tr-beat-dot${currentBeat === b ? ' active' : ''}`}
          />
        ))}
      </div>

      {/* Playback Controls */}
      <div className="tr-controls">
        <button className="tr-btn" data-action="stop" title="Stop" onClick={onStop}>
          <svg viewBox="0 0 16 16"><rect x="3" y="3" width="10" height="10" rx="1" /></svg>
        </button>
        <button className="tr-btn" data-action="rewind" title="Return to Start" onClick={onPrev}>
          <svg viewBox="0 0 16 16"><path d="M3 3v10M7 8l6-5v10z" /></svg>
        </button>
        <button
          className="tr-btn-play"
          data-state={isPlaying ? 'playing' : 'paused'}
          title="Play/Pause"
          onClick={onTogglePlay}
        >
          {isPlaying ? (
            <svg viewBox="0 0 16 16">
              <rect x="3" y="3" width="3.5" height="10" rx="0.5" />
              <rect x="9.5" y="3" width="3.5" height="10" rx="0.5" />
            </svg>
          ) : (
            <svg viewBox="0 0 16 16"><path d="M4 3l9 5-9 5z" /></svg>
          )}
        </button>
        <button className="tr-btn" data-action="forward" title="Next Section" onClick={onNext}>
          <svg viewBox="0 0 16 16"><path d="M3 3l6 5-6 5zM13 3v10" /></svg>
        </button>
        <button className="tr-btn tr-btn-pad" data-active="false" title="Transition Pad">
          PAD
        </button>
      </div>

      {/* Mode */}
      <div className="tr-mode">
        <button
          className={`tr-mode-btn${mode === 'ensayo' ? ' active' : ''}`}
          onClick={() => onModeChange('ensayo')}
        >
          ENSAYO
        </button>
        <button
          className={`tr-mode-btn${mode === 'vivo' ? ' active' : ''}`}
          onClick={() => onModeChange('vivo')}
        >
          VIVO
        </button>
      </div>

      {/* Right Actions */}
      <div className="tr-actions">
        <button
          className={`tr-btn-edit${mode === 'editar' ? ' active' : ''}`}
          onClick={() => onModeChange('editar')}
        >
          EDITAR
        </button>
        <button className="tr-btn" title="Show Mode" data-action="show-mode">
          <svg viewBox="0 0 16 16"><path d="M2 4h12v8H2z M5 1v3M11 1v3" /></svg>
        </button>
        <button className="tr-btn" title="Settings" data-action="settings">
          <svg viewBox="0 0 16 16">
            <circle cx="8" cy="8" r="2.5" />
            <path d="M8 1v2M8 13v2M1 8h2M13 8h2M3 3l1.5 1.5M11.5 11.5L13 13M3 13l1.5-1.5M11.5 4.5L13 3" />
          </svg>
        </button>
        <button className="tr-btn" title="Menu" data-action="menu">
          <svg viewBox="0 0 16 16"><path d="M2 4h12M2 8h12M2 12h12" /></svg>
        </button>
      </div>
    </div>
  )
}
