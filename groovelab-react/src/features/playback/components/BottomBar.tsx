/**
 * BottomBar — Combined tab bar + status matching HTML source gl-bottombar
 */
import type { BottomTab } from '../types'

interface BottomBarProps {
  activeTab: BottomTab
  onTabChange: (tab: BottomTab) => void
  bufferSize: number
  sampleRate: number
  latencyMs: number
}

interface TabDef {
  id: BottomTab
  label: string
  badge?: number
  icon: React.ReactNode
}

const TABS: TabDef[] = [
  {
    id: 'repertorio',
    label: 'Repertorio',
    icon: <svg viewBox="0 0 12 12"><path d="M1 2h10v8H1z M3 4h6M3 6h4" fill="none" stroke="currentColor" strokeWidth="1" /></svg>,
  },
  {
    id: 'midi-cues',
    label: 'MIDI Cues',
    badge: 6,
    icon: <svg viewBox="0 0 12 12"><circle cx="4" cy="8" r="2" fill="currentColor" /><circle cx="8" cy="8" r="2" fill="currentColor" /><path d="M6 2v6M10 2v6" stroke="currentColor" strokeWidth="1" fill="none" /></svg>,
  },
  {
    id: 'automatizacion',
    label: 'Automatización',
    icon: <svg viewBox="0 0 12 12"><polyline points="1,9 4,4 7,7 11,2" fill="none" stroke="currentColor" strokeWidth="1.2" /></svg>,
  },
  {
    id: 'midi-map',
    label: 'MIDI Map',
    icon: <svg viewBox="0 0 12 12"><path d="M2 3h8v6H2z M5 6h2" fill="none" stroke="currentColor" strokeWidth="1" /></svg>,
  },
  {
    id: 'tempo',
    label: 'Tempo',
    icon: <svg viewBox="0 0 12 12"><path d="M6 1v10M3 4l3-3 3 3" fill="none" stroke="currentColor" strokeWidth="1.2" /></svg>,
  },
  {
    id: 'routing',
    label: 'Routing',
    icon: <svg viewBox="0 0 12 12"><path d="M2 3h3l2 6h3M2 9h3l2-6h3" fill="none" stroke="currentColor" strokeWidth="1" /></svg>,
  },
]

export function BottomBar({
  activeTab,
  onTabChange,
  bufferSize,
  sampleRate,
  latencyMs,
}: BottomBarProps) {
  const sampleRateKHz = (sampleRate / 1000).toFixed(1)

  return (
    <div className="gl-bottombar">
      {TABS.map(tab => (
        <button
          key={tab.id}
          className={`bb-tab${activeTab === tab.id ? ' active' : ''}`}
          onClick={() => onTabChange(tab.id)}
        >
          {tab.icon}
          {tab.label}
          {tab.badge !== undefined && (
            <span className="bb-badge">{tab.badge}</span>
          )}
        </button>
      ))}

      <div className="bb-spacer" />

      <span className="bb-status">
        Buffer: {bufferSize} · {sampleRateKHz}kHz · Latencia: {latencyMs}ms
      </span>
    </div>
  )
}
