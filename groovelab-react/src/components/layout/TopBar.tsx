import { useEffect, useCallback } from 'react'
import { Menu, Volume2, Home, VolumeX } from 'lucide-react'
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
  const { activeTool, setActiveTool, toggleSidebar, bpm, isPlaying, setPlaying, masterVolume, setMasterVolume } = useAppStore()

  // Keyboard shortcuts
  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    // Space: toggle play (only when not in an input)
    if (e.code === 'Space' && !(e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement)) {
      e.preventDefault()
      setPlaying(!isPlaying)
    }
    // Escape: go to dashboard
    if (e.code === 'Escape' && activeTool !== 'dashboard') {
      setActiveTool('dashboard')
    }
  }, [isPlaying, setPlaying, activeTool, setActiveTool])

  useEffect(() => {
    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [handleKeyDown])

  const volumePercent = Math.round(masterVolume * 100)

  return (
    <header className="h-14 bg-gl-dark border-b border-gl-border flex items-center px-2 sm:px-4 gap-2 sm:gap-4 shrink-0" role="banner">
      {/* Mobile menu */}
      <button
        onClick={toggleSidebar}
        className="lg:hidden p-2 hover:bg-gl-surface rounded-lg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-gl-accent/50"
        aria-label="Toggle navigation menu"
      >
        <Menu size={20} className="text-gl-muted" />
      </button>

      {/* Home button (when not on dashboard) */}
      {activeTool !== 'dashboard' && (
        <button
          onClick={() => setActiveTool('dashboard')}
          className="hidden lg:flex p-2 hover:bg-gl-surface rounded-lg transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-gl-accent/50"
          aria-label="Back to Dashboard (Esc)"
          title="Back to Dashboard (Esc)"
        >
          <Home size={18} className="text-gl-muted hover:text-gl-accent transition-colors" />
        </button>
      )}

      {/* Title */}
      <div className="flex items-center gap-2 sm:gap-3 flex-1 min-w-0">
        <h1 className="font-mono text-gl-accent font-bold text-base tracking-wider hidden sm:block shrink-0">
          GROOVELAB
        </h1>
        <span className="text-gl-muted text-sm truncate">{TOOL_LABELS[activeTool] ?? activeTool}</span>
      </div>

      {/* BPM display */}
      <div className="flex items-center gap-1.5 sm:gap-2 shrink-0" aria-live="polite">
        <span className={cn(
          'font-mono text-sm tabular-nums',
          isPlaying ? 'text-gl-accent text-glow-accent' : 'text-gl-accent'
        )}>
          {bpm} <span className="text-xs text-gl-muted hidden xs:inline">BPM</span>
        </span>
        {isPlaying && (
          <div className="w-2 h-2 rounded-full bg-gl-accent animate-led-pulse" aria-label="Playing" />
        )}
      </div>

      {/* Master volume */}
      <div className="flex items-center gap-1.5 sm:gap-2 shrink-0">
        {masterVolume === 0 ? (
          <VolumeX size={16} className="text-gl-danger" />
        ) : (
          <Volume2 size={16} className="text-gl-muted" />
        )}
        <input
          type="range"
          min={0}
          max={1}
          step={0.01}
          value={masterVolume}
          onChange={(e) => setMasterVolume(Number(e.target.value))}
          className="w-16 sm:w-20 accent-gl-accent"
          aria-label={`Master volume: ${volumePercent}%`}
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={volumePercent}
        />
      </div>
    </header>
  )
}
