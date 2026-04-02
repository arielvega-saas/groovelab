import { useState, useEffect, useCallback, useRef } from 'react'
import * as Tone from 'tone'
import { useAppStore } from '@/stores/app-store'
import { cn } from '@/lib/cn'
import { HardwarePanel } from '@/components/ui/HardwarePanel'

/* ──────────────────────────── Types ──────────────────────────── */

type Subdivision = 'quarter' | 'eighth' | 'triplet' | 'sixteenth'

type ClickPreset = 'Wood' | 'Digital' | 'Hi-Hat' | 'Clave' | 'Cowbell' | 'Beep'

interface ClickConfig {
  freq: number
  accentFreq: number
  type: OscillatorType | 'noise'
  decay: number
}

const CLICK_PRESETS: Record<ClickPreset, ClickConfig> = {
  Wood:    { freq: 1000, accentFreq: 1500, type: 'sine',     decay: 0.03 },
  Digital: { freq: 800,  accentFreq: 1200, type: 'square',   decay: 0.02 },
  'Hi-Hat':{ freq: 0,    accentFreq: 0,    type: 'noise',    decay: 0.04 },
  Clave:   { freq: 2500, accentFreq: 3200, type: 'triangle', decay: 0.025 },
  Cowbell: { freq: 600,  accentFreq: 800,  type: 'square',   decay: 0.08 },
  Beep:    { freq: 440,  accentFreq: 660,  type: 'sine',     decay: 0.06 },
}

const TIME_SIGNATURES: [number, number][] = [
  [2, 4], [3, 4], [4, 4], [5, 4], [6, 8], [7, 8], [9, 8], [12, 8],
]

const SUBDIVISIONS: { key: Subdivision; label: string; divisions: number }[] = [
  { key: 'quarter',   label: '1/4', divisions: 1 },
  { key: 'eighth',    label: '1/8', divisions: 2 },
  { key: 'triplet',   label: 'Trip', divisions: 3 },
  { key: 'sixteenth', label: '1/16', divisions: 4 },
]

const TEMPO_PRESETS = [
  { name: 'Largo',    bpm: 50 },
  { name: 'Adagio',   bpm: 70 },
  { name: 'Andante',  bpm: 90 },
  { name: 'Moderato', bpm: 110 },
  { name: 'Allegro',  bpm: 130 },
  { name: 'Vivace',   bpm: 160 },
  { name: 'Presto',   bpm: 180 },
]

/* ──────────────────────────── Component ──────────────────────── */

