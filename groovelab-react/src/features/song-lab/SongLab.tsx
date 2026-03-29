import { useState, useEffect, useCallback, useRef, type DragEvent, type ChangeEvent } from 'react'
import * as Tone from 'tone'
import { cn } from '@/lib/cn'

/* ──────────────────────────── Types ──────────────────────────── */

interface StemConfig {
  name: string
  color: string
  eq: { low: number; mid: number; high: number }
}

interface StemState {
  name: string
  color: string
  volume: number      // -60 to 6 dB
  pan: number         // -1 to 1
  muted: boolean
  soloed: boolean
  player: Tone.Player | null
  eq: Tone.EQ3 | null
  panner: Tone.Panner | null
  vol: Tone.Volume | null
}

interface DetectedChord {
  time: number   // seconds
  label: string
}

/* ──────────────────────────── Constants ──────────────────────── */

const STEM_CONFIGS: StemConfig[] = [
  { name: 'Vocals', color: '#BF5AF2', eq: { low: -24, mid: 6, high: -12 } },
  { name: 'Drums',  color: '#FF9500', eq: { low: 3, mid: -6, high: 8 } },
  { name: 'Bass',   color: '#FF3B30', eq: { low: 10, mid: -12, high: -24 } },
  { name: 'Guitar', color: '#00E5FF', eq: { low: -12, mid: 8, high: -6 } },
  { name: 'Other',  color: '#8E8E93', eq: { low: -3, mid: -3, high: -3 } },
]

/* Demo chords kept as reference:
   Am(0s) F(2.5) C(5) G(7.5) Am(10) F(12.5) C(15) G(17.5) Dm(20) Am(22.5) E(25) Am(27.5) */

const PROCESSING_STEPS = [
  'Analyzing audio signal...',
  'Detecting frequency bands...',
  'Isolating vocal frequencies...',
  'Separating percussive elements...',
  'Extracting bass frequencies...',
  'Isolating harmonic content...',
  'Finalizing stem separation...',
]

/* ──────────────────────────── Helpers ─────────────────────────── */

function formatTime(secs: number): string {
  if (!isFinite(secs) || secs < 0) return '0:00.0'
  const m = Math.floor(secs / 60)
  const s = Math.floor(secs % 60)
  const ms = Math.floor((secs % 1) * 10)
  return `${m}:${s.toString().padStart(2, '0')}.${ms}`
}

function clamp(val: number, min: number, max: number) {
  return Math.min(max, Math.max(min, val))
}

/* ──────────────────────────── Component ──────────────────────── */

