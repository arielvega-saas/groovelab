/**
 * Playback Store — Zustand state for the Multitracks Live module
 *
 * Manages transport state, tracks, repertoire, mixer, mode selection,
 * and UI state. Persists mixer config and active session to localStorage.
 */
import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import type {
  PlaybackTrack,
  PlaybackSong,
  PlaybackRepertoire,
  PlaybackMode,
  TransitionType,
  BottomTab,
  MixSnapshot,
} from './types'
import { DEFAULT_TRACKS, DEMO_REPERTOIRE } from './constants'

interface PlaybackState {
  /* ── Transport ── */
  isPlaying: boolean
  currentTime: number
  duration: number

  /* ── Mode ── */
  mode: PlaybackMode

  /* ── Tracks ── */
  tracks: PlaybackTrack[]
  masterVolume: number    // 0–100

  /* ── Song / Repertoire ── */
  repertoire: PlaybackRepertoire | null
  activeSongIndex: number
  activeSong: PlaybackSong | null

  /* ── Transition ── */
  transitionType: TransitionType

  /* ── UI ── */
  activeTab: BottomTab
  visibleSequences: string[]
  sidebarCollapsed: boolean

  /* ── Audio engine readiness ── */
  engineReady: boolean
  loadingTrackId: string | null
  error: string | null

  /* ── Transport actions ── */
  setPlaying: (p: boolean) => void
  setCurrentTime: (t: number) => void
  setDuration: (d: number) => void

  /* ── Mode actions ── */
  setMode: (m: PlaybackMode) => void

  /* ── Track actions ── */
  setTracks: (tracks: PlaybackTrack[]) => void
  setFader: (id: string, val: number) => void
  toggleMute: (id: string) => void
  toggleSolo: (id: string) => void
  setPan: (id: string, val: number) => void
  setMasterVolume: (v: number) => void
  updateTrackBuffer: (id: string, buffer: AudioBuffer, waveform: Float32Array) => void

  /* ── Song / Repertoire actions ── */
  setRepertoire: (r: PlaybackRepertoire) => void
  setActiveSong: (index: number) => void
  nextSong: () => void
  prevSong: () => void

  /* ── Transition actions ── */
  setTransitionType: (t: TransitionType) => void

  /* ── UI actions ── */
  setActiveTab: (tab: BottomTab) => void
  setVisibleSequences: (seqs: string[]) => void
  toggleSequence: (name: string) => void
  toggleSidebar: () => void

  /* ── Engine actions ── */
  setEngineReady: (v: boolean) => void
  setLoadingTrack: (id: string | null) => void
  setError: (err: string | null) => void

  /* ── Mix snapshots ── */
  saveMixSnapshot: () => MixSnapshot
  loadMixSnapshot: (snap: MixSnapshot) => void

  /* ── Init ── */
  initDemo: () => void
}

