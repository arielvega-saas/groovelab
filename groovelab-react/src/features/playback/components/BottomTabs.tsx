/**
 * BottomTabs — Tab bar at the bottom of the playback module
 *
 * Shows tabs: Repertorio, MIDI Cues, Automatizacion, MIDI Map, Tempo, Routing
 * with active state indicator and optional badges.
 */
import { cn } from '@/lib/cn'
import type { BottomTab } from '../types'
import { BOTTOM_TABS } from '../constants'

interface BottomTabsProps {
  activeTab: BottomTab
  onTabChange: (tab: BottomTab) => void
}

export function BottomTabs({ activeTab, onTabChange }: BottomTabsProps) {
  return (
    <div className="h-8 flex-shrink-0 bg-studio-800 border-t border-studio-600/40 flex overflow-x-auto [&::-webkit-scrollbar]:hidden">
      {BOTTOM_TABS.map((tab) => (
        <button
          key={tab.id}
          onClick={() => onTabChange(tab.id)}
          className={cn(
            'flex-shrink-0 px-3 text-[10px] font-medium border-b-2 whitespace-nowrap transition-all flex items-center gap-1.5',
            activeTab === tab.id
              ? 'text-accent border-accent'
              : 'text-studio-500 border-transparent hover:text-studio-300',
          )}
        >
          {/* Active dot indicator */}
          {activeTab === tab.id && (
            <div className="w-1.5 h-1.5 rounded-full bg-led-green" />
          )}
          {tab.label}
          {/* Badge */}
          {tab.badge !== undefined && (
            <span className={cn(
              'text-[8px] font-bold px-1 py-px rounded-full min-w-[14px] text-center',
              activeTab === tab.id
                ? 'bg-accent text-studio-900'
                : 'bg-info text-white',
            )}>
              {tab.badge}
            </span>
          )}
        </button>
      ))}
    </div>
  )
}
