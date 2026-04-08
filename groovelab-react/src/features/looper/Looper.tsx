/**
 * Looper — Multi-layer loop recorder inspired by Loopy Pro / BIAS FX 2
 *
 * Records, overdubs, and plays back up to 8 audio layers with per-layer
 * waveform visualization, mute/solo, volume, undo/redo, BPM quantization,
 * metronome click, and WAV export.
 */
import { useState, useRef, useCallback, useEffect, useMemo } from 'react'
import * as Tone from 'tone'
import { cn } from '@/lib/cn'
import { useAppStore } from '@/stores/app-store'

/* ------------------------------------------------------------------ */
/*  Types                                                              */
/* ------------------------------------------------------------------ */

type RecordingState = 'IDLE' | 'RECORDING' | 'PLAYING' | 'OVERDUBBING'

interface Layer {
  id: string
  name: string
  buffer: AudioBuffer | null
  player: Tone.Player | null
  muted: boolean
  solo: boolean
  volume: number          // 0..1
  peaks: number[]         // normalised waveform peaks for canvas rendering
}

interface HistoryEntry {
  layerId: string
  buffer: AudioBuffer | null
  peaks: number[]
}

const MAX_LAYERS = 8
const PEAK_BUCKETS = 128

const LAYER_COLORS = [
  '#00E5FF', // cyan / gl-accent
  '#00FF11', // green / gl-green
  '#FF9500', // orange / gl-warm
  '#BF5AF2', // purple / gl-purple
  '#3B82F6', // blue
  '#EC4899', // pink
  '#FACC15', // yellow
  '#14B8A6', // teal
]

/* ------------------------------------------------------------------ */
/*  Helpers                                                            */
/* ------------------------------------------------------------------ */

function uid(): string {
  return Math.random().toString(36).slice(2, 10)
}

/** Quantise a duration (seconds) to the nearest bar at the given BPM / timeSig. */
function quantiseDuration(raw: number, bpm: number, beatsPerBar: number): number {
  const barLen = (60 / bpm) * beatsPerBar
  const bars = Math.max(1, Math.round(raw / barLen))
  return bars * barLen
}

/** Extract normalised peaks from an AudioBuffer for waveform drawing. */
function extractPeaks(buffer: AudioBuffer, buckets: number): number[] {
  const data = buffer.getChannelData(0)
  const step = Math.floor(data.length / buckets) || 1
  const peaks: number[] = []
  let max = 0
  for (let i = 0; i < buckets; i++) {
    let sum = 0
    const start = i * step
    const end = Math.min(start + step, data.length)
    for (let j = start; j < end; j++) {
      sum += Math.abs(data[j])
    }
    const avg = sum / (end - start)
    peaks.push(avg)
    if (avg > max) max = avg
  }
  // normalise
  if (max > 0) {
    for (let i = 0; i < peaks.length; i++) peaks[i] /= max
  }
  return peaks
}

