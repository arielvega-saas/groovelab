/**
 * Drums — Professional 16-step drum machine with synthesized voices
 *
 * 5 voices: Kick, Snare, Hi-Hat, Open HH, Ride
 * 10 preset styles with velocity-aware patterns
 * Tone.js synths scheduled on Tone.Transport
 * 3D drum kit scene with React Three Fiber
 */
import { Component, useCallback, useEffect, useMemo, useRef, useState, Suspense, type ReactNode, type ErrorInfo } from 'react'
import * as Tone from 'tone'
import { Canvas, useFrame, type ThreeEvent } from '@react-three/fiber'
import { OrbitControls, Environment, ContactShadows, useGLTF } from '@react-three/drei'
import { EffectComposer, Bloom } from '@react-three/postprocessing'
import * as THREE from 'three'
import { useAppStore } from '@/stores/app-store'
import { cn } from '@/lib/cn'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type VoiceName = 'kick' | 'snare' | 'hihat' | 'openHH' | 'ride'

/** velocity 0 = off, 0.01-1 = on with velocity */
type StepRow = number[]

interface DrumPattern {
  kick: StepRow
  snare: StepRow
  hihat: StepRow
  openHH: StepRow
  ride: StepRow
}

interface DrumStyle {
  name: string
  pattern: DrumPattern
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const STEPS = 16

const VOICES: { id: VoiceName; label: string; color: string; shortLabel: string }[] = [
  { id: 'kick',   label: 'Kick',    color: '#FF3B30', shortLabel: 'K' },
  { id: 'snare',  label: 'Snare',   color: '#FF9500', shortLabel: 'S' },
  { id: 'hihat',  label: 'Hi-Hat',  color: '#00E5FF', shortLabel: 'HH' },
  { id: 'openHH', label: 'Open HH', color: '#00FF11', shortLabel: 'OH' },
  { id: 'ride',   label: 'Ride',    color: '#BF5AF2', shortLabel: 'R' },
]

const emptyRow = (): StepRow => Array(STEPS).fill(0)

const emptyPattern = (): DrumPattern => ({
  kick: emptyRow(),
  snare: emptyRow(),
  hihat: emptyRow(),
  openHH: emptyRow(),
  ride: emptyRow(),
})

// ---------------------------------------------------------------------------
// Preset styles
// ---------------------------------------------------------------------------

const DRUM_STYLES: DrumStyle[] = [
  {
    name: 'Rock',
    pattern: {
      kick:   [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0],
      snare:  [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
      hihat:  [.9,.5,.9,.5, .9,.5,.9,.5, .9,.5,.9,.5, .9,.5,.9,.5],
      openHH: emptyRow(),
      ride:   emptyRow(),
    },
  },
  {
    name: 'Pop',
    pattern: {
      kick:   [1,0,0,0, 0,0,1,0, 1,0,0,0, 0,0,1,0],
      snare:  [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,.5],
      hihat:  [1,.5,1,.5, 1,.5,1,.5, 1,.5,1,.5, 1,.5,1,.5],
      openHH: [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
      ride:   emptyRow(),
    },
  },
  {
    name: 'Funk',
    pattern: {
      kick:   [1,0,.6,0, 0,0,0,.8, 0,.7,0,0, 1,0,0,0],
      snare:  [0,0,0,0, 1,0,0,.4, 0,0,0,.3, 1,0,0,0],
      hihat:  [1,.6,1,.6, 1,.6,1,.6, 1,.6,1,.6, 1,.6,1,.6],
      openHH: [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,.7,0],
      ride:   emptyRow(),
    },
  },
  {
    name: 'Jazz',
    pattern: {
      kick:   [.8,0,0,0, 0,0,.6,0, 0,0,0,0, .7,0,0,0],
      snare:  [0,0,0,0, 0,0,0,0, 0,0,.4,0, 0,0,0,.3],
      hihat:  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
      openHH: [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
      ride:   [1,0,.5,1, 0,.5,1,0, .5,1,0,.5, 1,0,.5,0],
    },
  },
  {
    name: 'Blues',
    pattern: {
      kick:   [1,0,0,0, 0,0,.7,0, 1,0,0,0, 0,0,.6,0],
      snare:  [0,0,0,0, 1,0,0,.3, 0,0,0,0, 1,0,0,.4],
      hihat:  [.8,.4,.8,.4, .8,.4,.8,.4, .8,.4,.8,.4, .8,.4,.8,.4],
      openHH: emptyRow(),
      ride:   emptyRow(),
    },
  },
  {
    name: 'Shuffle',
    pattern: {
      kick:   [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0],
      snare:  [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,.5],
      hihat:  [1,0,.7,1, 0,.7,1,0, .7,1,0,.7, 1,0,.7,0],
      openHH: emptyRow(),
      ride:   emptyRow(),
    },
  },
  {
    name: 'Latin',
    pattern: {
      kick:   [1,0,0,.7, 0,0,1,0, 0,.6,0,0, 1,0,0,0],
      snare:  [0,0,0,0, 0,0,0,0, .8,0,0,0, 0,0,.8,0],
      hihat:  [.8,.5,.8,.5, .8,.5,.8,.5, .8,.5,.8,.5, .8,.5,.8,.5],
      openHH: [0,0,0,0, 0,0,0,.7, 0,0,0,0, 0,0,0,.7],
      ride:   emptyRow(),
    },
  },
  {
    name: 'Bossa Nova',
    pattern: {
      kick:   [1,0,0,.6, 0,0,1,0, 0,0,.6,0, 0,1,0,0],
      snare:  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
      hihat:  [.7,.4,.7,.4, .7,.4,.7,.4, .7,.4,.7,.4, .7,.4,.7,.4],
      openHH: emptyRow(),
      ride:   [0,.5,0,.5, 0,.5,0,.5, 0,.5,0,.5, 0,.5,0,.5],
    },
  },
  {
    name: 'Hip Hop',
    pattern: {
      kick:   [1,0,0,.5, 0,0,0,0, 1,0,.7,0, 0,0,0,0],
      snare:  [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,.4],
      hihat:  [1,.6,1,.6, 1,.6,1,.6, 1,.6,1,.6, 1,.6,1,.6],
      openHH: [0,0,0,0, 0,0,0,.8, 0,0,0,0, 0,0,0,.8],
      ride:   emptyRow(),
    },
  },
  {
    name: 'Metal',
    pattern: {
      kick:   [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],
      snare:  [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
      hihat:  [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1],
      openHH: emptyRow(),
      ride:   emptyRow(),
    },
  },
]

// ---------------------------------------------------------------------------
// Voice icons (inline SVG for zero dependencies)
// ---------------------------------------------------------------------------

function VoiceIcon({ voice, size = 24 }: { voice: VoiceName; size?: number }) {
  const s = size
  switch (voice) {
    case 'kick':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
          <circle cx="12" cy="12" r="10" />
          <circle cx="12" cy="12" r="4" />
        </svg>
      )
    case 'snare':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
          <ellipse cx="12" cy="10" rx="9" ry="5" />
          <line x1="3" y1="10" x2="3" y2="16" />
          <line x1="21" y1="10" x2="21" y2="16" />
          <ellipse cx="12" cy="16" rx="9" ry="5" />
        </svg>
      )
    case 'hihat':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
          <ellipse cx="12" cy="10" rx="10" ry="3" />
          <ellipse cx="12" cy="14" rx="10" ry="3" />
          <line x1="12" y1="3" x2="12" y2="7" />
        </svg>
      )
    case 'openHH':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
          <ellipse cx="12" cy="8" rx="10" ry="3" />
          <ellipse cx="12" cy="16" rx="10" ry="3" />
          <line x1="12" y1="1" x2="12" y2="5" />
        </svg>
      )
    case 'ride':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
          <ellipse cx="12" cy="12" rx="11" ry="4" />
          <circle cx="12" cy="12" r="1.5" fill="currentColor" />
        </svg>
      )
  }
}

