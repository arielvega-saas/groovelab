/**
 * Playback / Multitracks Live — Constants & demo data
 *
 * Default tracks, sections, and demo repertoire matching the
 * exact design from the PlayBack - Multitrack Live frontend.
 */
import type {
  PlaybackTrack,
  PlaybackSong,
  PlaybackRepertoire,
  Section,
  AutomationPoint,
  BottomTab,
  ChannelGroup,
} from './types'

/* ── Default track layout (13 channels matching the HTML source) ── */
export const DEFAULT_TRACKS: PlaybackTrack[] = [
  { id: 'click',    name: 'Click',         shortName: 'Click',  color: '#f97316', volume: 0,  muted: true,  soloed: false, pan: 0,     type: 'click',      order: 0,  group: 'rhythm' },
  { id: 'guia',     name: 'Guía',          shortName: 'Guía',   color: '#eab308', volume: 49, muted: false, soloed: false, pan: 0,     type: 'guide',      order: 1,  group: 'rhythm' },
  { id: 'bat',      name: 'Batería',       shortName: 'Bat',    color: '#ef4444', volume: 70, muted: false, soloed: true,  pan: 0,     type: 'drums',      order: 2,  group: 'rhythm' },
  { id: 'loop',     name: 'Loop',          shortName: 'Loop',   color: '#a855f7', volume: 38, muted: false, soloed: true,  pan: -0.15, type: 'loop',       order: 3,  group: 'rhythm' },
  { id: 'bajo',     name: 'Bajo',          shortName: 'Bajo',   color: '#3b82f6', volume: 24, muted: false, soloed: false, pan: 0,     type: 'bass',       order: 4,  group: 'bass' },
  { id: 'bajosnt',  name: 'BajoSnt',       shortName: 'BSnt',   color: '#6366f1', volume: 51, muted: false, soloed: true,  pan: 0.1,   type: 'bass-synth', order: 5,  group: 'bass' },
  { id: 'ge1',      name: 'Eléctrica 1',   shortName: 'GE1',    color: '#22c55e', volume: 18, muted: false, soloed: true,  pan: -0.3,  type: 'guitar',     order: 6,  group: 'gtr' },
  { id: 'ge2',      name: 'Eléctrica 2',   shortName: 'GE2',    color: '#22c55e', volume: 34, muted: false, soloed: true,  pan: 0.25,  type: 'guitar',     order: 7,  group: 'gtr' },
  { id: 'piano',    name: 'Piano',         shortName: 'Pno',    color: '#06b6d4', volume: 45, muted: false, soloed: false, pan: -0.1,  type: 'keys',       order: 8,  group: 'keys' },
  { id: 'synth',    name: 'Synth',         shortName: 'Syn',    color: '#ec4899', volume: 28, muted: false, soloed: false, pan: 0.15,  type: 'synth',      order: 9,  group: 'keys' },
  { id: 'vocales',  name: 'Vocales',       shortName: 'Voc',    color: '#f43f5e', volume: 60, muted: false, soloed: false, pan: 0,     type: 'vocals',     order: 10 },
  { id: 'coro',     name: 'Coro',          shortName: 'Coro',   color: '#d946ef', volume: 36, muted: false, soloed: false, pan: 0,     type: 'choir',      order: 11 },
  { id: 'pad',      name: 'Pad',           shortName: 'Pad',    color: '#14b8a6', volume: 20, muted: false, soloed: false, pan: 0,     type: 'pad',        order: 12 },
]

/* ── Channel groups (visual separators in mixer) ── */
export const CHANNEL_GROUPS: ChannelGroup[] = [
  { id: 'rhythm', label: 'RHYTHM', afterTrackId: 'loop' },
  { id: 'bass',   label: 'BASS',   afterTrackId: 'bajosnt' },
  { id: 'gtr',    label: 'GTR',    afterTrackId: 'ge2' },
  { id: 'keys',   label: 'KEYS',   afterTrackId: 'synth' },
]

/* ── Section colors matching the design ── */
export const SECTION_COLORS: Record<string, string> = {
  ci:      '#04C5F7',
  intro:   '#04C5F7',
  verse:   '#20CC60',
  pre:     '#FFAA00',
  chorus:  '#FF3060',
  verse2:  '#3B82F6',
  bridge:  '#BF5AF2',
  outro:   '#505050',
}

