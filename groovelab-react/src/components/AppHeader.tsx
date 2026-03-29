import { cn } from '@/lib/utils'
import { LED } from '@/components/ui/LED'
import { useAppStore } from '@/stores/app-store'

type ToolId = 'metronome' | 'drums' | 'sampler' | 'looper' | 'tuner' | 'pedalboard' | 'songlab' | 'piano'

const NAV_TABS: { id: ToolId; icon: string; label: string }[] = [
  { id: 'metronome',  icon: '♩',  label: 'METRO'    },
  { id: 'drums',      icon: '◈',  label: 'DRUMS'    },
  { id: 'sampler',    icon: '▦',  label: 'PADS'     },
  { id: 'looper',     icon: '⟳',  label: 'LOOPER'   },
  { id: 'tuner',      icon: '◎',  label: 'TUNER'    },
  { id: 'pedalboard', icon: '◉',  label: 'PEDALES'  },
  { id: 'songlab',    icon: '♪',  label: 'SONG LAB' },
  { id: 'piano',      icon: '🎹', label: 'TECLADO'  },
]

export function AppHeader() {
  const { activeTool, setActiveTool, bpm, isPlaying } = useAppStore()

  return (
    <header className="sticky top-0 z-50 flex flex-col bg-gradient-to-b from-studio-800 to-studio-850 border-b border-studio-600/40 shadow-[inset_0_1px_0_rgba(255,255,255,0.06),0_2px_12px_rgba(0,0,0,0.6)]">
      {/* Top row */}
      <div className="flex items-center justify-between px-4 py-2 border-b border-studio-700/40">
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-accent animate-led-pulse shadow-[0_0_8px_rgba(4,197,247,0.6)]" />
          <span className="font-display text-base font-bold tracking-widest text-accent drop-shadow-[0_0_8px_rgba(4,197,247,0.5)]">
            GROOVELAB
          </span>
        </div>
        <div className="flex items-center gap-3">
          <LED color="green" state={isPlaying ? 'pulse' : 'off'} size="sm" />
          <div className="flex items-center gap-1.5 bg-studio-700/50 border border-studio-600/30 rounded px-2 py-0.5">
            <span className="numeric text-xs text-accent">{bpm}</span>
            <span className="hw-label">BPM</span>
          </div>
        </div>
      </div>

      {/* Nav tabs */}
      <nav className="flex overflow-x-auto" style={{ scrollbarWidth: 'none' }}>
        {NAV_TABS.map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTool(tab.id)}
            className={cn(
              'flex-shrink-0 min-w-[56px] flex flex-col items-center gap-0.5',
              'py-2 px-2 transition-all duration-150 no-select',
              'border-b-2',
              activeTool === tab.id
                ? 'text-accent border-accent'
                : 'text-studio-400 border-transparent hover:text-studio-200',
            )}
          >
            <span className="text-sm">{tab.icon}</span>
            <span className="hw-label text-[8px]">{tab.label}</span>
          </button>
        ))}
      </nav>
    </header>
  )
}
