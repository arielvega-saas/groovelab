/**
 * Dashboard — Home screen with status-aware module cards,
 * global transport bar, BPM display, and session info.
 */
import {
  Disc3, Drum, LayoutGrid, Repeat, Guitar, Music2,
  AudioLines, Piano, ListMusic, Play, Pause, Square,
  Activity, Clock, Zap, type LucideIcon,
} from 'lucide-react'
import { useAppStore, type ModuleId } from '@/stores/app-store'
import { cn } from '@/lib/cn'

/* ------------------------------------------------------------------ */
/*  Module card definitions                                            */
/* ------------------------------------------------------------------ */

interface ModuleCard {
  id: ModuleId
  label: string
  description: string
  icon: LucideIcon
  color: string        // tailwind text color
  glowClass: string    // CSS glow class
  accentHex: string    // raw hex for gradients
  category: 'rhythm' | 'instrument' | 'effects' | 'production'
}

const MODULE_CARDS: ModuleCard[] = [
  {
    id: 'metronome', label: 'Metronome', description: 'Tempo & click track',
    icon: Disc3, color: 'text-gl-accent', glowClass: 'glow-accent',
    accentHex: '#00E5FF', category: 'rhythm',
  },
  {
    id: 'drums', label: 'Drum Machine', description: '16-step sequencer',
    icon: Drum, color: 'text-gl-warm', glowClass: 'glow-warm',
    accentHex: '#FF9500', category: 'rhythm',
  },
  {
    id: 'sampler', label: 'Sampler Pads', description: 'Trigger samples & loops',
    icon: LayoutGrid, color: 'text-gl-purple', glowClass: 'glow-accent',
    accentHex: '#BF5AF2', category: 'instrument',
  },
  {
    id: 'looper', label: 'Looper', description: 'Multi-layer loop station',
    icon: Repeat, color: 'text-gl-green', glowClass: 'glow-green',
    accentHex: '#00FF11', category: 'production',
  },
  {
    id: 'tuner', label: 'Tuner', description: 'Chromatic instrument tuner',
    icon: AudioLines, color: 'text-gl-accent', glowClass: 'glow-accent',
    accentHex: '#00E5FF', category: 'instrument',
  },
  {
    id: 'pedalboard', label: 'Pedalboard', description: 'Effects & signal chain',
    icon: Guitar, color: 'text-gl-warm', glowClass: 'glow-warm',
    accentHex: '#FF9500', category: 'effects',
  },
  {
    id: 'songlab', label: 'Song Lab', description: 'Compose & arrange',
    icon: Music2, color: 'text-gl-purple', glowClass: 'glow-accent',
    accentHex: '#BF5AF2', category: 'production',
  },
  {
    id: 'piano', label: 'Piano', description: 'Virtual keyboard',
    icon: Piano, color: 'text-gl-green', glowClass: 'glow-green',
    accentHex: '#00FF11', category: 'instrument',
  },
  {
    id: 'multitracks', label: 'Multitracks', description: 'Multi-track player',
    icon: ListMusic, color: 'text-gl-accent', glowClass: 'glow-accent',
    accentHex: '#00E5FF', category: 'production',
  },
  {
    id: 'playback', label: 'Playback', description: 'Audio file player',
    icon: Play, color: 'text-gl-green', glowClass: 'glow-green',
    accentHex: '#00FF11', category: 'production',
  },
]

/* ------------------------------------------------------------------ */
/*  Helpers                                                            */
/* ------------------------------------------------------------------ */

function timeAgo(timestamp: number | null): string {
  if (!timestamp) return 'Never opened'
  const diff = Date.now() - timestamp
  const minutes = Math.floor(diff / 60_000)
  if (minutes < 1) return 'Just now'
  if (minutes < 60) return `${minutes}m ago`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  return `${days}d ago`
}

/* ------------------------------------------------------------------ */
/*  Sub-components                                                     */
/* ------------------------------------------------------------------ */

