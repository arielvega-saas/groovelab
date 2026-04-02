/**
 * SetlistPanel — Left sidebar matching the exact HTML source gl-setlist
 */
import type { PlaybackRepertoire, TransitionType } from '../types'
import { formatTime } from '../constants'

interface SetlistPanelProps {
  repertoire: PlaybackRepertoire | null
  activeSongIndex: number
  isPlaying: boolean
  transitionType: TransitionType
  collapsed: boolean
  onSelectSong: (index: number) => void
  onPrev: () => void
  onNext: () => void
  onTransitionChange: (type: TransitionType) => void
  totalDuration: number
}

export function SetlistPanel({
  repertoire,
  activeSongIndex,
  transitionType,
  collapsed,
  onSelectSong,
  onPrev,
  onNext,
  onTransitionChange,
  totalDuration,
}: SetlistPanelProps) {
  if (collapsed) return null

  const songs = repertoire?.songs ?? []
  const songColors = ['#f97316', '#3b82f6', '#22c55e', '#a855f7', '#ec4899']

  return (
    <div className="gl-setlist">
      {/* Header */}
      <div className="sl-header">
        <div>
          <div className="sl-title">Repertorio</div>
          <div className="sl-count">
            {repertoire?.name ?? 'Sin repertorio'} · {songs.length} canciones · {formatTime(totalDuration)}
          </div>
        </div>
        <div className="sl-header-actions">
          <button className="sl-header-btn" title="Import">+</button>
          <button className="sl-header-btn" title="Settings">⋯</button>
        </div>
      </div>

      {/* Song list */}
      <div className="sl-songs">
        {songs.map((song, i) => {
          const isActive = i === activeSongIndex
          const isNext = i === activeSongIndex + 1
          return (
            <div
              key={song.id}
              className={`sl-song${isActive ? ' active' : ''}${isNext ? ' next' : ''}`}
              onClick={() => onSelectSong(i)}
            >
              <span className="sl-song-num">{i + 1}</span>
              <div className="sl-song-color" style={{ background: songColors[i % songColors.length] }} />
              <div className="sl-song-info">
                <div className="sl-song-name">{song.name}</div>
                <div className="sl-song-meta">
                  <span className="sl-song-key">{song.key}</span>
                  <span className="sl-song-bpm">{song.bpm} bpm</span>
                  <span className="sl-song-dur">{formatTime(song.duration)}</span>
                </div>
              </div>
              <div className="sl-song-indicator" />
            </div>
          )
        })}
      </div>

      {/* Transition zone */}
      <div className="sl-transition-zone">
        <div style={{
          fontSize: '8px', fontWeight: 700, color: 'var(--gl-text-muted)',
          textTransform: 'uppercase', letterSpacing: '1px', marginBottom: '4px',
        }}>
          Transición
        </div>
        <div style={{ display: 'flex', gap: '3px' }}>
          <button
            className="sl-header-btn"
            style={{
              flex: 1, width: 'auto', fontSize: '8px',
              textTransform: 'uppercase', letterSpacing: '0.5px',
              background: transitionType === 'pad' ? 'var(--gl-accent-dim)' : undefined,
              color: transitionType === 'pad' ? 'var(--gl-accent)' : undefined,
            }}
            onClick={() => onTransitionChange('pad')}
          >
            🎹 PAD
          </button>
          <button
            className="sl-header-btn"
            style={{
              flex: 1, width: 'auto', fontSize: '8px',
              background: transitionType === 'bed' ? 'var(--gl-accent-dim)' : undefined,
              color: transitionType === 'bed' ? 'var(--gl-accent)' : undefined,
            }}
            onClick={() => onTransitionChange('bed')}
          >
            🌊 BED
          </button>
        </div>
      </div>

      {/* Navigation */}
      <div className="sl-nav">
        <button className="sl-nav-btn" onClick={onPrev}>
          <svg viewBox="0 0 12 12"><path d="M8 2L4 6l4 4" /></svg>
          PREV
        </button>
        <button className="sl-nav-btn" onClick={onNext}>
          NEXT
          <svg viewBox="0 0 12 12"><path d="M4 2l4 4-4 4" /></svg>
        </button>
      </div>

      {/* Footer */}
      <div className="sl-footer">
        <span className="sl-footer-label">Total</span>
        <span className="sl-footer-time">{formatTime(totalDuration)}</span>
      </div>
    </div>
  )
}
