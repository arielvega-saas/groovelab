import {
  Disc3, Drum, LayoutGrid, Repeat, Guitar, Music2,
  AudioLines, Piano, type LucideIcon,
} from 'lucide-react'
import { useAppStore, type ToolId } from '@/stores/app-store'
import { cn } from '@/lib/cn'

interface NavItem {
  id: ToolId
  label: string
  icon: LucideIcon
  color: string
}

const NAV_ITEMS: NavItem[] = [
  { id: 'metronome', label: 'Metronome', icon: Disc3, color: 'text-gl-accent' },
  { id: 'drums', label: 'Drums', icon: Drum, color: 'text-gl-warm' },
  { id: 'sampler', label: 'Sampler', icon: LayoutGrid, color: 'text-gl-purple' },
  { id: 'looper', label: 'Looper', icon: Repeat, color: 'text-gl-green' },
  { id: 'tuner', label: 'Tuner', icon: AudioLines, color: 'text-gl-accent' },
  { id: 'pedalboard', label: 'Pedalboard', icon: Guitar, color: 'text-gl-warm' },
  { id: 'songlab', label: 'Song Lab', icon: Music2, color: 'text-gl-purple' },
  { id: 'piano', label: 'Piano', icon: Piano, color: 'text-gl-green' },
]

export function Sidebar() {
  const { activeTool, setActiveTool, sidebarOpen, toggleSidebar } = useAppStore()

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
        {/* Logo */}
        <div className="h-14 flex items-center justify-center border-b border-gl-border">
          <span className="font-mono text-gl-accent font-bold text-sm tracking-wider">GL</span>
        </div>

        {/* Nav items */}
        <nav className="flex-1 py-2 flex flex-col gap-1 px-2 overflow-y-auto">
          {NAV_ITEMS.map((item) => {
            const isActive = activeTool === item.id
            const Icon = item.icon
            return (
              <button
                key={item.id}
                onClick={() => { setActiveTool(item.id); if (sidebarOpen) toggleSidebar() }}
                className={cn(
                  'flex flex-col items-center gap-0.5 py-2.5 px-1 rounded-lg transition-all',
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
                  'text-[9px] font-medium leading-none',
                  isActive ? 'text-gl-text' : 'text-gl-dim'
                )}>
                  {item.label}
                </span>
              </button>
            )
          })}
        </nav>
      </aside>
    </>
  )
}
