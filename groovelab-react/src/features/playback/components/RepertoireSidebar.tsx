/**
 * RepertoireSidebar — Left panel with song list, transitions, and navigation
 *
 * Matches the exact design: REPERTORIO header, song list with key/bpm/duration,
 * active song indicator, TRANSICION section with PAD/BED, PREV/NEXT buttons.
 */
import { cn } from '@/lib/cn'
import type { PlaybackRepertoire, TransitionType } from '../types'
import { formatTime, getTotalDuration } from '../constants'

interface RepertoireSidebarProps {
  repertoire: PlaybackRepertoire | null
  activeSongIndex: number
  isPlaying: boolean
  transitionType: TransitionType
  collapsed: boolean
  onSelectSong: (index: number) => void
  onPrev: () => void
  onNext: () => void
  onTransitionChange: (type: TransitionType) => void
  onToggleCollapse: () => void
  onOpenRepertoire: () => void
  onAddSong: () => void
}

export function RepertoireSidebar({
  repertoire,
  activeSongIndex,
  isPlaying,
  transitionType,
  collapsed,
  onSelectSong,
  onPrev,
  onNext,
  onTransitionChange,
  onOpenRepertoire,
  onAddSong,
}: RepertoireSidebarProps) {
  if (collapsed) return null

  const songs = repertoire?.songs ?? []
  const totalDuration = getTotalDuration(songs)

  return (
    <div className="w-[185px] flex-shrink-0 bg-studio-900 border-r border-studio-600/40 flex flex-col h-full select-none overflow-hidden">
      {/* Header */}
      <div className="px-3 pt-3 pb-1 flex-shrink-0">
        <div className="flex items-center justify-between mb-1">
          <span className="hw-label text-studio-400 tracking-[0.2em]">REPERTORIO</span>
        </div>
        <div className="flex items-center gap-1 text-[10px] text-studio-400">
          <span className="font-semibold text-studio-200">{repertoire?.name ?? 'Sin repertorio'}</span>
          <span className="text-studio-500">&middot;</span>
          <span>{songs.length} canciones</span>
          <div className="flex-1" />
          <button
            onClick={onAddSong}
            className="w-5 h-5 rounded bg-studio-700 border border-studio-600 flex items-center justify-center text-studio-400 hover:text-accent text-xs transition-colors"
          >
            +
          </button>
          <button
            onClick={onOpenRepertoire}
            className="w-5 h-5 rounded bg-studio-700 border border-studio-600 flex items-center justify-center text-studio-400 hover:text-studio-200 text-[10px] transition-colors"
          >
            &hellip;
          </button>
        </div>
        <div className="numeric text-[10px] text-studio-500 mt-0.5">
          {formatTime(totalDuration)}
        </div>
      </div>

      {/* Song list */}
      <div className="flex-1 overflow-y-auto overflow-x-hidden min-h-0 py-1">
        {songs.map((song, i) => {
          const isActive = i === activeSongIndex
          const isNext = i === activeSongIndex + 1
          return (
            <button
              key={song.id}
              onClick={() => onSelectSong(i)}
              className={cn(
                'w-full flex items-start gap-2 px-3 py-2 text-left transition-all border-l-2',
                isActive
                  ? 'bg-studio-800/60 border-led-green'
                  : 'border-transparent hover:bg-studio-800/30',
              )}
            >
              {/* Number */}
              <span className={cn(
                'numeric text-[11px] font-bold mt-0.5 flex-shrink-0 w-3',
                isActive ? 'text-led-green' : 'text-studio-500',
              )}>
                {i + 1}
              </span>

              {/* Song info */}
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-1.5">
                  {isActive && (
                    <div className={cn(
                      'w-2 h-2 rounded-full flex-shrink-0 bg-led-green',
                      isPlaying && 'animate-led-pulse',
                    )} />
                  )}
                  <span className={cn(
                    'text-[11px] font-semibold truncate',
                    isActive ? 'text-studio-100' : isNext ? 'text-led-green' : 'text-studio-300',
                  )}>
                    {song.name}
                  </span>
                </div>
                <div className="flex items-center gap-1.5 mt-0.5">
                  <span className={cn(
                    'text-[9px] font-bold px-1 py-px rounded',
                    isActive ? 'text-accent bg-accent/10' : 'text-studio-500 bg-studio-700/50',
                  )}>
                    {song.key}
                  </span>
                  <span className="numeric text-[9px] text-accent">
                    {song.bpm} bpm
                  </span>
                  <span className="numeric text-[9px] text-studio-500">
                    {formatTime(song.duration)}
                  </span>
                </div>
              </div>
            </button>
          )
        })}
      </div>

      {/* Transition section */}
      <div className="flex-shrink-0 border-t border-studio-600/40 px-3 py-2">
        <span className="hw-label text-studio-500 text-[8px] tracking-[0.2em] block mb-1.5">TRANSICION</span>
        <div className="flex gap-1.5 mb-2">
          <button
            onClick={() => onTransitionChange('pad')}
            className={cn(
              'flex-1 h-7 rounded-md border text-[9px] font-bold flex items-center justify-center gap-1 transition-all',
              transitionType === 'pad'
                ? 'bg-accent/10 border-accent text-accent'
                : 'bg-studio-800 border-studio-600 text-studio-400 hover:text-studio-200',
            )}
          >
            <svg width="10" height="10" viewBox="0 0 10 10" fill="currentColor" className="opacity-70">
              <path d="M5 0 L10 3 L10 7 L5 10 L0 7 L0 3Z" />
            </svg>
            PAD
          </button>
          <button
            onClick={() => onTransitionChange('bed')}
            className={cn(
              'flex-1 h-7 rounded-md border text-[9px] font-bold flex items-center justify-center gap-1 transition-all',
              transitionType === 'bed'
                ? 'bg-accent/10 border-accent text-accent'
                : 'bg-studio-800 border-studio-600 text-studio-400 hover:text-studio-200',
            )}
          >
            <svg width="10" height="8" viewBox="0 0 10 8" fill="currentColor" className="opacity-70">
              <rect x="0" y="4" width="10" height="4" rx="1" />
              <rect x="1" y="0" width="8" height="3" rx="1" />
            </svg>
            BED
          </button>
        </div>
        <div className="flex gap-1.5">
          <button
            onClick={onPrev}
            className="flex-1 h-7 rounded-md bg-studio-800 border border-studio-600 text-[9px] font-bold text-studio-300 hover:text-studio-100 flex items-center justify-center gap-0.5 transition-colors active:scale-95"
          >
            <span className="text-[8px]">&lsaquo;</span> PREV
          </button>
          <button
            onClick={onNext}
            className="flex-1 h-7 rounded-md bg-studio-800 border border-studio-600 text-[9px] font-bold text-studio-300 hover:text-studio-100 flex items-center justify-center gap-0.5 transition-colors active:scale-95"
          >
            NEXT <span className="text-[8px]">&rsaquo;</span>
          </button>
        </div>
      </div>
    </div>
  )
}
