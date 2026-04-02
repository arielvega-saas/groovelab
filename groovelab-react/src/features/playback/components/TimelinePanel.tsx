/**
 * TimelinePanel — Timeline area matching the exact HTML source gl-timeline
 *
 * Contains: ruler, section lane, cue markers, automation, waveform, toolbar
 */
import { useCallback, useRef } from 'react'
import type { Section, AutomationPoint } from '../types'

interface TimelinePanelProps {
  sections: Section[]
  automationPoints: AutomationPoint[]
  progress: number
  duration: number
  bpm: number
  onSeek: (ratio: number) => void
  onImport: () => void
}

/** Map section label to CSS data-type */
function getSectionType(label: string): string {
  const l = label.toLowerCase()
  if (l === 'ci') return 'count-in'
  if (l.startsWith('intro')) return 'intro'
  if (l.startsWith('verse')) return 'verse'
  if (l.startsWith('pre')) return 'pre-chorus'
  if (l.startsWith('chorus')) return 'chorus'
  if (l.startsWith('bridge')) return 'bridge'
  if (l.startsWith('outro')) return 'outro'
  return 'verse'
}

export function TimelinePanel({
  sections,
  automationPoints,
  progress,
  duration,
  bpm,
  onSeek,
  onImport,
}: TimelinePanelProps) {
  const waveformRef = useRef<HTMLDivElement>(null)

  const handleWaveformClick = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect()
    const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width))
    onSeek(ratio)
  }, [onSeek])

  // Generate bar marks: 4 bars per group, show number on every 4th
  const totalBars = Math.max(20, Math.ceil((duration * bpm) / (60 * 4)))
  const barMarks = Array.from({ length: Math.min(totalBars, 80) }, (_, i) => i + 1)

  // Find current section
  const currentSectionIdx = sections.findIndex(s => progress >= s.start && progress < s.end)

  // Section progress within current section
  const currentSection = sections[currentSectionIdx]
  const sectionProgress = currentSection
    ? ((progress - currentSection.start) / (currentSection.end - currentSection.start)) * 100
    : 0

  return (
    <div className="gl-timeline">
      {/* Ruler */}
      <div className="tl-ruler">
        <div className="tl-ruler-marks">
          {barMarks.map(b => (
            <div key={b} className="tl-bar-mark" style={{ flex: 1 }}>
              {b % 4 === 1 ? b : ''}
            </div>
          ))}
        </div>
      </div>

      {/* Section lane */}
      <div className="tl-sections">
        {sections.map((sec, i) => {
          const isCurrent = i === currentSectionIdx
          const flex = (sec.end - sec.start) * 10
          return (
            <div
              key={sec.id}
              className={`tl-section${isCurrent ? ' current' : ''}`}
              data-type={getSectionType(sec.label)}
              style={{ flex }}
              onClick={() => onSeek(sec.start)}
            >
              <span>{sec.label}</span>
              {isCurrent && (
                <div className="tl-section-progress" style={{ width: `${sectionProgress}%` }} />
              )}
            </div>
          )
        })}
      </div>

      {/* Cue markers lane */}
      <div className="tl-cues-lane">
        {automationPoints
          .filter(p => p.label === 'M' || p.label === 'L' || p.label === 'E')
          .map(p => (
            <div
              key={p.id}
              className="tl-cue-marker"
              data-type={p.label === 'M' ? 'midi' : p.label === 'L' ? 'light' : 'event'}
              style={{ left: `${p.position * 100}%` }}
              title={`${p.label === 'M' ? 'MIDI' : p.label === 'L' ? 'Light' : 'Event'}: Cue`}
            >
              {p.label}
            </div>
          ))}
      </div>

      {/* Automation lane */}
      <div className="tl-auto-lane">
        <svg
          width="100%"
          height="100%"
          preserveAspectRatio="none"
          style={{ position: 'absolute', inset: 0 }}
        >
          {automationPoints.length > 1 && (
            <polyline
              points={automationPoints.map(p => `${p.position * 100}%,${(1 - p.value) * 100}%`).join(' ')}
              fill="none"
              stroke="#f5a623"
              strokeWidth="1"
              strokeDasharray="3,2"
              opacity="0.5"
              vectorEffect="non-scaling-stroke"
            />
          )}
          {automationPoints.map(p => (
            <circle
              key={p.id}
              cx={`${p.position * 100}%`}
              cy={`${(1 - p.value) * 100}%`}
              r="3"
              fill={p.color}
              opacity="0.7"
            />
          ))}
        </svg>
      </div>

      {/* Waveform area */}
      <div className="tl-waveform" ref={waveformRef} onClick={handleWaveformClick}>
        {/* Progress fill */}
        <div className="tl-progress" style={{ width: `${progress * 100}%` }} />

        {/* Waveform SVG placeholder */}
        <svg
          className="tl-wave-svg"
          preserveAspectRatio="none"
          viewBox="0 0 1200 60"
          style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.9 }}
        >
          <defs>
            <linearGradient id="wfGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#4a90f7" stopOpacity="0.6" />
              <stop offset="45%" stopColor="#4a90f7" stopOpacity="0.3" />
              <stop offset="55%" stopColor="#4a90f7" stopOpacity="0.3" />
              <stop offset="100%" stopColor="#4a90f7" stopOpacity="0.6" />
            </linearGradient>
          </defs>
          {/* Generate fake waveform bars */}
          {Array.from({ length: 200 }, (_, i) => {
            const x = i * 6
            const h = 8 + Math.sin(i * 0.3) * 12 + Math.cos(i * 0.17) * 8
            return (
              <rect
                key={i}
                x={x}
                y={30 - h / 2}
                width="4"
                height={h}
                fill="url(#wfGrad)"
                rx="1"
              />
            )
          })}
        </svg>

        {/* Playhead */}
        <div className="tl-playhead" style={{ left: `${progress * 100}%` }} />
      </div>

      {/* Toolbar */}
      <div className="tl-toolbar">
        <button className="tl-tool-btn active" data-tool="sections">Secciones</button>
        <button className="tl-tool-btn" data-tool="markers">Marcadores</button>
        <button className="tl-tool-btn" data-tool="cues">Cues</button>
        <div className="tl-tool-sep" />
        <button className="tl-tool-btn" data-tool="loop">↻ Loop</button>
        <button className="tl-tool-btn" data-tool="snap">⊞ Snap</button>
        <div className="tl-tool-sep" />
        <button className="tl-tool-btn" data-tool="zoom-in">+ Zoom</button>
        <button className="tl-tool-btn" data-tool="zoom-out">− Zoom</button>
        <div style={{ flex: 1 }} />
        <button className="tl-tool-btn" data-tool="import-mt" onClick={onImport}>
          ↓ Importar Multitrack
        </button>
      </div>
    </div>
  )
}