export default function SongLab() {
  /* ── State ── */
  const [audioFile, setAudioFile] = useState<File | null>(null)
  const [audioUrl, setAudioUrl] = useState<string | null>(null)
  const [stems, setStems] = useState<StemState[]>([])
  const [isProcessing, setIsProcessing] = useState(false)
  const [processingStep, setProcessingStep] = useState(0)
  const [processingProgress, setProcessingProgress] = useState(0)
  const [isPlaying, setIsPlaying] = useState(false)
  const [position, setPosition] = useState(0)
  const [duration, setDuration] = useState(0)
  const [speed, setSpeed] = useState(1)
  const [pitchShift, setPitchShift] = useState(0)
  const [loopStart, setLoopStart] = useState<number | null>(null)
  const [loopEnd, setLoopEnd] = useState<number | null>(null)
  const [abLoopActive, setAbLoopActive] = useState(false)
  const [bpm, setBpm] = useState<number | null>(null)
  const [bpmInput, setBpmInput] = useState('')
  const [isDragOver, setIsDragOver] = useState(false)
  const [waveformPeaks, setWaveformPeaks] = useState<number[]>([])
  const [chords, setChords] = useState<DetectedChord[]>([])
  const [draggingMarker, setDraggingMarker] = useState<'A' | 'B' | null>(null)

  /* ── Refs ── */
  const masterPlayerRef = useRef<Tone.Player | null>(null)
  const pitchShifterRef = useRef<Tone.PitchShift | null>(null)
  const animFrameRef = useRef<number>(0)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const waveformContainerRef = useRef<HTMLDivElement>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const startTimeRef = useRef(0)
  const pausedAtRef = useRef(0)

  /* ── Cleanup on unmount ── */
  useEffect(() => {
    return () => {
      cancelAnimationFrame(animFrameRef.current)
      masterPlayerRef.current?.stop()
      masterPlayerRef.current?.dispose()
      pitchShifterRef.current?.dispose()
      stems.forEach((s) => {
        s.player?.stop()
        s.player?.dispose()
        s.eq?.dispose()
        s.panner?.dispose()
        s.vol?.dispose()
      })
      if (audioUrl) URL.revokeObjectURL(audioUrl)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  /* ── File handling ── */
  const handleFile = useCallback(async (file: File) => {
    if (!file.type.startsWith('audio/')) return
    // Cleanup previous
    masterPlayerRef.current?.stop()
    masterPlayerRef.current?.dispose()
    pitchShifterRef.current?.dispose()
    stems.forEach((s) => {
      s.player?.stop()
      s.player?.dispose()
      s.eq?.dispose()
      s.panner?.dispose()
      s.vol?.dispose()
    })
    if (audioUrl) URL.revokeObjectURL(audioUrl)

    const url = URL.createObjectURL(file)
    setAudioFile(file)
    setAudioUrl(url)
    setStems([])
    setIsPlaying(false)
    setPosition(0)
    setLoopStart(null)
    setLoopEnd(null)
    setAbLoopActive(false)
    setChords([])
    setBpm(null)
    setSpeed(1)
    setPitchShift(0)

    await Tone.start()

    // Load master player for waveform and playback
    const player = new Tone.Player(url)
    const ps = new Tone.PitchShift({ pitch: 0 }).toDestination()
    player.connect(ps)
    masterPlayerRef.current = player
    pitchShifterRef.current = ps

    player.onstop = () => {
      setIsPlaying(false)
    }

    // Wait for buffer to load
    await Tone.loaded()

    const dur = player.buffer.duration
    setDuration(dur)

    // Extract waveform peaks
    const rawData = player.buffer.getChannelData(0)
    const peakCount = 300
    const blockSize = Math.floor(rawData.length / peakCount)
    const peaks: number[] = []
    for (let i = 0; i < peakCount; i++) {
      let max = 0
      for (let j = 0; j < blockSize; j++) {
        const abs = Math.abs(rawData[i * blockSize + j] || 0)
        if (abs > max) max = abs
      }
      peaks.push(max)
    }
    setWaveformPeaks(peaks)

    // Simulate BPM detection
    const detectedBpm = Math.round(80 + Math.random() * 80) // 80-160 range
    setBpm(detectedBpm)
    setBpmInput(String(detectedBpm))

    // Generate chord progression matched to duration
    const chordsForSong: DetectedChord[] = []
    const chordOptions = ['Am', 'C', 'Dm', 'Em', 'F', 'G', 'A', 'Bm', 'D', 'E']
    const interval = 2.5
    for (let t = 0; t < dur; t += interval) {
      chordsForSong.push({
        time: t,
        label: chordOptions[Math.floor(Math.random() * chordOptions.length)],
      })
    }
    setChords(chordsForSong)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const handleDrop = useCallback((e: DragEvent<HTMLDivElement>) => {
    e.preventDefault()
    setIsDragOver(false)
    const file = e.dataTransfer.files[0]
    if (file) handleFile(file)
  }, [handleFile])

  const handleFileInput = useCallback((e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) handleFile(file)
  }, [handleFile])

  /* ── Stem separation (simulated) ── */
  const separateStems = useCallback(async () => {
    if (!audioUrl) return
    setIsProcessing(true)
    setProcessingStep(0)
    setProcessingProgress(0)

    // Animate processing steps
    for (let i = 0; i < PROCESSING_STEPS.length; i++) {
      setProcessingStep(i)
      setProcessingProgress(((i + 1) / PROCESSING_STEPS.length) * 100)
      await new Promise((r) => setTimeout(r, 600))
    }

    await Tone.start()

    const newStems: StemState[] = []

    for (const config of STEM_CONFIGS) {
      const player = new Tone.Player(audioUrl)
      const eq = new Tone.EQ3({
        low: config.eq.low,
        mid: config.eq.mid,
        high: config.eq.high,
        lowFrequency: 250,
        highFrequency: 4000,
      })
      const panner = new Tone.Panner(0)
      const vol = new Tone.Volume(0)
      player.chain(eq, panner, vol, Tone.getDestination())

      newStems.push({
        name: config.name,
        color: config.color,
        volume: 0,
        pan: 0,
        muted: false,
        soloed: false,
        player,
        eq,
        panner,
        vol,
      })
    }

    await Tone.loaded()

    // Mute the master player when stems are active
    if (masterPlayerRef.current) {
      masterPlayerRef.current.mute = true
    }

    setStems(newStems)
    setIsProcessing(false)
  }, [audioUrl])

  /* ── Transport controls ── */
  const play = useCallback(async () => {
    await Tone.start()
    const now = Tone.now()

    if (stems.length > 0) {
      stems.forEach((s) => {
        if (s.player && s.player.loaded) {
          s.player.start(now, pausedAtRef.current)
          s.player.playbackRate = speed
          if (abLoopActive && loopStart !== null && loopEnd !== null) {
            s.player.loop = true
            s.player.loopStart = loopStart
            s.player.loopEnd = loopEnd
          }
        }
      })
    } else if (masterPlayerRef.current?.loaded) {
      masterPlayerRef.current.start(now, pausedAtRef.current)
      masterPlayerRef.current.playbackRate = speed
      if (abLoopActive && loopStart !== null && loopEnd !== null) {
        masterPlayerRef.current.loop = true
        masterPlayerRef.current.loopStart = loopStart
        masterPlayerRef.current.loopEnd = loopEnd
      }
    }

    startTimeRef.current = now - pausedAtRef.current / speed
    setIsPlaying(true)
  }, [stems, speed, abLoopActive, loopStart, loopEnd])

  const stop = useCallback(() => {
    if (stems.length > 0) {
      stems.forEach((s) => s.player?.stop())
    } else {
      masterPlayerRef.current?.stop()
    }
    pausedAtRef.current = position
    setIsPlaying(false)
  }, [stems, position])

  const stopAndReset = useCallback(() => {
    if (stems.length > 0) {
      stems.forEach((s) => s.player?.stop())
    } else {
      masterPlayerRef.current?.stop()
    }
    pausedAtRef.current = 0
    setPosition(0)
    setIsPlaying(false)
  }, [stems])

  /* ── Position tracking ── */
  useEffect(() => {
    if (!isPlaying) {
      cancelAnimationFrame(animFrameRef.current)
      return
    }

    const tick = () => {
      const elapsed = (Tone.now() - startTimeRef.current) * speed
      let pos = elapsed

      if (abLoopActive && loopStart !== null && loopEnd !== null && loopEnd > loopStart) {
        const loopLen = loopEnd - loopStart
        if (pos > loopEnd) {
          pos = loopStart + ((pos - loopStart) % loopLen)
        }
      }

      if (pos >= duration && duration > 0) {
        if (!abLoopActive) {
          stopAndReset()
          return
        }
      }

      setPosition(clamp(pos, 0, duration))
      pausedAtRef.current = pos
      animFrameRef.current = requestAnimationFrame(tick)
    }

    animFrameRef.current = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(animFrameRef.current)
  }, [isPlaying, speed, duration, abLoopActive, loopStart, loopEnd, stopAndReset])

  /* ── Speed change ── */
  useEffect(() => {
    if (stems.length > 0) {
      stems.forEach((s) => {
        if (s.player) s.player.playbackRate = speed
      })
    } else if (masterPlayerRef.current) {
      masterPlayerRef.current.playbackRate = speed
    }
  }, [speed, stems])

  /* ── Pitch shift change ── */
  useEffect(() => {
    if (pitchShifterRef.current) {
      pitchShifterRef.current.pitch = pitchShift
    }
  }, [pitchShift])

  /* ── Stem volume / pan / mute / solo ── */
  const updateStem = useCallback((index: number, updates: Partial<StemState>) => {
    setStems((prev) => {
      const next = [...prev]
      next[index] = { ...next[index], ...updates }

      // Apply audio changes
      const stem = next[index]
      if (stem.vol) stem.vol.volume.value = stem.muted ? -Infinity : stem.volume
      if (stem.panner) stem.panner.pan.value = stem.pan

      // Handle solo logic
      const anySoloed = next.some((s) => s.soloed)
      next.forEach((s) => {
        if (s.vol) {
          if (anySoloed) {
            s.vol.volume.value = s.soloed ? s.volume : -Infinity
          } else {
            s.vol.volume.value = s.muted ? -Infinity : s.volume
          }
        }
      })

      return next
    })
  }, [])

  /* ── A-B Loop ── */
  const toggleABLoop = useCallback(() => {
    if (abLoopActive) {
      setAbLoopActive(false)
      setLoopStart(null)
      setLoopEnd(null)
      // Disable loop on players
      if (stems.length > 0) {
        stems.forEach((s) => { if (s.player) s.player.loop = false })
      } else if (masterPlayerRef.current) {
        masterPlayerRef.current.loop = false
      }
    } else if (loopStart !== null && loopEnd !== null) {
      setAbLoopActive(true)
      if (stems.length > 0) {
        stems.forEach((s) => {
          if (s.player) {
            s.player.loop = true
            s.player.loopStart = loopStart
            s.player.loopEnd = loopEnd
          }
        })
      } else if (masterPlayerRef.current) {
        masterPlayerRef.current.loop = true
        masterPlayerRef.current.loopStart = loopStart
        masterPlayerRef.current.loopEnd = loopEnd
      }
    }
  }, [abLoopActive, loopStart, loopEnd, stems])

  const setMarkerA = useCallback(() => {
    setLoopStart(position)
    if (loopEnd === null || position >= loopEnd) {
      setLoopEnd(Math.min(position + 5, duration))
    }
  }, [position, loopEnd, duration])

  const setMarkerB = useCallback(() => {
    setLoopEnd(position)
    if (loopStart === null || position <= loopStart) {
      setLoopStart(Math.max(position - 5, 0))
    }
  }, [position, loopStart])

  /* ── Waveform scrub ── */
  const handleWaveformClick = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    if (!duration || draggingMarker) return
    const rect = e.currentTarget.getBoundingClientRect()
    const x = e.clientX - rect.left
    const ratio = x / rect.width
    const newPos = ratio * duration

    const wasPlaying = isPlaying
    if (wasPlaying) {
      if (stems.length > 0) stems.forEach((s) => s.player?.stop())
      else masterPlayerRef.current?.stop()
    }

    pausedAtRef.current = newPos
    setPosition(newPos)

    if (wasPlaying) {
      const now = Tone.now()
      startTimeRef.current = now - newPos / speed
      if (stems.length > 0) {
        stems.forEach((s) => {
          if (s.player?.loaded) {
            s.player.start(now, newPos)
            s.player.playbackRate = speed
          }
        })
      } else if (masterPlayerRef.current?.loaded) {
        masterPlayerRef.current.start(now, newPos)
        masterPlayerRef.current.playbackRate = speed
      }
    }
  }, [duration, isPlaying, stems, speed, draggingMarker])

  /* ── Marker dragging on waveform ── */
  const handleWaveformMouseDown = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    if (!duration) return
    const rect = e.currentTarget.getBoundingClientRect()
    const x = e.clientX - rect.left
    const ratio = x / rect.width
    const clickTime = ratio * duration

    // Check if near A or B marker
    const threshold = duration * 0.015
    if (loopStart !== null && Math.abs(clickTime - loopStart) < threshold) {
      setDraggingMarker('A')
      e.preventDefault()
      return
    }
    if (loopEnd !== null && Math.abs(clickTime - loopEnd) < threshold) {
      setDraggingMarker('B')
      e.preventDefault()
      return
    }
  }, [duration, loopStart, loopEnd])

  const handleWaveformMouseMove = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    if (!draggingMarker || !duration) return
    const rect = e.currentTarget.getBoundingClientRect()
    const x = e.clientX - rect.left
    const ratio = clamp(x / rect.width, 0, 1)
    const t = ratio * duration
    if (draggingMarker === 'A') setLoopStart(t)
    else setLoopEnd(t)
  }, [draggingMarker, duration])

  const handleWaveformMouseUp = useCallback(() => {
    if (draggingMarker) {
      setDraggingMarker(null)
    }
  }, [draggingMarker])

  /* ── Canvas drawing ── */
  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas || waveformPeaks.length === 0) return

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const dpr = window.devicePixelRatio || 1
    const rect = canvas.getBoundingClientRect()
    canvas.width = rect.width * dpr
    canvas.height = rect.height * dpr
    ctx.scale(dpr, dpr)

    const w = rect.width
    const h = rect.height
    const barWidth = w / waveformPeaks.length
    const mid = h / 2

    // Clear
    ctx.clearRect(0, 0, w, h)

    // A-B loop region
    if (loopStart !== null && loopEnd !== null && duration > 0) {
      const x1 = (loopStart / duration) * w
      const x2 = (loopEnd / duration) * w
      ctx.fillStyle = abLoopActive ? 'rgba(0, 229, 255, 0.08)' : 'rgba(142, 142, 147, 0.06)'
      ctx.fillRect(x1, 0, x2 - x1, h)

      // A marker
      ctx.strokeStyle = abLoopActive ? '#00E5FF' : '#8E8E93'
      ctx.lineWidth = 2
      ctx.setLineDash([4, 3])
      ctx.beginPath()
      ctx.moveTo(x1, 0)
      ctx.lineTo(x1, h)
      ctx.stroke()

      // B marker
      ctx.beginPath()
      ctx.moveTo(x2, 0)
      ctx.lineTo(x2, h)
      ctx.stroke()
      ctx.setLineDash([])

      // Labels
      ctx.font = '10px monospace'
      ctx.fillStyle = abLoopActive ? '#00E5FF' : '#8E8E93'
      ctx.fillText('A', x1 + 3, 12)
      ctx.fillText('B', x2 + 3, 12)
    }

    // Draw waveform bars
    const playRatio = duration > 0 ? position / duration : 0
    const playX = playRatio * w

    waveformPeaks.forEach((peak, i) => {
      const x = i * barWidth
      const barH = peak * mid * 0.9
      const inPlayed = x < playX

      ctx.fillStyle = inPlayed ? '#00E5FF' : 'rgba(0, 229, 255, 0.35)'
      ctx.fillRect(x + 0.5, mid - barH, barWidth - 1, barH)
      ctx.fillRect(x + 0.5, mid, barWidth - 1, barH)
    })

    // Playback cursor
    if (duration > 0) {
      ctx.strokeStyle = '#FFFFFF'
      ctx.lineWidth = 1.5
      ctx.beginPath()
      ctx.moveTo(playX, 0)
      ctx.lineTo(playX, h)
      ctx.stroke()
    }
  }, [waveformPeaks, position, duration, loopStart, loopEnd, abLoopActive])

  /* ── BPM manual entry ── */
  const handleBpmSubmit = useCallback(() => {
    const val = parseInt(bpmInput, 10)
    if (val > 0 && val < 300) setBpm(val)
  }, [bpmInput])

  /* ──────────────────────────── Render ─────────────────────────── */

  return (
    <div className="flex flex-col h-full bg-gl-dark text-white overflow-y-auto">
      {/* ── Processing overlay ── */}
      {isProcessing && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm">
          <div className="flex flex-col items-center gap-6 p-8 rounded-2xl bg-gl-panel neu-raised max-w-sm w-full mx-4">
            {/* Spinner */}
            <div className="relative w-20 h-20">
              <div className="absolute inset-0 rounded-full border-4 border-gl-surface" />
              <div className="absolute inset-0 rounded-full border-4 border-t-[#00E5FF] border-r-transparent border-b-transparent border-l-transparent animate-spin" />
              <div className="absolute inset-2 rounded-full border-4 border-t-transparent border-r-[#BF5AF2] border-b-transparent border-l-transparent animate-spin [animation-direction:reverse] [animation-duration:1.5s]" />
            </div>
            <div className="text-center">
              <p className="text-sm text-white/60 mb-1">Separating Stems</p>
              <p className="text-sm font-medium text-white/90">{PROCESSING_STEPS[processingStep]}</p>
            </div>
            {/* Progress bar */}
            <div className="w-full h-2 rounded-full bg-gl-surface neu-inset overflow-hidden">
              <div
                className="h-full rounded-full bg-gradient-to-r from-[#BF5AF2] to-[#00E5FF] transition-all duration-500"
                style={{ width: `${processingProgress}%` }}
              />
            </div>
          </div>
        </div>
      )}

      {/* ── Upload zone ── */}
      {!audioFile && (
        <div className="p-4">
          <div
            className={cn(
              'relative flex flex-col items-center justify-center gap-4 p-12 rounded-2xl border-2 border-dashed transition-all cursor-pointer',
              isDragOver
                ? 'border-[#00E5FF] bg-[#00E5FF]/5 scale-[1.01]'
                : 'border-white/20 bg-gl-surface hover:border-white/40 hover:bg-gl-surface/80'
            )}
            onDragOver={(e) => { e.preventDefault(); setIsDragOver(true) }}
            onDragLeave={() => setIsDragOver(false)}
            onDrop={handleDrop}
            onClick={() => fileInputRef.current?.click()}
          >
            <input
              ref={fileInputRef}
              type="file"
              accept="audio/*"
              className="hidden"
              onChange={handleFileInput}
            />
            {/* Upload icon */}
            <div className="w-16 h-16 rounded-2xl bg-gl-panel neu-raised flex items-center justify-center">
              <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" className="text-[#00E5FF]">
                <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" />
                <polyline points="17 8 12 3 7 8" />
                <line x1="12" y1="3" x2="12" y2="15" />
              </svg>
            </div>
            <div className="text-center">
              <p className="text-lg font-semibold text-white/90">Drop audio file here</p>
              <p className="text-sm text-white/50 mt-1">or click to browse -- MP3, WAV, FLAC, AAC</p>
            </div>
          </div>
        </div>
      )}

      {/* ── Main content (when file loaded) ── */}
      {audioFile && (
        <div className="flex flex-col gap-3 p-4">
          {/* File info bar */}
          <div className="flex items-center gap-3 p-3 rounded-xl bg-gl-panel neu-raised">
            <div className="w-10 h-10 rounded-lg bg-[#00E5FF]/10 flex items-center justify-center shrink-0">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#00E5FF" strokeWidth="2">
                <path d="M9 18V5l12-2v13" />
                <circle cx="6" cy="18" r="3" />
                <circle cx="18" cy="16" r="3" />
              </svg>
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium truncate">{audioFile.name}</p>
              <p className="text-xs text-white/50">
                {(audioFile.size / (1024 * 1024)).toFixed(1)} MB
                {bpm && <span className="ml-2">BPM: {bpm}</span>}
              </p>
            </div>
            {/* Replace file */}
            <button
              className="px-3 py-1.5 text-xs rounded-lg bg-gl-surface hover:bg-white/10 transition-colors"
              onClick={() => {
                stopAndReset()
                setAudioFile(null)
                setAudioUrl(null)
                setStems([])
                setWaveformPeaks([])
                setChords([])
              }}
            >
              Replace
            </button>
            {/* Separate stems button */}
            {stems.length === 0 && (
              <button
                className="px-4 py-1.5 text-xs font-semibold rounded-lg bg-gradient-to-r from-[#BF5AF2] to-[#00E5FF] text-white hover:opacity-90 transition-opacity"
                onClick={separateStems}
              >
                Separate Stems
              </button>
            )}
          </div>

          {/* ── Waveform ── */}
          <div ref={waveformContainerRef} className="relative rounded-xl bg-gl-panel neu-inset overflow-hidden">
            <canvas
              ref={canvasRef}
              className="w-full h-28 cursor-crosshair"
              onClick={handleWaveformClick}
              onMouseDown={handleWaveformMouseDown}
              onMouseMove={handleWaveformMouseMove}
              onMouseUp={handleWaveformMouseUp}
              onMouseLeave={handleWaveformMouseUp}
            />
          </div>

          {/* ── Chord timeline ── */}
          {chords.length > 0 && duration > 0 && (
            <div className="relative h-8 rounded-lg bg-gl-surface overflow-hidden">
              {chords.map((chord, i) => {
                const left = (chord.time / duration) * 100
                const nextTime = chords[i + 1]?.time ?? duration
                const width = ((nextTime - chord.time) / duration) * 100
                return (
                  <div
                    key={i}
                    className="absolute top-0 h-full flex items-center justify-center border-r border-white/10 text-xs font-mono font-semibold"
                    style={{
                      left: `${left}%`,
                      width: `${width}%`,
                      color: i % 2 === 0 ? '#BF5AF2' : '#00E5FF',
                      backgroundColor: i % 2 === 0 ? 'rgba(191,90,242,0.06)' : 'rgba(0,229,255,0.06)',
                    }}
                  >
                    {chord.label}
                  </div>
                )
              })}
              {/* Playback position indicator */}
              <div
                className="absolute top-0 h-full w-px bg-white/80 pointer-events-none"
                style={{ left: `${(position / duration) * 100}%` }}
              />
            </div>
          )}

          {/* ── Transport bar ── */}
          <div className="flex items-center gap-3 p-3 rounded-xl bg-gl-panel neu-raised flex-wrap">
            {/* Play / Stop */}
            <div className="flex items-center gap-1.5">
              <button
                className={cn(
                  'w-10 h-10 rounded-xl flex items-center justify-center transition-all neu-raised',
                  isPlaying ? 'bg-[#00E5FF]/20 text-[#00E5FF]' : 'bg-gl-surface text-white hover:bg-white/10'
                )}
                onClick={isPlaying ? stop : play}
              >
                {isPlaying ? (
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                    <rect x="6" y="4" width="4" height="16" rx="1" />
                    <rect x="14" y="4" width="4" height="16" rx="1" />
                  </svg>
                ) : (
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                    <polygon points="5,3 19,12 5,21" />
                  </svg>
                )}
              </button>
              <button
                className="w-10 h-10 rounded-xl flex items-center justify-center bg-gl-surface text-white hover:bg-white/10 transition-colors neu-raised"
                onClick={stopAndReset}
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                  <rect x="4" y="4" width="16" height="16" rx="2" />
                </svg>
              </button>
            </div>

            {/* Time display */}
            <div className="font-mono text-sm tabular-nums text-white/80 min-w-[120px]">
              <span className="text-white">{formatTime(position)}</span>
              <span className="text-white/40"> / </span>
              <span className="text-white/60">{formatTime(duration)}</span>
            </div>

            {/* Speed control */}
            <div className="flex items-center gap-2 ml-auto">
              <span className="text-[10px] uppercase tracking-wider text-white/40">Speed</span>
              <input
                type="range"
                min="0.5"
                max="2"
                step="0.05"
                value={speed}
                onChange={(e) => setSpeed(parseFloat(e.target.value))}
                className="w-20 accent-[#00E5FF]"
              />
              <span className="text-xs font-mono text-white/70 w-10 text-right">{speed.toFixed(2)}x</span>
            </div>

            {/* Pitch control */}
            <div className="flex items-center gap-2">
              <span className="text-[10px] uppercase tracking-wider text-white/40">Pitch</span>
              <input
                type="range"
                min="-12"
                max="12"
                step="1"
                value={pitchShift}
                onChange={(e) => setPitchShift(parseInt(e.target.value, 10))}
                className="w-20 accent-[#BF5AF2]"
              />
              <span className="text-xs font-mono text-white/70 w-10 text-right">
                {pitchShift > 0 ? '+' : ''}{pitchShift}st
              </span>
            </div>

            {/* A-B Loop controls */}
            <div className="flex items-center gap-1.5">
              <button
                className={cn(
                  'px-2 py-1 text-[10px] font-bold rounded-md transition-colors',
                  loopStart !== null ? 'bg-[#00E5FF]/20 text-[#00E5FF]' : 'bg-gl-surface text-white/50 hover:text-white/80'
                )}
                onClick={setMarkerA}
              >
                A
              </button>
              <button
                className={cn(
                  'px-2 py-1 text-[10px] font-bold rounded-md transition-colors',
                  loopEnd !== null ? 'bg-[#00E5FF]/20 text-[#00E5FF]' : 'bg-gl-surface text-white/50 hover:text-white/80'
                )}
                onClick={setMarkerB}
              >
                B
              </button>
              <button
                className={cn(
                  'px-2.5 py-1 text-[10px] font-bold rounded-md transition-colors',
                  abLoopActive
                    ? 'bg-[#00E5FF] text-black'
                    : loopStart !== null && loopEnd !== null
                      ? 'bg-gl-surface text-[#00E5FF] hover:bg-[#00E5FF]/20'
                      : 'bg-gl-surface text-white/30 cursor-not-allowed'
                )}
                onClick={toggleABLoop}
                disabled={loopStart === null || loopEnd === null}
              >
                A-B
              </button>
            </div>

            {/* BPM */}
            <div className="flex items-center gap-1.5">
              <span className="text-[10px] uppercase tracking-wider text-white/40">BPM</span>
              <input
                type="text"
                inputMode="numeric"
                value={bpmInput}
                onChange={(e) => setBpmInput(e.target.value)}
                onBlur={handleBpmSubmit}
                onKeyDown={(e) => e.key === 'Enter' && handleBpmSubmit()}
                className="w-12 px-2 py-1 text-xs font-mono text-center rounded-md bg-gl-surface text-white border border-white/10 focus:border-[#00E5FF] focus:outline-none"
              />
            </div>
          </div>

          {/* ── Stem Mixer ── */}
          {stems.length > 0 && (
            <div className="rounded-xl bg-gl-panel neu-raised overflow-hidden">
              <div className="px-4 py-2 border-b border-white/5">
                <p className="text-xs font-semibold uppercase tracking-wider text-white/50">Stem Mixer</p>
              </div>
              <div className="divide-y divide-white/5">
                {stems.map((stem, i) => (
                  <div
                    key={stem.name}
                    className={cn(
                      'flex items-center gap-3 px-4 py-3',
                      i % 2 === 0 ? 'bg-gl-surface' : 'bg-gl-panel'
                    )}
                  >
                    {/* Color indicator */}
                    <div
                      className="w-1 h-10 rounded-full shrink-0"
                      style={{ backgroundColor: stem.color }}
                    />

                    {/* Name */}
                    <div className="w-16 shrink-0">
                      <p className="text-sm font-medium" style={{ color: stem.color }}>{stem.name}</p>
                    </div>

                    {/* Solo / Mute */}
                    <div className="flex gap-1 shrink-0">
                      <button
                        className={cn(
                          'w-7 h-7 text-[10px] font-bold rounded-md transition-all',
                          stem.soloed
                            ? 'bg-yellow-500 text-black neu-raised'
                            : 'bg-gl-surface text-white/50 hover:text-white/80 neu-raised'
                        )}
                        onClick={() => updateStem(i, { soloed: !stem.soloed })}
                      >
                        S
                      </button>
                      <button
                        className={cn(
                          'w-7 h-7 text-[10px] font-bold rounded-md transition-all',
                          stem.muted
                            ? 'bg-red-500/80 text-white neu-raised'
                            : 'bg-gl-surface text-white/50 hover:text-white/80 neu-raised'
                        )}
                        onClick={() => updateStem(i, { muted: !stem.muted })}
                      >
                        M
                      </button>
                    </div>

                    {/* Volume fader */}
                    <div className="flex items-center gap-2 flex-1 min-w-0">
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="text-white/30 shrink-0">
                        <polygon points="11,5 6,9 2,9 2,15 6,15 11,19" />
                      </svg>
                      <input
                        type="range"
                        min="-60"
                        max="6"
                        step="0.5"
                        value={stem.volume}
                        onChange={(e) => updateStem(i, { volume: parseFloat(e.target.value) })}
                        className="flex-1 accent-current"
                        style={{ color: stem.color } as React.CSSProperties}
                      />
                      <span className="text-[10px] font-mono text-white/50 w-10 text-right shrink-0">
                        {stem.volume > -60 ? `${stem.volume.toFixed(0)} dB` : '-inf'}
                      </span>
                    </div>

                    {/* Pan knob (simplified as slider) */}
                    <div className="flex items-center gap-1.5 shrink-0">
                      <span className="text-[9px] text-white/30">L</span>
                      <input
                        type="range"
                        min="-1"
                        max="1"
                        step="0.05"
                        value={stem.pan}
                        onChange={(e) => updateStem(i, { pan: parseFloat(e.target.value) })}
                        className="w-16 accent-white/60"
                      />
                      <span className="text-[9px] text-white/30">R</span>
                      <span className="text-[10px] font-mono text-white/40 w-5 text-center">
                        {stem.pan === 0 ? 'C' : stem.pan < 0 ? `L${Math.round(Math.abs(stem.pan) * 100)}` : `R${Math.round(stem.pan * 100)}`}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* ── Separator instructions (when no stems yet) ── */}
          {stems.length === 0 && audioFile && (
            <div className="flex items-center justify-center gap-3 p-6 rounded-xl bg-gl-surface/50 border border-white/5">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" className="text-[#BF5AF2] shrink-0">
                <circle cx="12" cy="12" r="10" />
                <line x1="12" y1="16" x2="12" y2="12" />
                <line x1="12" y1="8" x2="12.01" y2="8" />
              </svg>
              <p className="text-sm text-white/50">
                Click <span className="text-[#BF5AF2] font-semibold">Separate Stems</span> to split the track into Vocals, Drums, Bass, Guitar, and Other
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
