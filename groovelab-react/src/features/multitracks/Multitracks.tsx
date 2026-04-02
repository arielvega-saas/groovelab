/**
 * Multitracks — DAW-style multitrack session player
 *
 * Integrates with useSharedPlayer for Tone.js audio playback,
 * supports setlist management, per-track waveform visualization,
 * fader mixer with solo/mute, and timeline with markers.
 */
import { useState, useEffect, useRef, useCallback } from 'react'
import { useAppStore } from '@/stores/app-store'
import { useMultitrackStore } from '@/stores/multitrack-store'
import type { PistaMultitrack } from '@/stores/multitrack-store'
import { useSharedPlayer } from '@/hooks/useSharedPlayer'
import { REPERTORIO_DEMO, PISTAS_DEFAULT } from '@/data/multitracksDemo'
import { HardwarePanel } from '@/components/ui/HardwarePanel'
import { LED } from '@/components/ui/LED'
import { cn } from '@/lib/cn'

/* ------------------------------------------------------------------ */
/*  Constants                                                          */
/* ------------------------------------------------------------------ */

const BOTTOM_TABS = [
  'Repertorio / Mapa',
  'MIDI Cues',
  'Automatizacion',
  'MIDI Mapping',
  'Tonos',
]

const SECUENCIAS = [
  'Click', 'Guia', 'Bateria', 'Loop', 'Bajo',
  'Electrica 1', 'Electrica 2', 'Piano', 'Synth Group', 'Vocales', 'Coro',
]

/* ------------------------------------------------------------------ */
/*  Timeline Waveform Canvas                                            */
/* ------------------------------------------------------------------ */

function TrackWaveform({
  peaks,
  color,
  progress,
  muted,
}: {
  peaks: number[]
  color: string
  progress: number
  muted: boolean
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const dpr = window.devicePixelRatio || 1
    const w = canvas.clientWidth
    const h = canvas.clientHeight
    canvas.width = w * dpr
    canvas.height = h * dpr
    ctx.scale(dpr, dpr)
    ctx.clearRect(0, 0, w, h)

    const barW = w / peaks.length
    const half = h / 2
    const alpha = muted ? '30' : '90'

    for (let i = 0; i < peaks.length; i++) {
      const amp = peaks[i] * half * 0.85
      const x = i * barW
      ctx.fillStyle = color + alpha
      ctx.fillRect(x + 0.5, half - amp, Math.max(1, barW - 1), amp * 2)
    }

    // Playhead
    if (progress > 0 && progress < 1) {
      const px = progress * w
      ctx.fillStyle = 'rgba(255,255,255,0.8)'
      ctx.fillRect(px, 0, 1.5, h)
    }
  }, [peaks, color, progress, muted])

  return (
    <canvas
      ref={canvasRef}
      className="w-full h-full"
      style={{ display: 'block' }}
    />
  )
}

/* ------------------------------------------------------------------ */
/*  Fake waveform generator for demo tracks without real audio          */
/* ------------------------------------------------------------------ */

function generateFakeWaveform(seed: number, count = 80): number[] {
  const peaks: number[] = []
  let v = 0.3
  for (let i = 0; i < count; i++) {
    v += (Math.sin(seed * 13.7 + i * 0.47) * 0.15 + Math.cos(i * 0.23 + seed) * 0.1)
    v = Math.max(0.05, Math.min(1, v))
    peaks.push(v)
  }
  return peaks
}

/* ------------------------------------------------------------------ */
/*  VU Meter for mixer (mini version)                                   */
/* ------------------------------------------------------------------ */