// ---------------------------------------------------------------------------
// 3D Drum Kit pieces (procedural geometry)
// ---------------------------------------------------------------------------

/** Shared hit animation hook — returns a ref for the mesh group and a trigger fn */
function useHitAnimation() {
  const groupRef = useRef<THREE.Group>(null)
  const hitTime = useRef(-1)
  const emissiveIntensity = useRef(0)

  useFrame((_, delta) => {
    if (!groupRef.current) return
    if (hitTime.current >= 0) {
      hitTime.current += delta
      // Quick bounce: scale up then back
      const t = hitTime.current
      const bounce = t < 0.05
        ? 1 + 0.15 * (t / 0.05)
        : 1 + 0.15 * Math.max(0, 1 - (t - 0.05) / 0.15)
      const yBounce = t < 0.05
        ? -0.05 * (t / 0.05)
        : -0.05 * Math.max(0, 1 - (t - 0.05) / 0.15)

      groupRef.current.scale.setScalar(bounce)
      groupRef.current.position.y = (groupRef.current.userData.baseY ?? 0) + yBounce

      emissiveIntensity.current = Math.max(0, 2 * (1 - t / 0.25))

      if (t > 0.25) {
        hitTime.current = -1
        groupRef.current.scale.setScalar(1)
        groupRef.current.position.y = groupRef.current.userData.baseY ?? 0
        emissiveIntensity.current = 0
      }

      // Update emissive intensity on all meshes in the group
      groupRef.current.traverse((child) => {
        if (child instanceof THREE.Mesh && child.material instanceof THREE.MeshStandardMaterial) {
          child.material.emissiveIntensity = emissiveIntensity.current
        }
      })
    }
  })

  const triggerHit = useCallback(() => {
    hitTime.current = 0
  }, [])

  return { groupRef, triggerHit }
}

