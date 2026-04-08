import {
  Disc3, Drum, LayoutGrid, Repeat, Guitar, Music2,
  AudioLines, Piano, ListMusic, Play, Home, type LucideIcon,
} from 'lucide-react'
import { useAppStore, type ModuleId } from '@/stores/app-store'
import { cn } from '@/lib/cn'

interface NavItem {
  id: ModuleId
  label: string
  icon: LucideIcon
  color: string
  accentHex: string
}

const NAV_ITEMS: NavItem[] = [
  { id: 'metronome', label: 'Metronome', icon: Disc3, color: 'text-gl-accent', accentHex: '#00E5FF' },
  { id: 'drums', label: 'Drums', icon: Drum, color: 'text-gl-warm', accentHex: '#FF9500' },
  { id: 'sampler', label: 'Sampler', icon: LayoutGrid, color: 'text-gl-purple', accentHex: '#BF5AF2' },
  { id: 'looper', label: 'Looper', icon: Repeat, color: 'text-gl-green', accentHex: '#00FF11' },
  { id: 'tuner', label: 'Tuner', icon: AudioLines, color: 'text-gl-accent', accentHex: '#00E5FF' },
  { id: 'pedalboard', label: 'Pedalboard', icon: Guitar, color: 'text-gl-warm', accentHex: '#FF9500' },
  { id: 'songlab', label: 'Song Lab', icon: Music2, color: 'text-gl-purple', accentHex: '#BF5AF2' },
  { id: 'piano', label: 'Piano', icon: Piano, color: 'text-gl-green', accentHex: '#00FF11' },
  { id: 'multitracks', label: 'Multitracks', icon: ListMusic, color: 'text-gl-accent', accentHex: '#00E5FF' },
  { id: 'playback', label: 'Playback', icon: Play, color: 'text-gl-green', accentHex: '#00FF11' },
]

export function Sidebar() {
  const { activeTool, setActiveTool, sidebarOpen, toggleSidebar, moduleStatus } = useAppStore()

  return (
    <>
      {/* Mobile overlay */}
      {sidebarOpen && (
        <div className="fixed inset-0 bg-black/60 z-40 lg:hidden" onClick={toggleSidebar} />
      )}

      {/* Sidebar */}
      <aside
        className={cn(
          'fixed top-0 left-0 h-full z-50 bg-gl-dark border-r border-gl-border flex flex-col',
          'transition-transform duration-200 ease-out',
          'w-[72px] lg:w-[72px]',
          sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        )}
      >
        {/* Logo — clickable to go Home */}
        <button
          onClick={() => { setActiveTool('dashboard'); if (sidebarOpen) toggleSidebar() }}
          className={cn(
            'h-14 flex items-center justify-center border-b border-gl-border transition-colors',
            'hover:bg-gl-surface',
            activeTool === 'dashboard' && 'bg-gl-surface',
          )}
          aria-label="Dashboard"
          title="Dashboard"
        >
          {activeTool === 'dashboard' ? (
            <Home size={20} className="text-gl-accent" />
          ) : (
            <span className="font-mono text-gl-accent font-bold text-sm tracking-wider">GL</span>
          )}
        </button>

        {/* Nav items */}
        <nav className="flex-1 py-2 flex flex-col gap-1 px-2 overflow-y-auto">
          {NAV_ITEMS.map((item) => {
            const isActive = activeTool === item.id
            const Icon = item.icon
            const status = moduleStatus[item.id]
            const hasBeenUsed = status?.lastVisited !== null
            const isRecentlyUsed = status?.lastVisited != null && (Date.now() - status.lastVisited) < 3_600_000

            return (
              <button
                key={item.id}
                onClick={() => { setActiveTool(item.id); if (sidebarOpen) toggleSidebar() }}
                className={cn(
                  'relative flex flex-col items-center gap-0.5 py-2.5 px-1 rounded-lg transition-all',
                  'hover:bg-gl-surface active:scale-95',
                  isActive && 'bg-gl-surface neu-inset',
                )}
                aria-label={item.label}
                title={item.label}
              >
                <Icon
                  size={22}
                  className={cn(
                    'transition-colors',
                    isActive ? item.color : 'text-gl-muted'
                  )}
                />
                <span className={cn(
                  'text-[9px] font-medium leading-none truncate w-full text-center',
                  isActive ? 'text-gl-text' : 'text-gl-dim'
                )}>
                  {item.label}
                </span>

                {/* Status dot — top right corner */}
                {!isActive && hasBeenUsed && (
                  <div
                    className="absolute top-1.5 right-1.5 w-1.5 h-1.5 rounded-full"
                    style={{
                      backgroundColor: isRecentlyUsed ? item.accentHex : '#505050',
                      boxShadow: isRecentlyUsed ? `0 0 4px ${item.accentHex}60` : undefined,
                    }}
                  />
                )}

                {/* Active bar — left edge */}
                {isActive && (
                  <div
                    className="absolute left-0 top-2 bottom-2 w-[2px] rounded-full"
                    style={{ backgroundColor: item.accentHex }}
                  />
                )}
              </button>
            )
          })}
        </nav>
      </aside>
    </>
  )
}
