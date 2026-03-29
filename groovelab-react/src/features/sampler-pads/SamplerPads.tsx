import { useState, useRef, useEffect, useCallback, useMemo } from 'react';
import * as Tone from 'tone';
import { cn } from '@/lib/cn';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

enum PadMode {
  ONE_SHOT = 'ONE_SHOT',
  LOOP = 'LOOP',
  TOGGLE = 'TOGGLE',
}

interface PadConfig {
  id: number;
  name: string;
  note: string;
  color: string;
  mode: PadMode;
  volume: number; // 0-1
  isChord: boolean;
  chordNotes?: string[];
}

type GridSize = 4 | 8;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const PAD_COLORS = [
  '#FF3B30', '#FF9500', '#FFCC00', '#34C759',
  '#00E5FF', '#5AC8FA', '#007AFF', '#5856D6',
  '#BF5AF2', '#FF2D55', '#FF6482', '#AC8E68',
  '#8E8E93', '#00FF11', '#FF375F', '#30D158',
] as const;

const NOTES_BANK: { note: string; name: string; isChord: boolean; chordNotes?: string[] }[] = [
  { note: 'C3', name: 'C3', isChord: false },
  { note: 'D3', name: 'D3', isChord: false },
  { note: 'E3', name: 'E3', isChord: false },
  { note: 'F3', name: 'F3', isChord: false },
  { note: 'G3', name: 'G3', isChord: false },
  { note: 'A3', name: 'A3', isChord: false },
  { note: 'B3', name: 'B3', isChord: false },
  { note: 'C4', name: 'C4', isChord: false },
  { note: 'D4', name: 'D4', isChord: false },
  { note: 'E4', name: 'E4', isChord: false },
  { note: 'F4', name: 'F4', isChord: false },
  { note: 'G4', name: 'G4', isChord: false },
  { note: 'A4', name: 'A4', isChord: false },
  { note: 'B4', name: 'B4', isChord: false },
  { note: 'C5', name: 'C5', isChord: false },
  { note: 'C3', name: 'Cmaj', isChord: true, chordNotes: ['C3', 'E3', 'G3'] },
  // Extended bank for 8x8 mode (indices 16-63)
  { note: 'D3', name: 'Dm', isChord: true, chordNotes: ['D3', 'F3', 'A3'] },
  { note: 'E3', name: 'Em', isChord: true, chordNotes: ['E3', 'G3', 'B3'] },
  { note: 'F3', name: 'Fmaj', isChord: true, chordNotes: ['F3', 'A3', 'C4'] },
  { note: 'G3', name: 'Gmaj', isChord: true, chordNotes: ['G3', 'B3', 'D4'] },
  { note: 'A3', name: 'Am', isChord: true, chordNotes: ['A3', 'C4', 'E4'] },
  { note: 'B3', name: 'Bdim', isChord: true, chordNotes: ['B3', 'D4', 'F4'] },
  { note: 'C4', name: 'Cmaj4', isChord: true, chordNotes: ['C4', 'E4', 'G4'] },
  { note: 'C3', name: 'C3 Low', isChord: false },
  { note: 'D3', name: 'D3 Low', isChord: false },
  { note: 'E3', name: 'E3 Low', isChord: false },
  { note: 'F3', name: 'F3 Low', isChord: false },
  { note: 'G3', name: 'G3 Low', isChord: false },
  { note: 'A3', name: 'A3 Low', isChord: false },
  { note: 'B3', name: 'B3 Low', isChord: false },
  { note: 'C4', name: 'C4 Mid', isChord: false },
  { note: 'D4', name: 'D4 Mid', isChord: false },
  { note: 'E4', name: 'E4 Mid', isChord: false },
  { note: 'F4', name: 'F4 Mid', isChord: false },
  { note: 'G4', name: 'G4 Mid', isChord: false },
  { note: 'A4', name: 'A4 Mid', isChord: false },
  { note: 'B4', name: 'B4 Mid', isChord: false },
  { note: 'C5', name: 'C5 High', isChord: false },
  { note: 'D5', name: 'D5', isChord: false },
  { note: 'E5', name: 'E5', isChord: false },
  { note: 'F5', name: 'F5', isChord: false },
  { note: 'G5', name: 'G5', isChord: false },
  { note: 'A5', name: 'A5', isChord: false },
  { note: 'B5', name: 'B5', isChord: false },
  { note: 'C6', name: 'C6', isChord: false },
  { note: 'D4', name: 'Dm4', isChord: true, chordNotes: ['D4', 'F4', 'A4'] },
  { note: 'E4', name: 'Em4', isChord: true, chordNotes: ['E4', 'G4', 'B4'] },
  { note: 'F4', name: 'Fmaj4', isChord: true, chordNotes: ['F4', 'A4', 'C5'] },
  { note: 'G4', name: 'Gmaj4', isChord: true, chordNotes: ['G4', 'B4', 'D5'] },
  { note: 'A4', name: 'Am4', isChord: true, chordNotes: ['A4', 'C5', 'E5'] },
  { note: 'C3', name: 'Cmaj7', isChord: true, chordNotes: ['C3', 'E3', 'G3', 'B3'] },
  { note: 'D3', name: 'Dm7', isChord: true, chordNotes: ['D3', 'F3', 'A3', 'C4'] },
  { note: 'G3', name: 'G7', isChord: true, chordNotes: ['G3', 'B3', 'D4', 'F4'] },
  { note: 'F3', name: 'Fmaj7', isChord: true, chordNotes: ['F3', 'A3', 'C4', 'E4'] },
  { note: 'A3', name: 'Am7', isChord: true, chordNotes: ['A3', 'C4', 'E4', 'G4'] },
  { note: 'E3', name: 'Em7', isChord: true, chordNotes: ['E3', 'G3', 'B3', 'D4'] },
  { note: 'C4', name: 'Csus4', isChord: true, chordNotes: ['C4', 'F4', 'G4'] },
  { note: 'G4', name: 'Gsus4', isChord: true, chordNotes: ['G4', 'C5', 'D5'] },
  { note: 'D4', name: 'Dsus2', isChord: true, chordNotes: ['D4', 'E4', 'A4'] },
  { note: 'A4', name: 'Asus2', isChord: true, chordNotes: ['A4', 'B4', 'E5'] },
];