/** Kick drum — large cylinder */
function KickDrum({ position, color, onHit }: { position: [number, number, number]; color: string; onHit: () => void }) {
  const { groupRef, triggerHit } = useHitAnimation()

  useEffect(() => {
    if (groupRef.current) {
      groupRef.current.userData.baseY = position[1]
    }
  }, [groupRef, position])

  // Expose trigger via ref callback
  const triggerRef = useRef(triggerHit)
  triggerRef.current = triggerHit

  const handleClick = useCallback((e: ThreeEvent<MouseEvent>) => {
    e.stopPropagation()
    triggerRef.current()
    onHit()
  }, [onHit])

  return (
    <group ref={groupRef} position={position}>
      {/* Shell */}
      <mesh rotation={[Math.PI / 2, 0, 0]} onClick={handleClick}>
        <cylinderGeometry args={[0.55, 0.55, 0.5, 32]} />
        <meshStandardMaterial
          color={color}
          metalness={0.3}
          roughness={0.5}
          emissive={color}
          emissiveIntensity={0}
        />
      </mesh>
      {/* Front head */}
      <mesh rotation={[Math.PI / 2, 0, 0]} position={[0, 0, 0.26]} onClick={handleClick}>
        <cylinderGeometry args={[0.54, 0.54, 0.02, 32]} />
        <meshStandardMaterial
          color="#e8e0d0"
          metalness={0.1}
          roughness={0.7}
          emissive={color}
          emissiveIntensity={0}
        />
      </mesh>
    </group>
  )
}

/** Snare / Tom — shorter cylinder */
function SnareDrum({ position, color, onHit, radius = 0.35, height = 0.2 }: { position: [number, number, number]; color: string; onHit: () => void; radius?: number; height?: number }) {
  const { groupRef, triggerHit } = useHitAnimation()

  useEffect(() => {
    if (groupRef.current) {
      groupRef.current.userData.baseY = position[1]
    }
  }, [groupRef, position])

  const triggerRef = useRef(triggerHit)
  triggerRef.current = triggerHit

  const handleClick = useCallback((e: ThreeEvent<MouseEvent>) => {
    e.stopPropagation()
    triggerRef.current()
    onHit()
  }, [onHit])

  return (
    <group ref={groupRef} position={position}>
      {/* Shell */}
      <mesh onClick={handleClick}>
        <cylinderGeometry args={[radius, radius, height, 32]} />
        <meshStandardMaterial
          color={color}
          metalness={0.4}
          roughness={0.4}
          emissive={color}
          emissiveIntensity={0}
        />
      </mesh>
      {/* Head */}
      <mesh position={[0, height / 2 + 0.005, 0]} onClick={handleClick}>
        <cylinderGeometry args={[radius - 0.01, radius - 0.01, 0.01, 32]} />
        <meshStandardMaterial
          color="#f0e8d8"
          metalness={0.05}
          roughness={0.8}
          emissive={color}
          emissiveIntensity={0}
        />
      </mesh>
    </group>
  )
}

/** Cymbal — thin disc */
function Cymbal({ position, color, onHit, radius = 0.4 }: { position: [number, number, number]; color: string; onHit: () => void; radius?: number }) {
  const { groupRef, triggerHit } = useHitAnimation()

  useEffect(() => {
    if (groupRef.current) {
      groupRef.current.userData.baseY = position[1]
    }
  }, [groupRef, position])

  const triggerRef = useRef(triggerHit)
  triggerRef.current = triggerHit

  const handleClick = useCallback((e: ThreeEvent<MouseEvent>) => {
    e.stopPropagation()
    triggerRef.current()
    onHit()
  }, [onHit])

  return (
    <group ref={groupRef} position={position}>
      {/* Cymbal disc */}
      <mesh onClick={handleClick}>
        <cylinderGeometry args={[radius, radius * 0.95, 0.015, 48]} />
        <meshStandardMaterial
          color={color}
          metalness={0.9}
          roughness={0.15}
          emissive={color}
          emissiveIntensity={0}
        />
      </mesh>
      {/* Bell */}
      <mesh position={[0, 0.02, 0]} onClick={handleClick}>
        <sphereGeometry args={[radius * 0.15, 16, 8, 0, Math.PI * 2, 0, Math.PI / 2]} />
        <meshStandardMaterial
          color={color}
          metalness={0.95}
          roughness={0.1}
          emissive={color}
          emissiveIntensity={0}
        />
      </mesh>
      {/* Stand rod */}
      <mesh position={[0, -0.4, 0]}>
        <cylinderGeometry args={[0.02, 0.02, 0.8, 8]} />
        <meshStandardMaterial color="#555555" metalness={0.8} roughness={0.3} />
      </mesh>
    </group>
  )
}

/**
 * Simple error boundary for catching GLTF load failures inside the Canvas.
 * Falls back to procedural geometry on error.
 */
class DrumKitErrorBoundary extends Component<
  { fallback: ReactNode; children: ReactNode },
  { hasError: boolean }
