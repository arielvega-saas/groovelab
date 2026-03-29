import { useState, useEffect } from 'react'
import { useAppStore } from '@/stores/app-store'
import { useMultitrackStore } from '@/stores/multitrack-store'
import type { PistaMultitrack } from '@/stores/multitrack-store'
import { REPERTORIO_DEMO, PISTAS_DEFAULT } from '@/data/multitracksDemo'

const BOTTOM_TABS = [
  'Repertorio / Mapa',
  'MIDI Cues',
  'Automatizacion',
  'MIDI Mapping',
  'Tonos',
]

const SECUENCIAS = [
  'Click','Guia','Bateria','Loop','Bajo',
  'Electrica 1','Electrica 2','Piano','Synth Group','Vocales','Coro',
]

export default function Multitracks() {
  const [tabActivo, setTabActivo] = useState(0)
  const [modalRepert, setModalRepert] = useState(false)
  const [modalSeq, setModalSeq] = useState(false)
  const [seqActivas, setSeqActivas] = useState(new Set(SECUENCIAS))

  const { isPlaying, setPlaying, bpm } = useAppStore()
  const {
    currentTime, duration,
    pistaBase, pistasMultitrack,
    repertorio, cancionActiva,
    setRepertorio, setCancionActiva,
    toggleMute, toggleSolo, setFader,
    setCurrentTime,
  } = useMultitrackStore()

  useEffect(() => {
    if (!repertorio) {
      setRepertorio(REPERTORIO_DEMO)
      if (REPERTORIO_DEMO.canciones[0]) {
        setCancionActiva(REPERTORIO_DEMO.canciones[0])
      }
    }
  }, [])

  const progress = duration ? currentTime / duration : 0

  const pistasVisibles: PistaMultitrack[] = [
    ...(pistaBase ? [pistaBase] : []),
    ...pistasMultitrack.filter(p => p.origen !== 'base'),
    ...(pistaBase ? [] : PISTAS_DEFAULT.map(p => ({ ...p } as PistaMultitrack))),
  ]

  const formatTime = (s: number) => {
    const m = Math.floor(s / 60).toString().padStart(2, '0')
    const sec = Math.floor(s % 60).toString().padStart(2, '0')
    return `${m}:${sec}`
  }

  const togglePlay = () => setPlaying(!isPlaying)
  const stop = () => { setPlaying(false); setCurrentTime(0) }

  return (
    <div className="flex flex-col h-full bg-studio-900 overflow-hidden">
      {/* TOP BAR */}
      <div className="h-14 flex items-center gap-0 bg-studio-800 border-b border-studio-600/40 px-3 flex-shrink-0 shadow-[inset_0_1px_0_rgba(255,255,255,0.04),0_4px_16px_rgba(0,0,0,0.5)]">
        <div className="flex flex-col items-center min-w-[42px]">
          <span className="numeric text-[19px] font-bold text-studio-100 leading-none">{cancionActiva?.bpm ?? bpm}</span>
          <span className="hw-label text-studio-500">4/4</span>
        </div>
        <div className="w-px h-7 bg-studio-600 mx-3 flex-shrink-0" />
        <div className="flex flex-col items-center">
          <span className="numeric text-[22px] font-bold text-studio-100 leading-none">{formatTime(currentTime)}</span>
          <span className="numeric text-[9px] text-studio-500">{formatTime(currentTime)} / {formatTime(duration || 0)}</span>
        </div>
        <div className="w-px h-7 bg-studio-600 mx-3 flex-shrink-0" />
        <div className="flex-1 text-center text-[11px] font-semibold text-studio-300 px-2 overflow-hidden whitespace-nowrap text-ellipsis">
          {repertorio?.nombre ?? 'Sin repertorio'}
        </div>
        <div className="flex items-center gap-1.5">
          <button onClick={stop} className="w-8 h-8 rounded-full bg-studio-700 border border-studio-600 flex items-center justify-center text-studio-300 text-sm hover:text-studio-100 transition-colors">
            {'\u23EE'}
          </button>
          <button onClick={togglePlay}
            className={`w-10 h-10 rounded-full border flex items-center justify-center text-base transition-all ${isPlaying ? 'bg-red-500/10 border-red-500 text-red-400' : 'bg-accent/10 border-accent text-accent'}`}>
            {isPlaying ? '\u23F8' : '\u25B6'}
          </button>
          <div className="w-px h-7 bg-studio-600 mx-1" />
          <button onClick={() => setModalSeq(true)} className="w-8 h-8 rounded-lg bg-studio-700 border border-studio-600 flex items-center justify-center text-studio-400 text-sm hover:text-studio-200 transition-colors">
            {'\u2630'}
          </button>
          <button onClick={() => setModalRepert(true)} className="w-8 h-8 rounded-lg flex items-center justify-center text-studio-400 hover:text-studio-200 transition-colors">
            {'\u22EE'}
          </button>
        </div>
      </div>

      {/* SETLIST CAROUSEL */}
      <div className="h-24 flex-shrink-0 flex items-stretch bg-studio-900 border-b border-studio-600/40 overflow-x-auto [&::-webkit-scrollbar]:hidden">
        {(repertorio?.canciones ?? []).map(cancion => (
          <button key={cancion.id}
            onClick={() => setCancionActiva(cancion)}
            className={`flex-shrink-0 w-28 flex flex-col border-r border-studio-600/40 overflow-hidden transition-all relative ${cancionActiva?.id === cancion.id ? 'bg-accent/5 after:absolute after:bottom-0 after:inset-x-0 after:h-0.5 after:bg-accent' : 'hover:bg-studio-800/50'}`}>
            <div className="h-14 bg-studio-800 flex items-center justify-center text-2xl flex-shrink-0">
              {cancion.emoji ?? '\uD83C\uDFB5'}
            </div>
            <div className="px-1.5 py-1 flex flex-col gap-0.5">
              <span className="text-[9px] font-semibold text-studio-100 overflow-hidden whitespace-nowrap text-ellipsis">{cancion.nombre}</span>
              <span className="numeric text-[8px] text-studio-500">({cancion.tonalidad})</span>
            </div>
          </button>
        ))}
        <button className="flex-shrink-0 w-14 flex items-center justify-center text-studio-500 hover:text-accent text-2xl border-r border-studio-600/40 transition-colors">+</button>
      </div>

      {/* TIMELINE */}
      <div className="flex-1 overflow-y-auto overflow-x-hidden bg-studio-900 min-h-0 relative">
        <div className="h-5 bg-studio-800 border-b border-studio-600/40 sticky top-0 z-10 flex items-center relative">
          {Array.from({ length: 11 }, (_, i) => (
            <div key={i} className="absolute top-0 bottom-0 flex items-center border-l border-studio-600/30 pl-1" style={{ left: `${i * 10}%` }}>
              <span className="numeric text-[8px] text-studio-500">{Math.round((i / 10) * (duration || 0))}s</span>
            </div>
          ))}
          <div className="absolute top-0 bottom-0 w-0.5 bg-accent z-20 pointer-events-none" style={{ left: `${progress * 100}%`, boxShadow: '0 0 6px rgba(4,197,247,0.5)' }} />
        </div>

        {pistasVisibles.map(pista => (
          <div key={pista.id} className="h-12 flex border-b border-studio-800/60 hover:bg-studio-800/20 transition-colors relative">
            <div className="w-12 flex-shrink-0 flex items-center justify-center bg-studio-800 border-r border-studio-600/40 sticky left-0 z-[5] p-1">
              <div className="flex flex-col items-center gap-0.5">
                <div className="w-5 h-0.5 rounded-full" style={{ background: pista.color }} />
                <span className="text-[8px] font-semibold text-studio-300 leading-tight text-center">{pista.nombre}</span>
              </div>
            </div>
            <div className="flex-1 relative overflow-hidden" style={{ filter: pista.muted ? 'grayscale(1) brightness(0.4)' : 'none' }}>
              {(cancionActiva?.marcadores ?? []).map(m => (
                <div key={m.id} className="absolute top-0 h-3.5 flex items-center px-1 border-l-2 z-10 pointer-events-none"
                  style={{ left: `${m.posicion * 100}%`, borderColor: m.color, background: m.color + '18' }}>
                  <span className="text-[8px] font-bold font-mono leading-none" style={{ color: m.color }}>{m.etiqueta}</span>
                </div>
              ))}
              <div className="absolute inset-0 pt-4 flex items-center gap-px px-1 pb-1">
                {pista.waveformData
                  ? Array.from(pista.waveformData).map((v, i) => (
                      <div key={i} className="flex-1 rounded-sm" style={{ height: `${v * 100}%`, background: pista.color + '60', minWidth: 1 }} />
                    ))
                  : Array.from({ length: 80 }, (_, i) => (
                      <div key={i} className="flex-1 rounded-sm" style={{ height: `${15 + Math.random() * 70}%`, background: pista.color + '50', minWidth: 1 }} />
                    ))
                }
              </div>
            </div>
            <div className="absolute top-0 bottom-0 w-px pointer-events-none z-10"
              style={{ left: `calc(48px + ${progress * 100}%)`, background: 'rgba(255,255,255,0.7)', boxShadow: '0 0 4px rgba(255,255,255,0.4)' }} />
          </div>
        ))}
      </div>

      {/* MIXER */}
      <div className="h-52 flex-shrink-0 flex overflow-x-auto bg-studio-800 border-t border-studio-600/40 shadow-[0_-4px_20px_rgba(0,0,0,0.4)] [&::-webkit-scrollbar]:hidden">
        {[...pistasVisibles,
          { id: 'master', nombre: 'Master', color: '#04C5F7', volumen: 90, muted: false, soloed: false, origen: 'custom' as const }
        ].map((pista) => {
          const isMaster = pista.id === 'master'
          const val = pista.volumen ?? 70
          const dBDisplay = (v: number) => {
            if (v === 0) return '-\u221E'
            const db = 20 * Math.log10(v / 100)
            return (db >= 0 ? '+' : '') + db.toFixed(1)
          }

          return (
            <div key={pista.id}
              className={`flex-shrink-0 ${isMaster ? 'w-20' : 'w-16'} flex flex-col items-center border-r border-studio-600/30 px-1.5 py-2 gap-1.5 hover:bg-studio-700/30 transition-colors ${isMaster ? 'bg-studio-700 sticky right-0 border-l border-studio-500/40' : ''}`}>
              {!isMaster && (
                <div className="flex gap-1 w-full">
                  <button onClick={() => toggleSolo(pista.id)}
                    className={`flex-1 h-4 rounded text-[8px] font-bold border transition-all ${pista.soloed ? 'border-led-green text-led-green bg-led-green/10' : 'border-studio-600 text-studio-500'}`}>S</button>
                  <button onClick={() => toggleMute(pista.id)}
                    className={`flex-1 h-4 rounded text-[8px] font-bold border transition-all ${pista.muted ? 'border-led-amber text-led-amber bg-led-amber/10' : 'border-studio-600 text-studio-500'}`}>M</button>
                </div>
              )}
              {isMaster && <span className="hw-label text-studio-400 text-[8px]">MASTER</span>}
              <div className="flex-1 w-full flex items-center justify-center" style={{ minHeight: 80 }}>
                <input type="range" min={0} max={100} step={1} value={val}
                  onChange={e => setFader(pista.id, +e.target.value)}
                  className="accent-accent cursor-grab"
                  style={{ height: 80, writingMode: 'vertical-lr' as never, direction: 'rtl' as never }} />
              </div>
              <span className="numeric text-[9px]" style={{ color: isMaster ? '#04C5F7' : '#707070' }}>{dBDisplay(val)}</span>
              <div className="flex items-center gap-1 justify-center">
                <div className="w-2 h-2 rounded-full flex-shrink-0" style={{ background: pista.color }} />
                <span className="text-[8px] font-semibold text-studio-300 text-center leading-tight truncate max-w-[44px]">{pista.nombre}</span>
              </div>
            </div>
          )
        })}
      </div>

      {/* BOTTOM TABS */}
      <div className="h-8 flex-shrink-0 bg-studio-800 border-t border-studio-600/40 flex overflow-x-auto [&::-webkit-scrollbar]:hidden">
        {BOTTOM_TABS.map((tab, i) => (
          <button key={i} onClick={() => setTabActivo(i)}
            className={`flex-shrink-0 px-3 text-[10px] font-medium border-b-2 whitespace-nowrap transition-all ${tabActivo === i ? 'text-accent border-accent' : 'text-studio-500 border-transparent hover:text-studio-300'}`}>
            {tab}
          </button>
        ))}
      </div>

      {/* MODAL REPERTORIOS */}
      {modalRepert && (
        <div className="fixed inset-0 bg-black/75 backdrop-blur-sm z-50 flex items-end" onClick={() => setModalRepert(false)}>
          <div className="w-full bg-studio-800 rounded-t-2xl border border-studio-600/40 max-h-[75vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
            <div className="w-9 h-1 bg-studio-600 rounded-full mx-auto mt-3" />
            <h2 className="text-sm font-bold text-studio-100 text-center py-3">Repertorios</h2>
            <div className="mx-3 mb-2 p-3 rounded-lg bg-red-500/[0.08] border border-red-500/20 flex gap-3 items-start">
              <div className="w-2 h-2 rounded-full bg-led-red mt-1 flex-shrink-0" />
              <div>
                <p className="text-[12px] font-semibold text-studio-100 mb-0.5">Cambios no guardados</p>
                <p className="text-[11px] text-studio-400">Guarda a la Nube para compartir con tu equipo.</p>
              </div>
            </div>
            <button className="mx-3 mb-3 w-[calc(100%-24px)] py-2.5 rounded-lg bg-accent/10 border border-accent text-accent text-[12px] font-semibold">
              {'\u2601'} Guardar a la Nube
            </button>
            {[
              { icon: '\uD83D\uDCC1', title: 'Nuevo Repertorio' },
              { icon: '\uD83D\uDCC2', title: 'Abrir Repertorio' },
              { icon: '\uD83D\uDD17', title: 'Conectar a Planning Center', sub: 'Importa tu lista de canciones como repertorio.' },
            ].map(item => (
              <div key={item.title} className="flex items-center gap-3 px-4 py-3 border-b border-studio-700/40 cursor-pointer hover:bg-studio-700/30 transition-colors">
                <div className="w-9 h-9 rounded-lg bg-studio-700 flex items-center justify-center text-base flex-shrink-0">{item.icon}</div>
                <div className="flex-1">
                  <p className="text-[13px] font-semibold text-studio-100">{item.title}</p>
                  {item.sub && <p className="text-[11px] text-studio-400 mt-0.5">{item.sub}</p>}
                </div>
                <span className="text-studio-500">{'\u203A'}</span>
              </div>
            ))}
            {repertorio && (
              <>
                <p className="hw-label px-4 pt-3 pb-1">Repertorio Actual</p>
                <div className="flex items-center gap-3 px-4 py-3 bg-studio-700/30 cursor-pointer">
                  <div className="w-9 h-9 rounded-lg bg-studio-600 flex items-center justify-center text-base">{'\u267E\uFE0F'}</div>
                  <div className="flex-1">
                    <p className="text-[13px] font-semibold text-studio-100">{repertorio.nombre}</p>
                    <p className="text-[11px] text-studio-400">{repertorio.fecha} {'\u00B7'} {repertorio.canciones.length} Canciones</p>
                  </div>
                  <span className="text-accent">{'\u203A'}</span>
                </div>
              </>
            )}
            <button onClick={() => setModalRepert(false)} className="w-full py-4 text-center text-accent text-[14px] font-medium border-t border-studio-600/40">Cancelar</button>
          </div>
        </div>
      )}

      {/* MODAL SECUENCIAS */}
      {modalSeq && (
        <div className="fixed inset-0 bg-black/75 backdrop-blur-sm z-50 flex items-end" onClick={() => setModalSeq(false)}>
          <div className="w-full bg-studio-800 rounded-t-2xl border border-studio-600/40 max-h-[70vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
            <div className="w-9 h-1 bg-studio-600 rounded-full mx-auto mt-3" />
            <div className="flex items-center px-4 py-3">
              <button onClick={() => setModalSeq(false)} className="text-accent text-[13px]">{'\u2039'} Atras</button>
              <h2 className="flex-1 text-[14px] font-bold text-studio-100 text-center">Seleccionar Secuencias</h2>
              <button className="text-accent text-[13px]">Agregar</button>
            </div>
            {SECUENCIAS.map(nombre => {
              const activa = seqActivas.has(nombre)
              return (
                <div key={nombre}
                  className="flex items-center justify-between px-4 py-3 border-b border-studio-700/40 cursor-pointer hover:bg-studio-700/30 transition-colors"
                  onClick={() => setSeqActivas(prev => {
                    const next = new Set(prev)
                    if (next.has(nombre)) next.delete(nombre)
                    else next.add(nombre)
                    return next
                  })}>
                  <span className="text-[13px] text-studio-100">{nombre}</span>
                  <div className={`w-5 h-5 rounded-full flex items-center justify-center text-[11px] font-bold transition-all ${activa ? 'bg-accent text-studio-900' : 'bg-transparent border border-studio-600'}`}>
                    {activa ? '\u2713' : ''}
                  </div>
                </div>
              )
            })}
            <button onClick={() => setSeqActivas(new Set())} className="w-full py-3 text-center text-accent text-[13px] font-medium border-t border-studio-600/40">Anular todas las selecciones</button>
          </div>
        </div>
      )}
    </div>
  )
}