/** Format seconds as mm:ss.ms */
function fmtTime(s: number): string {
  const m = Math.floor(s / 60)
  const sec = Math.floor(s % 60)
  const ms = Math.floor((s % 1) * 10)
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}.${ms}`
}

/** Convert an AudioBuffer to a WAV Blob */
function audioBufferToWav(buffer: AudioBuffer): Blob {
  const numChannels = buffer.numberOfChannels
  const sampleRate = buffer.sampleRate
  const length = buffer.length
  const bytesPerSample = 2
  const blockAlign = numChannels * bytesPerSample
  const dataSize = length * blockAlign
  const headerSize = 44
  const arrayBuffer = new ArrayBuffer(headerSize + dataSize)
  const view = new DataView(arrayBuffer)

  const writeString = (offset: number, str: string) => {
    for (let i = 0; i < str.length; i++) {
      view.setUint8(offset + i, str.charCodeAt(i))
    }
  }

  writeString(0, 'RIFF')
  view.setUint32(4, 36 + dataSize, true)
  writeString(8, 'WAVE')
  writeString(12, 'fmt ')
  view.setUint32(16, 16, true)
  view.setUint16(20, 1, true) // PCM
  view.setUint16(22, numChannels, true)
  view.setUint32(24, sampleRate, true)
  view.setUint32(28, sampleRate * blockAlign, true)
  view.setUint16(32, blockAlign, true)
  view.setUint16(34, bytesPerSample * 8, true)
  writeString(36, 'data')
  view.setUint32(40, dataSize, true)

  // Interleave and write samples
  let offset = 44
  const channels: Float32Array[] = []
  for (let ch = 0; ch < numChannels; ch++) {
    channels.push(buffer.getChannelData(ch))
  }

  for (let i = 0; i < length; i++) {
    for (let ch = 0; ch < numChannels; ch++) {
      const sample = Math.max(-1, Math.min(1, channels[ch][i]))
      const int16 = sample < 0 ? sample * 0x8000 : sample * 0x7FFF
      view.setInt16(offset, int16, true)
      offset += 2
    }
  }

  return new Blob([arrayBuffer], { type: 'audio/wav' })
}

/* ------------------------------------------------------------------ */
/*  Circular Progress Ring                                              */
/* ------------------------------------------------------------------ */

function CircularProgressRing({
  progress,
  state,
  elapsed,
}: {
  progress: number
  state: RecordingState
  elapsed: number
}) {
  const size = 180
  const strokeWidth = 6
  const radius = (size - strokeWidth * 2) / 2
  const circumference = 2 * Math.PI * radius
  const offset = circumference - progress * circumference

  const ringColor =
    state === 'RECORDING'
      ? '#FF3B30'
      : state === 'OVERDUBBING'
        ? '#FF9500'
        : state === 'PLAYING'
          ? '#00FF11'
          : '#333333'

  const glowColor =
    state === 'RECORDING'
      ? 'rgba(255, 59, 48, 0.6)'
      : state === 'OVERDUBBING'
        ? 'rgba(255, 149, 0, 0.6)'
        : state === 'PLAYING'
          ? 'rgba(0, 255, 17, 0.4)'
          : 'transparent'

  return (
    <div className="relative flex items-center justify-center" style={{ width: size, height: size }}>
      <svg
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
        className="absolute inset-0"
        style={{ filter: state !== 'IDLE' ? `drop-shadow(0 0 12px ${glowColor})` : undefined }}
      >
        {/* Background track */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="#1A1A1A"
          strokeWidth={strokeWidth}
        />
        {/* Progress arc */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={ringColor}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
          style={{ transition: 'stroke-dashoffset 0.1s linear' }}
        />
        {/* Recording pulse ring */}
        {state === 'RECORDING' && (
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius + 8}
            fill="none"
            stroke="#FF3B30"
            strokeWidth={1.5}
            opacity={0.5}
            className="animate-pulse"
          />
        )}
      </svg>
      {/* Center timer */}
      <div className="flex flex-col items-center z-10">
        <span
          className="text-2xl font-mono font-bold tracking-wider"
          style={{
            color: ringColor === '#333333' ? '#666666' : ringColor,
            textShadow:
              state !== 'IDLE'
                ? `0 0 10px ${glowColor}, 0 0 20px ${glowColor}`
                : undefined,
          }}
        >
          {fmtTime(elapsed)}
        </span>
        <span
          className="text-[10px] font-mono uppercase tracking-widest mt-1"
          style={{ color: ringColor === '#333333' ? '#555' : ringColor }}
        >
          {state === 'IDLE'
            ? 'READY'
            : state === 'RECORDING'
              ? 'REC'
              : state === 'OVERDUBBING'
                ? 'OVERDUB'
                : 'PLAY'}
        </span>
      </div>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  Waveform canvas component (upgraded with gradient fill + playhead) */
/* ------------------------------------------------------------------ */

function Waveform({
  peaks,
  playing,
  color,
  loopDuration,
  playStartTime,
}: {
  peaks: number[]
  playing: boolean
  color: string
  loopDuration: number
  playStartTime: number
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const rafRef = useRef<number>(0)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    let running = true

    const draw = () => {
      if (!running) return
      const dpr = window.devicePixelRatio || 1
      const w = canvas.clientWidth
      const h = canvas.clientHeight
      canvas.width = w * dpr
      canvas.height = h * dpr
      ctx.scale(dpr, dpr)

      ctx.clearRect(0, 0, w, h)

      const barW = w / peaks.length
      const gap = Math.max(0.5, barW * 0.15)
      const drawBarW = Math.max(1, barW - gap)
      const topZone = h * 0.62   // main waveform occupies upper 62%
      const mirrorZone = h * 0.30 // reflection occupies lower 30%
      const midY = topZone         // dividing line
      const cornerR = Math.min(drawBarW / 2, 2.5) // rounded top radius

      // ---- Main waveform bars with gradient fill and rounded tops ----
      for (let i = 0; i < peaks.length; i++) {
        const amp = peaks[i] * topZone * 0.85
        if (amp < 1) continue
        const x = i * barW + gap / 2
        const barTop = midY - amp

        // Gradient: color at top fading to transparent at baseline
        const grad = ctx.createLinearGradient(x, barTop, x, midY)
        grad.addColorStop(0, color + 'DD')
        grad.addColorStop(0.6, color + '66')
        grad.addColorStop(1, color + '0A')
        ctx.fillStyle = grad

        // Draw bar with rounded top corners
        ctx.beginPath()
        ctx.moveTo(x, midY)
        ctx.lineTo(x, barTop + cornerR)
        ctx.quadraticCurveTo(x, barTop, x + cornerR, barTop)
        ctx.lineTo(x + drawBarW - cornerR, barTop)
        ctx.quadraticCurveTo(x + drawBarW, barTop, x + drawBarW, barTop + cornerR)
        ctx.lineTo(x + drawBarW, midY)
        ctx.closePath()
        ctx.fill()
      }

      // ---- Mirror / reflection below the baseline (inverted, 30% opacity) ----
      ctx.save()
      ctx.globalAlpha = 0.3
      for (let i = 0; i < peaks.length; i++) {
        const amp = peaks[i] * mirrorZone * 0.7
        if (amp < 1) continue
        const x = i * barW + gap / 2
        const barBottom = midY + amp

        const grad = ctx.createLinearGradient(x, midY, x, barBottom)
        grad.addColorStop(0, color + '66')
        grad.addColorStop(1, color + '00')
        ctx.fillStyle = grad
        ctx.fillRect(x, midY + 1, drawBarW, amp)
      }
      ctx.restore()

      // ---- Thin glowing peak line tracing the tops ----
      ctx.save()
      ctx.strokeStyle = color
      ctx.lineWidth = 1.5
      ctx.shadowColor = color
      ctx.shadowBlur = 6
      ctx.beginPath()
      for (let i = 0; i < peaks.length; i++) {
        const amp = peaks[i] * topZone * 0.85
        const x = i * barW + barW / 2
        const y = midY - amp
        if (i === 0) {
          ctx.moveTo(x, y)
        } else {
          ctx.lineTo(x, y)
        }
      }
      ctx.stroke()
      ctx.restore()

      // ---- Animated playhead sweep during playback ----
      if (playing && loopDuration > 0) {
        const elapsed = (Tone.now() - playStartTime) % loopDuration
        const phase = elapsed / loopDuration
        const px = phase * w

        // Outer glow halo
        const halo = ctx.createLinearGradient(px - 12, 0, px + 12, 0)
        halo.addColorStop(0, 'rgba(255,255,255,0)')
        halo.addColorStop(0.35, 'rgba(255,255,255,0.06)')
        halo.addColorStop(0.5, 'rgba(255,255,255,0.12)')
        halo.addColorStop(0.65, 'rgba(255,255,255,0.06)')
        halo.addColorStop(1, 'rgba(255,255,255,0)')
        ctx.fillStyle = halo
        ctx.fillRect(px - 12, 0, 24, h)

        // Core playhead line with glow
        ctx.save()
        ctx.shadowColor = 'rgba(255,255,255,0.8)'
        ctx.shadowBlur = 8
        ctx.fillStyle = 'rgba(255,255,255,0.9)'
        ctx.fillRect(px - 0.75, 0, 1.5, h)
        ctx.restore()
      }

      rafRef.current = requestAnimationFrame(draw)
    }
    draw()

    return () => {
      running = false
      cancelAnimationFrame(rafRef.current)
    }
  }, [peaks, playing, color, loopDuration, playStartTime])

  return (
    <canvas
      ref={canvasRef}
      className="w-full h-20 rounded-md"
      style={{ background: '#0A0A0A' }}
    />
  )
}

/* ------------------------------------------------------------------ */
/*  Input Level Meter (segmented LED style with peak hold)             */
/* ------------------------------------------------------------------ */

function LevelMeter({ level }: { level: number }) {
  const segments = 24
  const peakRef = useRef(0)
  const peakDecayRef = useRef(0)

  // Track peak with hold & decay
  if (level > peakRef.current) {
    peakRef.current = level
    peakDecayRef.current = Date.now()
  } else if (Date.now() - peakDecayRef.current > 800) {
    peakRef.current = Math.max(0, peakRef.current - 0.02)
  }

  const peakSegment = Math.floor(peakRef.current * segments)

  return (
    <div className="flex flex-col-reverse gap-[2px] w-3 h-44 rounded p-[2px]" style={{ background: '#0A0A0A' }}>
      {Array.from({ length: segments }).map((_, i) => {
        const threshold = i / segments
        const active = level >= threshold
        const isPeak = i === peakSegment && peakRef.current > 0.05
        const ratio = i / segments

        let bgColor: string
        if (ratio >= 0.85) {
          bgColor = '#FF3B30'
        } else if (ratio >= 0.65) {
          bgColor = '#FF9500'
        } else {
          bgColor = '#00FF11'
        }

        const isLit = active || isPeak

        return (
          <div
            key={i}
            className="flex-1 rounded-[1px]"
            style={{
              background: isLit ? bgColor : '#1A1A1A',
              opacity: isLit ? 1 : 0.3,
              boxShadow: isLit ? `0 0 4px ${bgColor}44` : undefined,
              transition: 'opacity 0.05s ease',
            }}
          />
        )
      })}
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  (Volume fader is inline in layer cards)                             */
/* ------------------------------------------------------------------ */

/* ------------------------------------------------------------------ */
/*  Main Looper Component                                               */
/* ------------------------------------------------------------------ */

export default function Looper() {
  const bpm = useAppStore((s) => s.bpm)
  const timeSig = useAppStore((s) => s.timeSig)

  /* ---- state ---- */
  const [layers, setLayers] = useState<Layer[]>([])
  const [recordingState, setRecordingState] = useState<RecordingState>('IDLE')
  const [activeLayerIdx, setActiveLayerIdx] = useState<number>(-1)
  const [inputLevel, setInputLevel] = useState(0)
  const [elapsed, setElapsed] = useState(0)
  const [quantize, setQuantize] = useState(true)
  const [clickEnabled, setClickEnabled] = useState(false)
  const [exporting, setExporting] = useState(false)
  const [exportProgress, setExportProgress] = useState(0)

  /* ---- undo/redo ---- */
  const [undoStack, setUndoStack] = useState<HistoryEntry[]>([])
  const [redoStack, setRedoStack] = useState<HistoryEntry[]>([])

  /* ---- audio refs ---- */
  const micRef = useRef<Tone.UserMedia | null>(null)
  const recorderRef = useRef<Tone.Recorder | null>(null)
  const meterRef = useRef<Tone.Meter | null>(null)
  const startTimeRef = useRef(0)
  const timerRef = useRef<number>(0)
  const playersRef = useRef<Map<string, Tone.Player>>(new Map())
  const soloActiveRef = useRef(false)
  const playStartTimeRef = useRef(0)

  /* ---- click/metronome refs ---- */
  const clickSynthRef = useRef<Tone.Synth | null>(null)
  const clickLoopRef = useRef<Tone.Loop | null>(null)

  /* ---- derived ---- */
  const hasSolo = useMemo(() => layers.some((l) => l.solo), [layers])
  soloActiveRef.current = hasSolo

  /** Longest layer duration for loop progress ring */
  const loopDuration = useMemo(() => {
    let maxDur = 0
    for (const l of layers) {
      if (l.buffer && l.buffer.duration > maxDur) {
        maxDur = l.buffer.duration
      }
    }
    return maxDur
  }, [layers])

  /** Progress for the ring (0..1) */
  const [ringProgress, setRingProgress] = useState(0)

  useEffect(() => {
    if (recordingState !== 'PLAYING' && recordingState !== 'OVERDUBBING') {
      // During recording, show pulsing full ring via elapsed
      if (recordingState === 'RECORDING') {
        // pulse 0..1 based on elapsed modulo a short cycle
        const beatDur = 60 / bpm
        setRingProgress((elapsed % beatDur) / beatDur)
      } else {
        setRingProgress(0)
      }
      return
    }
    if (loopDuration <= 0) return

    let running = true
    const tick = () => {
      if (!running) return
      const e = (Tone.now() - playStartTimeRef.current) % loopDuration
      setRingProgress(e / loopDuration)
      requestAnimationFrame(tick)
    }
    requestAnimationFrame(tick)

    return () => {
      running = false
    }
  }, [recordingState, loopDuration, elapsed, bpm])

  const statusText = useMemo(() => {
    switch (recordingState) {
      case 'IDLE':
        return layers.length === 0 ? 'Tap REC to start' : 'Stopped'
      case 'RECORDING':
        return 'Recording...'
      case 'PLAYING':
        return 'Playing'
      case 'OVERDUBBING':
        return 'Overdubbing...'
    }
  }, [recordingState, layers.length])

  /* ---- cleanup ---- */
  useEffect(() => {
    return () => {
      // eslint-disable-next-line react-hooks/exhaustive-deps
      micRef.current?.close()
      recorderRef.current?.dispose()
      meterRef.current?.dispose()
      playersRef.current.forEach((p) => { p.stop(); p.dispose() })
      clearInterval(timerRef.current)
      clickSynthRef.current?.dispose()
      clickLoopRef.current?.dispose()
      Tone.getTransport().stop()
    }
  }, [])

  /* ---- mic level polling ---- */
  useEffect(() => {
    if (recordingState !== 'RECORDING' && recordingState !== 'OVERDUBBING') {
      setInputLevel(0)
      return
    }
    const id = setInterval(() => {
      if (meterRef.current) {
        const db = meterRef.current.getValue()
        const val = typeof db === 'number' ? db : (db as number[])[0]
        // map -60..0 dB to 0..1
        const norm = Math.max(0, Math.min(1, (val + 60) / 60))
        setInputLevel(norm)
      }
    }, 50)
    return () => clearInterval(id)
  }, [recordingState])

  /* ---- click / metronome management ---- */
  const startClick = useCallback(() => {
    if (!clickEnabled) return

    const transport = Tone.getTransport()
    transport.bpm.value = bpm

    if (!clickSynthRef.current) {
      clickSynthRef.current = new Tone.Synth({
        oscillator: { type: 'triangle' },
        envelope: { attack: 0.001, decay: 0.05, sustain: 0, release: 0.01 },
        volume: -12,
      }).toDestination()
    }

    let beatCount = 0
    if (clickLoopRef.current) {
      clickLoopRef.current.dispose()
    }
    clickLoopRef.current = new Tone.Loop((time) => {
      const isAccent = beatCount % timeSig[0] === 0
      clickSynthRef.current?.triggerAttackRelease(
        isAccent ? 'C6' : 'G5',
        '32n',
        time,
      )
      beatCount++
    }, `${timeSig[1]}n`)

    clickLoopRef.current.start(0)
    transport.start()
  }, [clickEnabled, bpm, timeSig])

  const stopClick = useCallback(() => {
    clickLoopRef.current?.stop()
    clickLoopRef.current?.dispose()
    clickLoopRef.current = null
    Tone.getTransport().stop()
    Tone.getTransport().cancel()
  }, [])

  /* ---- ensure mic + recorder ---- */
  const ensureAudio = useCallback(async () => {
    await Tone.start()

    if (!micRef.current) {
      const mic = new Tone.UserMedia()
      await mic.open()
      micRef.current = mic
    }

    if (!recorderRef.current) {
      recorderRef.current = new Tone.Recorder()
    }

    if (!meterRef.current) {
      meterRef.current = new Tone.Meter({ smoothing: 0.8 })
    }

    micRef.current.connect(recorderRef.current)
    micRef.current.connect(meterRef.current)
  }, [])

  /* ---- sync player volumes / mute / solo ---- */
  const syncPlayers = useCallback(
    (updatedLayers: Layer[]) => {
      const anySolo = updatedLayers.some((l) => l.solo)
      for (const l of updatedLayers) {
        const p = playersRef.current.get(l.id)
        if (!p) continue
        const audible = anySolo ? l.solo && !l.muted : !l.muted
        p.volume.value = audible ? Tone.gainToDb(l.volume) : -Infinity
      }
    },
    [],
  )

  /* ---- play all layers ---- */
  const playAll = useCallback(
    (layerList: Layer[]) => {
      Tone.getTransport().stop()
      Tone.getTransport().cancel()

      playersRef.current.forEach((p) => { p.stop(); p.dispose() })
      playersRef.current.clear()

      for (const l of layerList) {
        if (!l.buffer) continue
        const toneBuffer = new Tone.ToneAudioBuffer(l.buffer)
        const player = new Tone.Player(toneBuffer).toDestination()
        player.loop = true
        player.autostart = false
        playersRef.current.set(l.id, player)
        l.player = player
      }

      syncPlayers(layerList)

      // start all together
      const now = Tone.now() + 0.05
      playStartTimeRef.current = now
      playersRef.current.forEach((p) => p.start(now))
    },
    [syncPlayers],
  )

  /* ---- stop all ---- */
  const stopAll = useCallback(() => {
    playersRef.current.forEach((p) => p.stop())
    clearInterval(timerRef.current)
    setElapsed(0)
    setRecordingState('IDLE')
    stopClick()
  }, [stopClick])

  /* ---- finalise recorded blob -> AudioBuffer -> layer ---- */
  const finaliseRecording = useCallback(
    async (overdubLayerId?: string) => {
      if (!recorderRef.current || recorderRef.current.state !== 'started') return

      const blob = await recorderRef.current.stop()
      const arrayBuf = await blob.arrayBuffer()
      const audioBuf = await Tone.getContext().rawContext.decodeAudioData(arrayBuf)

      clearInterval(timerRef.current)
      stopClick()

      // quantise
      let finalBuf = audioBuf
      if (quantize) {
        const qDur = quantiseDuration(audioBuf.duration, bpm, timeSig[0])
        if (Math.abs(qDur - audioBuf.duration) > 0.01) {
          const ctx = Tone.getContext().rawContext
          const qBuf = ctx.createBuffer(
            audioBuf.numberOfChannels,
            Math.round(qDur * audioBuf.sampleRate),
            audioBuf.sampleRate,
          )
          for (let ch = 0; ch < audioBuf.numberOfChannels; ch++) {
            const src = audioBuf.getChannelData(ch)
            const dst = qBuf.getChannelData(ch)
            const len = Math.min(src.length, dst.length)
            dst.set(src.subarray(0, len))
          }
          finalBuf = qBuf
        }
      }

      const peaks = extractPeaks(finalBuf, PEAK_BUCKETS)

      if (overdubLayerId) {
        // overdub: mix into existing layer
        setLayers((prev) => {
          const idx = prev.findIndex((l) => l.id === overdubLayerId)
          if (idx === -1) return prev

          const existing = prev[idx]
          // push undo before modifying
          setUndoStack((u) => [...u, { layerId: existing.id, buffer: existing.buffer, peaks: existing.peaks }])
          setRedoStack([])

          // mix buffers
          const ctx = Tone.getContext().rawContext
          const maxLen = Math.max(existing.buffer?.length ?? 0, finalBuf.length)
          const sr = finalBuf.sampleRate
          const mixed = ctx.createBuffer(1, maxLen, sr)
          const out = mixed.getChannelData(0)

          if (existing.buffer) {
            const old = existing.buffer.getChannelData(0)
            for (let i = 0; i < old.length; i++) out[i] = old[i]
          }
          const newData = finalBuf.getChannelData(0)
          for (let i = 0; i < newData.length; i++) {
            out[i] = (out[i] || 0) + newData[i]
          }

          // clip
          for (let i = 0; i < out.length; i++) {
            out[i] = Math.max(-1, Math.min(1, out[i]))
          }

          const mixedPeaks = extractPeaks(mixed, PEAK_BUCKETS)
          const updated = [...prev]
          updated[idx] = { ...existing, buffer: mixed, peaks: mixedPeaks }

          playAll(updated)
          return updated
        })
        setRecordingState('PLAYING')
      } else {
        // new layer
        setLayers((prev) => {
          if (prev.length >= MAX_LAYERS) return prev
          const newLayer: Layer = {
            id: uid(),
            name: `Layer ${prev.length + 1}`,
            buffer: finalBuf,
            player: null,
            muted: false,
            solo: false,
            volume: 0.8,
            peaks,
          }
          const updated = [...prev, newLayer]
          setActiveLayerIdx(updated.length - 1)
          playAll(updated)
          return updated
        })
        setRecordingState('PLAYING')
      }
    },
    [bpm, timeSig, quantize, playAll, stopClick],
  )

  /* ---- REC button ---- */
  const handleRec = useCallback(async () => {
    if (layers.length >= MAX_LAYERS && recordingState === 'IDLE') return

    switch (recordingState) {
      case 'IDLE': {
        await ensureAudio()
        recorderRef.current!.start()
        startTimeRef.current = Date.now()
        timerRef.current = window.setInterval(() => {
          setElapsed((Date.now() - startTimeRef.current) / 1000)
        }, 100)
        setRecordingState('RECORDING')
        startClick()
        break
      }
      case 'RECORDING': {
        await finaliseRecording()
        break
      }
      case 'PLAYING': {
        // start recording a new layer while playing
        if (layers.length >= MAX_LAYERS) return
        await ensureAudio()
        recorderRef.current!.start()
        startTimeRef.current = Date.now()
        timerRef.current = window.setInterval(() => {
          setElapsed((Date.now() - startTimeRef.current) / 1000)
        }, 100)
        setRecordingState('RECORDING')
        startClick()
        break
      }
      case 'OVERDUBBING': {
        await finaliseRecording(layers[activeLayerIdx]?.id)
        break
      }
    }
  }, [recordingState, layers, activeLayerIdx, ensureAudio, finaliseRecording, startClick])

  /* ---- Play / Stop ---- */
  const handlePlayStop = useCallback(() => {
    if (recordingState === 'PLAYING') {
      stopAll()
    } else if (recordingState === 'IDLE' && layers.length > 0) {
      playAll(layers)
      setRecordingState('PLAYING')
    }
  }, [recordingState, layers, playAll, stopAll])

  /* ---- Overdub ---- */
  const handleOverdub = useCallback(async () => {
    if (layers.length === 0 || activeLayerIdx < 0) return
    if (recordingState === 'OVERDUBBING') {
      await finaliseRecording(layers[activeLayerIdx]?.id)
      return
    }
    if (recordingState !== 'PLAYING') return

    await ensureAudio()
    recorderRef.current!.start()
    startTimeRef.current = Date.now()
    timerRef.current = window.setInterval(() => {
      setElapsed((Date.now() - startTimeRef.current) / 1000)
    }, 100)
    setRecordingState('OVERDUBBING')
    startClick()
  }, [recordingState, layers, activeLayerIdx, ensureAudio, finaliseRecording, startClick])

  /* ---- Layer controls ---- */
  const toggleMute = useCallback(
    (id: string) => {
      setLayers((prev) => {
        const updated = prev.map((l) =>
          l.id === id ? { ...l, muted: !l.muted } : l,
        )
        syncPlayers(updated)
        return updated
      })
    },
    [syncPlayers],
  )

  const toggleSolo = useCallback(
    (id: string) => {
      setLayers((prev) => {
        const updated = prev.map((l) =>
          l.id === id ? { ...l, solo: !l.solo } : l,
        )
        syncPlayers(updated)
        return updated
      })
    },
    [syncPlayers],
  )

  const setVolume = useCallback(
    (id: string, vol: number) => {
      setLayers((prev) => {
        const updated = prev.map((l) =>
          l.id === id ? { ...l, volume: vol } : l,
        )
        syncPlayers(updated)
        return updated
      })
    },
    [syncPlayers],
  )

  const deleteLayer = useCallback(
    (id: string) => {
      const player = playersRef.current.get(id)
      if (player) {
        player.stop()
        player.dispose()
        playersRef.current.delete(id)
      }
      setLayers((prev) => {
        const updated = prev.filter((l) => l.id !== id)
        if (updated.length === 0) {
          stopAll()
        }
        return updated
      })
      setActiveLayerIdx((idx) => Math.max(0, idx - 1))
    },
    [stopAll],
  )

  /* ---- Undo / Redo ---- */
  const handleUndo = useCallback(() => {
    if (undoStack.length === 0) return
    const entry = undoStack[undoStack.length - 1]
    setUndoStack((u) => u.slice(0, -1))

    setLayers((prev) => {
      const idx = prev.findIndex((l) => l.id === entry.layerId)
      if (idx === -1) return prev
      const current = prev[idx]
      setRedoStack((r) => [...r, { layerId: current.id, buffer: current.buffer, peaks: current.peaks }])
      const updated = [...prev]
      updated[idx] = { ...current, buffer: entry.buffer, peaks: entry.peaks }
      if (recordingState === 'PLAYING') playAll(updated)
      return updated
    })
  }, [undoStack, recordingState, playAll])

  const handleRedo = useCallback(() => {
    if (redoStack.length === 0) return
    const entry = redoStack[redoStack.length - 1]
    setRedoStack((r) => r.slice(0, -1))

    setLayers((prev) => {
      const idx = prev.findIndex((l) => l.id === entry.layerId)
      if (idx === -1) return prev
      const current = prev[idx]
      setUndoStack((u) => [...u, { layerId: current.id, buffer: current.buffer, peaks: current.peaks }])
      const updated = [...prev]
      updated[idx] = { ...current, buffer: entry.buffer, peaks: entry.peaks }
      if (recordingState === 'PLAYING') playAll(updated)
      return updated
    })
  }, [redoStack, recordingState, playAll])

  /* ---- Export ---- */
  const handleExport = useCallback(async () => {
    const unmutedLayers = layers.filter((l) => {
      const anySolo = layers.some((x) => x.solo)
      return anySolo ? l.solo && !l.muted : !l.muted
    })

    if (unmutedLayers.length === 0 || !unmutedLayers.some((l) => l.buffer)) return

    setExporting(true)
    setExportProgress(0)

    try {
      // Find the longest buffer
      let maxLength = 0
      let sampleRate = 44100
      for (const l of unmutedLayers) {
        if (l.buffer) {
          if (l.buffer.length > maxLength) maxLength = l.buffer.length
          sampleRate = l.buffer.sampleRate
        }
      }

      setExportProgress(0.2)

      // Use OfflineAudioContext to render the mix
      const offlineCtx = new OfflineAudioContext(1, maxLength, sampleRate)

      for (const l of unmutedLayers) {
        if (!l.buffer) continue
        const source = offlineCtx.createBufferSource()
        const gainNode = offlineCtx.createGain()
        source.buffer = l.buffer
        gainNode.gain.value = l.volume
        source.connect(gainNode)
        gainNode.connect(offlineCtx.destination)
        source.start(0)
      }

      setExportProgress(0.5)

      const renderedBuffer = await offlineCtx.startRendering()

      setExportProgress(0.8)

      // Convert to WAV
      const wavBlob = audioBufferToWav(renderedBuffer)

      setExportProgress(1.0)

      // Trigger download
      const url = URL.createObjectURL(wavBlob)
      const a = document.createElement('a')
      a.href = url
      a.download = `groovelab-loop-${Date.now()}.wav`
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(url)
    } catch (err) {
      console.error('Export failed:', err)
    } finally {
      setTimeout(() => {
        setExporting(false)
        setExportProgress(0)
      }, 600)
    }
  }, [layers])

  /* ================================================================ */
  /*  Render                                                           */
  /* ================================================================ */

  const isRecording = recordingState === 'RECORDING' || recordingState === 'OVERDUBBING'

  return (
    <div className="flex flex-col h-full text-white select-none overflow-y-auto" style={{ background: '#0A0A0A' }}>
      {/* Injected keyframes for recording pulse animation */}
      <style>{`
        @keyframes gl-rec-pulse {
          0%, 100% { box-shadow: 0 0 8px rgba(255,59,48,0.3), inset 0 0 4px rgba(255,59,48,0.05); border-color: rgba(255,59,48,0.5); }
          50% { box-shadow: 0 0 20px rgba(255,59,48,0.6), inset 0 0 8px rgba(255,59,48,0.1); border-color: rgba(255,59,48,0.8); }
        }
        @keyframes gl-overdub-pulse {
          0%, 100% { box-shadow: 0 0 8px rgba(255,149,0,0.3), inset 0 0 4px rgba(255,149,0,0.05); border-color: rgba(255,149,0,0.5); }
          50% { box-shadow: 0 0 20px rgba(255,149,0,0.6), inset 0 0 8px rgba(255,149,0,0.1); border-color: rgba(255,149,0,0.8); }
        }
        @keyframes gl-rec-dot-pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.3; }
        }
      `}</style>
      {/* ---- Header ---- */}
      <div
        className="flex items-center justify-between px-4 py-3 border-b"
        style={{ background: '#1A1A1A', borderColor: '#333' }}
      >
        <div>
          <h2 className="text-lg font-bold font-mono tracking-widest" style={{ color: '#00E5FF' }}>
            LOOPER
          </h2>
          <p className="text-xs font-mono" style={{ color: '#666' }}>{statusText}</p>
        </div>
        <div className="flex items-center gap-2">
          {/* Click toggle */}
          <button
            onClick={() => setClickEnabled(!clickEnabled)}
            className={cn(
              'px-2.5 py-1.5 text-[10px] font-mono font-bold rounded transition-all',
            )}
            style={{
              background: clickEnabled ? 'rgba(0,229,255,0.15)' : '#212121',
              color: clickEnabled ? '#00E5FF' : '#666',
              border: `1px solid ${clickEnabled ? 'rgba(0,229,255,0.4)' : '#333'}`,
            }}
          >
            CLICK
          </button>
          <span className="text-xs font-mono" style={{ color: '#666' }}>{bpm} BPM</span>
          <span className="text-[10px] font-mono" style={{ color: '#555' }}>{timeSig[0]}/{timeSig[1]}</span>
          <button
            onClick={() => setQuantize(!quantize)}
            className="px-2 py-1.5 text-[10px] font-mono font-bold rounded transition-all"
            style={{
              background: quantize ? 'rgba(0,229,255,0.15)' : '#212121',
              color: quantize ? '#00E5FF' : '#666',
              border: `1px solid ${quantize ? 'rgba(0,229,255,0.4)' : '#333'}`,
            }}
          >
            QUANTIZE
          </button>
          <button
            onClick={handleUndo}
            disabled={undoStack.length === 0}
            className="px-2 py-1.5 text-[10px] font-mono font-bold rounded transition-all"
            style={{
              background: '#212121',
              color: undoStack.length > 0 ? '#ccc' : '#444',
              border: '1px solid #333',
              cursor: undoStack.length === 0 ? 'not-allowed' : 'pointer',
              opacity: undoStack.length === 0 ? 0.5 : 1,
            }}
          >
            UNDO
          </button>
          <button
            onClick={handleRedo}
            disabled={redoStack.length === 0}
            className="px-2 py-1.5 text-[10px] font-mono font-bold rounded transition-all"
            style={{
              background: '#212121',
              color: redoStack.length > 0 ? '#ccc' : '#444',
              border: '1px solid #333',
              cursor: redoStack.length === 0 ? 'not-allowed' : 'pointer',
              opacity: redoStack.length === 0 ? 0.5 : 1,
            }}
          >
            REDO
          </button>
          {/* Export */}
          <button
            onClick={handleExport}
            disabled={layers.length === 0 || exporting}
            className="px-2.5 py-1.5 text-[10px] font-mono font-bold rounded transition-all relative overflow-hidden"
            style={{
              background: exporting ? 'rgba(191,90,242,0.2)' : '#212121',
              color: layers.length > 0 ? '#BF5AF2' : '#444',
              border: `1px solid ${exporting ? 'rgba(191,90,242,0.4)' : '#333'}`,
              cursor: layers.length === 0 || exporting ? 'not-allowed' : 'pointer',
              opacity: layers.length === 0 ? 0.5 : 1,
            }}
          >
            {exporting && (
              <div
                className="absolute inset-0"
                style={{
                  background: 'rgba(191,90,242,0.15)',
                  width: `${exportProgress * 100}%`,
                  transition: 'width 0.3s ease',
                }}
              />
            )}
            <span className="relative z-10">{exporting ? 'EXPORTING...' : 'EXPORT'}</span>
          </button>
        </div>
      </div>

      {/* ---- Circular Progress Ring + Transport ---- */}
      <div
        className="flex items-center justify-center gap-8 py-8"
        style={{ background: '#121212' }}
      >
        {/* Input level meter (left) */}
        <LevelMeter level={inputLevel} />

        {/* Play / Stop */}
        <button
          onClick={handlePlayStop}
          disabled={layers.length === 0 && recordingState === 'IDLE'}
          className="transition-all active:scale-95"
          style={{
            width: 64,
            height: 64,
            borderRadius: 16,
            background:
              recordingState === 'PLAYING'
                ? 'linear-gradient(145deg, #1a3a1a, #0d1f0d)'
                : 'linear-gradient(145deg, #2a2a2a, #1a1a1a)',
            border:
              recordingState === 'PLAYING'
                ? '2px solid #00FF11'
                : '1px solid #444',
            boxShadow:
              recordingState === 'PLAYING'
                ? '0 0 20px rgba(0,255,17,0.3), inset 0 1px 0 rgba(255,255,255,0.05)'
                : '4px 4px 8px #0a0a0a, -2px -2px 6px #2a2a2a, inset 0 1px 0 rgba(255,255,255,0.05)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: layers.length === 0 && recordingState === 'IDLE' ? 'not-allowed' : 'pointer',
            opacity: layers.length === 0 && recordingState === 'IDLE' ? 0.35 : 1,
          }}
        >
          {recordingState === 'PLAYING' ? (
            <div style={{ width: 20, height: 20, borderRadius: 3, background: '#fff' }} />
          ) : (
            <div
              style={{
                width: 0,
                height: 0,
                marginLeft: 4,
                borderLeft: '16px solid white',
                borderTop: '11px solid transparent',
                borderBottom: '11px solid transparent',
              }}
            />
          )}
        </button>

        {/* Circular ring + REC */}
        <div className="relative">
          <CircularProgressRing
            progress={ringProgress}
            state={recordingState}
            elapsed={elapsed}
          />
          {/* Loop duration in bars/beats */}
          {loopDuration > 0 && (
            <div
              className="absolute left-1/2 -translate-x-1/2 flex items-center gap-1 whitespace-nowrap"
              style={{ top: -18 }}
            >
              {(() => {
                const barLen = (60 / bpm) * timeSig[0]
                const bars = Math.max(1, Math.round(loopDuration / barLen))
                const beats = Math.round(loopDuration / (60 / bpm))
                return (
                  <>
                    <span className="text-[9px] font-mono font-bold" style={{ color: '#00E5FF' }}>
                      {bars} {bars === 1 ? 'bar' : 'bars'}
                    </span>
                    <span className="text-[9px] font-mono" style={{ color: '#555' }}>
                      ({beats} beats / {loopDuration.toFixed(1)}s)
                    </span>
                  </>
                )
              })()}
            </div>
          )}
          {/* REC button overlaid at the bottom of the ring */}
          <button
            onClick={handleRec}
            disabled={layers.length >= MAX_LAYERS && recordingState === 'IDLE'}
            className="absolute transition-all active:scale-95"
            style={{
              bottom: -16,
              left: '50%',
              transform: 'translateX(-50%)',
              width: 48,
              height: 48,
              borderRadius: '50%',
              background: isRecording
                ? 'radial-gradient(circle, #FF3B30, #CC2200)'
                : 'linear-gradient(145deg, #3a3a3a, #222)',
              border: isRecording
                ? '3px solid #FF6B60'
                : '3px solid #555',
              boxShadow: isRecording
                ? '0 0 24px rgba(255,59,48,0.6), 0 0 48px rgba(255,59,48,0.3)'
                : '3px 3px 6px #0a0a0a, -1px -1px 4px #333, inset 0 1px 0 rgba(255,255,255,0.1)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: layers.length >= MAX_LAYERS && recordingState === 'IDLE' ? 'not-allowed' : 'pointer',
              opacity: layers.length >= MAX_LAYERS && recordingState === 'IDLE' ? 0.35 : 1,
            }}
          >
            {isRecording ? (
              <div style={{ width: 16, height: 16, borderRadius: 3, background: '#fff' }} />
            ) : (
              <div style={{ width: 20, height: 20, borderRadius: '50%', background: '#FF3B30' }} />
            )}
          </button>
        </div>

        {/* Overdub */}
        <button
          onClick={handleOverdub}
          disabled={layers.length === 0 || (recordingState !== 'PLAYING' && recordingState !== 'OVERDUBBING')}
          className="transition-all active:scale-95"
          style={{
            width: 64,
            height: 64,
            borderRadius: 16,
            background:
              recordingState === 'OVERDUBBING'
                ? 'linear-gradient(145deg, #3a2a0a, #1f1500)'
                : 'linear-gradient(145deg, #2a2a2a, #1a1a1a)',
            border:
              recordingState === 'OVERDUBBING'
                ? '2px solid #FF9500'
                : '1px solid #444',
            boxShadow:
              recordingState === 'OVERDUBBING'
                ? '0 0 20px rgba(255,149,0,0.3), inset 0 1px 0 rgba(255,255,255,0.05)'
                : '4px 4px 8px #0a0a0a, -2px -2px 6px #2a2a2a, inset 0 1px 0 rgba(255,255,255,0.05)',
            display: 'flex',
            flexDirection: 'column' as const,
            alignItems: 'center',
            justifyContent: 'center',
            gap: 4,
            cursor:
              layers.length === 0 || (recordingState !== 'PLAYING' && recordingState !== 'OVERDUBBING')
                ? 'not-allowed'
                : 'pointer',
            opacity:
              layers.length === 0 || (recordingState !== 'PLAYING' && recordingState !== 'OVERDUBBING')
                ? 0.35
                : 1,
          }}
        >
          {/* Stacked layers icon */}
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path d="M12 2L2 7l10 5 10-5-10-5z" stroke={recordingState === 'OVERDUBBING' ? '#FF9500' : '#888'} strokeWidth="1.5" fill="none" />
            <path d="M2 12l10 5 10-5" stroke={recordingState === 'OVERDUBBING' ? '#FF9500' : '#888'} strokeWidth="1.5" />
            <path d="M2 17l10 5 10-5" stroke={recordingState === 'OVERDUBBING' ? '#FF9500' : '#888'} strokeWidth="1.5" />
          </svg>
          <span style={{ fontSize: 9, fontFamily: 'monospace', color: '#888' }}>OVR</span>
        </button>

        {/* Input level meter (right) */}
        <LevelMeter level={inputLevel} />
      </div>

      {/* ---- Recording timer bar ---- */}
      {isRecording && (
        <div
          className="flex items-center justify-center gap-3 py-2"
          style={{
            background: recordingState === 'OVERDUBBING' ? 'rgba(255,149,0,0.08)' : 'rgba(255,59,48,0.08)',
            borderTop: `1px solid ${recordingState === 'OVERDUBBING' ? 'rgba(255,149,0,0.2)' : 'rgba(255,59,48,0.2)'}`,
            borderBottom: `1px solid ${recordingState === 'OVERDUBBING' ? 'rgba(255,149,0,0.2)' : 'rgba(255,59,48,0.2)'}`,
          }}
        >
          <div
            className="w-2 h-2 rounded-full animate-pulse"
            style={{ background: recordingState === 'OVERDUBBING' ? '#FF9500' : '#FF3B30' }}
          />
          <span className="text-xs font-mono" style={{ color: recordingState === 'OVERDUBBING' ? '#FF9500' : '#FF3B30' }}>
            {recordingState === 'OVERDUBBING' ? 'OVERDUB' : 'REC'} {fmtTime(elapsed)}
          </span>
          <span className="text-xs font-mono" style={{ color: '#666' }}>
            Layer {recordingState === 'OVERDUBBING' ? activeLayerIdx + 1 : layers.length + 1} / {MAX_LAYERS}
          </span>
          {clickEnabled && (
            <span className="text-[10px] font-mono" style={{ color: '#00E5FF' }}>
              CLICK ON
            </span>
          )}
        </div>
      )}

      {/* ---- Layer List ---- */}
      <div className="flex-1 overflow-y-auto px-3 py-3 space-y-2">
        {layers.length === 0 && (
          <div className="flex flex-col items-center justify-center h-48 gap-4">
            {/* Pulsing microphone icon */}
            <div
              className="animate-pulse flex items-center justify-center rounded-full"
              style={{
                width: 64,
                height: 64,
                background: 'radial-gradient(circle, rgba(255,59,48,0.12) 0%, transparent 70%)',
                border: '1px solid rgba(255,59,48,0.18)',
              }}
            >
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#FF3B30" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                <rect x="9" y="2" width="6" height="12" rx="3" />
                <path d="M5 10a7 7 0 0 0 14 0" />
                <line x1="12" y1="17" x2="12" y2="22" />
                <line x1="8" y1="22" x2="16" y2="22" />
              </svg>
            </div>
            <span className="text-sm font-mono font-bold" style={{ color: '#666' }}>
              Tap REC to start your first loop
            </span>
            <span className="text-[10px] font-mono" style={{ color: '#444' }}>
              Record up to {MAX_LAYERS} layers with overdub, mute, and solo
            </span>
          </div>
        )}

        {layers.map((layer, idx) => {
          const isActive = idx === activeLayerIdx
          const isAudible = hasSolo ? layer.solo && !layer.muted : !layer.muted
          const accentColor = LAYER_COLORS[idx % LAYER_COLORS.length]
          const isRecordingThisLayer = isActive && recordingState === 'RECORDING'
          const isOverdubbingThisLayer = isActive && recordingState === 'OVERDUBBING'
          const isLayerRecActive = isRecordingThisLayer || isOverdubbingThisLayer

          return (
            <div
              key={layer.id}
              onClick={() => setActiveLayerIdx(idx)}
              className="flex rounded-xl overflow-hidden transition-all cursor-pointer"
              style={{
                background: isActive ? '#212121' : '#1A1A1A',
                border: isLayerRecActive
                  ? `1px solid ${isOverdubbingThisLayer ? 'rgba(255,149,0,0.6)' : 'rgba(255,59,48,0.6)'}`
                  : isActive ? `1px solid ${accentColor}44` : '1px solid #2a2a2a',
                boxShadow: isActive ? `0 0 12px ${accentColor}11` : undefined,
                animation: isLayerRecActive
                  ? `${isOverdubbingThisLayer ? 'gl-overdub-pulse' : 'gl-rec-pulse'} 1.2s ease-in-out infinite`
                  : undefined,
              }}
            >
              {/* Colored accent bar */}
              <div
                className="w-1.5 shrink-0"
                style={{
                  background: `linear-gradient(to bottom, ${accentColor}, ${accentColor}66)`,
                  boxShadow: `0 0 8px ${accentColor}33`,
                }}
              />

              <div className="flex-1 p-3">
                {/* Layer header */}
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    {/* Layer number badge */}
                    <div
                      className="w-6 h-6 rounded-md flex items-center justify-center text-[10px] font-mono font-bold"
                      style={{
                        background: `${accentColor}22`,
                        color: accentColor,
                        border: `1px solid ${accentColor}44`,
                      }}
                    >
                      {idx + 1}
                    </div>
                    <span
                      className="text-xs font-mono font-bold"
                      style={{ color: isAudible ? accentColor : '#555' }}
                    >
                      {layer.name}
                    </span>
                    {layer.buffer && (
                      <span className="text-[10px] font-mono" style={{ color: '#555' }}>
                        {fmtTime(layer.buffer.duration)}
                      </span>
                    )}
                    {/* Recording state badge */}
                    {isLayerRecActive && (
                      <span
                        className="text-[9px] font-mono font-black px-1.5 py-0.5 rounded-sm tracking-wider"
                        style={{
                          background: isOverdubbingThisLayer ? 'rgba(255,149,0,0.18)' : 'rgba(255,59,48,0.18)',
                          color: isOverdubbingThisLayer ? '#FF9500' : '#FF3B30',
                          border: `1px solid ${isOverdubbingThisLayer ? 'rgba(255,149,0,0.35)' : 'rgba(255,59,48,0.35)'}`,
                        }}
                      >
                        {isOverdubbingThisLayer ? 'OVERDUB' : 'REC'}
                      </span>
                    )}
                    {!isLayerRecActive && isActive && recordingState === 'PLAYING' && (
                      <span
                        className="text-[9px] font-mono font-black px-1.5 py-0.5 rounded-sm tracking-wider"
                        style={{
                          background: 'rgba(0,255,17,0.12)',
                          color: '#00FF11',
                          border: '1px solid rgba(0,255,17,0.25)',
                        }}
                      >
                        PLAY
                      </span>
                    )}
                    {/* Recording duration indicator */}
                    {isLayerRecActive && (
                      <span className="text-[10px] font-mono" style={{ color: isOverdubbingThisLayer ? '#FF9500' : '#FF3B30' }}>
                        {fmtTime(elapsed)}
                      </span>
                    )}
                  </div>

                  <div className="flex items-center gap-1.5">
                    {/* Mute - LED-lit toggle */}
                    <button
                      onClick={(e) => {
                        e.stopPropagation()
                        toggleMute(layer.id)
                      }}
                      className="transition-all active:scale-95"
                      style={{
                        width: 28,
                        height: 28,
                        borderRadius: 6,
                        fontSize: 10,
                        fontWeight: 800,
                        fontFamily: 'monospace',
                        background: layer.muted
                          ? 'linear-gradient(145deg, #3a1515, #2a0a0a)'
                          : 'linear-gradient(145deg, #2a2a2a, #1a1a1a)',
                        color: layer.muted ? '#FF3B30' : '#666',
                        border: `1px solid ${layer.muted ? '#FF3B3066' : '#333'}`,
                        boxShadow: layer.muted
                          ? '0 0 8px rgba(255,59,48,0.3), inset 0 0 4px rgba(255,59,48,0.1)'
                          : 'inset 0 1px 0 rgba(255,255,255,0.05)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      M
                    </button>

                    {/* Solo - LED-lit toggle */}
                    <button
                      onClick={(e) => {
                        e.stopPropagation()
                        toggleSolo(layer.id)
                      }}
                      className="transition-all active:scale-95"
                      style={{
                        width: 28,
                        height: 28,
                        borderRadius: 6,
                        fontSize: 10,
                        fontWeight: 800,
                        fontFamily: 'monospace',
                        background: layer.solo
                          ? 'linear-gradient(145deg, #3a3515, #2a250a)'
                          : 'linear-gradient(145deg, #2a2a2a, #1a1a1a)',
                        color: layer.solo ? '#FACC15' : '#666',
                        border: `1px solid ${layer.solo ? '#FACC1566' : '#333'}`,
                        boxShadow: layer.solo
                          ? '0 0 8px rgba(250,204,21,0.3), inset 0 0 4px rgba(250,204,21,0.1)'
                          : 'inset 0 1px 0 rgba(255,255,255,0.05)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      S
                    </button>

                    {/* Delete */}
                    <button
                      onClick={(e) => {
                        e.stopPropagation()
                        deleteLayer(layer.id)
                      }}
                      className="transition-all active:scale-95 hover:border-red-500/40"
                      style={{
                        width: 28,
                        height: 28,
                        borderRadius: 6,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        background: 'linear-gradient(145deg, #2a2a2a, #1a1a1a)',
                        color: '#555',
                        border: '1px solid #333',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      &times;
                    </button>
                  </div>
                </div>

                {/* Waveform with gradient fill and animated playhead */}
                <Waveform
                  peaks={layer.peaks}
                  playing={recordingState === 'PLAYING' || recordingState === 'OVERDUBBING'}
                  color={accentColor}
                  loopDuration={layer.buffer?.duration ?? 0}
                  playStartTime={playStartTimeRef.current}
                />

                {/* Volume fader row */}
                <div className="flex items-center gap-3 mt-2">
                  <span className="text-[9px] font-mono font-bold" style={{ color: '#555', width: 24 }}>VOL</span>
                  {/* Horizontal fader styled as hardware mixer */}
                  <div
                    className="flex-1 relative h-6 rounded cursor-pointer"
                    style={{ background: '#0A0A0A', border: '1px solid #333' }}
                    onClick={(e) => {
                      e.stopPropagation()
                      const rect = e.currentTarget.getBoundingClientRect()
                      const x = e.clientX - rect.left
                      const ratio = Math.max(0, Math.min(1, x / rect.width))
                      setVolume(layer.id, Math.round(ratio * 100) / 100)
                    }}
                  >
                    {/* Fill */}
                    <div
                      className="absolute inset-y-0 left-0 rounded-l"
                      style={{
                        width: `${layer.volume * 100}%`,
                        background: `linear-gradient(to right, ${accentColor}33, ${accentColor}22)`,
                      }}
                    />
                    {/* Groove marks */}
                    {[0.25, 0.5, 0.75].map((mark) => (
                      <div
                        key={mark}
                        className="absolute top-1 bottom-1 w-[1px]"
                        style={{ left: `${mark * 100}%`, background: '#333' }}
                      />
                    ))}
                    {/* Fader knob */}
                    <div
                      className="absolute top-0 bottom-0 flex items-center"
                      style={{
                        left: `calc(${layer.volume * 100}% - 8px)`,
                        pointerEvents: 'none',
                      }}
                    >
                      <div
                        style={{
                          width: 16,
                          height: 20,
                          borderRadius: 3,
                          background: 'linear-gradient(to bottom, #666, #444, #555)',
                          border: '1px solid #777',
                          boxShadow: '0 1px 4px rgba(0,0,0,0.5), inset 0 1px 0 rgba(255,255,255,0.15)',
                          display: 'flex',
                          flexDirection: 'column' as const,
                          alignItems: 'center',
                          justifyContent: 'center',
                          gap: 2,
                        }}
                      >
                        <div style={{ width: 8, height: 1, background: '#999' }} />
                        <div style={{ width: 8, height: 1, background: '#999' }} />
                      </div>
                    </div>
                  </div>
                  <span className="text-[9px] font-mono" style={{ color: '#555', width: 32, textAlign: 'right' }}>
                    {Math.round(layer.volume * 100)}%
                  </span>
                  <span className="text-[8px] font-mono" style={{ color: '#444', width: 36, textAlign: 'right' }}>
                    {layer.volume > 0 ? `${(20 * Math.log10(layer.volume)).toFixed(1)} dB` : '-inf'}
                  </span>
                  {/* Pulsing red dot when this layer is being overdubbed */}
                  {isOverdubbingThisLayer && (
                    <div
                      className="w-2 h-2 rounded-full ml-1"
                      style={{
                        background: '#FF3B30',
                        animation: 'gl-rec-dot-pulse 0.8s ease-in-out infinite',
                        boxShadow: '0 0 6px rgba(255,59,48,0.6)',
                      }}
                    />
                  )}
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* ---- Footer ---- */}
      <div
        className="flex items-center justify-between px-4 py-2 border-t"
        style={{ background: '#1A1A1A', borderColor: '#333' }}
      >
        <span className="text-[10px] font-mono" style={{ color: '#555' }}>
          {layers.length}/{MAX_LAYERS} layers
        </span>
        <span className="text-[10px] font-mono" style={{ color: '#555' }}>
          {quantize ? `Quantized to ${timeSig[0]}/${timeSig[1]}` : 'Free length'}
        </span>
      </div>
    </div>
  )
}