function TransportBar() {
  const bpm = useAppStore((s) => s.bpm)
  const setBpm = useAppStore((s) => s.setBpm)
  const isPlaying = useAppStore((s) => s.isPlaying)
  const setPlaying = useAppStore((s) => s.setPlaying)
  const timeSig = useAppStore((s) => s.timeSig)
  const lastSessionTime = useAppStore((s) => s.lastSessionTime)

  return (
    <div className="flex flex-wrap items-center gap-4 p-4 bg-gl-dark rounded-xl border border-gl-border neu-flat">
      {/* Play / Stop */}
      <div className="flex items-center gap-2">
        <button
          onClick={() => setPlaying(!isPlaying)}
          className={cn(
            'w-11 h-11 rounded-lg flex items-center justify-center transition-all',
            'border border-gl-border hover:border-gl-accent/50',
            isPlaying
              ? 'bg-gl-accent/20 text-gl-accent glow-accent'
              : 'bg-gl-surface text-gl-muted hover:text-gl-accent'
          )}
          aria-label={isPlaying ? 'Stop' : 'Play'}
        >
          {isPlaying ? <Pause size={20} /> : <Play size={20} className="ml-0.5" />}
        </button>
        <button
          onClick={() => setPlaying(false)}
          className="w-11 h-11 rounded-lg flex items-center justify-center bg-gl-surface text-gl-muted hover:text-gl-danger border border-gl-border hover:border-gl-danger/50 transition-all"
          aria-label="Stop"
        >
          <Square size={16} />
        </button>
      </div>

      {/* BPM */}
      <div className="flex items-center gap-3 px-4 py-2 bg-gl-panel rounded-lg border border-gl-border">
        <div className="flex flex-col">
          <span className="text-[10px] uppercase tracking-wider text-gl-dim font-semibold">Tempo</span>
          <div className="flex items-baseline gap-1">
            <span className="font-mono text-2xl font-bold text-gl-accent text-glow-accent">{bpm}</span>
            <span className="text-xs text-gl-muted">BPM</span>
          </div>
        </div>
        <div className="flex flex-col gap-1">
          <button
            onClick={() => setBpm(bpm + 1)}
            className="w-6 h-5 flex items-center justify-center rounded bg-gl-surface hover:bg-gl-elevated text-gl-muted hover:text-gl-text text-xs transition-colors"
            aria-label="Increase BPM"
          >
            +
          </button>
          <button
            onClick={() => setBpm(bpm - 1)}
            className="w-6 h-5 flex items-center justify-center rounded bg-gl-surface hover:bg-gl-elevated text-gl-muted hover:text-gl-text text-xs transition-colors"
            aria-label="Decrease BPM"
          >
            -
          </button>
        </div>
      </div>

      {/* Time Signature */}
      <div className="flex flex-col px-3 py-2 bg-gl-panel rounded-lg border border-gl-border">
        <span className="text-[10px] uppercase tracking-wider text-gl-dim font-semibold">Time Sig</span>
        <span className="font-mono text-lg font-bold text-gl-text">{timeSig[0]}/{timeSig[1]}</span>
      </div>

      {/* Spacer */}
      <div className="flex-1" />

      {/* Session info */}
      <div className="flex items-center gap-2 text-gl-muted text-sm">
        <Clock size={14} />
        <span>Last session: {timeAgo(lastSessionTime)}</span>
      </div>

      {/* Playing indicator */}
      {isPlaying && (
        <div className="flex items-center gap-1.5 px-3 py-1.5 bg-gl-accent/10 rounded-full border border-gl-accent/30">
          <div className="w-2 h-2 rounded-full bg-gl-accent animate-led-pulse" />
          <span className="text-xs font-medium text-gl-accent">PLAYING</span>
        </div>
      )}
    </div>
  )
}

