/**
 * Session Import Service — Audio file loading, validation, and stem detection
 *
 * Handles importing multitrack sessions from audio files,
 * auto-detecting stem types from filenames, and computing waveform data.
 */
import * as Tone from 'tone'
import type { PlaybackTrack, StemType } from '../types'
import { DEFAULT_TRACKS } from '../constants'

/* ── Supported audio formats ── */
const SUPPORTED_FORMATS = new Set([
  'audio/wav', 'audio/wave', 'audio/x-wav',
  'audio/mp3', 'audio/mpeg',
  'audio/ogg', 'audio/flac',
  'audio/aac', 'audio/mp4', 'audio/x-m4a',
  'audio/webm',
])

const SUPPORTED_EXTENSIONS = new Set([
  '.wav', '.mp3', '.ogg', '.flac', '.aac', '.m4a', '.webm',
])

/* ── Stem type detection from filename ── */
const STEM_PATTERNS: [RegExp, StemType][] = [
  [/click/i,            'click'],
  [/gui[aá]/i,          'guide'],
  [/guide/i,            'guide'],
  [/bater[ií]a|drums?/i,'drums'],
  [/loop/i,             'loop'],
  [/bajo[^s]|bass(?!.?s)/i, 'bass'],
  [/bajo.?s[iy]n|bass.?syn/i, 'bass-synth'],
  [/rhythm|r18/i,       'rhythm'],
  [/electr|ge.?[12]/i,  'guitar-electric'],
  [/acous|acust/i,      'guitar-acoustic'],
  [/piano|keys|teclad/i,'keys'],
  [/synth|pad|l18/i,    'synth'],
  [/vocal|voz|voc/i,    'vocals'],
  [/coro|choir|bkg/i,   'choir'],
  [/fx|effect|sfx/i,    'fx'],
]

function detectStemType(filename: string): StemType {
  for (const [pattern, type] of STEM_PATTERNS) {
    if (pattern.test(filename)) return type
  }
  return 'custom'
}

/* ── Color assignment by stem type ── */
const STEM_COLORS: Record<StemType, string> = {
  click:            '#04C5F7',
  guide:            '#9B6BFF',
  drums:            '#FF9020',
  loop:             '#20CC60',
  bass:             '#FFAA00',
  'bass-synth':     '#FF6B00',
  rhythm:           '#CC3060',
  guitar:            '#22c55e',
  'guitar-electric': '#FF3060',
  'guitar-acoustic': '#8B6914',
  keys:             '#F0CC60',
  synth:            '#04C5F7',
  vocals:           '#FF6B9D',
  choir:            '#BF5AF2',
  pad:              '#20CC60',
  fx:               '#FF9020',
  custom:           '#707070',
}

/* ── Validate audio file ── */
export function validateAudioFile(file: File): { valid: boolean; error?: string } {
  const ext = '.' + file.name.split('.').pop()?.toLowerCase()
  if (!SUPPORTED_FORMATS.has(file.type) && !SUPPORTED_EXTENSIONS.has(ext)) {
    return { valid: false, error: `Formato no soportado: ${file.type || ext}` }
  }
  if (file.size > 500 * 1024 * 1024) {
    return { valid: false, error: 'Archivo demasiado grande (max 500MB)' }
  }
  if (file.size === 0) {
    return { valid: false, error: 'Archivo vacío' }
  }
  return { valid: true }
}

/* ── Compute waveform peaks from AudioBuffer ── */
export function computeWaveformPeaks(buffer: AudioBuffer, numPeaks = 120): Float32Array {
  const channelData = buffer.getChannelData(0)
  const peaks = new Float32Array(numPeaks)
  const samplesPerPeak = Math.floor(channelData.length / numPeaks)

  for (let i = 0; i < numPeaks; i++) {
    let max = 0
    const start = i * samplesPerPeak
    const end = Math.min(start + samplesPerPeak, channelData.length)
    for (let j = start; j < end; j++) {
      const abs = Math.abs(channelData[j])
      if (abs > max) max = abs
    }
    peaks[i] = max
  }
  return peaks
}

/* ── Load a single audio file into a track ── */
export async function loadAudioFileToTrack(
  file: File,
  existingTrackId?: string,
): Promise<{ track: Partial<PlaybackTrack>; buffer: AudioBuffer; duration: number }> {
  const validation = validateAudioFile(file)
  if (!validation.valid) {
    throw new Error(validation.error)
  }

  await Tone.start()

  const arrayBuffer = await file.arrayBuffer()
  const audioContext = Tone.getContext().rawContext as AudioContext
  const buffer = await audioContext.decodeAudioData(arrayBuffer)
  const waveform = computeWaveformPeaks(buffer)
  const stemType = detectStemType(file.name)

  // Try to match to an existing default track
  let matchedTrack = existingTrackId
    ? DEFAULT_TRACKS.find(t => t.id === existingTrackId)
    : DEFAULT_TRACKS.find(t => t.type === stemType)

  const trackData: Partial<PlaybackTrack> = {
    id: matchedTrack?.id ?? `custom-${Date.now()}`,
    name: matchedTrack?.name ?? file.name.replace(/\.[^.]+$/, ''),
    shortName: matchedTrack?.shortName ?? file.name.slice(0, 4),
    color: matchedTrack?.color ?? STEM_COLORS[stemType],
    type: stemType,
    audioBuffer: buffer,
    waveformData: waveform,
  }

  return { track: trackData, buffer, duration: buffer.duration }
}

/* ── Import multiple files as a multitrack session ── */
export async function importMultitrackSession(
  files: FileList | File[],
): Promise<{ tracks: Partial<PlaybackTrack>[]; maxDuration: number; errors: string[] }> {
  const tracks: Partial<PlaybackTrack>[] = []
  const errors: string[] = []
  let maxDuration = 0

  const fileArray = Array.from(files)

  for (const file of fileArray) {
    try {
      const result = await loadAudioFileToTrack(file)
      tracks.push(result.track)
      if (result.duration > maxDuration) maxDuration = result.duration
    } catch (err) {
      errors.push(`${file.name}: ${err instanceof Error ? err.message : 'Error desconocido'}`)
    }
  }

  return { tracks, maxDuration, errors }
}

/* ── Get color for stem type ── */
export function getColorForStem(type: StemType): string {
  return STEM_COLORS[type] ?? '#707070'
}
