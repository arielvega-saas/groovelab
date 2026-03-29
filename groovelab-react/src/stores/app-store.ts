/**
 * Global App Store — Zustand store for application-wide state
 */
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

export type ToolId =
  | 'metronome' | 'drums' | 'sampler' | 'looper'
  | 'tuner' | 'pedalboard' | 'songlab' | 'piano'
  | 'multitracks'

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
}

export const useAppStore = create<AppState>()(
  persist(
    (set) => ({
      activeTool: 'metronome',
      setActiveTool: (tool) => set({ activeTool: tool }),
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
    }),
    { name: 'groovelab-app', partialize: (s) => ({ bpm: s.bpm, timeSig: s.timeSig, masterVolume: s.masterVolume, activeTool: s.activeTool }) }
  )
)