function ModuleCardComponent({ card }: { card: ModuleCard }) {
  const setActiveTool = useAppStore((s) => s.setActiveTool)
  const moduleStatus = useAppStore((s) => s.moduleStatus)
  const isPlaying = useAppStore((s) => s.isPlaying)

  const status = moduleStatus[card.id]
  const hasBeenUsed = status && status.lastVisited !== null
  const isRecentlyUsed = status?.lastVisited != null && (Date.now() - status.lastVisited) < 3_600_000 // 1h
  const Icon = card.icon

  return (
    <button
      role="listitem"
      onClick={() => setActiveTool(card.id)}
      className={cn(
        'group relative flex flex-col p-4 rounded-xl border transition-all duration-200',
        'hover:scale-[1.02] active:scale-[0.98]',
        'bg-gl-panel hover:bg-gl-surface',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-gl-accent/50 focus-visible:ring-offset-2 focus-visible:ring-offset-gl-deepest',
        isRecentlyUsed
          ? 'border-gl-border/80 hover:border-opacity-60'
          : 'border-gl-border/40 hover:border-gl-border',
      )}
      style={{
        borderColor: isRecentlyUsed ? `${card.accentHex}40` : undefined,
      }}
    >
      {/* Accent glow overlay for recently used */}
      {isRecentlyUsed && (
        <div
          className="absolute inset-0 rounded-xl opacity-[0.06] pointer-events-none"
          style={{ background: `radial-gradient(ellipse at top left, ${card.accentHex}, transparent 70%)` }}
        />
      )}

      {/* Header row: icon + status */}
      <div className="flex items-start justify-between mb-3">
        <div
          className={cn(
            'w-11 h-11 rounded-lg flex items-center justify-center transition-all',
            'bg-gl-surface group-hover:bg-gl-elevated',
          )}
          style={{
            boxShadow: isRecentlyUsed ? `0 0 12px ${card.accentHex}30` : undefined,
          }}
        >
          <Icon size={22} className={cn('transition-colors', card.color)} />
        </div>

        {/* Status indicator */}
        <div className="flex items-center gap-1.5">
          {isPlaying && card.id === 'metronome' && (
            <div className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-gl-accent/15">
              <Activity size={10} className="text-gl-accent animate-pulse" />
              <span className="text-[9px] font-semibold text-gl-accent uppercase">Live</span>
            </div>
          )}
          {hasBeenUsed ? (
            <div
              className="w-2 h-2 rounded-full"
              style={{
                backgroundColor: isRecentlyUsed ? card.accentHex : '#505050',
                boxShadow: isRecentlyUsed ? `0 0 6px ${card.accentHex}60` : undefined,
              }}
            />
          ) : (
            <div className="w-2 h-2 rounded-full bg-gl-border" />
          )}
        </div>
      </div>

      {/* Label */}
      <h3 className="text-sm font-semibold text-gl-text text-left mb-0.5">{card.label}</h3>
      <p className="text-xs text-gl-muted text-left mb-3">{card.description}</p>

      {/* Footer: last used + visit count */}
      <div className="mt-auto flex items-center justify-between">
        <span className="text-[10px] text-gl-dim">
          {hasBeenUsed ? timeAgo(status.lastVisited) : 'Not yet explored'}
        </span>
        {hasBeenUsed && (
          <div className="flex items-center gap-1 text-[10px] text-gl-dim">
            <Zap size={9} />
            <span>{status.visitCount}</span>
          </div>
        )}
      </div>

      {/* Bottom accent bar */}
      <div
        className={cn(
          'absolute bottom-0 left-3 right-3 h-[2px] rounded-full transition-opacity',
          isRecentlyUsed ? 'opacity-60' : 'opacity-0 group-hover:opacity-30',
        )}
        style={{ backgroundColor: card.accentHex }}
      />
    </button>
  )
}

/* ------------------------------------------------------------------ */
/*  Dashboard                                                          */
/* ------------------------------------------------------------------ */

export default function Dashboard() {
  const moduleStatus = useAppStore((s) => s.moduleStatus)

  // Stats for the header
  const usedModules = Object.values(moduleStatus).filter((s) => s.lastVisited !== null).length
  const totalVisits = Object.values(moduleStatus).reduce((sum, s) => sum + s.visitCount, 0)

  return (
    <div className="max-w-6xl mx-auto space-y-6 animate-fade-in">
      {/* Welcome header */}
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gl-text tracking-tight">
            Groove<span className="text-gl-accent">Lab</span>
          </h1>
          <p className="text-sm text-gl-muted mt-1">Your professional live rig — all modules at a glance</p>
        </div>
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2 px-3 py-1.5 bg-gl-panel rounded-lg border border-gl-border">
            <div className="w-1.5 h-1.5 rounded-full bg-gl-green" />
            <span className="text-xs text-gl-muted">
              <span className="font-mono text-gl-text">{usedModules}</span>/10 modules explored
            </span>
          </div>
          {totalVisits > 0 && (
            <div className="flex items-center gap-2 px-3 py-1.5 bg-gl-panel rounded-lg border border-gl-border">
              <Zap size={12} className="text-gl-accent" />
              <span className="text-xs text-gl-muted">
                <span className="font-mono text-gl-text">{totalVisits}</span> total opens
              </span>
            </div>
          )}
        </div>
      </div>

      {/* Global transport bar */}
      <TransportBar />

      {/* Module cards grid */}
      <div>
        <div className="flex items-center gap-2 mb-3">
          <h2 className="text-sm font-semibold text-gl-muted uppercase tracking-wider">Modules</h2>
          <div className="flex-1 h-px bg-gl-border/50" />
        </div>
        <div className="grid grid-cols-1 xs:grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3 module-grid" role="list" aria-label="Available modules">
          {MODULE_CARDS.map((card) => (
            <ModuleCardComponent key={card.id} card={card} />
          ))}
        </div>
      </div>

      {/* Quick tips / status footer */}
      <div className="flex flex-wrap items-center gap-3 px-4 py-3 bg-gl-dark/50 rounded-lg border border-gl-border/30 text-xs text-gl-dim">
        <span className="flex items-center gap-1.5">
          <div className="w-2 h-2 rounded-full bg-gl-accent" style={{ boxShadow: '0 0 6px #00E5FF60' }} />
          Recently active
        </span>
        <span className="flex items-center gap-1.5">
          <div className="w-2 h-2 rounded-full bg-[#505050]" />
          Previously used
        </span>
        <span className="flex items-center gap-1.5">
          <div className="w-2 h-2 rounded-full bg-gl-border" />
          Not explored
        </span>
      </div>
    </div>
  )
}
