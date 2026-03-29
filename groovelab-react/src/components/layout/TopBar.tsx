import { Menu, Volume2 } from 'lucide-react'
import { useAppStore } from '@/stores/app-store'

export function TopBar() {
  const { activeTool, toggleSidebar, bpm, masterVolume, setMasterVolume } = useAppStore()

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

      {/* Title */}
      <div className="flex items-center gap-3 flex-1">
        <h1 className="font-mono text-gl-accent font-bold text-base tracking-wider hidden sm:block">
          GROOVELAB
        </h1>
        <span className="text-gl-muted text-sm capitalize">{activeTool}</span>
      </div>

      {/* BPM display */}
      <div className="flex items-center gap-2">
        <span className="font-mono text-gl-accent text-sm">{bpm} BPM</span>
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