export const usePlaybackStore = create<PlaybackState>()(
  persist(
    (set, get) => ({
      /* ── Defaults ── */
      isPlaying: false,
      currentTime: 0,
      duration: 0,
      mode: 'vivo',
      tracks: DEFAULT_TRACKS.map(t => ({ ...t })),
      masterVolume: 90,
      repertoire: null,
      activeSongIndex: 0,
      activeSong: null,
      transitionType: 'pad',
      activeTab: 'repertorio',
      visibleSequences: DEFAULT_TRACKS.map(t => t.name),
      sidebarCollapsed: false,
      engineReady: false,
      loadingTrackId: null,
      error: null,

      /* ── Transport ── */
      setPlaying: (p) => set({ isPlaying: p }),
      setCurrentTime: (t) => set({ currentTime: t }),
      setDuration: (d) => set({ duration: d }),

      /* ── Mode ── */
      setMode: (m) => set({ mode: m }),

      /* ── Tracks ── */
      setTracks: (tracks) => set({ tracks }),
      setFader: (id, val) => set((s) => ({
        tracks: s.tracks.map(t => t.id === id ? { ...t, volume: val } : t),
      })),
      toggleMute: (id) => set((s) => ({
        tracks: s.tracks.map(t => t.id === id ? { ...t, muted: !t.muted } : t),
      })),
      toggleSolo: (id) => set((s) => ({
        tracks: s.tracks.map(t => t.id === id ? { ...t, soloed: !t.soloed } : t),
      })),
      setPan: (id, val) => set((s) => ({
        tracks: s.tracks.map(t => t.id === id ? { ...t, pan: val } : t),
      })),
      setMasterVolume: (v) => set({ masterVolume: v }),
      updateTrackBuffer: (id, buffer, waveform) => set((s) => ({
        tracks: s.tracks.map(t =>
          t.id === id ? { ...t, audioBuffer: buffer, waveformData: waveform } : t
        ),
      })),

      /* ── Song / Repertoire ── */
      setRepertoire: (r) => set({
        repertoire: r,
        activeSongIndex: 0,
        activeSong: r.songs[0] ?? null,
        duration: r.songs[0]?.duration ?? 0,
      }),
      setActiveSong: (index) => {
        const rep = get().repertoire
        if (!rep || index < 0 || index >= rep.songs.length) return
        set({
          activeSongIndex: index,
          activeSong: rep.songs[index],
          duration: rep.songs[index].duration,
          currentTime: 0,
        })
      },
      nextSong: () => {
        const { activeSongIndex, repertoire } = get()
        if (!repertoire) return
        const next = activeSongIndex + 1
        if (next < repertoire.songs.length) {
          get().setActiveSong(next)
        }
      },
      prevSong: () => {
        const { activeSongIndex } = get()
        if (activeSongIndex > 0) {
          get().setActiveSong(activeSongIndex - 1)
        }
      },

      /* ── Transition ── */
      setTransitionType: (t) => set({ transitionType: t }),

      /* ── UI ── */
      setActiveTab: (tab) => set({ activeTab: tab }),
      setVisibleSequences: (seqs) => set({ visibleSequences: seqs }),
      toggleSequence: (name) => set((s) => {
        const seqs = [...s.visibleSequences]
        const idx = seqs.indexOf(name)
        if (idx >= 0) seqs.splice(idx, 1)
        else seqs.push(name)
        return { visibleSequences: seqs }
      }),
      toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),

      /* ── Engine ── */
      setEngineReady: (v) => set({ engineReady: v }),
      setLoadingTrack: (id) => set({ loadingTrackId: id }),
      setError: (err) => set({ error: err }),

      /* ── Mix snapshots ── */
      saveMixSnapshot: () => {
        const s = get()
        const snap: MixSnapshot = {
          id: `mix-${Date.now()}`,
          name: `Mix ${new Date().toLocaleTimeString()}`,
          trackVolumes: Object.fromEntries(s.tracks.map(t => [t.id, t.volume])),
          trackMutes: Object.fromEntries(s.tracks.map(t => [t.id, t.muted])),
          trackSolos: Object.fromEntries(s.tracks.map(t => [t.id, t.soloed])),
          trackPans: Object.fromEntries(s.tracks.map(t => [t.id, t.pan])),
          masterVolume: s.masterVolume,
          timestamp: Date.now(),
        }
        return snap
      },
      loadMixSnapshot: (snap) => set((s) => ({
        tracks: s.tracks.map(t => ({
          ...t,
          volume: snap.trackVolumes[t.id] ?? t.volume,
          muted: snap.trackMutes[t.id] ?? t.muted,
          soloed: snap.trackSolos[t.id] ?? t.soloed,
          pan: snap.trackPans[t.id] ?? t.pan,
        })),
        masterVolume: snap.masterVolume,
      })),

      /* ── Init with demo data ── */
      initDemo: () => {
        const s = get()
        if (!s.repertoire) {
          set({
            repertoire: DEMO_REPERTOIRE,
            activeSongIndex: 0,
            activeSong: DEMO_REPERTOIRE.songs[0],
            duration: DEMO_REPERTOIRE.songs[0].duration,
          })
        }
      },
    }),
    {
      name: 'groovelab-playback',
      partialize: (s) => ({
        mode: s.mode,
        masterVolume: s.masterVolume,
        activeTab: s.activeTab,
        visibleSequences: s.visibleSequences,
        tracks: s.tracks.map(({ audioBuffer, waveformData, ...rest }) => rest),
      }),
    }
  )
)