> {
  constructor(props: { fallback: ReactNode; children: ReactNode }) {
    super(props)
    this.state = { hasError: false }
  }
  static getDerivedStateFromError(): { hasError: boolean } {
    return { hasError: true }
  }
  componentDidCatch(_error: Error, _info: ErrorInfo) {
    // Silently fall back to procedural kit
  }
  render() {
    if (this.state.hasError) return this.props.fallback
    return this.props.children
  }
}

/** GLTF model sub-component — will suspend/throw if file is missing */
function GLTFModel() {
  const { scene } = useGLTF('/models/drumkit/drumkit.glb')
  return <primitive object={scene} scale={0.5} />
}

/** Wrapper: tries GLTF first, falls back to procedural geometry gracefully */
function GLTFDrumKit({ onVoiceHit }: { onVoiceHit: (voice: VoiceName) => void }) {
  const procedural = <ProceduralDrumKit onVoiceHit={onVoiceHit} />

  return (
    <DrumKitErrorBoundary fallback={procedural}>
      <Suspense fallback={procedural}>
        <GLTFModel />
      </Suspense>
    </DrumKitErrorBoundary>
  )
}

// Preload attempt (won't throw if file doesn't exist at build time)
try {
  useGLTF.preload('/models/drumkit/drumkit.glb')
} catch {
  // silently ignore — we'll fall back to procedural
}

/** Procedural fallback drum kit */
function ProceduralDrumKit({ onVoiceHit }: { onVoiceHit: (voice: VoiceName) => void }) {
  const handleKick = useCallback(() => onVoiceHit('kick'), [onVoiceHit])
  const handleSnare = useCallback(() => onVoiceHit('snare'), [onVoiceHit])
  const handleHihat = useCallback(() => onVoiceHit('hihat'), [onVoiceHit])
  const handleOpenHH = useCallback(() => onVoiceHit('openHH'), [onVoiceHit])
  const handleRide = useCallback(() => onVoiceHit('ride'), [onVoiceHit])

  return (
    <group>
      {/* Kick — center back */}
      <KickDrum position={[0, 0.3, 0.3]} color="#FF3B30" onHit={handleKick} />
      {/* Snare — front left */}
      <SnareDrum position={[-0.5, 0.55, -0.3]} color="#FF9500" onHit={handleSnare} radius={0.3} height={0.18} />
      {/* Hi-Hat — far left */}
      <Cymbal position={[-1.1, 0.8, -0.1]} color="#00E5FF" onHit={handleHihat} radius={0.3} />
      {/* Open HH — left cymbal up high */}
      <Cymbal position={[-0.7, 1.0, 0.2]} color="#00FF11" onHit={handleOpenHH} radius={0.32} />
      {/* Ride — right side */}
      <Cymbal position={[1.0, 0.85, 0.0]} color="#BF5AF2" onHit={handleRide} radius={0.45} />
      {/* Floor tom — right front */}
      <SnareDrum position={[0.6, 0.35, -0.4]} color="#FF5555" onHit={handleKick} radius={0.28} height={0.25} />
    </group>
  )
}

/** The full 3D scene with environment, shadows, and post-processing */
function DrumScene3D({ onVoiceHit }: { onVoiceHit: (voice: VoiceName) => void }) {
  return (
    <div className="w-full rounded-2xl overflow-hidden bg-gl-deepest" style={{ height: 250 }}>
      <Canvas
        camera={{ position: [0, 2.2, -2.5], fov: 45 }}
        shadows
        gl={{ antialias: true, alpha: false }}
        style={{ background: '#0A0A0A' }}
      >
        <Suspense fallback={null}>
          <ambientLight intensity={0.3} />
          <directionalLight
            position={[3, 5, -2]}
            intensity={1.2}
            castShadow
            shadow-mapSize-width={1024}
            shadow-mapSize-height={1024}
          />
          <pointLight position={[-2, 3, -1]} intensity={0.5} color="#00E5FF" />
          <pointLight position={[2, 3, 1]} intensity={0.4} color="#BF5AF2" />

          <Environment preset="studio" />

          <GLTFDrumKit onVoiceHit={onVoiceHit} />

          <ContactShadows
            position={[0, -0.01, 0]}
            opacity={0.6}
            scale={8}
            blur={2}
            far={4}
          />

          <OrbitControls
            enablePan={false}
            enableZoom={false}
            minPolarAngle={Math.PI / 6}
            maxPolarAngle={Math.PI / 2.5}
            minAzimuthAngle={-Math.PI / 4}
            maxAzimuthAngle={Math.PI / 4}
          />

          <EffectComposer>
            <Bloom
              luminanceThreshold={0.6}
              luminanceSmoothing={0.4}
              intensity={0.8}
            />
          </EffectComposer>
        </Suspense>
      </Canvas>
    </div>
  )
}

// ---------------------------------------------------------------------------
// CSS keyframes injected once (pad hit flash + LED pulse)
// ---------------------------------------------------------------------------

