/**
 * Playback / Multitracks Live — Type definitions
 *
 * Covers tracks, songs, sections, repertoire, and playback state
 * for the professional multitrack live player module.
 */

/* ── Playback modes ── */
export type PlaybackMode = 'pad' | 'ensayo' | 'vivo' | 'editar'

/* ── Track stem types ── */
export type StemType =
  | 'click' | 'guide' | 'drums' | 'loop' | 'bass'
  | 'bass-synth' | 'rhythm' | 'guitar' | 'guitar-electric' | 'guitar-acoustic'
  | 'keys' | 'synth' | 'vocals' | 'choir' | 'pad' | 'fx' | 'custom'

/* ── Track definition ── */
export interface PlaybackTrack {
  id: string
  name: string
  shortName: string
  color: string
  volume: number        // 0–100
  muted: boolean
  soloed: boolean
  pan: number           // -1 (L) to 1 (R)
  type: StemType
  order: number
  group?: string        // Channel group id (rhythm, bass, gtr, keys)
  audioUrl?: string
  audioBuffer?: AudioBuffer
  waveformData?: Float32Array
}

/* ── Channel group (visual separator in mixer) ── */
export interface ChannelGroup {
  id: string
  label: string         // 'RHYTHM', 'BASS', 'GTR', 'KEYS'
  afterTrackId: string  // the last track id before the separator
}

/* ── Section marker on timeline ── */
export interface Section {
  id: string
  label: string         // 'INTRO', 'VERSE 1', etc.
  shortLabel: string    // 'CI', 'I', 'V1', etc.
  color: string
  start: number         // 0–1 normalized position
  end: number           // 0–1 normalized position
}

/* ── Automation point ── */
export interface AutomationPoint {
  id: string
  position: number      // 0–1 normalized
  value: number         // 0–1 normalized (e.g. volume level)
  label?: string
  color: string
}

/* ── Song definition ── */
export interface PlaybackSong {
  id: string
  name: string
  key: string           // Tonalidad (Am, Ab, G, D, etc.)
  bpm: number
  duration: number      // seconds
  emoji?: string
  sections: Section[]
  automationPoints: AutomationPoint[]
  trackOverrides?: Partial<PlaybackTrack>[]  // Per-song track config
}

/* ── Repertoire / Setlist ── */
export interface PlaybackRepertoire {
  id: string
  name: string
  date: string
  songs: PlaybackSong[]
  updatedAt: number
}

/* ── Transition type ── */
export type TransitionType = 'pad' | 'bed'

/* ── Mix snapshot (saveable mixer state) ── */
export interface MixSnapshot {
  id: string
  name: string
  trackVolumes: Record<string, number>
  trackMutes: Record<string, boolean>
  trackSolos: Record<string, boolean>
  trackPans: Record<string, number>
  masterVolume: number
  timestamp: number
}

/* ── Session (persistent, includes everything) ── */
export interface PlaybackSession {
  id: string
  repertoire: PlaybackRepertoire
  tracks: PlaybackTrack[]
  activeSongId: string
  mixSnapshot: MixSnapshot
  mode: PlaybackMode
  updatedAt: number
}

/* ── Bottom tab identifiers ── */
export type BottomTab =
  | 'repertorio'
  | 'midi-cues'
  | 'automatizacion'
  | 'midi-map'
  | 'tempo'
  | 'routing'
