/**
 * Global App Store — Zustand store for application-wide state
 */
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

export type ModuleId =
  | 'metronome' | 'drums' | 'sampler' | 'looper'
  | 'tuner' | 'pedalboard' | 'songlab' | 'piano'
  | 'multitracks' | 'playback'

export type ToolId = 'dashboard' | ModuleId

export interface ModuleStatus {
  lastVisited: number | null   // timestamp
  visitCount: number
}

type ModuleStatusMap = Record<ModuleId, ModuleStatus>

const MODULE_IDS: ModuleId[] = [
  'metronome', 'drums', 'sampler', 'looper',
  'tuner', 'pedalboard', 'songlab', 'piano',
  'multitracks', 'playback',
]

function defaultModuleStatus(): ModuleStatusMap {
  const map = {} as ModuleStatusMap
  for (const id of MODULE_IDS) {
    map[id] = { lastVisited: null, visitCount: 0 }
  }
  return map
}

interface AppState {
  activeTool: ToolId
  setActiveTool: (tool: ToolId) => void
  sidebarOpen: boolean
  toggleSidebar: () => void
  masterVolume: number
  setMasterVolume: (v: number) => void
  bpm: number
  setBpm: (bpm: number) => void
  isPlaying: boolean
  setPlaying: (p: boolean) => void
  timeSig: [number, number]
  setTimeSig: (ts: [number, number]) => void
  audioInitialized: boolean
  setAudioInitialized: (v: boolean) => void
  moduleStatus: ModuleStatusMap
  lastSessionTime: number | null
}

export const useAppStore = create<AppState>()(
  persist(
    (set) => ({
      activeTool: 'dashboard',
      setActiveTool: (tool) => set((s) => {
        const updates: Partial<AppState> = { activeTool: tool }
        if (tool !== 'dashboard') {
          const moduleStatus = { ...s.moduleStatus }
          moduleStatus[tool] = {
            lastVisited: Date.now(),
            visitCount: (moduleStatus[tool]?.visitCount ?? 0) + 1,
          }
          updates.moduleStatus = moduleStatus
          updates.lastSessionTime = Date.now()
        }
        return updates
      }),
      sidebarOpen: false,
      toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
      masterVolume: 0.8,
      setMasterVolume: (v) => set({ masterVolume: v }),
      bpm: 120,
      setBpm: (bpm) => set({ bpm: Math.max(20, Math.min(500, bpm)) }),
      isPlaying: false,
      setPlaying: (p) => set({ isPlaying: p }),
      timeSig: [4, 4],
      setTimeSig: (ts) => set({ timeSig: ts }),
      audioInitialized: false,
      setAudioInitialized: (v) => set({ audioInitialized: v }),
      moduleStatus: defaultModuleStatus(),
      lastSessionTime: null,
    }),
    {
      name: 'groovelab-app',
      partialize: (s) => ({
        bpm: s.bpm,
        timeSig: s.timeSig,
        masterVolume: s.masterVolume,
        activeTool: s.activeTool,
        moduleStatus: s.moduleStatus,
        lastSessionTime: s.lastSessionTime,
      }),
    }
  )
)