const styleId = 'drums-keyframes'
if (typeof document !== 'undefined' && !document.getElementById(styleId)) {
  const style = document.createElement('style')
  style.id = styleId
  style.textContent = `
    @keyframes drum-pad-flash {
      0% { filter: brightness(2.5); transform: scale(0.92); }
      50% { filter: brightness(1.6); transform: scale(1.02); }
      100% { filter: brightness(1); transform: scale(1); }
    }
    .drum-pad-hit {
      animation: drum-pad-flash 200ms ease-out;
    }
    @keyframes led-pulse {
      0%, 100% { opacity: 0.7; }
      50% { opacity: 1; }
    }
    .led-current-pulse {
      animation: led-pulse 300ms ease-in-out;
    }
  `
  document.head.appendChild(style)
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function Drums() {
  const { bpm, isPlaying, setPlaying } = useAppStore()

  // Local state
  const [currentStep, setCurrentStep] = useState(-1)
  const [pattern, setPattern] = useState<DrumPattern>(() => deepClonePattern(DRUM_STYLES[0].pattern))
  const [drumStyle, setDrumStyle] = useState(0)
  const [volumes, setVolumes] = useState<Record<VoiceName, number>>({
    kick: 0, snare: 0, hihat: -6, openHH: -6, ride: -6,
  })
  const [activeVoice, setActiveVoice] = useState<VoiceName>('kick')
  const [hitPads, setHitPads] = useState<Set<VoiceName>>(new Set())

  // Refs for Tone objects (created once)
  const synthsRef = useRef<Record<VoiceName, Tone.MembraneSynth | Tone.NoiseSynth | Tone.MetalSynth> | null>(null)
  const volumeNodesRef = useRef<Record<VoiceName, Tone.Volume> | null>(null)
  const loopRef = useRef<number | null>(null)
  const patternRef = useRef(pattern)
  const volumesRef = useRef(volumes)

  // Keep refs in sync
  patternRef.current = pattern
  volumesRef.current = volumes

  // -------------------------------------------------------------------------
  // Create synths
  // -------------------------------------------------------------------------

  const ensureSynths = useCallback(() => {
    if (synthsRef.current) return

    const kickVol   = new Tone.Volume(0).toDestination()
    const snareVol  = new Tone.Volume(0).toDestination()
    const hihatVol  = new Tone.Volume(-6).toDestination()
    const openHHVol = new Tone.Volume(-6).toDestination()
    const rideVol   = new Tone.Volume(-6).toDestination()

    volumeNodesRef.current = {
      kick: kickVol, snare: snareVol, hihat: hihatVol, openHH: openHHVol, ride: rideVol,
    }

    const kick = new Tone.MembraneSynth({
      pitchDecay: 0.05,
      octaves: 6,
      oscillator: { type: 'sine' },
      envelope: { attack: 0.001, decay: 0.4, sustain: 0.01, release: 0.4, attackCurve: 'exponential' },
    }).connect(kickVol)

    const snare = new Tone.NoiseSynth({
      noise: { type: 'white' },
      envelope: { attack: 0.001, decay: 0.18, sustain: 0, release: 0.08 },
    }).connect(snareVol)

    const hihat = new Tone.NoiseSynth({
      noise: { type: 'white' },
      envelope: { attack: 0.001, decay: 0.06, sustain: 0, release: 0.03 },
    }).connect(hihatVol)

    const openHH = new Tone.NoiseSynth({
      noise: { type: 'white' },
      envelope: { attack: 0.001, decay: 0.3, sustain: 0.05, release: 0.15 },
    }).connect(openHHVol)

    const ride = new Tone.MetalSynth({
      envelope: { attack: 0.001, decay: 0.6, release: 0.2 },
      harmonicity: 5.1,
      modulationIndex: 32,
      resonance: 4000,
      octaves: 1.5,
    }).connect(rideVol)

    synthsRef.current = { kick, snare, hihat, openHH, ride }
  }, [])

  // -------------------------------------------------------------------------
  // Trigger a single voice
  // -------------------------------------------------------------------------

  const triggerVoice = useCallback((voice: VoiceName, velocity: number, time?: number) => {
    if (!synthsRef.current) return
    const synth = synthsRef.current[voice]
    const t = time ?? Tone.now()
    if (synth instanceof Tone.MembraneSynth) {
      synth.triggerAttackRelease('C1', '8n', t, velocity)
    } else if (synth instanceof Tone.NoiseSynth) {
      synth.triggerAttackRelease('16n', t, velocity)
    } else if (synth instanceof Tone.MetalSynth) {
      synth.triggerAttackRelease('16n', t, velocity)
    }
  }, [])

  // -------------------------------------------------------------------------
  // Transport sync
  // -------------------------------------------------------------------------

  useEffect(() => {
    Tone.getTransport().bpm.value = bpm
  }, [bpm])

  useEffect(() => {
    ensureSynths()

    if (isPlaying) {
      void Tone.start()
      const transport = Tone.getTransport()

      const eventId = transport.scheduleRepeat((time) => {
        // More reliable step tracking using ticks
        const sixteenths = Math.floor(transport.ticks / (transport.PPQ / 4)) % STEPS

        setCurrentStep(sixteenths)

        const p = patternRef.current
        const triggeredPads = new Set<VoiceName>()

        for (const voice of VOICES) {
          const vel = p[voice.id][sixteenths]
          if (vel > 0) {
            triggerVoice(voice.id, vel, time)
            triggeredPads.add(voice.id)
          }
        }

        if (triggeredPads.size > 0) {
          Tone.getDraw().schedule(() => {
            setHitPads(new Set(triggeredPads))
            setTimeout(() => setHitPads(new Set()), 120)
          }, time)
        }
      }, '16n')

      loopRef.current = eventId

      if (transport.state !== 'started') {
        transport.start()
      }

      return () => {
        transport.clear(eventId)
        loopRef.current = null
      }
    } else {
      const transport = Tone.getTransport()
      if (loopRef.current !== null) {
        transport.clear(loopRef.current)
        loopRef.current = null
      }
      transport.stop()
      transport.position = 0
      setCurrentStep(-1)
    }
  }, [isPlaying, bpm, ensureSynths, triggerVoice])

  // Sync volume nodes
  useEffect(() => {
    if (!volumeNodesRef.current) return
    for (const v of VOICES) {
      volumeNodesRef.current[v.id].volume.value = volumes[v.id]
    }
  }, [volumes])

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      const transport = Tone.getTransport()
      if (loopRef.current !== null) {
        transport.clear(loopRef.current)
      }
      if (synthsRef.current) {
        Object.values(synthsRef.current).forEach((s) => s.dispose())
        synthsRef.current = null
      }
      if (volumeNodesRef.current) {
        Object.values(volumeNodesRef.current).forEach((v) => v.dispose())
        volumeNodesRef.current = null
      }
    }
  }, [])

  // -------------------------------------------------------------------------
  // Pattern mutation helpers
  // -------------------------------------------------------------------------

  const toggleStep = useCallback((voice: VoiceName, step: number) => {
    setPattern((prev) => {
      const next = deepClonePattern(prev)
      next[voice][step] = prev[voice][step] > 0 ? 0 : 0.8
      return next
    })
  }, [])

  const cycleVelocity = useCallback((voice: VoiceName, step: number) => {
    setPattern((prev) => {
      const next = deepClonePattern(prev)
      const cur = prev[voice][step]
      // Cycle: 0 -> 0.4 -> 0.7 -> 1 -> 0
      if (cur === 0) next[voice][step] = 0.4
      else if (cur <= 0.4) next[voice][step] = 0.7
      else if (cur <= 0.7) next[voice][step] = 1
      else next[voice][step] = 0
      return next
    })
  }, [])

  const loadStyle = useCallback((index: number) => {
    setDrumStyle(index)
    setPattern(deepClonePattern(DRUM_STYLES[index].pattern))
  }, [])

  const clearPattern = useCallback(() => {
    setPattern(emptyPattern())
  }, [])

  // Pad tap: trigger sound and animate
  const handlePadTap = useCallback(async (voice: VoiceName) => {
    await Tone.start()
    ensureSynths()
    triggerVoice(voice, 0.9)
    setActiveVoice(voice)
    setHitPads((prev) => new Set(prev).add(voice))
    setTimeout(() => setHitPads((prev) => {
      const n = new Set(prev)
      n.delete(voice)
      return n
    }), 200)
  }, [ensureSynths, triggerVoice])

  // 3D scene voice hit handler (triggers audio from the 3D kit)
  const handle3DVoiceHit = useCallback(async (voice: VoiceName) => {
    await Tone.start()
    ensureSynths()
    triggerVoice(voice, 0.9)
    setActiveVoice(voice)
    setHitPads((prev) => new Set(prev).add(voice))
    setTimeout(() => setHitPads((prev) => {
      const n = new Set(prev)
      n.delete(voice)
      return n
    }), 200)
  }, [ensureSynths, triggerVoice])

  // Volume change
  const handleVolumeChange = useCallback((voice: VoiceName, value: number) => {
    setVolumes((prev) => ({ ...prev, [voice]: value }))
  }, [])

  // -------------------------------------------------------------------------
  // Derived
  // -------------------------------------------------------------------------

  const activeVoiceInfo = useMemo(
    () => VOICES.find((v) => v.id === activeVoice)!,
    [activeVoice],
  )

  // -------------------------------------------------------------------------
  // Render
  // -------------------------------------------------------------------------

  return (
    <div className="flex flex-col gap-4 w-full max-w-4xl mx-auto select-none">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-bold text-gl-text tracking-wide uppercase">Drum Machine</h2>
        <div className="flex items-center gap-2">
          <button
            onClick={() => { void Tone.start(); setPlaying(!isPlaying) }}
            className={cn(
              'px-4 py-2 rounded-lg font-bold text-sm tracking-wider transition-all',
              isPlaying
                ? 'bg-gl-danger text-white glow-danger'
                : 'bg-gl-accent text-gl-deepest glow-accent',
              'neu-raised hover:brightness-110 active:scale-95',
            )}
          >
            {isPlaying ? 'STOP' : 'PLAY'}
          </button>
          <button
            onClick={clearPattern}
            className="px-3 py-2 rounded-lg text-sm text-gl-muted bg-gl-surface neu-raised hover:text-gl-text transition-colors"
          >
            CLEAR
          </button>
        </div>
      </div>

      {/* 3D Drum Kit Scene */}
      <DrumScene3D onVoiceHit={handle3DVoiceHit} />

      {/* Style selector */}
      <div className="flex flex-wrap gap-1.5">
        {DRUM_STYLES.map((style, i) => (
          <button
            key={style.name}
            onClick={() => loadStyle(i)}
            className={cn(
              'px-3 py-1.5 rounded-md text-xs font-semibold transition-all',
              drumStyle === i
                ? 'bg-gl-accent text-gl-deepest glow-accent'
                : 'bg-gl-surface text-gl-muted hover:text-gl-text neu-flat',
            )}
          >
            {style.name}
          </button>
        ))}
      </div>

      {/* Drum pads row */}
      <div className="grid grid-cols-5 gap-3">
        {VOICES.map((voice) => {
          const isHit = hitPads.has(voice.id)
          return (
            <button
              key={voice.id}
              onPointerDown={() => handlePadTap(voice.id)}
              className={cn(
                'relative flex flex-col items-center justify-center gap-1',
                'aspect-square rounded-2xl transition-all duration-100',
                'bg-gl-elevated neu-raised cursor-pointer',
                activeVoice === voice.id && 'ring-2',
                isHit && 'drum-pad-hit',
              )}
              style={{
                color: voice.color,
                boxShadow: isHit
                  ? `0 0 24px ${voice.color}88, 0 0 48px ${voice.color}44, 4px 4px 8px #080808, -4px -4px 8px #1e1e1e`
                  : activeVoice === voice.id
                    ? `0 0 16px ${voice.color}44, 4px 4px 8px #080808, -4px -4px 8px #1e1e1e`
                    : undefined,
              }}
            >
              <VoiceIcon voice={voice.id} size={28} />
              <span className="text-xs font-bold tracking-wide" style={{ color: voice.color }}>
                {voice.label}
              </span>
              {/* Active indicator dot */}
              {activeVoice === voice.id && (
                <span
                  className="absolute top-2 right-2 w-2 h-2 rounded-full"
                  style={{ backgroundColor: voice.color, boxShadow: `0 0 6px ${voice.color}` }}
                />
              )}
            </button>
          )
        })}
      </div>

      {/* Per-voice volume for selected voice */}
      <div className="flex items-center gap-3 px-3 py-2 rounded-xl bg-gl-panel neu-inset">
        <span className="text-xs font-bold w-16 truncate" style={{ color: activeVoiceInfo.color }}>
          {activeVoiceInfo.label}
        </span>
        <span className="text-[10px] text-gl-muted font-mono">VOL</span>
        <input
          type="range"
          min={-24}
          max={6}
          step={1}
          value={volumes[activeVoice]}
          onChange={(e) => handleVolumeChange(activeVoice, Number(e.target.value))}
          className="flex-1 h-1.5 accent-gl-accent cursor-pointer"
          style={{ accentColor: activeVoiceInfo.color }}
        />
        <span className="text-xs font-mono text-gl-muted w-10 text-right">
          {volumes[activeVoice] > 0 ? '+' : ''}{volumes[activeVoice]} dB
        </span>
      </div>

      {/* 16-step sequencer grid */}
      <div className="rounded-2xl bg-gl-panel p-3 neu-inset overflow-x-auto">
        {/* Step numbers header */}
        <div className="grid gap-1 mb-1" style={{ gridTemplateColumns: `48px repeat(${STEPS}, 1fr)` }}>
          <div /> {/* spacer */}
          {Array.from({ length: STEPS }, (_, i) => (
            <div
              key={i}
              className={cn(
                'text-center text-[10px] font-mono rounded py-0.5 transition-colors',
                currentStep === i
                  ? 'text-gl-accent font-bold text-glow-accent'
                  : i % 4 === 0
                    ? 'text-gl-muted'
                    : 'text-gl-dim',
              )}
            >
              {i + 1}
            </div>
          ))}
        </div>

        {/* Instrument rows */}
        {VOICES.map((voice) => (
          <div
            key={voice.id}
            className="grid gap-1 mb-1"
            style={{ gridTemplateColumns: `48px repeat(${STEPS}, 1fr)` }}
          >
            {/* Row label */}
            <button
              onClick={() => setActiveVoice(voice.id)}
              className={cn(
                'flex items-center justify-center text-[11px] font-bold rounded-md py-1 transition-all',
                activeVoice === voice.id ? 'bg-gl-surface' : 'bg-transparent hover:bg-gl-surface/50',
              )}
              style={{ color: voice.color }}
            >
              {voice.shortLabel}
            </button>

            {/* Step cells */}
            {Array.from({ length: STEPS }, (_, step) => {
              const vel = pattern[voice.id][step]
              const isActive = vel > 0
              const isCurrent = currentStep === step

              return (
                <button
                  key={step}
                  onClick={() => toggleStep(voice.id, step)}
                  onContextMenu={(e) => {
                    e.preventDefault()
                    cycleVelocity(voice.id, step)
                  }}
                  className={cn(
                    'relative rounded-md aspect-[1/0.8] min-h-[28px] transition-all duration-75 border overflow-hidden',
                    step % 4 === 0 ? 'border-gl-border/40' : 'border-transparent',
                    !isActive && 'bg-gl-surface/60 hover:bg-gl-surface',
                    isCurrent && !isActive && 'ring-1 ring-gl-accent/60',
                    isCurrent && isActive && 'led-current-pulse',
                  )}
                  style={isActive ? {
                    background: `radial-gradient(circle at center, ${voice.color}${Math.round(40 + vel * 50).toString(16).padStart(2, '0')} 0%, ${voice.color}${Math.round(15 + vel * 25).toString(16).padStart(2, '0')} 70%, transparent 100%)`,
                    boxShadow: isCurrent
                      ? `0 0 14px ${voice.color}AA, 0 0 4px ${voice.color}66, inset 0 0 8px ${voice.color}44`
                      : `0 0 6px ${voice.color}55, inset 0 0 4px ${voice.color}22`,
                  } : undefined}
                >
                  {/* Velocity inner bar */}
                  {isActive && (
                    <span
                      className="absolute bottom-0 left-[15%] right-[15%] rounded-t-sm pointer-events-none"
                      style={{
                        height: `${vel * 100}%`,
                        backgroundColor: voice.color,
                        opacity: 0.3 + vel * 0.5,
                        boxShadow: `0 0 4px ${voice.color}66`,
                      }}
                    />
                  )}

                  {/* LED dot for active steps */}
                  {isActive && (
                    <span
                      className="absolute top-[3px] left-1/2 -translate-x-1/2 w-1.5 h-1.5 rounded-full pointer-events-none"
                      style={{
                        backgroundColor: voice.color,
                        boxShadow: `0 0 4px ${voice.color}, 0 0 8px ${voice.color}88`,
                        opacity: 0.5 + vel * 0.5,
                      }}
                    />
                  )}

                  {/* Glow column for current step */}
                  {isCurrent && (
                    <span
                      className="absolute inset-0 rounded-md pointer-events-none"
                      style={{
                        background: isActive
                          ? `radial-gradient(circle, ${voice.color}33 0%, transparent 70%)`
                          : 'radial-gradient(circle, rgba(0,229,255,0.08) 0%, transparent 70%)',
                        boxShadow: isActive
                          ? `inset 0 0 10px ${voice.color}44`
                          : 'inset 0 0 6px rgba(0,229,255,0.1)',
                      }}
                    />
                  )}
                </button>
              )
            })}
          </div>
        ))}

        {/* Beat markers */}
        <div className="grid gap-1 mt-0.5" style={{ gridTemplateColumns: `48px repeat(${STEPS}, 1fr)` }}>
          <div />
          {Array.from({ length: STEPS }, (_, i) => (
            <div key={i} className="flex justify-center">
              {i % 4 === 0 && (
                <span className={cn(
                  'w-1.5 h-1.5 rounded-full transition-all',
                  currentStep >= i && currentStep < i + 4
                    ? 'bg-gl-accent'
                    : 'bg-gl-border',
                )} style={
                  currentStep >= i && currentStep < i + 4
                    ? { boxShadow: '0 0 6px #00E5FF88' }
                    : undefined
                } />
              )}
            </div>
          ))}
        </div>
      </div>

      {/* All volumes row */}
      <div className="grid grid-cols-5 gap-2">
        {VOICES.map((voice) => (
          <div
            key={voice.id}
            className="flex flex-col items-center gap-1 rounded-xl bg-gl-surface/50 p-2"
          >
            <span className="text-[10px] font-bold" style={{ color: voice.color }}>
              {voice.shortLabel}
            </span>
            <input
              type="range"
              min={-24}
              max={6}
              step={1}
              value={volumes[voice.id]}
              onChange={(e) => handleVolumeChange(voice.id, Number(e.target.value))}
              className="w-full h-1 cursor-pointer"
              style={{ accentColor: voice.color }}
            />
            <span className="text-[9px] font-mono text-gl-dim">
              {volumes[voice.id]}dB
            </span>
          </div>
        ))}
      </div>

      {/* Hint */}
      <p className="text-[10px] text-gl-dim text-center">
        Click 3D drums to preview. Tap pads to preview. Click grid to toggle steps. Right-click to cycle velocity.
      </p>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function deepClonePattern(p: DrumPattern): DrumPattern {
  return {
    kick: [...p.kick],
    snare: [...p.snare],
    hihat: [...p.hihat],
    openHH: [...p.openHH],
    ride: [...p.ride],
  }
}