function buildPadConfigs(count: number): PadConfig[] {
  return Array.from({ length: count }, (_, i) => {
    const bank = NOTES_BANK[i % NOTES_BANK.length];
    return {
      id: i,
      name: bank.name,
      note: bank.note,
      color: PAD_COLORS[i % PAD_COLORS.length],
      mode: PadMode.ONE_SHOT,
      volume: 0.8,
      isChord: bank.isChord,
      chordNotes: bank.chordNotes,
    };
  });
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function SamplerPads() {
  const [activeGrid, setActiveGrid] = useState<GridSize>(4);
  const [pads, setPads] = useState<PadConfig[]>(() => buildPadConfigs(16));
  const [activePads, setActivePads] = useState<Set<number>>(() => new Set());
  const [hitPads, setHitPads] = useState<Set<number>>(() => new Set());
  const [pressedPads, setPressedPads] = useState<Set<number>>(() => new Set());
  const [masterVolume, setMasterVolume] = useState(0.8);
  const [selectedMode, setSelectedMode] = useState<PadMode>(PadMode.ONE_SHOT);

  // Audio refs
  const masterGainRef = useRef<Tone.Gain | null>(null);
  const synthsRef = useRef<Map<number, Tone.Synth | Tone.PolySynth>>(new Map());
  const loopIdsRef = useRef<Map<number, number>>(new Map()); // for LOOP mode intervals

  const padCount = activeGrid === 4 ? 16 : 64;

  // -----------------------------------------------------------------------
  // Audio initialisation
  // -----------------------------------------------------------------------

  const ensureAudioContext = useCallback(async () => {
    if (Tone.getContext().state !== 'running') {
      await Tone.start();
    }
  }, []);

  // Create / recreate master gain
  useEffect(() => {
    const gain = new Tone.Gain(masterVolume).toDestination();
    masterGainRef.current = gain;
    return () => {
      gain.dispose();
    };
    // only on mount
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Keep master volume in sync
  useEffect(() => {
    if (masterGainRef.current) {
      masterGainRef.current.gain.rampTo(masterVolume, 0.05);
    }
  }, [masterVolume]);

  // Build synths when pad list changes
  useEffect(() => {
    const master = masterGainRef.current;
    if (!master) return;

    // Dispose old synths
    synthsRef.current.forEach((s) => s.dispose());
    synthsRef.current.clear();

    pads.forEach((pad) => {
      if (pad.isChord) {
        const poly = new Tone.PolySynth(Tone.Synth, {
          oscillator: { type: 'triangle' },
          envelope: { attack: 0.02, decay: 0.3, sustain: 0.4, release: 0.8 },
        }).connect(master);
        synthsRef.current.set(pad.id, poly);
      } else {
        const synth = new Tone.Synth({
          oscillator: { type: 'triangle' },
          envelope: { attack: 0.01, decay: 0.2, sustain: 0.3, release: 0.6 },
        }).connect(master);
        synthsRef.current.set(pad.id, synth);
      }
    });

    return () => {
      synthsRef.current.forEach((s) => s.dispose());
      synthsRef.current.clear();
    };
  }, [pads]);

  // Cleanup loops on unmount
  useEffect(() => {
    return () => {
      loopIdsRef.current.forEach((id) => clearInterval(id));
      loopIdsRef.current.clear();
    };
  }, []);

  // -----------------------------------------------------------------------
  // Grid size switching
  // -----------------------------------------------------------------------

  const toggleGrid = useCallback(() => {
    // Stop all active sounds first
    loopIdsRef.current.forEach((id) => clearInterval(id));
    loopIdsRef.current.clear();
    setActivePads(new Set());

    const next: GridSize = activeGrid === 4 ? 8 : 4;
    setActiveGrid(next);
    setPads(buildPadConfigs(next === 4 ? 16 : 64));
  }, [activeGrid]);

  // -----------------------------------------------------------------------
  // Pad trigger logic
  // -----------------------------------------------------------------------

  const triggerPad = useCallback(
    async (pad: PadConfig, velocity: number) => {
      await ensureAudioContext();

      const synth = synthsRef.current.get(pad.id);
      if (!synth) return;

      const vol = pad.volume * velocity;
      synth.volume.value = Tone.gainToDb(vol);

      const duration = '8n';

      switch (pad.mode) {
        case PadMode.ONE_SHOT: {
          if (pad.isChord && pad.chordNotes && synth instanceof Tone.PolySynth) {
            synth.triggerAttackRelease(pad.chordNotes, duration);
          } else if (synth instanceof Tone.Synth) {
            synth.triggerAttackRelease(pad.note, duration);
          }
          // Hit flash
          setHitPads((prev) => new Set(prev).add(pad.id));
          setTimeout(() => {
            setHitPads((prev) => {
              const next = new Set(prev);
              next.delete(pad.id);
              return next;
            });
          }, 200);
          break;
        }

        case PadMode.LOOP: {
          if (activePads.has(pad.id)) {
            // Stop loop
            const loopId = loopIdsRef.current.get(pad.id);
            if (loopId != null) clearInterval(loopId);
            loopIdsRef.current.delete(pad.id);
            setActivePads((prev) => {
              const next = new Set(prev);
              next.delete(pad.id);
              return next;
            });
          } else {
            // Start loop
            const play = () => {
              const s = synthsRef.current.get(pad.id);
              if (!s) return;
              s.volume.value = Tone.gainToDb(vol);
              if (pad.isChord && pad.chordNotes && s instanceof Tone.PolySynth) {
                s.triggerAttackRelease(pad.chordNotes, duration);
              } else if (s instanceof Tone.Synth) {
                s.triggerAttackRelease(pad.note, duration);
              }
            };
            play();
            const id = window.setInterval(play, 500);
            loopIdsRef.current.set(pad.id, id);
            setActivePads((prev) => new Set(prev).add(pad.id));
          }
          break;
        }

        case PadMode.TOGGLE: {
          if (activePads.has(pad.id)) {
            // Release
            if (synth instanceof Tone.PolySynth && pad.chordNotes) {
              synth.triggerRelease(pad.chordNotes);
            } else if (synth instanceof Tone.Synth) {
              synth.triggerRelease();
            }
            setActivePads((prev) => {
              const next = new Set(prev);
              next.delete(pad.id);
              return next;
            });
          } else {
            // Attack (sustain until toggled off)
            if (pad.isChord && pad.chordNotes && synth instanceof Tone.PolySynth) {
              synth.triggerAttack(pad.chordNotes);
            } else if (synth instanceof Tone.Synth) {
              synth.triggerAttack(pad.note);
            }
            setActivePads((prev) => new Set(prev).add(pad.id));
          }
          break;
        }
      }
    },
    [activePads, ensureAudioContext],
  );

  // -----------------------------------------------------------------------
  // Velocity from pointer
  // -----------------------------------------------------------------------

  const getVelocity = useCallback((e: React.PointerEvent<HTMLButtonElement>) => {
    // Use pressure if available (stylus / force-touch)
    if (e.pressure > 0 && e.pressure < 1) {
      return 0.3 + e.pressure * 0.7; // map 0-1 → 0.3-1.0
    }
    // Fallback: distance from center of pad
    const rect = e.currentTarget.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    const dx = e.clientX - cx;
    const dy = e.clientY - cy;
    const maxDist = Math.sqrt((rect.width / 2) ** 2 + (rect.height / 2) ** 2);
    const dist = Math.sqrt(dx * dx + dy * dy);
    const normalized = 1 - Math.min(dist / maxDist, 1); // center = 1, edge = 0
    return 0.4 + normalized * 0.6; // map 0-1 → 0.4-1.0
  }, []);

  // -----------------------------------------------------------------------
  // Pad mode change (applied to new presses)
  // -----------------------------------------------------------------------

  const applyModeToAll = useCallback(
    (mode: PadMode) => {
      setSelectedMode(mode);
      setPads((prev) => prev.map((p) => ({ ...p, mode })));
      // Clear active pads and loops when switching modes
      loopIdsRef.current.forEach((id) => clearInterval(id));
      loopIdsRef.current.clear();
      activePads.forEach((padId) => {
        const synth = synthsRef.current.get(padId);
        if (synth instanceof Tone.PolySynth) {
          synth.releaseAll();
        } else if (synth instanceof Tone.Synth) {
          synth.triggerRelease();
        }
      });
      setActivePads(new Set());
    },
    [activePads],
  );

  // -----------------------------------------------------------------------
  // Pointer handlers
  // -----------------------------------------------------------------------

  const handlePointerDown = useCallback(
    (pad: PadConfig, e: React.PointerEvent<HTMLButtonElement>) => {
      e.currentTarget.setPointerCapture(e.pointerId);
      setPressedPads((prev) => new Set(prev).add(pad.id));
      const vel = getVelocity(e);
      triggerPad(pad, vel);
    },
    [getVelocity, triggerPad],
  );

  const handlePointerUp = useCallback((padId: number) => {
    setPressedPads((prev) => {
      const next = new Set(prev);
      next.delete(padId);
      return next;
    });
  }, []);

  // -----------------------------------------------------------------------
  // Memoised pad elements
  // -----------------------------------------------------------------------

  const gridCols = activeGrid === 4 ? 'grid-cols-4' : 'grid-cols-8';

  const padElements = useMemo(() => {
    return pads.slice(0, padCount).map((pad) => {
      const isActive = activePads.has(pad.id);
      const isHit = hitPads.has(pad.id);
      const isPressed = pressedPads.has(pad.id);

      return (
        <button
          key={pad.id}
          type="button"
          className={cn(
            'relative flex flex-col items-center justify-center rounded-xl',
            'min-h-[80px] select-none touch-none',
            'border border-white/10 transition-all duration-100',
            'active:scale-95 cursor-pointer',
            isHit && 'animate-pad-hit',
            isPressed && 'scale-[0.94]',
          )}
          style={{
            backgroundColor: `${pad.color}22`,
            boxShadow: isActive ? `0 0 20px ${pad.color}88, inset 0 0 12px ${pad.color}44` : 'none',
            borderColor: isActive ? pad.color : undefined,
          }}
          onPointerDown={(e) => handlePointerDown(pad, e)}
          onPointerUp={() => handlePointerUp(pad.id)}
          onPointerCancel={() => handlePointerUp(pad.id)}
          onContextMenu={(e) => e.preventDefault()}
        >
          {/* Pad number */}
          <span className="text-[10px] font-medium text-white/40 absolute top-1 left-2">
            {pad.id + 1}
          </span>

          {/* Pad name */}
          <span
            className={cn(
              'text-sm font-semibold transition-colors',
              isActive ? 'text-white' : 'text-white/70',
            )}
          >
            {pad.name}
          </span>

          {/* Mode indicator */}
          <span className="text-[9px] text-white/30 mt-0.5">
            {pad.mode === PadMode.ONE_SHOT ? 'shot' : pad.mode === PadMode.LOOP ? 'loop' : 'hold'}
          </span>

          {/* Active pulse dot */}
          {isActive && (
            <span
              className="absolute top-1.5 right-2 h-2 w-2 rounded-full animate-pulse"
              style={{ backgroundColor: pad.color }}
            />
          )}
        </button>
      );
    });
  }, [pads, padCount, activePads, hitPads, pressedPads, handlePointerDown, handlePointerUp]);

  // -----------------------------------------------------------------------
  // Render
  // -----------------------------------------------------------------------

  return (
    <div className="flex flex-col h-full w-full bg-black/50 backdrop-blur-sm rounded-2xl p-4 gap-4 overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between shrink-0">
        <h2 className="text-lg font-bold text-white tracking-tight">Sampler Pads</h2>
        <span className="text-xs text-white/40">
          {activeGrid}x{activeGrid} &middot; {padCount} pads
        </span>
      </div>

      {/* Pad Grid */}
      <div
        className={cn(
          'grid gap-2 flex-1 auto-rows-fr overflow-y-auto',
          gridCols,
        )}
      >
        {padElements}
      </div>

      {/* Bottom Toolbar */}
      <div className="flex items-center gap-4 shrink-0 flex-wrap">
        {/* Grid toggle */}
        <div className="flex items-center gap-1 bg-white/5 rounded-lg p-1">
          <button
            type="button"
            className={cn(
              'px-3 py-1.5 rounded-md text-xs font-medium transition-colors',
              activeGrid === 4
                ? 'bg-white/15 text-white'
                : 'text-white/50 hover:text-white/70',
            )}
            onClick={() => activeGrid !== 4 && toggleGrid()}
          >
            4x4
          </button>
          <button
            type="button"
            className={cn(
              'px-3 py-1.5 rounded-md text-xs font-medium transition-colors',
              activeGrid === 8
                ? 'bg-white/15 text-white'
                : 'text-white/50 hover:text-white/70',
            )}
            onClick={() => activeGrid !== 8 && toggleGrid()}
          >
            8x8
          </button>
        </div>

        {/* Pad mode selector */}
        <div className="flex items-center gap-1 bg-white/5 rounded-lg p-1">
          {([PadMode.ONE_SHOT, PadMode.LOOP, PadMode.TOGGLE] as const).map((mode) => {
            const label = mode === PadMode.ONE_SHOT ? 'One-Shot' : mode === PadMode.LOOP ? 'Loop' : 'Toggle';
            return (
              <button
                key={mode}
                type="button"
                className={cn(
                  'px-3 py-1.5 rounded-md text-xs font-medium transition-colors',
                  selectedMode === mode
                    ? 'bg-white/15 text-white'
                    : 'text-white/50 hover:text-white/70',
                )}
                onClick={() => applyModeToAll(mode)}
              >
                {label}
              </button>
            );
          })}
        </div>

        {/* Master volume */}
        <div className="flex items-center gap-2 ml-auto">
          <span className="text-xs text-white/50">Vol</span>
          <input
            type="range"
            min={0}
            max={1}
            step={0.01}
            value={masterVolume}
            onChange={(e) => setMasterVolume(parseFloat(e.target.value))}
            className="w-24 h-1.5 appearance-none bg-white/20 rounded-full outline-none
                       [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-3.5
                       [&::-webkit-slider-thumb]:h-3.5 [&::-webkit-slider-thumb]:rounded-full
                       [&::-webkit-slider-thumb]:bg-white [&::-webkit-slider-thumb]:cursor-pointer
                       [&::-moz-range-thumb]:w-3.5 [&::-moz-range-thumb]:h-3.5
                       [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:bg-white
                       [&::-moz-range-thumb]:border-0 [&::-moz-range-thumb]:cursor-pointer"
          />
          <span className="text-xs text-white/40 w-8 text-right tabular-nums">
            {Math.round(masterVolume * 100)}
          </span>
        </div>
      </div>
    </div>
  );
}
