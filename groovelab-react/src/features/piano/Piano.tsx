import { useCallback, useEffect, useMemo, useRef, useState, Suspense } from 'react';
import * as Tone from 'tone';
import { cn } from '@/lib/cn';
import { Canvas, useFrame, useLoader } from '@react-three/fiber';
import { Environment, RoundedBox } from '@react-three/drei';
import { EffectComposer, Bloom } from '@react-three/postprocessing';
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type InstrumentId = 'grand' | 'rhodes' | 'wurlitzer' | 'clavinet' | 'organ';

interface NoteDefinition {
  note: string; // e.g. "C4"
  midi: number;
  isBlack: boolean;
  label: string; // e.g. "C"
}

interface InstrumentOption {
  id: InstrumentId;
  name: string;
  icon: string;
  color: string; // tailwind-compatible hex for glow
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const INSTRUMENTS: InstrumentOption[] = [
  { id: 'grand', name: 'Grand Piano', icon: '🎹', color: '#00E5FF' },
  { id: 'rhodes', name: 'Rhodes', icon: '🎸', color: '#FF9500' },
  { id: 'wurlitzer', name: 'Wurlitzer', icon: '🎶', color: '#BF5AF2' },
  { id: 'clavinet', name: 'Clavinet', icon: '🔑', color: '#00FF11' },
  { id: 'organ', name: 'Organ', icon: '⛪', color: '#FF3B30' },
];

const INSTRUMENT_COLOR_MAP: Record<InstrumentId, string> = {
  grand: '#00E5FF',
  rhodes: '#FF9500',
  wurlitzer: '#BF5AF2',
  clavinet: '#00FF11',
  organ: '#FF3B30',
};

const NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const BLACK_NOTE_SET = new Set([1, 3, 6, 8, 10]); // semitone indices of black keys

/** Build 61 keys from C2 to C7 */
function buildKeys(): NoteDefinition[] {
  const keys: NoteDefinition[] = [];
  const startOctave = 2;
  const endNote = { name: 'C', octave: 7 };

  for (let octave = startOctave; octave <= 7; octave++) {
    for (let semitone = 0; semitone < 12; semitone++) {
      const noteName = NOTE_NAMES[semitone];
      const note = `${noteName}${octave}`;
      const midi = (octave + 1) * 12 + semitone; // MIDI number
      keys.push({
        note,
        midi,
        isBlack: BLACK_NOTE_SET.has(semitone),
        label: noteName,
      });
      if (noteName === endNote.name && octave === endNote.octave) {
        return keys;
      }
    }
  }
  return keys;
}

const ALL_KEYS = buildKeys();

/** How many white keys exist in a range */
function countWhiteKeys(keys: NoteDefinition[]): number {
  return keys.filter((k) => !k.isBlack).length;
}

// Visible octaves at a time
const VISIBLE_OCTAVES = 3;
const KEYS_PER_OCTAVE = 12;

// ---------------------------------------------------------------------------
// Synth factory
// ---------------------------------------------------------------------------

function createSynth(instrument: InstrumentId): Tone.PolySynth {
  switch (instrument) {
    case 'grand':
      return new Tone.PolySynth(Tone.Synth, {
        maxPolyphony: 16,
        voice: Tone.Synth,
        options: {
          oscillator: { type: 'triangle' },
          envelope: { attack: 0.005, decay: 0.4, sustain: 0.3, release: 1.4 },
          detune: 4,
        },
      } as unknown as Partial<Tone.SynthOptions>);

    case 'rhodes':
      return new Tone.PolySynth(Tone.FMSynth, {
        maxPolyphony: 16,
        voice: Tone.FMSynth,
        options: {
          harmonicity: 3.01,
          modulationIndex: 14,
          oscillator: { type: 'triangle' },
          envelope: { attack: 0.002, decay: 0.5, sustain: 0.2, release: 1.2 },
          modulation: { type: 'square' },
          modulationEnvelope: { attack: 0.002, decay: 0.2, sustain: 0, release: 0.5 },
        },
      } as unknown as Partial<Tone.FMSynthOptions>);

    case 'wurlitzer':
      return new Tone.PolySynth(Tone.AMSynth, {
        maxPolyphony: 16,
        voice: Tone.AMSynth,
        options: {
          harmonicity: 2,
          oscillator: { type: 'sine' },
          envelope: { attack: 0.003, decay: 0.3, sustain: 0.2, release: 1.0 },
          modulation: { type: 'square' },
          modulationEnvelope: { attack: 0.5, decay: 0.1, sustain: 0.3, release: 0.5 },
        },
      } as unknown as Partial<Tone.AMSynthOptions>);

    case 'clavinet':
      return new Tone.PolySynth(Tone.PluckSynth as unknown as typeof Tone.Synth, {
        maxPolyphony: 16,
        voice: Tone.PluckSynth,
        options: {
          attackNoise: 4,
          dampening: 3500,
          resonance: 0.92,
          release: 0.8,
        },
      } as unknown as Partial<Tone.PluckSynthOptions>);

    case 'organ':
      return new Tone.PolySynth(Tone.Synth, {
        maxPolyphony: 16,
        voice: Tone.Synth,
        options: {
          oscillator: { type: 'square' },
          envelope: { attack: 0.01, decay: 0.1, sustain: 0.9, release: 0.3 },
        },
      } as unknown as Partial<Tone.SynthOptions>);

    default:
      return new Tone.PolySynth(Tone.Synth, { maxPolyphony: 16 } as unknown as Partial<Tone.SynthOptions>);
  }
}

// ---------------------------------------------------------------------------
// 3D Scene Components
// ---------------------------------------------------------------------------

/** A single 3D piano key that animates when pressed */
function PianoKey3D({
  position,
  isBlack,
  isActive,
  accentColor,
}: {
  position: [number, number, number];
  isBlack: boolean;
  isActive: boolean;
  accentColor: string;
}) {
  const meshRef = useRef<THREE.Mesh>(null);
  const targetRotation = useRef(0);

  useFrame((_state, delta) => {
    if (!meshRef.current) return;
    targetRotation.current = isActive ? -0.06 : 0;
    meshRef.current.rotation.x = THREE.MathUtils.lerp(
      meshRef.current.rotation.x,
      targetRotation.current,
      1 - Math.pow(0.001, delta),
    );
  });

  const activeColorObj = useMemo(() => new THREE.Color(accentColor), [accentColor]);

  if (isBlack) {
    return (
      <mesh ref={meshRef} position={position} castShadow>
        <boxGeometry args={[0.12, 0.08, 0.5]} />
        <meshStandardMaterial
          color={isActive ? activeColorObj : '#1a1a1a'}
          roughness={0.2}
          metalness={0.4}
          emissive={isActive ? activeColorObj : '#000000'}
          emissiveIntensity={isActive ? 0.8 : 0}
        />
      </mesh>
    );
  }

  return (
    <mesh ref={meshRef} position={position} castShadow>
      <RoundedBox args={[0.18, 0.04, 0.8]} radius={0.008} smoothness={2}>
        <meshStandardMaterial
          color={isActive ? activeColorObj : '#f5f0e8'}
          roughness={isActive ? 0.3 : 0.5}
          metalness={0.05}
          emissive={isActive ? activeColorObj : '#000000'}
          emissiveIntensity={isActive ? 0.5 : 0}
        />
      </RoundedBox>
    </mesh>
  );
}

/** Piano body frame - glossy black */
function PianoBody({ width }: { width: number }) {
  return (
    <group>
      {/* Main body bottom plate */}
      <mesh position={[0, -0.04, 0]} receiveShadow>
        <boxGeometry args={[width + 0.6, 0.04, 1.2]} />
        <meshStandardMaterial color="#0a0a0a" roughness={0.05} metalness={0.8} />
      </mesh>
      {/* Left side */}
      <mesh position={[-(width + 0.6) / 2, 0.02, 0]}>
        <boxGeometry args={[0.08, 0.12, 1.2]} />
        <meshStandardMaterial color="#0a0a0a" roughness={0.05} metalness={0.8} />
      </mesh>
      {/* Right side */}
      <mesh position={[(width + 0.6) / 2, 0.02, 0]}>
        <boxGeometry args={[0.08, 0.12, 1.2]} />
        <meshStandardMaterial color="#0a0a0a" roughness={0.05} metalness={0.8} />
      </mesh>
      {/* Back panel */}
      <mesh position={[0, 0.02, -0.62]}>
        <boxGeometry args={[width + 0.76, 0.12, 0.08]} />
        <meshStandardMaterial color="#0a0a0a" roughness={0.05} metalness={0.8} />
      </mesh>
      {/* Front lip */}
      <mesh position={[0, -0.01, 0.44]}>
        <boxGeometry args={[width + 0.76, 0.05, 0.06]} />
        <meshStandardMaterial color="#0a0a0a" roughness={0.05} metalness={0.8} />
      </mesh>
    </group>
  );
}

/** Try loading a GLTF model, returns null if not found */
function GltfPianoModel() {
  try {
    const gltf = useLoader(GLTFLoader, '/models/piano/grand_piano.glb');
    return (
      <primitive
        object={gltf.scene}
        scale={0.5}
        position={[0, -0.5, -1]}
        rotation={[0, 0, 0]}
      />
    );
  } catch {
    return null;
  }
}

/** Fallback procedural piano or GLTF */
function PianoModelWithFallback({
  visibleKeys,
  activeNotes,
  accentColor,
}: {
  visibleKeys: NoteDefinition[];
  activeNotes: Set<string>;
  accentColor: string;
}) {
  const whiteKeys = visibleKeys.filter((k) => !k.isBlack);
  const totalWidth = whiteKeys.length * 0.2;
  const startX = -totalWidth / 2;

  let whiteIdx = 0;
  const keyElements: React.ReactNode[] = [];

  for (let i = 0; i < visibleKeys.length; i++) {
    const key = visibleKeys[i];
    const isActive = activeNotes.has(key.note);

    if (!key.isBlack) {
      const x = startX + whiteIdx * 0.2 + 0.1;
      keyElements.push(
        <PianoKey3D
          key={key.note}
          position={[x, 0, 0]}
          isBlack={false}
          isActive={isActive}
          accentColor={accentColor}
        />,
      );
      whiteIdx++;
    }
  }

  // Black keys pass
  whiteIdx = 0;
  for (let i = 0; i < visibleKeys.length; i++) {
    const key = visibleKeys[i];
    if (!key.isBlack) {
      whiteIdx++;
      continue;
    }
    const isActive = activeNotes.has(key.note);
    const x = startX + (whiteIdx - 0.5) * 0.2 + 0.1;
    keyElements.push(
      <PianoKey3D
        key={key.note}
        position={[x, 0.04, -0.12]}
        isBlack={true}
        isActive={isActive}
        accentColor={accentColor}
      />,
    );
  }

  return (
    <group>
      <PianoBody width={totalWidth} />
      {keyElements}
    </group>
  );
}

/** Full 3D scene */
function Piano3DScene({
  visibleKeys,
  activeNotes,
  accentColor,
}: {
  visibleKeys: NoteDefinition[];
  activeNotes: Set<string>;
  accentColor: string;
}) {
  return (
    <Canvas
      camera={{ position: [0, 2.2, 2.8], fov: 32 }}
      style={{ height: '200px', background: '#0A0A0A' }}
      gl={{ antialias: true, alpha: false }}
      dpr={[1, 1.5]}
    >
      <ambientLight intensity={0.3} />
      <directionalLight position={[3, 5, 4]} intensity={0.8} castShadow />
      <directionalLight position={[-2, 3, -2]} intensity={0.3} color="#8888ff" />

      <Suspense fallback={null}>
        <GltfPianoModel />
      </Suspense>

      <PianoModelWithFallback
        visibleKeys={visibleKeys}
        activeNotes={activeNotes}
        accentColor={accentColor}
      />

      <Suspense fallback={null}>
        <Environment preset="apartment" />
      </Suspense>

      <EffectComposer>
        <Bloom
          luminanceThreshold={0.6}
          luminanceSmoothing={0.4}
          intensity={0.8}
          mipmapBlur
        />
      </EffectComposer>
    </Canvas>
  );
}

// ---------------------------------------------------------------------------
// Reverb Visualization
// ---------------------------------------------------------------------------

function ReverbVisualization({ amount }: { amount: number }) {
  const [tick, setTick] = useState(0);

  useEffect(() => {
    if (amount <= 0) return;
    const interval = setInterval(() => setTick((t) => t + 1), 1800);
    return () => clearInterval(interval);
  }, [amount]);

  if (amount <= 0) return null;

  const circles = [0, 1, 2];

  return (
    <div className="absolute right-4 top-1/2 -translate-y-1/2 pointer-events-none flex items-center justify-center w-10 h-10">
      {circles.map((i) => {
        const delay = i * 0.6;
        const opacity = Math.max(0, amount * 0.4 - i * 0.1);
        return (
          <div
            key={`${i}-${tick}`}
            className="absolute rounded-full border border-gl-accent/30"
            style={{
              width: `${12 + i * 10}px`,
              height: `${12 + i * 10}px`,
              opacity,
              animation: `ping-slow 2.4s ease-out ${delay}s both`,
            }}
          />
        );
      })}
      <style>{`
        @keyframes ping-slow {
          0% { transform: scale(0.8); opacity: var(--tw-opacity, 0.4); }
          100% { transform: scale(2.2); opacity: 0; }
        }
      `}</style>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Mic Placement Indicator (decorative)
// ---------------------------------------------------------------------------

function MicIndicator() {
  return (
    <div className="flex items-center gap-1.5 px-2 py-1 rounded-md bg-gl-surface/50 border border-white/5">
      <div className="relative w-3 h-3">
        <div className="absolute inset-0 rounded-full bg-gl-danger/60 animate-pulse" />
        <div className="absolute inset-[3px] rounded-full bg-gl-danger" />
      </div>
      <span className="text-[10px] font-mono text-gray-500 uppercase tracking-wider">Mic</span>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function Piano() {
  // State ---------------------------------------------------------------
  const [instrument, setInstrument] = useState<InstrumentId>('grand');
  const [octaveOffset, setOctaveOffset] = useState(0); // in semitones (multiples of 12)
  const [sustainOn, setSustainOn] = useState(false);
  const [reverbAmount, setReverbAmount] = useState(0.3);
  const [volume, setVolume] = useState(-6); // dB
  const [activeNotes, setActiveNotes] = useState<Set<string>>(new Set());
  const [showLabels, setShowLabels] = useState(true);
  const [audioStarted, setAudioStarted] = useState(false);

  // Refs ----------------------------------------------------------------
  const synthRef = useRef<Tone.PolySynth | null>(null);
  const reverbRef = useRef<Tone.Reverb | null>(null);
  const volumeRef = useRef<Tone.Volume | null>(null);
  const sustainedNotesRef = useRef<Set<string>>(new Set());
  const activePointersRef = useRef<Map<number, string>>(new Map()); // pointerId -> note
  const containerRef = useRef<HTMLDivElement>(null);

  // Derived visible keys ------------------------------------------------
  const startIndex = Math.max(0, octaveOffset * KEYS_PER_OCTAVE);
  const endIndex = Math.min(ALL_KEYS.length, startIndex + VISIBLE_OCTAVES * KEYS_PER_OCTAVE + 1);
  const visibleKeys = ALL_KEYS.slice(startIndex, endIndex);
  const whiteKeyCount = countWhiteKeys(visibleKeys);

  const maxOctaveOffset = Math.floor(
    (ALL_KEYS.length - VISIBLE_OCTAVES * KEYS_PER_OCTAVE - 1) / KEYS_PER_OCTAVE,
  );

  const accentColor = INSTRUMENT_COLOR_MAP[instrument];

  // Audio init / cleanup ------------------------------------------------
  const initAudio = useCallback(async () => {
    if (audioStarted) return;
    await Tone.start();
    setAudioStarted(true);
  }, [audioStarted]);

  // Build / rebuild synth chain when instrument or reverb/volume changes
  useEffect(() => {
    // Dispose previous
    synthRef.current?.releaseAll();
    synthRef.current?.dispose();
    reverbRef.current?.dispose();
    volumeRef.current?.dispose();

    const vol = new Tone.Volume(volume).toDestination();
    const reverb = new Tone.Reverb({ decay: 2.5, wet: reverbAmount }).connect(vol);
    const synth = createSynth(instrument);
    synth.connect(reverb);

    synthRef.current = synth;
    reverbRef.current = reverb;
    volumeRef.current = vol;

    return () => {
      synth.releaseAll();
      synth.dispose();
      reverb.dispose();
      vol.dispose();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [instrument]);

  // Update reverb wet in real-time
  useEffect(() => {
    if (reverbRef.current) {
      reverbRef.current.wet.value = reverbAmount;
    }
  }, [reverbAmount]);

  // Update volume in real-time
  useEffect(() => {
    if (volumeRef.current) {
      volumeRef.current.volume.value = volume;
    }
  }, [volume]);

  // Update release time based on sustain
  useEffect(() => {
    if (!synthRef.current) return;
    try {
      synthRef.current.set({
        envelope: { release: sustainOn ? 8 : 1.4 },
      } as Record<string, unknown>);
    } catch {
      // PluckSynth doesn't have a standard envelope setter
    }
  }, [sustainOn]);

  // When sustain is turned OFF, release all sustained notes
  useEffect(() => {
    if (!sustainOn && sustainedNotesRef.current.size > 0) {
      const toRelease = Array.from(sustainedNotesRef.current);
      sustainedNotesRef.current.clear();
      const currentlyPressed = new Set(activePointersRef.current.values());
      toRelease.forEach((n) => {
        if (!currentlyPressed.has(n)) {
          synthRef.current?.triggerRelease(n, Tone.now());
        }
      });
      setActiveNotes(new Set(currentlyPressed));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sustainOn]);

  // Key handlers --------------------------------------------------------
  const noteOn = useCallback(
    async (note: string, velocity: number, pointerId: number) => {
      await initAudio();
      activePointersRef.current.set(pointerId, note);
      const vel = Math.max(0.05, Math.min(1, velocity));

      try {
        synthRef.current?.triggerAttack(note, Tone.now(), vel);
      } catch {
        // ignore duplicate attack
      }

      setActiveNotes((prev) => {
        const next = new Set(prev);
        next.add(note);
        return next;
      });
    },
    [initAudio],
  );

  const noteOff = useCallback(
    (note: string, pointerId: number) => {
      activePointersRef.current.delete(pointerId);

      // Check if same note is still held by another pointer
      const stillHeld = Array.from(activePointersRef.current.values()).includes(note);
      if (stillHeld) return;

      if (sustainOn) {
        sustainedNotesRef.current.add(note);
        // Keep note visually active
        return;
      }

      try {
        synthRef.current?.triggerRelease(note, Tone.now());
      } catch {
        // ignore
      }

      setActiveNotes((prev) => {
        const next = new Set(prev);
        next.delete(note);
        return next;
      });
    },
    [sustainOn],
  );

  // Pointer event handlers for keys ------------------------------------
  const handlePointerDown = useCallback(
    (note: string, e: React.PointerEvent<HTMLButtonElement>) => {
      e.preventDefault();
      (e.target as HTMLElement).setPointerCapture?.(e.pointerId);

      const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
      const yRatio = (e.clientY - rect.top) / rect.height;
      const velocity = 0.2 + yRatio * 0.8; // top=soft(0.2), bottom=loud(1.0)

      noteOn(note, velocity, e.pointerId);
    },
    [noteOn],
  );

  const handlePointerUp = useCallback(
    (note: string, e: React.PointerEvent<HTMLButtonElement>) => {
      e.preventDefault();
      noteOff(note, e.pointerId);
    },
    [noteOff],
  );

  const handlePointerLeave = useCallback(
    (note: string, e: React.PointerEvent<HTMLButtonElement>) => {
      // Only release if this pointer had this note pressed
      if (activePointersRef.current.get(e.pointerId) === note) {
        noteOff(note, e.pointerId);
      }
    },
    [noteOff],
  );

  const handlePointerEnter = useCallback(
    (note: string, e: React.PointerEvent<HTMLButtonElement>) => {
      // Glissando: if pointer is pressed while entering a new key
      if (e.buttons > 0 || e.pressure > 0) {
        const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
        const yRatio = (e.clientY - rect.top) / rect.height;
        const velocity = 0.2 + yRatio * 0.8;
        noteOn(note, velocity, e.pointerId);
      }
    },
    [noteOn],
  );

  // CSS variable for instrument accent color
  const accentCSSVar = { '--accent-glow': accentColor } as React.CSSProperties;

  // Keyboard rendering helpers ------------------------------------------
  const renderKeys = () => {
    const whites: React.ReactNode[] = [];
    const blacks: React.ReactNode[] = [];
    let whiteIndex = 0;

    for (let i = 0; i < visibleKeys.length; i++) {
      const key = visibleKeys[i];
      const isActive = activeNotes.has(key.note);

      if (!key.isBlack) {
        const wIdx = whiteIndex;
        whites.push(
          <button
            key={key.note}
            data-note={key.note}
            onPointerDown={(e) => handlePointerDown(key.note, e)}
            onPointerUp={(e) => handlePointerUp(key.note, e)}
            onPointerLeave={(e) => handlePointerLeave(key.note, e)}
            onPointerEnter={(e) => handlePointerEnter(key.note, e)}
            onContextMenu={(e) => e.preventDefault()}
            style={{
              left: `${(wIdx / whiteKeyCount) * 100}%`,
              width: `${(1 / whiteKeyCount) * 100}%`,
              ...(isActive
                ? ({
                    boxShadow: `inset 0 -4px 12px ${accentColor}20, 0 0 20px ${accentColor}15`,
                    '--key-glow': accentColor,
                  } as React.CSSProperties)
                : {}),
            }}
            className={cn(
              'absolute top-0 bottom-0 z-10 touch-none select-none',
              'border-x border-b rounded-b-md',
              'transition-all duration-100 ease-out',
              'focus:outline-none',
              isActive
                ? 'border-white/10 translate-y-[2px]'
                : 'border-gray-300/40 shadow-md hover:brightness-[0.97]',
            )}
          >
            {/* Ivory gradient overlay */}
            <div
              className={cn(
                'absolute inset-0 rounded-b-md transition-all duration-100',
                isActive
                  ? 'opacity-100'
                  : 'opacity-100',
              )}
              style={{
                background: isActive
                  ? `linear-gradient(to bottom, ${accentColor}18 0%, ${accentColor}08 40%, #f8f5ee 100%)`
                  : 'linear-gradient(to bottom, #ffffff 0%, #faf8f2 30%, #f0ece0 85%, #e8e2d4 100%)',
              }}
            />
            {showLabels && (
              <span
                className={cn(
                  'absolute bottom-2 left-1/2 -translate-x-1/2 z-10',
                  'text-[10px] font-mono select-none pointer-events-none',
                  'transition-colors duration-100',
                  isActive ? 'font-semibold' : 'text-gray-400',
                )}
                style={isActive ? { color: accentColor } : {}}
              >
                {key.label}
                {key.note.includes('C') && !key.note.includes('#') && (
                  <span className="text-[8px] text-gray-500 block text-center">
                    {key.note.replace('C', '')}
                  </span>
                )}
              </span>
            )}
          </button>,
        );
        whiteIndex++;
      }
    }

    // Black keys - placed relative to white keys
    whiteIndex = 0;
    for (let i = 0; i < visibleKeys.length; i++) {
      const key = visibleKeys[i];
      if (!key.isBlack) {
        whiteIndex++;
        continue;
      }

      const isActive = activeNotes.has(key.note);
      // Position black key between the two surrounding white keys
      const leftPercent = ((whiteIndex - 0.35) / whiteKeyCount) * 100;
      const widthPercent = (0.7 / whiteKeyCount) * 100;

      blacks.push(
        <button
          key={key.note}
          data-note={key.note}
          onPointerDown={(e) => handlePointerDown(key.note, e)}
          onPointerUp={(e) => handlePointerUp(key.note, e)}
          onPointerLeave={(e) => handlePointerLeave(key.note, e)}
          onPointerEnter={(e) => handlePointerEnter(key.note, e)}
          onContextMenu={(e) => e.preventDefault()}
          style={{
            left: `${leftPercent}%`,
            width: `${widthPercent}%`,
            height: '62%',
            ...(isActive
              ? ({
                  boxShadow: `inset 0 -2px 8px ${accentColor}30, 0 0 16px ${accentColor}25, 0 4px 12px rgba(0,0,0,0.4)`,
                } as React.CSSProperties)
              : {
                  boxShadow: '0 4px 8px rgba(0,0,0,0.5), inset 0 -1px 2px rgba(255,255,255,0.05)',
                }),
          }}
          className={cn(
            'absolute top-0 z-20 touch-none select-none',
            'rounded-b-md border border-gray-900/80',
            'transition-all duration-100 ease-out',
            'focus:outline-none overflow-hidden',
            isActive ? 'translate-y-[1px]' : '',
          )}
        >
          {/* Ebony sheen gradient */}
          <div
            className="absolute inset-0 rounded-b-md"
            style={{
              background: isActive
                ? `linear-gradient(to bottom, ${accentColor}35 0%, ${accentColor}18 30%, #1c1c1c 70%, #0f0f0f 100%)`
                : 'linear-gradient(to bottom, #3a3a3a 0%, #2a2a2a 15%, #1a1a1a 50%, #0e0e0e 85%, #0a0a0a 100%)',
            }}
          />
          {/* Specular highlight strip */}
          <div
            className={cn(
              'absolute top-0 left-[15%] right-[15%] h-[35%] rounded-b-sm',
              'pointer-events-none',
            )}
            style={{
              background: isActive
                ? `linear-gradient(to bottom, ${accentColor}20, transparent)`
                : 'linear-gradient(to bottom, rgba(255,255,255,0.08), transparent)',
            }}
          />
          {showLabels && (
            <span
              className={cn(
                'absolute bottom-2 left-1/2 -translate-x-1/2 z-10',
                'text-[8px] font-mono select-none pointer-events-none',
                'transition-colors duration-100',
                isActive ? 'font-semibold' : 'text-gray-600',
              )}
              style={isActive ? { color: accentColor } : {}}
            >
              {key.label}
            </span>
          )}
        </button>,
      );
    }

    return (
      <>
        {whites}
        {blacks}
      </>
    );
  };

  // --------------------------------------------------------------------
  // Render
  // --------------------------------------------------------------------

  return (
    <div
      className="flex flex-col h-full bg-gl-deepest text-white select-none"
      ref={containerRef}
      style={accentCSSVar}
    >
      {/* Header / instrument selector */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-white/5">
        <div className="flex items-center gap-3">
          <h2 className="text-lg font-semibold tracking-wide text-gray-200">Piano</h2>
          <MicIndicator />
        </div>
        <div className="flex items-center gap-1.5">
          {INSTRUMENTS.map((inst) => (
            <button
              key={inst.id}
              onClick={() => setInstrument(inst.id)}
              className={cn(
                'px-3 py-1.5 rounded-lg text-xs font-medium transition-all',
                'border border-white/5',
                instrument === inst.id
                  ? 'shadow-sm'
                  : 'bg-gl-panel text-gray-400 hover:text-gray-200 hover:bg-gl-panel/80',
              )}
              style={
                instrument === inst.id
                  ? {
                      backgroundColor: `${inst.color}20`,
                      color: inst.color,
                      borderColor: `${inst.color}30`,
                    }
                  : {}
              }
            >
              <span className="mr-1">{inst.icon}</span>
              {inst.name}
            </button>
          ))}
        </div>
      </div>

      {/* 3D Piano Scene */}
      <div className="relative border-b border-white/5 shrink-0">
        <Piano3DScene
          visibleKeys={visibleKeys}
          activeNotes={activeNotes}
          accentColor={accentColor}
        />
        {/* Fade overlay at bottom for seamless transition */}
        <div className="absolute bottom-0 left-0 right-0 h-8 bg-gradient-to-t from-gl-deepest to-transparent pointer-events-none" />
      </div>

      {/* Controls bar */}
      <div className="flex items-center gap-6 px-4 py-3 bg-gl-panel border-b border-white/5 relative">
        {/* Octave shift */}
        <div className="flex items-center gap-2">
          <span className="text-[11px] font-mono text-gray-500 uppercase tracking-wider">
            Octave
          </span>
          <button
            onClick={() => setOctaveOffset((p) => Math.max(0, p - 1))}
            disabled={octaveOffset <= 0}
            className={cn(
              'w-7 h-7 rounded-md flex items-center justify-center text-sm font-bold',
              'bg-gl-deepest border border-white/10 transition-colors',
              octaveOffset <= 0
                ? 'text-gray-600 cursor-not-allowed'
                : 'text-gray-300 hover:text-white hover:border-gl-accent/40',
            )}
          >
            ◄
          </button>
          <span className="text-xs font-mono text-gray-300 w-6 text-center">
            {visibleKeys[0]?.note.slice(-1) ?? ''}
          </span>
          <button
            onClick={() => setOctaveOffset((p) => Math.min(maxOctaveOffset, p + 1))}
            disabled={octaveOffset >= maxOctaveOffset}
            className={cn(
              'w-7 h-7 rounded-md flex items-center justify-center text-sm font-bold',
              'bg-gl-deepest border border-white/10 transition-colors',
              octaveOffset >= maxOctaveOffset
                ? 'text-gray-600 cursor-not-allowed'
                : 'text-gray-300 hover:text-white hover:border-gl-accent/40',
            )}
          >
            ►
          </button>
        </div>

        {/* Sustain */}
        <button
          onClick={() => setSustainOn((p) => !p)}
          className={cn(
            'px-3 py-1.5 rounded-lg text-xs font-medium transition-all border',
            sustainOn
              ? 'bg-gl-accent/20 text-gl-accent border-gl-accent/30'
              : 'bg-gl-deepest text-gray-400 border-white/10 hover:text-gray-200',
          )}
        >
          Sustain {sustainOn ? 'ON' : 'OFF'}
        </button>

        {/* Reverb */}
        <div className="flex items-center gap-2 relative">
          <span className="text-[11px] font-mono text-gray-500 uppercase tracking-wider">
            Reverb
          </span>
          <input
            type="range"
            min={0}
            max={1}
            step={0.01}
            value={reverbAmount}
            onChange={(e) => setReverbAmount(parseFloat(e.target.value))}
            className="w-20 h-1 accent-gl-accent bg-gray-700 rounded-full appearance-none cursor-pointer
                       [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-3 [&::-webkit-slider-thumb]:h-3
                       [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-gl-accent"
          />
          <span className="text-[10px] font-mono text-gray-500 w-8">
            {Math.round(reverbAmount * 100)}%
          </span>
        </div>

        {/* Volume */}
        <div className="flex items-center gap-2">
          <span className="text-[11px] font-mono text-gray-500 uppercase tracking-wider">
            Volume
          </span>
          <input
            type="range"
            min={-30}
            max={0}
            step={1}
            value={volume}
            onChange={(e) => setVolume(parseFloat(e.target.value))}
            className="w-20 h-1 accent-gl-accent bg-gray-700 rounded-full appearance-none cursor-pointer
                       [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-3 [&::-webkit-slider-thumb]:h-3
                       [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-gl-accent"
          />
          <span className="text-[10px] font-mono text-gray-500 w-8">{volume}dB</span>
        </div>

        {/* Show labels toggle */}
        <button
          onClick={() => setShowLabels((p) => !p)}
          className={cn(
            'px-3 py-1.5 rounded-lg text-xs font-medium transition-all border',
            showLabels
              ? 'bg-white/5 text-gray-300 border-white/10'
              : 'bg-gl-deepest text-gray-500 border-white/5',
          )}
        >
          Labels
        </button>

        {/* Reverb visualization */}
        <ReverbVisualization amount={reverbAmount} />
      </div>

      {/* Active notes display */}
      <div className="px-4 py-2 border-b border-white/5 min-h-[32px] flex items-center gap-1.5 flex-wrap">
        {activeNotes.size === 0 ? (
          <span className="text-[11px] font-mono text-gray-600">No active notes</span>
        ) : (
          Array.from(activeNotes)
            .sort()
            .map((note) => (
              <span
                key={note}
                className="px-2 py-0.5 text-[11px] font-mono rounded border"
                style={{
                  backgroundColor: `${accentColor}15`,
                  color: accentColor,
                  borderColor: `${accentColor}20`,
                }}
              >
                {note}
              </span>
            ))
        )}
      </div>

      {/* 2D Keyboard - primary touch interface */}
      <div className="flex-1 relative overflow-hidden px-1 pb-2 pt-1">
        <div
          className="relative w-full h-full min-h-[200px]"
          style={{ touchAction: 'none' }}
        >
          {renderKeys()}
        </div>
      </div>

      {/* Audio context start overlay */}
      {!audioStarted && (
        <div
          className="absolute inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm cursor-pointer"
          onClick={initAudio}
        >
          <div className="text-center">
            <div className="text-4xl mb-3">🎹</div>
            <p className="text-gray-300 text-sm font-medium">Tap anywhere to enable audio</p>
          </div>
        </div>
      )}
    </div>
  );
}
