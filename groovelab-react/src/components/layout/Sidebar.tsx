import { useState } from 'react'
import {
  Disc3, Drum, LayoutGrid, Repeat, Guitar, Music2,
  AudioLines, Piano, ListMusic, Play, Home, ChevronLeft,
  ChevronRight, type LucideIcon,
} from 'lucide-react'
import { useAppStore, type ModuleId } from '@/stores/app-store'
import { cn } from '@/lib/cn'

interface NavItem {
  id: ModuleId
  label: string
  icon: LucideIcon
  color: string
  accentHex: string
  shortLabel: string
}

const NAV_ITEMS: NavItem[] = [
  { id: 'metronome', label: 'Metronome', shortLabel: 'Metro', icon: Disc3, color: 'text-gl-accent', accentHex: '#00E5FF' },
  { id: 'drums', label: 'Drums', shortLabel: 'Drums', icon: Drum, color: 'text-gl-warm', accentHex: '#FF9500' },
  { id: 'sampler', label: 'Sampler', shortLabel: 'Sampl', icon: LayoutGrid, color: 'text-gl-purple', accentHex: '#BF5AF2' },
  { id: 'looper', label: 'Looper', shortLabel: 'Loop', icon: Repeat, color: 'text-gl-green', accentHex: '#00FF11' },
  { id: 'tuner', label: 'Tuner', shortLabel: 'Tuner', icon: AudioLines, color: 'text-gl-accent', accentHex: '#00E5FF' },
  { id: 'pedalboard', label: 'Pedalboard', shortLabel: 'Pedal', icon: Guitar, color: 'text-gl-warm', accentHex: '#FF9500' },
  { id: 'songlab', label: 'Song Lab', shortLabel: 'Song', icon: Music2, color: 'text-gl-purple', accentHex: '#BF5AF2' },
  { id: 'piano', label: 'Piano', shortLabel: 'Piano', icon: Piano, color: 'text-gl-green', accentHex: '#00FF11' },
  { id: 'multitracks', label: 'Multitracks', shortLabel: 'Multi', icon: ListMusic, color: 'text-gl-accent', accentHex: '#00E5FF' },
  { id: 'playback', label: 'Playback', shortLabel: 'Play', icon: Play, color: 'text-gl-green', accentHex: '#00FF11' },
]

export function Sidebar() {
  const { activeTool, setActiveTool, sidebarOpen, toggleSidebar, moduleStatus, isPlaying } = useAppStore()
  const [expanded, setExpanded] = useState(false)

  const sidebarWidth = expanded ? 'w-[180px]' : 'w-[72px]'

  return (
    <>
      {/* Mobile overlay */}
      {sidebarOpen && (
        <div className="fixed inset-0 bg-black/60 z-40 lg:hidden" onClick={toggleSidebar} />
      )}

      {/* Sidebar */}
      <aside
        onMouseEnter={() => setExpanded(true)}
        onMouseLeave={() => setExpanded(false)}
        className={cn(
          'fixed top-0 left-0 h-full z-50 bg-gl-dark border-r border-gl-border flex flex-col',
          'transition-all duration-200 ease-out',
          sidebarWidth,
          sidebarOpen ? 'translate-x-0 w-[220px]' : '-translate-x-full lg:translate-x-0'
        )}
      >
        {/* Logo — clickable to go Home */}
        <button
          onClick={() => { setActiveTool('dashboard'); if (sidebarOpen) toggleSidebar() }}
          className={cn(
            'h-14 flex items-center gap-3 border-b border-gl-border transition-colors shrink-0',
            'hover:bg-gl-surface',
            expanded || sidebarOpen ? 'px-4 justify-start' : 'justify-center',
            activeTool === 'dashboard' && 'bg-gl-surface',
          )}
          aria-label="Dashboard"
        >
          {activeTool === 'dashboard' ? (
            <Home size={20} className="text-gl-accent shrink-0" />
          ) : (
            <span className="font-mono text-gl-accent font-bold text-sm tracking-wider shrink-0">GL</span>
          )}
          {(expanded || sidebarOpen) && (
            <span className="text-sm font-semibold text-gl-text whitespace-nowrap overflow-hidden animate-fade-in">
              Groove<span className="text-gl-accent">Lab</span>
            </span>
          )}
        </button>

        {/* Nav items */}
        <nav className="flex-1 py-2 flex flex-col gap-0.5 px-1.5 overflow-y-auto" role="navigation" aria-label="Module navigation">
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
                  'group relative flex items-center gap-3 rounded-lg transition-all',
                  'hover:bg-gl-surface active:scale-[0.97]',
                  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-gl-accent/50 focus-visible:ring-offset-1 focus-visible:ring-offset-gl-dark',
                  expanded || sidebarOpen
                    ? 'px-3 py-2.5 justify-start'
                    : 'flex-col px-1 py-2.5 justify-center',
                  isActive && 'bg-gl-surface neu-inset',
                )}
                aria-label={item.label}
                aria-current={isActive ? 'page' : undefined}
                title={!expanded && !sidebarOpen ? item.label : undefined}
              >
                {/* Icon */}
                <div className="relative shrink-0">
                  <Icon
                    size={expanded || sidebarOpen ? 20 : 22}
                    className={cn(
                      'transition-colors',
                      isActive ? item.color : 'text-gl-muted group-hover:text-gl-text'
                    )}
                  />
                  {/* Status dot — top right of icon */}
                  {!isActive && hasBeenUsed && (
                    <div
                      className="absolute -top-0.5 -right-0.5 w-1.5 h-1.5 rounded-full"
                      style={{
                        backgroundColor: isRecentlyUsed ? item.accentHex : '#505050',
                        boxShadow: isRecentlyUsed ? `0 0 4px ${item.accentHex}60` : undefined,
                      }}
                    />
                  )}
                </div>

                {/* Label — collapsed: tiny text below icon, expanded: full text beside icon */}
                {expanded || sidebarOpen ? (
                  <span className={cn(
                    'text-sm font-medium whitespace-nowrap overflow-hidden',
                    isActive ? 'text-gl-text' : 'text-gl-muted group-hover:text-gl-text'
                  )}>
                    {item.label}
                  </span>
                ) : (
                  <span className={cn(
                    'text-[9px] font-medium leading-none text-center w-full',
                    isActive ? 'text-gl-text' : 'text-gl-dim'
                  )}>
                    {item.shortLabel}
                  </span>
                )}

                {/* Playing indicator for metronome */}
                {isActive && isPlaying && item.id === 'metronome' && (
                  <div
                    className={cn(
                      'w-1.5 h-1.5 rounded-full bg-gl-accent animate-led-pulse',
                      expanded || sidebarOpen ? 'ml-auto' : 'absolute top-1.5 right-1.5'
                    )}
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

        {/* Expand/collapse toggle — desktop only */}
        <button
          onClick={() => setExpanded((e) => !e)}
          className="hidden lg:flex items-center justify-center h-10 border-t border-gl-border text-gl-dim hover:text-gl-muted hover:bg-gl-surface transition-colors"
          aria-label={expanded ? 'Collapse sidebar' : 'Expand sidebar'}
        >
          {expanded ? <ChevronLeft size={16} /> : <ChevronRight size={16} />}
        </button>
      </aside>
    </>
  )
}