/* ── Demo sections for "Jesús Es Mi Refugio" ── */
const SECTIONS_JESUS: Section[] = [
  { id: 'ci',     label: 'CI',       shortLabel: 'CI',    color: '#04C5F7', start: 0,    end: 0.04  },
  { id: 'intro',  label: 'INTRO',    shortLabel: 'I',     color: '#04C5F7', start: 0.04, end: 0.15  },
  { id: 'v1',     label: 'VERSE 1',  shortLabel: 'V1',    color: '#20CC60', start: 0.15, end: 0.30  },
  { id: 'pre',    label: 'PRE',      shortLabel: 'Pr',    color: '#FFAA00', start: 0.30, end: 0.38  },
  { id: 'ch1',    label: 'CHORUS',   shortLabel: 'Ch',    color: '#FF3060', start: 0.38, end: 0.52  },
  { id: 'v2',     label: 'VERSE 2',  shortLabel: 'V2',    color: '#3B82F6', start: 0.52, end: 0.64  },
  { id: 'ch2',    label: 'CHORUS',   shortLabel: 'Ch',    color: '#FF3060', start: 0.64, end: 0.74  },
  { id: 'bridge', label: 'BRIDGE',   shortLabel: 'Br',    color: '#BF5AF2', start: 0.74, end: 0.84  },
  { id: 'ch3',    label: 'CHORUS',   shortLabel: 'Ch',    color: '#FF3060', start: 0.84, end: 0.94  },
  { id: 'outro',  label: 'OUTRO',    shortLabel: 'Out',   color: '#505050', start: 0.94, end: 1     },
]

/* ── Demo automation points ── */
const AUTOMATION_JESUS: AutomationPoint[] = [
  { id: 'a1',  position: 0.05, value: 0.3,  color: '#FF3060', label: 'M' },
  { id: 'a2',  position: 0.15, value: 0.45, color: '#20CC60', label: 'L' },
  { id: 'a3',  position: 0.25, value: 0.55, color: '#FF3060' },
  { id: 'a4',  position: 0.32, value: 0.5,  color: '#20CC60', label: 'S' },
  { id: 'a5',  position: 0.38, value: 0.5,  color: '#20CC60', label: 'S' },
  { id: 'a6',  position: 0.45, value: 0.6,  color: '#FF3060', label: 'M' },
  { id: 'a7',  position: 0.52, value: 0.55, color: '#3B82F6', label: 'E' },
  { id: 'a8',  position: 0.58, value: 0.5,  color: '#20CC60', label: 'S' },
  { id: 'a9',  position: 0.65, value: 0.55, color: '#20CC60', label: 'S' },
  { id: 'a10', position: 0.72, value: 0.5,  color: '#20CC60', label: 'S' },
  { id: 'a11', position: 0.78, value: 0.45, color: '#20CC60', label: 'L' },
  { id: 'a12', position: 0.88, value: 0.6,  color: '#FF3060', label: 'M' },
]

/* ── Demo songs ── */
const DEMO_SONGS: PlaybackSong[] = [
  {
    id: 's1',
    name: 'Jesús Es Mi Refugio',
    key: 'Am',
    bpm: 70,
    duration: 512,
    emoji: '\u267E\uFE0F',
    sections: SECTIONS_JESUS,
    automationPoints: AUTOMATION_JESUS,
  },
  {
    id: 's2',
    name: 'La Gloria De Dios',
    key: 'Ab',
    bpm: 132,
    duration: 448,
    sections: [
      { id: 'intro', label: 'INTRO', shortLabel: 'I', color: '#04C5F7', start: 0, end: 0.12 },
      { id: 'v1', label: 'VERSE 1', shortLabel: 'V1', color: '#20CC60', start: 0.12, end: 0.30 },
      { id: 'ch1', label: 'CHORUS', shortLabel: 'Ch', color: '#FF3060', start: 0.30, end: 0.50 },
      { id: 'v2', label: 'VERSE 2', shortLabel: 'V2', color: '#3B82F6', start: 0.50, end: 0.68 },
      { id: 'ch2', label: 'CHORUS', shortLabel: 'Ch', color: '#FF3060', start: 0.68, end: 0.88 },
      { id: 'outro', label: 'OUTRO', shortLabel: 'Out', color: '#505050', start: 0.88, end: 1 },
    ],
    automationPoints: [],
  },
  {
    id: 's3',
    name: 'Yahweh Se Manifestara',
    key: 'G',
    bpm: 148,
    duration: 495,
    emoji: '\uD83D\uDC65',
    sections: [
      { id: 'intro', label: 'INTRO', shortLabel: 'I', color: '#04C5F7', start: 0, end: 0.10 },
      { id: 'v1', label: 'VERSE 1', shortLabel: 'V1', color: '#20CC60', start: 0.10, end: 0.35 },
      { id: 'ch1', label: 'CHORUS', shortLabel: 'Ch', color: '#FF3060', start: 0.35, end: 0.55 },
      { id: 'bridge', label: 'BRIDGE', shortLabel: 'Br', color: '#BF5AF2', start: 0.55, end: 0.70 },
      { id: 'ch2', label: 'CHORUS', shortLabel: 'Ch', color: '#FF3060', start: 0.70, end: 0.90 },
      { id: 'outro', label: 'OUTRO', shortLabel: 'Out', color: '#505050', start: 0.90, end: 1 },
    ],
    automationPoints: [],
  },
  {
    id: 's4',
    name: 'Digno de Adorar',
    key: 'D',
    bpm: 78,
    duration: 393,
    emoji: '\uD83C\uDFA4',
    sections: [
      { id: 'intro', label: 'INTRO', shortLabel: 'I', color: '#04C5F7', start: 0, end: 0.15 },
      { id: 'v1', label: 'VERSE', shortLabel: 'V', color: '#20CC60', start: 0.15, end: 0.45 },
      { id: 'ch1', label: 'CHORUS', shortLabel: 'Ch', color: '#FF3060', start: 0.45, end: 0.70 },
      { id: 'bridge', label: 'BRIDGE', shortLabel: 'Br', color: '#BF5AF2', start: 0.70, end: 0.85 },
      { id: 'outro', label: 'OUTRO', shortLabel: 'Out', color: '#505050', start: 0.85, end: 1 },
    ],
    automationPoints: [],
  },
  {
    id: 's5',
    name: 'Creo En Ti',
    key: 'D',
    bpm: 126,
    duration: 470,
    emoji: '\uD83D\uDD4A\uFE0F',
    sections: [
      { id: 'intro', label: 'INTRO', shortLabel: 'I', color: '#04C5F7', start: 0, end: 0.12 },
      { id: 'v1', label: 'VERSE 1', shortLabel: 'V1', color: '#20CC60', start: 0.12, end: 0.32 },
      { id: 'pre', label: 'PRE', shortLabel: 'Pr', color: '#FFAA00', start: 0.32, end: 0.40 },
      { id: 'ch1', label: 'CHORUS', shortLabel: 'Ch', color: '#FF3060', start: 0.40, end: 0.60 },
      { id: 'v2', label: 'VERSE 2', shortLabel: 'V2', color: '#3B82F6', start: 0.60, end: 0.75 },
      { id: 'ch2', label: 'CHORUS', shortLabel: 'Ch', color: '#FF3060', start: 0.75, end: 0.92 },
      { id: 'outro', label: 'OUTRO', shortLabel: 'Out', color: '#505050', start: 0.92, end: 1 },
    ],
    automationPoints: [],
  },
]

