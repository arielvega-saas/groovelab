import { Menu, Volume2, Home } from 'lucide-react'
import { useAppStore } from '@/stores/app-store'
import { cn } from '@/lib/cn'

const TOOL_LABELS: Record<string, string> = {
  dashboard: 'Dashboard',
  metronome: 'Metronome',
  drums: 'Drum Machine',
  sampler: 'Sampler Pads',
  looper: 'Looper',
  tuner: 'Tuner',
  pedalboard: 'Pedalboard',
  songlab: 'Song Lab',
  piano: 'Piano',
  multitracks: 'Multitracks',
  playback: 'Playback',
}

export function TopBar() {
  const { activeTool, setActiveTool, toggleSidebar, bpm, isPlaying, masterVolume, setMasterVolume } = useAppStore()

  return (
    <header className="h-14 bg-gl-dark border-b border-gl-border flex items-center px-4 gap-4 shrink-0">
      {/* Mobile menu */}
      <button
        onClick={toggleSidebar}
        className="lg:hidden p-2 hover:bg-gl-surface rounded-lg"
        aria-label="Toggle menu"
      >
        <Menu size={20} className="text-gl-muted" />
      </button>

      {/* Home button (when not on dashboard) */}
      {activeTool !== 'dashboard' && (
        <button
          onClick={() => setActiveTool('dashboard')}
          className="hidden lg:flex p-2 hover:bg-gl-surface rounded-lg transition-colors"
          aria-label="Back to Dashboard"
          title="Back to Dashboard"
        >
          <Home size={18} className="text-gl-muted hover:text-gl-accent transition-colors" />
        </button>
      )}

      {/* Title */}
      <div className="flex items-center gap-3 flex-1">
        <h1 className="font-mono text-gl-accent font-bold text-base tracking-wider hidden sm:block">
          GROOVELAB
        </h1>
        <span className="text-gl-muted text-sm">{TOOL_LABELS[activeTool] ?? activeTool}</span>
      </div>

      {/* BPM display */}
      <div className="flex items-center gap-2">
        <span className={cn(
          'font-mono text-sm',
          isPlaying ? 'text-gl-accent text-glow-accent' : 'text-gl-accent'
        )}>
          {bpm} BPM
        </span>
        {isPlaying && (
          <div className="w-2 h-2 rounded-full bg-gl-accent animate-led-pulse" />
        )}
      </div>

      {/* Master volume */}
      <div className="flex items-center gap-2">
        <Volume2 size={16} className="text-gl-muted" />
        <input
          type="range"
          min={0}
          max={1}
          step={0.01}
          value={masterVolume}
          onChange={(e) => setMasterVolume(Number(e.target.value))}
          className="w-20 accent-gl-accent"
          aria-label="Master volume"
        />
      </div>
    </header>
  )
}