export default function Metronome() {
  /* ── Global state ── */
  const bpm = useAppStore((s) => s.bpm)
  const setBpm = useAppStore((s) => s.setBpm)
  const isPlaying = useAppStore((s) => s.isPlaying)
  const setPlaying = useAppStore((s) => s.setPlaying)
  const timeSig = useAppStore((s) => s.timeSig)
  const setTimeSig = useAppStore((s) => s.setTimeSig)

  /* ── Local state ── */
  const [subdivision, setSubdivision] = useState<Subdivision>('quarter')
  const [clickSound, setClickSound] = useState<ClickPreset>('Wood')
  const [swing, setSwing] = useState(0)
  const [currentBeat, setCurrentBeat] = useState(-1)
  const [flash, setFlash] = useState(false)

  /* ── Tap tempo ── */
  const tapTimesRef = useRef<number[]>([])
  const TAP_WINDOW = 6
  const TAP_TIMEOUT = 2000

  /* ── Refs ── */
  const synthRef = useRef<Tone.Synth | null>(null)
  const noiseSynthRef = useRef<Tone.NoiseSynth | null>(null)
  const loopRef = useRef<Tone.Loop | null>(null)
  const beatIndexRef = useRef(0)
  const isPlayingRef = useRef(false)

  /* ── Knob drag ── */
  const knobDragging = useRef(false)
  const knobStartY = useRef(0)
  const knobStartBpm = useRef(0)

  const beatsPerMeasure = timeSig[0]
  const subdivisionsPerBeat = SUBDIVISIONS.find((s) => s.key === subdivision)?.divisions ?? 1

  /* ──────────────────── Audio Init & Cleanup ──────────────────── */

  useEffect(() => {
    const synth = new Tone.Synth({
      oscillator: { type: 'sine' },
      envelope: { attack: 0.001, decay: 0.03, sustain: 0, release: 0.01 },
      volume: -6,
    }).toDestination()

    const noiseSynth = new Tone.NoiseSynth({
      noise: { type: 'white' },
      envelope: { attack: 0.001, decay: 0.04, sustain: 0, release: 0.01 },
      volume: -6,
    }).toDestination()

    synthRef.current = synth
    noiseSynthRef.current = noiseSynth

    return () => {
      synth.dispose()
      noiseSynth.dispose()
      if (loopRef.current) {
        loopRef.current.dispose()
        loopRef.current = null
      }
      Tone.getTransport().stop()
      Tone.getTransport().cancel()
    }
  }, [])

  /* ──────────────────── Play click sound ──────────────────── */

  const playClick = useCallback(
    (time: number, isAccent: boolean, isSubdiv: boolean) => {
      const preset = CLICK_PRESETS[clickSound]

      if (preset.type === 'noise') {
        if (!noiseSynthRef.current) return
        noiseSynthRef.current.envelope.decay = isAccent ? preset.decay * 1.5 : isSubdiv ? preset.decay * 0.5 : preset.decay
        noiseSynthRef.current.volume.setValueAtTime(isAccent ? -3 : isSubdiv ? -18 : -8, time)
        noiseSynthRef.current.triggerAttackRelease(preset.decay, time)
      } else {
        if (!synthRef.current) return
        const freq = isAccent ? preset.accentFreq : preset.freq
        const vol = isAccent ? -3 : isSubdiv ? -18 : -8
        synthRef.current.oscillator.type = preset.type
        synthRef.current.envelope.decay = isAccent ? preset.decay * 1.5 : isSubdiv ? preset.decay * 0.5 : preset.decay
        synthRef.current.volume.setValueAtTime(vol, time)
        synthRef.current.triggerAttackRelease(freq, preset.decay, time)
      }
    },
    [clickSound],
  )

  /* ──────────────────── Transport Loop ──────────────────── */

  const scheduleLoop = useCallback(() => {
    if (loopRef.current) {
      loopRef.current.dispose()
      loopRef.current = null
    }

    const transport = Tone.getTransport()
    transport.bpm.value = bpm

    const totalSubs = beatsPerMeasure * subdivisionsPerBeat
    beatIndexRef.current = 0

    const subdivisionDuration = (60 / bpm) / subdivisionsPerBeat

    const loop = new Tone.Loop((time) => {
      const idx = beatIndexRef.current % totalSubs
      const beatNum = Math.floor(idx / subdivisionsPerBeat)
      const subNum = idx % subdivisionsPerBeat
      const isAccent = idx === 0
      const isBeatHead = subNum === 0
      const isSubdiv = !isBeatHead

      // Apply swing to even-numbered subdivisions (0-indexed)
      // Swing delays the off-beat subdivisions
      let adjustedTime = time
      if (subdivisionsPerBeat >= 2 && subNum % 2 === 1 && swing > 0) {
        const swingAmount = (swing / 100) * subdivisionDuration * 0.5
        adjustedTime = time + swingAmount
      }

      if (isBeatHead || subdivisionsPerBeat > 1) {
        playClick(adjustedTime, isAccent, isSubdiv)
      }

      Tone.getDraw().schedule(() => {
        setCurrentBeat(beatNum)
        if (isAccent) {
          setFlash(true)
          setTimeout(() => setFlash(false), 100)
        }
      }, time)

      beatIndexRef.current++
    }, subdivisionDuration)

    loop.start(0)
    loopRef.current = loop
  }, [bpm, beatsPerMeasure, subdivisionsPerBeat, playClick, swing])

  /* ──────────────────── Start / Stop ──────────────────── */

  const togglePlay = useCallback(async () => {
    if (isPlayingRef.current) {
      Tone.getTransport().stop()
      Tone.getTransport().cancel()
      if (loopRef.current) {
        loopRef.current.dispose()
        loopRef.current = null
      }
      setCurrentBeat(-1)
      setFlash(false)
      beatIndexRef.current = 0
      setPlaying(false)
      isPlayingRef.current = false
    } else {
      await Tone.start()
      scheduleLoop()
      Tone.getTransport().start()
      setPlaying(true)
      isPlayingRef.current = true
    }
  }, [scheduleLoop, setPlaying])

  /* ──────────────── Reschedule on param change while playing ──── */

  useEffect(() => {
    if (isPlayingRef.current) {
      Tone.getTransport().stop()
      Tone.getTransport().cancel()
      beatIndexRef.current = 0
      scheduleLoop()
      Tone.getTransport().start()
    }
  }, [bpm, beatsPerMeasure, subdivisionsPerBeat, clickSound, swing, scheduleLoop])

  /* sync ref */
  useEffect(() => {
    isPlayingRef.current = isPlaying
  }, [isPlaying])

  /* ──────────────────── Tap Tempo ──────────────────── */

  const handleTap = useCallback(() => {
    const now = performance.now()
    const taps = tapTimesRef.current

    if (taps.length > 0 && now - taps[taps.length - 1] > TAP_TIMEOUT) {
      tapTimesRef.current = []
    }

    taps.push(now)
    if (taps.length > TAP_WINDOW) taps.shift()

    if (taps.length >= 2) {
      const intervals: number[] = []
      for (let i = 1; i < taps.length; i++) {
        intervals.push(taps[i] - taps[i - 1])
      }
      const avg = intervals.reduce((a, b) => a + b, 0) / intervals.length
      const tappedBpm = Math.round(60000 / avg)
      setBpm(Math.max(20, Math.min(500, tappedBpm)))
    }

    tapTimesRef.current = taps
  }, [setBpm])

  /* ──────────────────── Knob Drag ──────────────────── */

  const onKnobPointerDown = useCallback(
    (e: React.PointerEvent) => {
      knobDragging.current = true
      knobStartY.current = e.clientY
      knobStartBpm.current = bpm
      ;(e.target as HTMLElement).setPointerCapture(e.pointerId)
    },
    [bpm],
  )

  const onKnobPointerMove = useCallback(
    (e: React.PointerEvent) => {
      if (!knobDragging.current) return
      const dy = knobStartY.current - e.clientY
      const sensitivity = 0.5
      const newBpm = Math.round(knobStartBpm.current + dy * sensitivity)
      setBpm(newBpm)
    },
    [setBpm],
  )

  const onKnobPointerUp = useCallback(() => {
    knobDragging.current = false
  }, [])

  /* ──────────────────── Knob rotation ──────────────────── */

  const knobRotation = ((bpm - 20) / (500 - 20)) * 270 - 135

  /* ──────────────────── Tempo label ──────────────────── */

  const tempoLabel = (() => {
    if (bpm <= 59) return 'Largo'
    if (bpm <= 79) return 'Adagio'
    if (bpm <= 99) return 'Andante'
    if (bpm <= 119) return 'Moderato'
    if (bpm <= 149) return 'Allegro'
    if (bpm <= 175) return 'Vivace'
    return 'Presto'
  })()

  /* ──────────────────── Render ──────────────────── */

  return (
    <div className="w-full max-w-md mx-auto select-none min-h-full overflow-y-auto">
    <HardwarePanel
      title="METRONOME"
      className={cn(
        'flex flex-col items-center gap-4 p-4 pb-6 relative transition-colors duration-75',
        flash && 'bg-studio-800',
      )}
    >
      {/* ── Downbeat flash overlay ── */}
      {flash && (
        <div
          className="pointer-events-none absolute inset-0 z-0 rounded-xl"
          style={{
            background: 'radial-gradient(circle at 50% 30%, rgba(0,229,255,0.12) 0%, transparent 70%)',
          }}
        />
      )}

      {/* ── Title provided by HardwarePanel ── */}

      {/* ══════════════ BPM Knob Area ══════════════ */}
      <div className="relative z-10 flex flex-col items-center gap-1">
        {/* Knob */}
        <div
          className="relative w-44 h-44 rounded-full neu-raised cursor-ns-resize flex items-center justify-center"
          style={{ background: 'radial-gradient(circle at 40% 35%, #2a2a2a, #141414)' }}
          onPointerDown={onKnobPointerDown}
          onPointerMove={onKnobPointerMove}
          onPointerUp={onKnobPointerUp}
          onPointerCancel={onKnobPointerUp}
          role="slider"
          aria-label="BPM"
          aria-valuemin={20}
          aria-valuemax={500}
          aria-valuenow={bpm}
        >
          {/* Outer ring */}
          <div
            className="absolute inset-1 rounded-full"
            style={{
              border: '2px solid rgba(0,229,255,0.15)',
            }}
          />

          {/* Tick indicator */}
          <div
            className="absolute w-1 h-5 rounded-full bg-accent top-3 left-1/2 -translate-x-1/2 origin-[50%_340%]"
            style={{
              transform: `translateX(-50%) rotate(${knobRotation}deg)`,
              boxShadow: '0 0 6px rgba(0,229,255,0.6)',
            }}
          />

          {/* Center BPM display */}
          <div className="flex flex-col items-center">
            <span
              className="font-mono text-5xl font-bold text-accent text-glow-accent leading-none"
            >
              {bpm}
            </span>
            <span className="font-mono text-[10px] text-studio-400 mt-0.5 tracking-wider">BPM</span>
          </div>
        </div>

        {/* Tempo name */}
        <span className="font-display text-sm text-studio-400">{tempoLabel}</span>
      </div>

      {/* ══════════════ LED Beat Bar ══════════════ */}
      <div className="z-10 flex items-center justify-center gap-2 py-2">
        {Array.from({ length: beatsPerMeasure }).map((_, i) => {
          const isActive = i === currentBeat
          const isAccentBeat = i === 0
          return (
            <div
              key={i}
              className={cn(
                'w-5 h-5 rounded-full transition-all duration-75',
                isActive && isAccentBeat && 'scale-125',
                isActive && !isAccentBeat && 'scale-110',
              )}
              style={{
                background: isActive
                  ? isAccentBeat
                    ? '#FF9500'
                    : '#00E5FF'
                  : '#2A2A2A',
                boxShadow: isActive
                  ? isAccentBeat
                    ? '0 0 12px rgba(255,149,0,0.7), 0 0 4px rgba(255,149,0,0.4)'
                    : '0 0 12px rgba(0,229,255,0.7), 0 0 4px rgba(0,229,255,0.4)'
                  : 'inset 2px 2px 4px #080808, inset -2px -2px 4px #1e1e1e',
              }}
            />
          )
        })}
      </div>

      {/* ══════════════ Play / Stop Button ══════════════ */}
      <button
        onClick={togglePlay}
        className={cn(
          'z-10 w-20 h-20 rounded-full flex items-center justify-center',
          'transition-all duration-150 active:scale-95',
          isPlaying
            ? 'bg-error glow-danger'
            : 'bg-accent glow-accent',
          'neu-raised',
        )}
        aria-label={isPlaying ? 'Stop' : 'Play'}
      >
        {isPlaying ? (
          /* Stop icon */
          <div className="w-7 h-7 rounded-sm bg-white" />
        ) : (
          /* Play icon */
          <div
            className="w-0 h-0 ml-1.5"
            style={{
              borderLeft: '14px solid white',
              borderTop: '10px solid transparent',
              borderBottom: '10px solid transparent',
            }}
          />
        )}
      </button>

      {/* ══════════════ Time Signature & Subdivision Row ══════════════ */}
      <div className="z-10 w-full grid grid-cols-2 gap-3">
        {/* Time Signature */}
        <div className="flex flex-col gap-1">
          <label className="font-display text-[10px] text-studio-400 uppercase tracking-wider text-center">
            Time Sig
          </label>
          <div className="flex flex-wrap justify-center gap-1">
            {TIME_SIGNATURES.map((ts) => (
              <button
                key={ts.join('/')}
                onClick={() => setTimeSig(ts)}
                className={cn(
                  'px-2 py-1 rounded-md text-xs font-mono transition-colors',
                  timeSig[0] === ts[0] && timeSig[1] === ts[1]
                    ? 'bg-accent-dim text-accent border border-accent/40'
                    : 'bg-studio-750 text-studio-400 border border-studio-600 hover:border-studio-400',
                )}
              >
                {ts[0]}/{ts[1]}
              </button>
            ))}
          </div>
        </div>

        {/* Subdivision */}
        <div className="flex flex-col gap-1">
          <label className="font-display text-[10px] text-studio-400 uppercase tracking-wider text-center">
            Subdivision
          </label>
          <div className="flex flex-wrap justify-center gap-1">
            {SUBDIVISIONS.map((sub) => (
              <button
                key={sub.key}
                onClick={() => setSubdivision(sub.key)}
                className={cn(
                  'px-2 py-1 rounded-md text-xs font-mono transition-colors',
                  subdivision === sub.key
                    ? 'bg-accent-dim text-accent border border-accent/40'
                    : 'bg-studio-750 text-studio-400 border border-studio-600 hover:border-studio-400',
                )}
              >
                {sub.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* ══════════════ Click Sound Presets ══════════════ */}
      <div className="z-10 w-full flex flex-col gap-1">
        <label className="font-display text-[10px] text-studio-400 uppercase tracking-wider text-center">
          Click Sound
        </label>
        <div className="flex flex-wrap justify-center gap-1.5">
          {(Object.keys(CLICK_PRESETS) as ClickPreset[]).map((preset) => (
            <button
              key={preset}
              onClick={() => setClickSound(preset)}
              className={cn(
                'px-3 py-1.5 rounded-lg text-xs font-display transition-colors',
                clickSound === preset
                  ? 'bg-accent-dim text-accent border border-accent/40'
                  : 'bg-studio-750 text-studio-400 border border-studio-600 hover:border-studio-400',
              )}
            >
              {preset}
            </button>
          ))}
        </div>
      </div>

      {/* ══════════════ Swing Slider ══════════════ */}
      <div className="z-10 w-full flex flex-col gap-1 px-2">
        <div className="flex items-center justify-between">
          <label className="font-display text-[10px] text-studio-400 uppercase tracking-wider">
            Swing
          </label>
          <span className="font-mono text-xs text-accent">{swing}%</span>
        </div>
        <input
          type="range"
          min={0}
          max={100}
          value={swing}
          onChange={(e) => setSwing(Number(e.target.value))}
          className="w-full h-2 rounded-full appearance-none cursor-pointer neu-inset"
          style={{
            background: `linear-gradient(to right, #00E5FF ${swing}%, #2A2A2A ${swing}%)`,
          }}
        />
      </div>

      {/* ══════════════ Tap Tempo ══════════════ */}
      <button
        onClick={handleTap}
        className={cn(
          'z-10 w-full py-3 rounded-xl font-display text-sm uppercase tracking-wider',
          'bg-studio-750 text-studio-400 border border-studio-600',
          'neu-flat active:neu-inset active:scale-[0.98] transition-all',
          'hover:text-accent hover:border-accent/30',
        )}
      >
        Tap Tempo
      </button>

      {/* ══════════════ Tempo Presets ══════════════ */}
      <div className="z-10 w-full flex flex-col gap-1">
        <label className="font-display text-[10px] text-studio-400 uppercase tracking-wider text-center">
          Presets
        </label>
        <div className="flex flex-wrap justify-center gap-1.5">
          {TEMPO_PRESETS.map((p) => (
            <button
              key={p.name}
              onClick={() => setBpm(p.bpm)}
              className={cn(
                'px-2.5 py-1 rounded-lg text-[11px] font-display transition-colors',
                bpm === p.bpm
                  ? 'bg-warning/20 text-warning border border-warning/40'
                  : 'bg-studio-750 text-studio-400 border border-studio-600 hover:border-studio-400',
              )}
            >
              {p.name}
              <span className="ml-1 font-mono text-[10px] opacity-60">{p.bpm}</span>
            </button>
          ))}
        </div>
      </div>

      {/* ══════════════ BPM Fine Control ══════════════ */}
      <div className="z-10 flex items-center gap-3">
        <button
          onClick={() => setBpm(bpm - 1)}
          className="w-10 h-10 rounded-full bg-studio-750 border border-studio-600 text-studio-400 font-mono text-lg
                     neu-flat active:neu-inset transition-all hover:text-accent"
        >
          -
        </button>
        <input
          type="range"
          min={20}
          max={500}
          value={bpm}
          onChange={(e) => setBpm(Number(e.target.value))}
          className="flex-1 h-2 rounded-full appearance-none cursor-pointer neu-inset"
          style={{
            background: `linear-gradient(to right, #00E5FF ${((bpm - 20) / 480) * 100}%, #2A2A2A ${((bpm - 20) / 480) * 100}%)`,
          }}
        />
        <button
          onClick={() => setBpm(bpm + 1)}
          className="w-10 h-10 rounded-full bg-studio-750 border border-studio-600 text-studio-400 font-mono text-lg
                     neu-flat active:neu-inset transition-all hover:text-accent"
        >
          +
        </button>
      </div>
    </HardwarePanel>
    </div>
  )
}