function MiniVU({ level, color }: { level: number; color: string }) {
  const segments = 12
  return (
    <div className="flex flex-col-reverse gap-px w-1.5" style={{ height: 60 }}>
      {Array.from({ length: segments }).map((_, i) => {
        const threshold = i / segments
        const active = level >= threshold
        const ratio = i / segments
        const bg = ratio >= 0.85 ? '#FF3B30' : ratio >= 0.65 ? '#FF9500' : color
        return (
          <div
            key={i}
            className="flex-1 rounded-[1px]"
            style={{
              background: active ? bg : '#1A1A1A',
              opacity: active ? 1 : 0.2,
            }}
          />
        )
      })}
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  Format time helper                                                  */
/* ------------------------------------------------------------------ */

function formatTime(s: number): string {
  const m = Math.floor(s / 60).toString().padStart(2, '0')
  const sec = Math.floor(s % 60).toString().padStart(2, '0')
  return `${m}:${sec}`
}

function formatTimeMs(s: number): string {
  const m = Math.floor(s / 60).toString().padStart(2, '0')
  const sec = Math.floor(s % 60).toString().padStart(2, '0')
  const ms = Math.floor((s % 1) * 10)
  return `${m}:${sec}.${ms}`
}

/* ------------------------------------------------------------------ */
/*  Main Component                                                      */
/* ------------------------------------------------------------------ */

export default function Multitracks() {
  const [tabActivo, setTabActivo] = useState(0)
  const [modalRepert, setModalRepert] = useState(false)
  const [modalSeq, setModalSeq] = useState(false)
  const [seqActivas, setSeqActivas] = useState(new Set(SECUENCIAS))
  const [fileLoading, setFileLoading] = useState(false)

  const { bpm } = useAppStore()
  const {
    repertorio, cancionActiva,
    setRepertorio, setCancionActiva,
    pistaBase, pistasMultitrack,
  } = useMultitrackStore()

  const {
    isPlaying,
    currentTime,
    duration,
    togglePlay,
    stop,
    seek,
    loadTrackAudio,
    setFader,
    toggleMute,
    toggleSolo,
    hasSolo,
  } = useSharedPlayer()

  const fileInputRef = useRef<HTMLInputElement>(null)

  // Init demo data
  useEffect(() => {
    if (!repertorio) {
      setRepertorio(REPERTORIO_DEMO)
      if (REPERTORIO_DEMO.canciones[0]) {
        setCancionActiva(REPERTORIO_DEMO.canciones[0])
      }
    }
  }, [])

  const progress = duration ? currentTime / duration : 0

  // Build visible tracks list
  const pistasVisibles: PistaMultitrack[] = [
    ...(pistaBase ? [pistaBase] : []),
    ...pistasMultitrack.filter(p => p.origen !== 'base'),
    ...(pistaBase ? [] : PISTAS_DEFAULT.map(p => ({ ...p } as PistaMultitrack))),
  ]

  // File input for loading audio
  const handleFileSelect = useCallback(async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file || !file.type.startsWith('audio/')) return

    setFileLoading(true)
    try {
      const url = URL.createObjectURL(file)
      // Load into the first custom track
      await loadTrackAudio('bat', url)
    } catch (err) {
      console.error('Failed to load audio:', err)
    } finally {
      setFileLoading(false)
    }
  }, [loadTrackAudio])

  // Timeline click to seek
  const handleTimelineClick = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    if (!duration) return
    const rect = e.currentTarget.getBoundingClientRect()
    const x = e.clientX - rect.left
    const ratio = Math.max(0, Math.min(1, x / rect.width))
    seek(ratio * duration)
  }, [duration, seek])

  // Fake waveform data for demo
  const getWaveform = (pista: PistaMultitrack, idx: number): number[] => {
    if (pista.waveformData) return Array.from(pista.waveformData)
    return generateFakeWaveform(idx * 7 + pista.id.charCodeAt(0))
  }

  // Fake VU levels based on playback
  const getVULevel = (pista: PistaMultitrack): number => {
    if (!isPlaying || pista.muted || (hasSolo && !pista.soloed)) return 0
    const base = (pista.volumen / 100) * 0.7
    return base + Math.sin(Date.now() / 200 + pista.id.charCodeAt(0)) * 0.15
  }

  return (
    <div className="flex flex-col h-full bg-studio-950 overflow-hidden select-none">
      {/* ════════ TOP BAR ════════ */}
      <HardwarePanel className="flex-shrink-0 rounded-none border-x-0 border-t-0">
        <div className="h-14 flex items-center gap-0 px-3">
          {/* BPM */}
          <div className="flex flex-col items-center min-w-[42px]">
            <span className="numeric text-[19px] font-bold text-studio-100 leading-none">
              {cancionActiva?.bpm ?? bpm}
            </span>
            <span className="hw-label text-studio-500">4/4</span>
          </div>

          <div className="w-px h-7 bg-studio-600 mx-3 flex-shrink-0" />

          {/* Time display */}
          <div className="flex flex-col items-center">
            <span className="numeric text-[22px] font-bold text-studio-100 leading-none">
              {formatTimeMs(currentTime)}
            </span>
            <span className="numeric text-[9px] text-studio-500">
              {formatTime(currentTime)} / {formatTime(duration || cancionActiva?.duracion || 0)}
            </span>
          </div>

          <div className="w-px h-7 bg-studio-600 mx-3 flex-shrink-0" />

          {/* Song name */}
          <div className="flex-1 flex items-center justify-center gap-2 px-2 overflow-hidden">
            <LED
              color={isPlaying ? 'green' : 'red'}
              state={isPlaying ? 'pulse' : 'on'}
              size="sm"
            />
            <span className="text-[11px] font-semibold text-studio-300 whitespace-nowrap text-ellipsis overflow-hidden">
              {cancionActiva?.nombre ?? 'Sin cancion'}
            </span>
          </div>

          <div className="w-px h-7 bg-studio-600 mx-1 flex-shrink-0" />

          {/* Transport controls */}
          <div className="flex items-center gap-1.5">
            <button
              onClick={stop}
              className="w-8 h-8 rounded-full bg-studio-700 border border-studio-600 flex items-center justify-center text-studio-300 text-sm hover:text-studio-100 transition-colors active:scale-95"
            >
              {'\u23EE'}
            </button>
            <button
              onClick={togglePlay}
              className={cn(
                'w-10 h-10 rounded-full border flex items-center justify-center text-base transition-all active:scale-95',
                isPlaying
                  ? 'bg-red-500/10 border-red-500 text-red-400 shadow-[0_0_12px_rgba(239,68,68,0.3)]'
                  : 'bg-accent/10 border-accent text-accent shadow-glow-accent',
              )}
            >
              {isPlaying ? '\u23F8' : '\u25B6'}
            </button>
            <div className="w-px h-7 bg-studio-600 mx-1" />
            <button
              onClick={() => fileInputRef.current?.click()}
              className="w-8 h-8 rounded-lg bg-studio-700 border border-studio-600 flex items-center justify-center text-studio-400 text-sm hover:text-accent transition-colors"
              title="Load audio file"
            >
              {fileLoading ? '\u23F3' : '\u2795'}
            </button>
            <button
              onClick={() => setModalSeq(true)}
              className="w-8 h-8 rounded-lg bg-studio-700 border border-studio-600 flex items-center justify-center text-studio-400 text-sm hover:text-studio-200 transition-colors"
            >
              {'\u2630'}
            </button>
            <button
              onClick={() => setModalRepert(true)}
              className="w-8 h-8 rounded-lg flex items-center justify-center text-studio-400 hover:text-studio-200 transition-colors"
            >
              {'\u22EE'}
            </button>
          </div>
        </div>
      </HardwarePanel>

      <input
        ref={fileInputRef}
        type="file"
        accept="audio/*"
        className="hidden"
        onChange={handleFileSelect}
      />

      {/* ════════ SETLIST CAROUSEL ════════ */}
      <div className="h-24 flex-shrink-0 flex items-stretch bg-studio-900 border-b border-studio-600/40 overflow-x-auto [&::-webkit-scrollbar]:hidden">
        {(repertorio?.canciones ?? []).map((cancion) => (
          <button
            key={cancion.id}
            onClick={() => setCancionActiva(cancion)}
            className={cn(
              'flex-shrink-0 w-28 flex flex-col border-r border-studio-600/40 overflow-hidden transition-all relative',
              cancionActiva?.id === cancion.id
                ? 'bg-accent/5 after:absolute after:bottom-0 after:inset-x-0 after:h-0.5 after:bg-accent'
                : 'hover:bg-studio-800/50',
            )}
          >
            <div className="h-14 bg-studio-800 flex items-center justify-center text-2xl flex-shrink-0">
              {cancion.emoji ?? '\uD83C\uDFB5'}
            </div>
            <div className="px-1.5 py-1 flex flex-col gap-0.5">
              <span className="text-[9px] font-semibold text-studio-100 overflow-hidden whitespace-nowrap text-ellipsis">
                {cancion.nombre}
              </span>
              <div className="flex items-center gap-1">
                <span className="numeric text-[8px] text-studio-500">
                  {cancion.tonalidad}
                </span>
                <span className="numeric text-[8px] text-accent">
                  {cancion.bpm}
                </span>
              </div>
            </div>
          </button>
        ))}
        <button className="flex-shrink-0 w-14 flex items-center justify-center text-studio-500 hover:text-accent text-2xl border-r border-studio-600/40 transition-colors">
          +
        </button>
      </div>

      {/* ════════ TIMELINE ════════ */}
      <div className="flex-1 overflow-y-auto overflow-x-hidden bg-studio-950 min-h-0 relative">
        {/* Time ruler */}
        <div
          className="h-5 bg-studio-800 border-b border-studio-600/40 sticky top-0 z-10 flex items-center relative cursor-pointer"
          onClick={handleTimelineClick}
        >
          {Array.from({ length: 11 }, (_, i) => (
            <div
              key={i}
              className="absolute top-0 bottom-0 flex items-center border-l border-studio-600/30 pl-1"
              style={{ left: `${i * 10}%` }}
            >
              <span className="numeric text-[8px] text-studio-500">
                {formatTime((i / 10) * (duration || cancionActiva?.duracion || 0))}
              </span>
            </div>
          ))}
          {/* Playhead on ruler */}
          <div
            className="absolute top-0 bottom-0 w-0.5 bg-accent z-20 pointer-events-none"
            style={{
              left: `${progress * 100}%`,
              boxShadow: '0 0 6px rgba(4,197,247,0.5)',
            }}
          />
        </div>

        {/* Track lanes */}
        {pistasVisibles.map((pista, idx) => {
          const isMutedVisual = pista.muted || (hasSolo && !pista.soloed)
          const waveform = getWaveform(pista, idx)

          return (
            <div
              key={pista.id}
              className="h-12 flex border-b border-studio-800/60 hover:bg-studio-800/20 transition-colors relative"
            >
              {/* Track label */}
              <div className="w-14 flex-shrink-0 flex items-center justify-center bg-studio-800 border-r border-studio-600/40 sticky left-0 z-[5] p-1">
                <div className="flex flex-col items-center gap-0.5">
                  <div
                    className="w-5 h-0.5 rounded-full"
                    style={{ background: pista.color }}
                  />
                  <span className="text-[8px] font-semibold text-studio-300 leading-tight text-center">
                    {pista.nombre}
                  </span>
                </div>
              </div>

              {/* Waveform area */}
              <div
                className="flex-1 relative overflow-hidden cursor-pointer"
                style={{ opacity: isMutedVisual ? 0.3 : 1 }}
                onClick={handleTimelineClick}
              >
                {/* Markers */}
                {(cancionActiva?.marcadores ?? []).map((m) => (
                  <div
                    key={m.id}
                    className="absolute top-0 h-3.5 flex items-center px-1 border-l-2 z-10 pointer-events-none"
                    style={{
                      left: `${m.posicion * 100}%`,
                      borderColor: m.color,
                      background: m.color + '18',
                    }}
                  >
                    <span
                      className="text-[8px] font-bold font-mono leading-none"
                      style={{ color: m.color }}
                    >
                      {m.etiqueta}
                    </span>
                  </div>
                ))}

                {/* Canvas waveform */}
                <div className="absolute inset-0 pt-3.5">
                  <TrackWaveform
                    peaks={waveform}
                    color={pista.color}
                    progress={progress}
                    muted={isMutedVisual}
                  />
                </div>
              </div>

              {/* Playhead line */}
              <div
                className="absolute top-0 bottom-0 w-px pointer-events-none z-10"
                style={{
                  left: `calc(56px + ${progress * 100}% * (100% - 56px) / 100%)`,
                  background: 'rgba(255,255,255,0.7)',
                  boxShadow: '0 0 4px rgba(255,255,255,0.4)',
                }}
              />
            </div>
          )
        })}
      </div>

      {/* ════════ MIXER ════════ */}
      <HardwarePanel className="flex-shrink-0 rounded-none border-x-0 border-b-0">
        <div className="h-52 flex overflow-x-auto [&::-webkit-scrollbar]:hidden">
          {[
            ...pistasVisibles,
            {
              id: 'master',
              nombre: 'Master',
              color: '#04C5F7',
              volumen: 90,
              muted: false,
              soloed: false,
              origen: 'custom' as const,
            },
          ].map((pista) => {
            const isMaster = pista.id === 'master'
            const val = pista.volumen ?? 70
            const vuLevel = getVULevel(pista)

            const dBDisplay = (v: number) => {
              if (v === 0) return '-\u221E'
              const db = 20 * Math.log10(v / 100)
              return (db >= 0 ? '+' : '') + db.toFixed(1)
            }

            return (
              <div
                key={pista.id}
                className={cn(
                  'flex-shrink-0 flex flex-col items-center border-r border-studio-600/30 px-1.5 py-2 gap-1 hover:bg-studio-700/30 transition-colors',
                  isMaster
                    ? 'w-20 bg-studio-700 sticky right-0 border-l border-studio-500/40'
                    : 'w-16',
                )}
              >
                {/* Solo / Mute buttons */}
                {!isMaster && (
                  <div className="flex gap-1 w-full">
                    <button
                      onClick={() => toggleSolo(pista.id)}
                      className={cn(
                        'flex-1 h-4 rounded text-[8px] font-bold border transition-all',
                        pista.soloed
                          ? 'border-led-green text-led-green bg-led-green/10'
                          : 'border-studio-600 text-studio-500',
                      )}
                    >
                      S
                    </button>
                    <button
                      onClick={() => toggleMute(pista.id)}
                      className={cn(
                        'flex-1 h-4 rounded text-[8px] font-bold border transition-all',
                        pista.muted
                          ? 'border-led-amber text-led-amber bg-led-amber/10'
                          : 'border-studio-600 text-studio-500',
                      )}
                    >
                      M
                    </button>
                  </div>
                )}

                {isMaster && (
                  <span className="hw-label text-studio-400 text-[8px]">MASTER</span>
                )}

                {/* Fader + VU */}
                <div className="flex-1 w-full flex items-center justify-center gap-1" style={{ minHeight: 80 }}>
                  <MiniVU level={vuLevel} color={pista.color} />
                  <input
                    type="range"
                    min={0}
                    max={100}
                    step={1}
                    value={val}
                    onChange={(e) => setFader(pista.id, +e.target.value)}
                    className="accent-accent cursor-grab"
                    style={{
                      height: 80,
                      writingMode: 'vertical-lr' as never,
                      direction: 'rtl' as never,
                    }}
                  />
                </div>

                {/* dB display */}
                <span
                  className="numeric text-[9px]"
                  style={{ color: isMaster ? '#04C5F7' : '#707070' }}
                >
                  {dBDisplay(val)}
                </span>

                {/* Track name */}
                <div className="flex items-center gap-1 justify-center">
                  <div
                    className="w-2 h-2 rounded-full flex-shrink-0"
                    style={{ background: pista.color }}
                  />
                  <span className="text-[8px] font-semibold text-studio-300 text-center leading-tight truncate max-w-[44px]">
                    {pista.nombre}
                  </span>
                </div>
              </div>
            )
          })}
        </div>
      </HardwarePanel>

      {/* ════════ BOTTOM TABS ════════ */}
      <div className="h-8 flex-shrink-0 bg-studio-800 border-t border-studio-600/40 flex overflow-x-auto [&::-webkit-scrollbar]:hidden">
        {BOTTOM_TABS.map((tab, i) => (
          <button
            key={i}
            onClick={() => setTabActivo(i)}
            className={cn(
              'flex-shrink-0 px-3 text-[10px] font-medium border-b-2 whitespace-nowrap transition-all',
              tabActivo === i
                ? 'text-accent border-accent'
                : 'text-studio-500 border-transparent hover:text-studio-300',
            )}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* ════════ MODAL REPERTORIOS ════════ */}
      {modalRepert && (
        <div
          className="fixed inset-0 bg-black/75 backdrop-blur-sm z-50 flex items-end"
          onClick={() => setModalRepert(false)}
        >
          <div
            className="w-full bg-studio-800 rounded-t-2xl border border-studio-600/40 max-h-[75vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="w-9 h-1 bg-studio-600 rounded-full mx-auto mt-3" />
            <h2 className="text-sm font-bold text-studio-100 text-center py-3">
              Repertorios
            </h2>
            <div className="mx-3 mb-2 p-3 rounded-lg bg-red-500/[0.08] border border-red-500/20 flex gap-3 items-start">
              <LED color="red" state="on" size="sm" />
              <div>
                <p className="text-[12px] font-semibold text-studio-100 mb-0.5">
                  Cambios no guardados
                </p>
                <p className="text-[11px] text-studio-400">
                  Guarda a la Nube para compartir con tu equipo.
                </p>
              </div>
            </div>
            <button className="mx-3 mb-3 w-[calc(100%-24px)] py-2.5 rounded-lg bg-accent/10 border border-accent text-accent text-[12px] font-semibold">
              {'\u2601'} Guardar a la Nube
            </button>
            {[
              { icon: '\uD83D\uDCC1', title: 'Nuevo Repertorio' },
              { icon: '\uD83D\uDCC2', title: 'Abrir Repertorio' },
              {
                icon: '\uD83D\uDD17',
                title: 'Conectar a Planning Center',
                sub: 'Importa tu lista de canciones como repertorio.',
              },
            ].map((item) => (
              <div
                key={item.title}
                className="flex items-center gap-3 px-4 py-3 border-b border-studio-700/40 cursor-pointer hover:bg-studio-700/30 transition-colors"
              >
                <div className="w-9 h-9 rounded-lg bg-studio-700 flex items-center justify-center text-base flex-shrink-0">
                  {item.icon}
                </div>
                <div className="flex-1">
                  <p className="text-[13px] font-semibold text-studio-100">
                    {item.title}
                  </p>
                  {item.sub && (
                    <p className="text-[11px] text-studio-400 mt-0.5">
                      {item.sub}
                    </p>
                  )}
                </div>
                <span className="text-studio-500">{'\u203A'}</span>
              </div>
            ))}
            {repertorio && (
              <>
                <p className="hw-label px-4 pt-3 pb-1">Repertorio Actual</p>
                <div className="flex items-center gap-3 px-4 py-3 bg-studio-700/30 cursor-pointer">
                  <div className="w-9 h-9 rounded-lg bg-studio-600 flex items-center justify-center text-base">
                    {'\u267E\uFE0F'}
                  </div>
                  <div className="flex-1">
                    <p className="text-[13px] font-semibold text-studio-100">
                      {repertorio.nombre}
                    </p>
                    <p className="text-[11px] text-studio-400">
                      {repertorio.fecha} {'\u00B7'} {repertorio.canciones.length}{' '}
                      Canciones
                    </p>
                  </div>
                  <span className="text-accent">{'\u203A'}</span>
                </div>
              </>
            )}
            <button
              onClick={() => setModalRepert(false)}
              className="w-full py-4 text-center text-accent text-[14px] font-medium border-t border-studio-600/40"
            >
              Cancelar
            </button>
          </div>
        </div>
      )}

      {/* ════════ MODAL SECUENCIAS ════════ */}
      {modalSeq && (
        <div
          className="fixed inset-0 bg-black/75 backdrop-blur-sm z-50 flex items-end"
          onClick={() => setModalSeq(false)}
        >
          <div
            className="w-full bg-studio-800 rounded-t-2xl border border-studio-600/40 max-h-[70vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="w-9 h-1 bg-studio-600 rounded-full mx-auto mt-3" />
            <div className="flex items-center px-4 py-3">
              <button
                onClick={() => setModalSeq(false)}
                className="text-accent text-[13px]"
              >
                {'\u2039'} Atras
              </button>
              <h2 className="flex-1 text-[14px] font-bold text-studio-100 text-center">
                Seleccionar Secuencias
              </h2>
              <button className="text-accent text-[13px]">Agregar</button>
            </div>
            {SECUENCIAS.map((nombre) => {
              const activa = seqActivas.has(nombre)
              return (
                <div
                  key={nombre}
                  className="flex items-center justify-between px-4 py-3 border-b border-studio-700/40 cursor-pointer hover:bg-studio-700/30 transition-colors"
                  onClick={() =>
                    setSeqActivas((prev) => {
                      const next = new Set(prev)
                      if (next.has(nombre)) next.delete(nombre)
                      else next.add(nombre)
                      return next
                    })
                  }
                >
                  <span className="text-[13px] text-studio-100">{nombre}</span>
                  <div
                    className={cn(
                      'w-5 h-5 rounded-full flex items-center justify-center text-[11px] font-bold transition-all',
                      activa
                        ? 'bg-accent text-studio-900'
                        : 'bg-transparent border border-studio-600',
                    )}
                  >
                    {activa ? '\u2713' : ''}
                  </div>
                </div>
              )
            })}
            <button
              onClick={() => setSeqActivas(new Set())}
              className="w-full py-3 text-center text-accent text-[13px] font-medium border-t border-studio-600/40"
            >
              Anular todas las selecciones
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