/* ── Demo repertoire ── */
export const DEMO_REPERTOIRE: PlaybackRepertoire = {
  id: 'rep-domingo',
  name: 'Domingo',
  date: 'sept 21, 2025',
  songs: DEMO_SONGS,
  updatedAt: Date.now(),
}

/* ── Bottom tabs ── */
export const BOTTOM_TABS: { id: BottomTab; label: string; badge?: string | number }[] = [
  { id: 'repertorio',     label: 'Repertorio' },
  { id: 'midi-cues',      label: 'MIDI Cues', badge: 1 },
  { id: 'automatizacion', label: 'Automatizacion' },
  { id: 'midi-map',       label: 'MIDI Map' },
  { id: 'tempo',          label: 'Tempo' },
  { id: 'routing',        label: 'Routing' },
]

/* ── Sequence names (for channel visibility modal) ── */
export const SEQUENCE_NAMES = [
  'Click', 'Guía', 'Batería', 'Loop', 'Bajo', 'BajoSnt',
  'Eléctrica 1', 'Eléctrica 2',
  'Piano', 'Synth', 'Vocales', 'Coro', 'Pad',
]

/* ── Helpers ── */
export function formatTime(s: number): string {
  const m = Math.floor(s / 60).toString().padStart(2, '0')
  const sec = Math.floor(s % 60).toString().padStart(2, '0')
  return `${m}:${sec}`
}

export function formatTimeMs(s: number): string {
  const m = Math.floor(s / 60).toString().padStart(2, '0')
  const sec = Math.floor(s % 60).toString().padStart(2, '0')
  const ms = Math.floor((s % 1) * 10)
  return `${m}:${sec}.${ms}`
}

export function volumeToDb(v: number): string {
  if (v === 0) return '-\u221E'
  const db = 20 * Math.log10(v / 100)
  return (db >= 0 ? '+' : '') + db.toFixed(1)
}

export function getTotalDuration(songs: PlaybackSong[]): number {
  return songs.reduce((acc, s) => acc + s.duration, 0)
}

/** Generate a deterministic fake waveform for demo tracks */
export function generateFakeWaveform(seed: number, count = 120): number[] {
  const peaks: number[] = []
  let v = 0.3
  for (let i = 0; i < count; i++) {
    v += (Math.sin(seed * 13.7 + i * 0.47) * 0.15 + Math.cos(i * 0.23 + seed) * 0.1)
    v = Math.max(0.05, Math.min(1, v))
    peaks.push(v)
  }
  return peaks
}
