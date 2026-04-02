/**
 * Playback Modals — Repertoire and Sequences selection modals
 *
 * Bottom-sheet style modals matching the existing GrooveLab design language.
 */
import { cn } from '@/lib/cn'
import { LED } from '@/components/ui/LED'
import type { PlaybackRepertoire } from '../types'
import { SEQUENCE_NAMES } from '../constants'

/* ── Repertoire Modal ── */

interface RepertoireModalProps {
  open: boolean
  repertoire: PlaybackRepertoire | null
  onClose: () => void
}

export function RepertoireModal({ open, repertoire, onClose }: RepertoireModalProps) {
  if (!open) return null

  return (
    <div
      className="fixed inset-0 bg-black/75 backdrop-blur-sm z-50 flex items-end"
      onClick={onClose}
    >
      <div
        className="w-full bg-studio-800 rounded-t-2xl border border-studio-600/40 max-h-[75vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="w-9 h-1 bg-studio-600 rounded-full mx-auto mt-3" />
        <h2 className="text-sm font-bold text-studio-100 text-center py-3">
          Repertorios
        </h2>

        {/* Unsaved changes warning */}
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

        {/* Save to cloud button */}
        <button className="mx-3 mb-3 w-[calc(100%-24px)] py-2.5 rounded-lg bg-accent/10 border border-accent text-accent text-[12px] font-semibold">
          {'\u2601'} Guardar a la Nube
        </button>

        {/* Options */}
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
            <span className="text-studio-500">&rsaquo;</span>
          </div>
        ))}

        {/* Current repertoire */}
        {repertoire && (
          <>
            <p className="hw-label px-4 pt-3 pb-1">Repertorio Actual</p>
            <div className="flex items-center gap-3 px-4 py-3 bg-studio-700/30 cursor-pointer">
              <div className="w-9 h-9 rounded-lg bg-studio-600 flex items-center justify-center text-base">
                {'\u267E\uFE0F'}
              </div>
              <div className="flex-1">
                <p className="text-[13px] font-semibold text-studio-100">
                  {repertoire.name}
                </p>
                <p className="text-[11px] text-studio-400">
                  {repertoire.date} &middot; {repertoire.songs.length} Canciones
                </p>
              </div>
              <span className="text-accent">&rsaquo;</span>
            </div>
          </>
        )}

        {/* Cancel */}
        <button
          onClick={onClose}
          className="w-full py-4 text-center text-accent text-[14px] font-medium border-t border-studio-600/40"
        >
          Cancelar
        </button>
      </div>
    </div>
  )
}

/* ── Sequences Modal ── */

interface SequencesModalProps {
  open: boolean
  visibleSequences: string[]
  onToggle: (name: string) => void
  onDeselectAll: () => void
  onClose: () => void
}

export function SequencesModal({ open, visibleSequences, onToggle, onDeselectAll, onClose }: SequencesModalProps) {
  if (!open) return null

  return (
    <div
      className="fixed inset-0 bg-black/75 backdrop-blur-sm z-50 flex items-end"
      onClick={onClose}
    >
      <div
        className="w-full bg-studio-800 rounded-t-2xl border border-studio-600/40 max-h-[70vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="w-9 h-1 bg-studio-600 rounded-full mx-auto mt-3" />
        <div className="flex items-center px-4 py-3">
          <button onClick={onClose} className="text-accent text-[13px]">
            &lsaquo; Atras
          </button>
          <h2 className="flex-1 text-[14px] font-bold text-studio-100 text-center">
            Seleccionar Secuencias
          </h2>
          <button className="text-accent text-[13px]">Agregar</button>
        </div>

        {SEQUENCE_NAMES.map((nombre) => {
          const activa = visibleSequences.includes(nombre)
          return (
            <div
              key={nombre}
              className="flex items-center justify-between px-4 py-3 border-b border-studio-700/40 cursor-pointer hover:bg-studio-700/30 transition-colors"
              onClick={() => onToggle(nombre)}
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
          onClick={onDeselectAll}
          className="w-full py-3 text-center text-accent text-[13px] font-medium border-t border-studio-600/40"
        >
          Anular todas las selecciones
        </button>
      </div>
    </div>
  )
}
