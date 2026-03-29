import { create } from 'zustand'

export interface PistaMultitrack {
  id: string
  nombre: string
  color: string
  volumen: number
  muted: boolean
  soloed: boolean
  origen: 'base' | 'click' | 'guia' | 'custom'
  audioBuffer?: AudioBuffer
  waveformData?: Float32Array
}

export interface Marcador {
  id: string
  posicion: number
  etiqueta: string
  color: string
}

export interface Cancion {
  id: string
  nombre: string
  tonalidad: string
  bpm: number
  duracion: number
  emoji?: string
  marcadores: Marcador[]
}

export interface Repertorio {
  id: string
  nombre: string
  fecha: string
  canciones: Cancion[]
  updatedAt: number
}

interface MultitrackState {
  // Playback
  currentTime: number
  duration: number

  // Tracks
  pistaBase: PistaMultitrack | null
  pistasMultitrack: PistaMultitrack[]

  // Song/Setlist
  cancionActiva: Cancion | null
  repertorio: Repertorio | null

  // Actions
  setCurrentTime: (t: number) => void
  setDuration: (d: number) => void
  setPistaBase: (p: PistaMultitrack) => void
  addPistaMultitrack: (p: PistaMultitrack) => void
  removePistaMultitrack: (id: string) => void
  setFader: (id: string, val: number) => void
  toggleMute: (id: string) => void
  toggleSolo: (id: string) => void
  setRepertorio: (r: Repertorio) => void
  setCancionActiva: (c: Cancion) => void
}

export const useMultitrackStore = create<MultitrackState>((set) => ({
  currentTime: 0,
  duration: 0,
  pistaBase: null,
  pistasMultitrack: [],
  cancionActiva: null,
  repertorio: null,

  setCurrentTime: (t) => set({ currentTime: t }),
  setDuration: (d) => set({ duration: d }),
  setPistaBase: (p) => set({ pistaBase: p }),
  addPistaMultitrack: (p) => set((s) => ({ pistasMultitrack: [...s.pistasMultitrack, p] })),
  removePistaMultitrack: (id) => set((s) => ({ pistasMultitrack: s.pistasMultitrack.filter(p => p.id !== id) })),
  setFader: (id, val) => set((s) => {
    if (s.pistaBase?.id === id) return { pistaBase: { ...s.pistaBase, volumen: val } }
    return { pistasMultitrack: s.pistasMultitrack.map(p => p.id === id ? { ...p, volumen: val } : p) }
  }),
  toggleMute: (id) => set((s) => {
    if (s.pistaBase?.id === id) return { pistaBase: { ...s.pistaBase, muted: !s.pistaBase.muted } }
    return { pistasMultitrack: s.pistasMultitrack.map(p => p.id === id ? { ...p, muted: !p.muted } : p) }
  }),
  toggleSolo: (id) => set((s) => {
    if (s.pistaBase?.id === id) return { pistaBase: { ...s.pistaBase, soloed: !s.pistaBase.soloed } }
    return { pistasMultitrack: s.pistasMultitrack.map(p => p.id === id ? { ...p, soloed: !p.soloed } : p) }
  }),
  setRepertorio: (r) => set({ repertorio: r }),
  setCancionActiva: (c) => set({ cancionActiva: c }),
}))
