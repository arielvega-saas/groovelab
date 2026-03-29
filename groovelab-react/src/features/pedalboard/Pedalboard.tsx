import { useState, useRef, useCallback, useEffect, useMemo } from 'react';
import * as Tone from 'tone';
import { cn } from '@/lib/cn';
import {
  DndContext,
  closestCenter,
  PointerSensor,
  useSensor,
  useSensors,
  DragEndEvent,
  DragStartEvent,
  DragOverlay,
} from '@dnd-kit/core';
import {
  SortableContext,
  useSortable,
  horizontalListSortingStrategy,
  arrayMove,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';

/* ─── Types ──────────────────────────────────────────────────────── */

type PedalCategory =
  | 'Drive'
  | 'Distortion'
  | 'Modulation'
  | 'Delay'
  | 'Reverb'
  | 'Compression'
  | 'EQ'
  | 'Wah'
  | 'Utility';

interface PedalParam {
  name: string;
  min: number;
  max: number;
  default: number;
  unit: string;
}

interface PedalDefinition {
  id: string;
  name: string;
  category: PedalCategory;
  color: string;
  params: PedalParam[];
}

interface PedalInstance {
  uid: string;
  definitionId: string;
  bypassed: boolean;
  paramValues: number[];
}

type SceneId = 'A' | 'B' | 'C' | 'D';

interface SceneState {
  chain: PedalInstance[];
}

/* ─── Category Colors ────────────────────────────────────────────── */

const CATEGORY_COLORS: Record<PedalCategory, string> = {
  Drive: '#FF9500',
  Distortion: '#FF3B30',
  Modulation: '#BF5AF2',
  Delay: '#00E5FF',
  Reverb: '#5AC8FA',
  Compression: '#34C759',
  EQ: '#FFCC00',
  Wah: '#FF6B00',
  Utility: '#8E8E93',
};

/* ─── Pedal Library (20+ pedals) ─────────────────────────────────── */

const PEDAL_LIBRARY: PedalDefinition[] = [
  // Drive
  {
    id: 'tube-screamer',
    name: 'Tube Screamer',
    category: 'Drive',
    color: CATEGORY_COLORS.Drive,
    params: [
      { name: 'Drive', min: 0, max: 100, default: 50, unit: '%' },
      { name: 'Tone', min: 0, max: 100, default: 50, unit: '%' },
      { name: 'Level', min: 0, max: 100, default: 70, unit: '%' },
    ],
  },
  {
    id: 'blues-driver',
    name: 'Blues Driver',
    category: 'Drive',
    color: CATEGORY_COLORS.Drive,
    params: [
      { name: 'Gain', min: 0, max: 100, default: 45, unit: '%' },
      { name: 'Tone', min: 0, max: 100, default: 60, unit: '%' },
      { name: 'Volume', min: 0, max: 100, default: 65, unit: '%' },
    ],
  },
  {
    id: 'klon',
    name: 'Klon',
    category: 'Drive',
    color: CATEGORY_COLORS.Drive,
    params: [
      { name: 'Gain', min: 0, max: 100, default: 30, unit: '%' },
      { name: 'Treble', min: 0, max: 100, default: 55, unit: '%' },
      { name: 'Output', min: 0, max: 100, default: 70, unit: '%' },
    ],
  },
  // Distortion
  {
    id: 'metal-zone',
    name: 'Metal Zone',
    category: 'Distortion',
    color: CATEGORY_COLORS.Distortion,
    params: [
      { name: 'Dist', min: 0, max: 100, default: 80, unit: '%' },
      { name: 'Mid Freq', min: 200, max: 5000, default: 800, unit: 'Hz' },
      { name: 'Level', min: 0, max: 100, default: 60, unit: '%' },
    ],
  },
  {
    id: 'rat',
    name: 'RAT',
    category: 'Distortion',
    color: CATEGORY_COLORS.Distortion,
    params: [
      { name: 'Distortion', min: 0, max: 100, default: 60, unit: '%' },
      { name: 'Filter', min: 0, max: 100, default: 50, unit: '%' },
      { name: 'Volume', min: 0, max: 100, default: 55, unit: '%' },
    ],
  },
  {
    id: 'big-muff',
    name: 'Big Muff',
    category: 'Distortion',
    color: CATEGORY_COLORS.Distortion,
    params: [
      { name: 'Sustain', min: 0, max: 100, default: 70, unit: '%' },
      { name: 'Tone', min: 0, max: 100, default: 45, unit: '%' },
      { name: 'Volume', min: 0, max: 100, default: 60, unit: '%' },
    ],
  },
  // Modulation
  {
    id: 'chorus',
    name: 'Chorus',
    category: 'Modulation',
    color: CATEGORY_COLORS.Modulation,
    params: [
      { name: 'Rate', min: 0.1, max: 10, default: 1.5, unit: 'Hz' },
      { name: 'Depth', min: 0, max: 100, default: 50, unit: '%' },
      { name: 'Mix', min: 0, max: 100, default: 50, unit: '%' },
    ],
  },
  {
    id: 'phaser',
    name: 'Phaser',
    category: 'Modulation',
    color: CATEGORY_COLORS.Modulation,
    params: [
      { name: 'Rate', min: 0.1, max: 8, default: 0.5, unit: 'Hz' },
      { name: 'Depth', min: 0, max: 100, default: 80, unit: '%' },
      { name: 'Feedback', min: 0, max: 100, default: 50, unit: '%' },
    ],
  },
  {
    id: 'flanger',
    name: 'Flanger',
    category: 'Modulation',
    color: CATEGORY_COLORS.Modulation,
    params: [
      { name: 'Rate', min: 0.01, max: 5, default: 0.3, unit: 'Hz' },
      { name: 'Depth', min: 0, max: 1, default: 0.7, unit: '' },
      { name: 'Feedback', min: 0, max: 1, default: 0.5, unit: '' },
    ],
  },
  {
    id: 'tremolo',
    name: 'Tremolo',
    category: 'Modulation',
    color: CATEGORY_COLORS.Modulation,
    params: [
      { name: 'Rate', min: 0.1, max: 20, default: 4, unit: 'Hz' },
      { name: 'Depth', min: 0, max: 100, default: 70, unit: '%' },
    ],
  },
  // Delay
  {
    id: 'digital-delay',
    name: 'Digital Delay',
    category: 'Delay',
    color: CATEGORY_COLORS.Delay,
    params: [
      { name: 'Time', min: 10, max: 2000, default: 400, unit: 'ms' },
      { name: 'Feedback', min: 0, max: 100, default: 40, unit: '%' },
      { name: 'Mix', min: 0, max: 100, default: 30, unit: '%' },
    ],
  },
  {
    id: 'tape-echo',
    name: 'Tape Echo',
    category: 'Delay',
    color: CATEGORY_COLORS.Delay,
    params: [
      { name: 'Time', min: 50, max: 1500, default: 350, unit: 'ms' },
      { name: 'Feedback', min: 0, max: 100, default: 50, unit: '%' },
      { name: 'Wow', min: 0, max: 100, default: 20, unit: '%' },
      { name: 'Mix', min: 0, max: 100, default: 35, unit: '%' },
    ],
  },
  {
    id: 'ping-pong',
    name: 'Ping Pong',
    category: 'Delay',
    color: CATEGORY_COLORS.Delay,
    params: [
      { name: 'Time', min: 50, max: 2000, default: 500, unit: 'ms' },
      { name: 'Feedback', min: 0, max: 100, default: 45, unit: '%' },
      { name: 'Mix', min: 0, max: 100, default: 30, unit: '%' },
    ],
  },
  // Reverb
  {
    id: 'hall-reverb',
    name: 'Hall',
    category: 'Reverb',
    color: CATEGORY_COLORS.Reverb,
    params: [
      { name: 'Decay', min: 0.5, max: 10, default: 3, unit: 's' },
      { name: 'Pre-Delay', min: 0, max: 200, default: 30, unit: 'ms' },
      { name: 'Mix', min: 0, max: 100, default: 30, unit: '%' },
    ],
  },
  {
    id: 'plate-reverb',
    name: 'Plate',
    category: 'Reverb',
    color: CATEGORY_COLORS.Reverb,
    params: [
      { name: 'Decay', min: 0.3, max: 8, default: 2.5, unit: 's' },
      { name: 'Damping', min: 0, max: 100, default: 60, unit: '%' },
      { name: 'Mix', min: 0, max: 100, default: 25, unit: '%' },
    ],
  },
  {
    id: 'spring-reverb',
    name: 'Spring',
    category: 'Reverb',
    color: CATEGORY_COLORS.Reverb,
    params: [
      { name: 'Decay', min: 0.2, max: 5, default: 1.5, unit: 's' },
      { name: 'Mix', min: 0, max: 100, default: 35, unit: '%' },
    ],
  },
  {
    id: 'shimmer-reverb',
    name: 'Shimmer',
    category: 'Reverb',
    color: CATEGORY_COLORS.Reverb,
    params: [
      { name: 'Decay', min: 1, max: 15, default: 5, unit: 's' },
      { name: 'Shimmer', min: 0, max: 100, default: 60, unit: '%' },
      { name: 'Mix', min: 0, max: 100, default: 40, unit: '%' },
    ],
  },
  // Compression
  {
    id: 'studio-comp',
    name: 'Studio Comp',
    category: 'Compression',
    color: CATEGORY_COLORS.Compression,
    params: [
      { name: 'Threshold', min: -60, max: 0, default: -20, unit: 'dB' },
      { name: 'Ratio', min: 1, max: 20, default: 4, unit: ':1' },
      { name: 'Attack', min: 0.1, max: 100, default: 10, unit: 'ms' },
      { name: 'Release', min: 10, max: 1000, default: 100, unit: 'ms' },
    ],
  },
  {
    id: 'optical-comp',
    name: 'Optical Comp',
    category: 'Compression',
    color: CATEGORY_COLORS.Compression,
    params: [
      { name: 'Comp', min: 0, max: 100, default: 50, unit: '%' },
      { name: 'Volume', min: 0, max: 100, default: 70, unit: '%' },
    ],
  },
  // EQ
  {
    id: 'parametric-eq',
    name: 'Parametric EQ',
    category: 'EQ',
    color: CATEGORY_COLORS.EQ,
    params: [
      { name: 'Low', min: -12, max: 12, default: 0, unit: 'dB' },
      { name: 'Mid', min: -12, max: 12, default: 0, unit: 'dB' },
      { name: 'High', min: -12, max: 12, default: 0, unit: 'dB' },
    ],
  },
  {
    id: 'graphic-eq',
    name: 'Graphic EQ',
    category: 'EQ',
    color: CATEGORY_COLORS.EQ,
    params: [
      { name: 'Low', min: -12, max: 12, default: 0, unit: 'dB' },
      { name: 'Mid', min: -12, max: 12, default: 0, unit: 'dB' },
      { name: 'High', min: -12, max: 12, default: 0, unit: 'dB' },
    ],
  },
  // Utility
  {
    id: 'noise-gate',
    name: 'Noise Gate',
    category: 'Utility',
    color: CATEGORY_COLORS.Utility,
    params: [
      { name: 'Threshold', min: -80, max: 0, default: -40, unit: 'dB' },
      { name: 'Release', min: 10, max: 500, default: 50, unit: 'ms' },
    ],
  },
  {
    id: 'volume',
    name: 'Volume',
    category: 'Utility',
    color: CATEGORY_COLORS.Utility,
    params: [
      { name: 'Level', min: 0, max: 100, default: 80, unit: '%' },
    ],
  },
];

const PEDAL_MAP = new Map(PEDAL_LIBRARY.map((p) => [p.id, p]));

/* ─── Helpers ────────────────────────────────────────────────────── */

let uidCounter = 0;
function nextUid() {
  return `pedal-${++uidCounter}-${Date.now()}`;
}

function createInstance(defId: string): PedalInstance {
  const def = PEDAL_MAP.get(defId)!;
  return {
    uid: nextUid(),
    definitionId: defId,
    bypassed: false,
    paramValues: def.params.map((p) => p.default),
  };
}

function cloneChain(chain: PedalInstance[]): PedalInstance[] {
  return chain.map((p) => ({ ...p, paramValues: [...p.paramValues] }));
}

function lerp(a: number, b: number, t: number) {
  return a + (b - a) * t;
}

function formatValue(value: number, unit: string): string {
  if (unit === 'Hz' && value >= 1000) return `${(value / 1000).toFixed(1)}k`;
  if (unit === 'ms' && value >= 1000) return `${(value / 1000).toFixed(1)}s`;
  if (Number.isInteger(value)) return `${value}`;
  return value.toFixed(1);
}

/* ─── Tone.js Effect Factory ─────────────────────────────────────── */

function createToneEffect(
  instance: PedalInstance
): Tone.ToneAudioNode | null {
  const def = PEDAL_MAP.get(instance.definitionId)!;
  const vals = instance.paramValues;
  const pMap: Record<string, number> = {};
  def.params.forEach((p, i) => {
    pMap[p.name] = vals[i];
  });

  try {
    switch (def.id) {
      case 'tube-screamer':
      case 'blues-driver':
      case 'klon':
        return new Tone.Distortion({
          distortion: (pMap['Drive'] ?? pMap['Gain'] ?? 50) / 100,
          wet: 1,
        });

      case 'metal-zone':
      case 'rat':
      case 'big-muff':
        return new Tone.Distortion({
          distortion: (pMap['Dist'] ?? pMap['Distortion'] ?? pMap['Sustain'] ?? 60) / 100,
          wet: 1,
        });

      case 'chorus':
        return new Tone.Chorus({
          frequency: pMap['Rate'],
          depth: pMap['Depth'] / 100,
          wet: pMap['Mix'] / 100,
        }).start();

      case 'phaser':
        return new Tone.Phaser({
          frequency: pMap['Rate'],
          baseFrequency: 350,
          wet: pMap['Depth'] / 100,
        });

      case 'flanger':
        // Approximate flanger with chorus
        return new Tone.Chorus({
          frequency: pMap['Rate'],
          depth: pMap['Depth'],
          wet: 0.5,
          delayTime: 2,
        }).start();

      case 'tremolo':
        return new Tone.Tremolo({
          frequency: pMap['Rate'],
          depth: pMap['Depth'] / 100,
        }).start();

      case 'digital-delay':
      case 'tape-echo':
      case 'ping-pong':
        return new Tone.FeedbackDelay({
          delayTime: pMap['Time'] / 1000,
          feedback: (pMap['Feedback'] ?? 40) / 100,
          wet: (pMap['Mix'] ?? 30) / 100,
        });

      case 'hall-reverb':
      case 'plate-reverb':
      case 'spring-reverb':
      case 'shimmer-reverb':
        return new Tone.Reverb({
          decay: pMap['Decay'],
          wet: (pMap['Mix'] ?? 30) / 100,
        });

      case 'studio-comp':
        return new Tone.Compressor({
          threshold: pMap['Threshold'],
          ratio: pMap['Ratio'],
          attack: (pMap['Attack'] ?? 10) / 1000,
          release: (pMap['Release'] ?? 100) / 1000,
        });

      case 'optical-comp':
        return new Tone.Compressor({
          threshold: lerp(-40, -10, pMap['Comp'] / 100),
          ratio: 4,
        });

      case 'parametric-eq':
      case 'graphic-eq':
        return new Tone.EQ3({
          low: pMap['Low'],
          mid: pMap['Mid'],
          high: pMap['High'],
        });

      case 'noise-gate':
        // Approximate with compressor as Tone has no gate
        return new Tone.Compressor({
          threshold: pMap['Threshold'],
          ratio: 20,
          release: (pMap['Release'] ?? 50) / 1000,
        });

      case 'volume':
        return new Tone.Volume({
          volume: lerp(-Infinity, 0, pMap['Level'] / 100),
        });

      default:
        return null;
    }
  } catch {
    return null;
  }
}

/* ─── CSS Knob Component ─────────────────────────────────────────── */

function Knob({
  value,
  min,
  max,
  label,
  unit,
  color,
  onChange,
  size = 40,
}: {
  value: number;
  min: number;
  max: number;
  label: string;
  unit: string;
  color: string;
  onChange: (v: number) => void;
  size?: number;
}) {
  const dragging = useRef(false);
  const startY = useRef(0);
  const startVal = useRef(0);

  const normalized = (value - min) / (max - min);
  const angle = -135 + normalized * 270;

  const handlePointerDown = useCallback(
    (e: React.PointerEvent) => {
      e.preventDefault();
      e.stopPropagation();
      dragging.current = true;
      startY.current = e.clientY;
      startVal.current = value;
      (e.target as Element).setPointerCapture(e.pointerId);
    },
    [value]
  );

  const handlePointerMove = useCallback(
    (e: React.PointerEvent) => {
      if (!dragging.current) return;
      const delta = (startY.current - e.clientY) / 120;
      const newVal = Math.min(max, Math.max(min, startVal.current + delta * (max - min)));
      onChange(newVal);
    },
    [min, max, onChange]
  );

  const handlePointerUp = useCallback(() => {
    dragging.current = false;
  }, []);

  return (
    <div className="flex flex-col items-center gap-0.5 select-none">
      <div
        className="relative cursor-ns-resize"
        style={{ width: size, height: size }}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
      >
        {/* Knob body - brushed metal look */}
        <div
          className="absolute inset-0 rounded-full"
          style={{
            background: `conic-gradient(
              from 0deg,
              #3a3a3a 0deg,
              #555 60deg,
              #3a3a3a 120deg,
              #555 180deg,
              #3a3a3a 240deg,
              #555 300deg,
              #3a3a3a 360deg
            )`,
            boxShadow: `
              0 2px 4px rgba(0,0,0,0.5),
              inset 0 1px 1px rgba(255,255,255,0.08),
              inset 0 -1px 1px rgba(0,0,0,0.3)
            `,
          }}
        />
        {/* Inner ring */}
        <div
          className="absolute rounded-full"
          style={{
            inset: 3,
            background: `radial-gradient(circle at 35% 30%, #4a4a4a 0%, #2a2a2a 70%, #1a1a1a 100%)`,
            boxShadow: `inset 0 2px 4px rgba(0,0,0,0.5), inset 0 -1px 2px rgba(255,255,255,0.05)`,
          }}
        />
        {/* Indicator line */}
        <div
          className="absolute"
          style={{
            top: '50%',
            left: '50%',
            width: 2,
            height: size / 2 - 4,
            marginLeft: -1,
            transformOrigin: '50% 0',
            transform: `rotate(${angle}deg)`,
            background: color,
            borderRadius: 1,
            boxShadow: `0 0 4px ${color}80`,
          }}
        />
        {/* Arc track (SVG overlay) */}
        <svg
          className="absolute inset-0"
          width={size}
          height={size}
          viewBox={`0 0 ${size} ${size}`}
        >
          {/* Background arc */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={size / 2 - 1}
            fill="none"
            stroke="rgba(255,255,255,0.06)"
            strokeWidth="2"
            strokeDasharray={`${(270 / 360) * Math.PI * (size - 2)} ${(90 / 360) * Math.PI * (size - 2)}`}
            strokeDashoffset={`${-(225 / 360) * Math.PI * (size - 2)}`}
            strokeLinecap="round"
          />
          {/* Active arc */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={size / 2 - 1}
            fill="none"
            stroke={color}
            strokeWidth="2"
            strokeDasharray={`${normalized * (270 / 360) * Math.PI * (size - 2)} ${Math.PI * (size - 2)}`}
            strokeDashoffset={`${-(225 / 360) * Math.PI * (size - 2)}`}
            strokeLinecap="round"
            opacity="0.7"
          />
        </svg>
      </div>
      <span className="text-[8px] font-mono text-gray-400 leading-none mt-0.5">
        {formatValue(value, unit)}
        {unit && <span className="text-gray-600 ml-0.5">{unit}</span>}
      </span>
      <span className="text-[7px] text-gray-500 leading-none truncate max-w-[52px]">
        {label}
      </span>
    </div>
  );
}

/* ─── Cable SVG (bezier between pedals) ──────────────────────────── */

function CableSVG({ color = '#333', animated = false }: { color?: string; animated?: boolean }) {
  return (
    <svg width="48" height="64" viewBox="0 0 48 64" className="shrink-0 self-center -mx-1">
      <defs>
        <linearGradient id={`cableGrad-${color.replace('#', '')}`} x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor={color} stopOpacity="0.8" />
          <stop offset="50%" stopColor={color} stopOpacity="0.4" />
          <stop offset="100%" stopColor={color} stopOpacity="0.8" />
        </linearGradient>
      </defs>
      {/* Cable shadow */}
      <path
        d="M2,32 C14,32 14,22 24,22 C34,22 34,32 46,32"
        fill="none"
        stroke="rgba(0,0,0,0.4)"
        strokeWidth="5"
        strokeLinecap="round"
      />
      {/* Cable body */}
      <path
        d="M2,32 C14,32 14,22 24,22 C34,22 34,32 46,32"
        fill="none"
        stroke={`url(#cableGrad-${color.replace('#', '')})`}
        strokeWidth="3"
        strokeLinecap="round"
      />
      {/* Plug dots */}
      <circle cx="2" cy="32" r="4" fill="#1a1a1a" stroke={color} strokeWidth="1.5" opacity="0.9" />
      <circle cx="46" cy="32" r="4" fill="#1a1a1a" stroke={color} strokeWidth="1.5" opacity="0.9" />
      {/* Animated signal dot */}
      {animated && (
        <circle r="2.5" fill={color} opacity="0.9">
          <animateMotion
            dur="1.5s"
            repeatCount="indefinite"
            path="M2,32 C14,32 14,22 24,22 C34,22 34,32 46,32"
          />
        </circle>
      )}
    </svg>
  );
}

/* ─── Sortable Pedal Card (BIAS FX 2 Style) ─────────────────────── */

function SortablePedalCard({
  instance,
  definition,
  onToggleBypass,
  onParamChange,
  onRemove,
  isOverlay,
}: {
  instance: PedalInstance;
  definition: PedalDefinition;
  onToggleBypass: () => void;
  onParamChange: (paramIdx: number, value: number) => void;
  onRemove: () => void;
  isOverlay?: boolean;
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: instance.uid });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.4 : 1,
  };

  return (
    <div
      ref={isOverlay ? undefined : setNodeRef}
      style={isOverlay ? undefined : style}
      className={cn(
        'relative flex flex-col w-[140px] shrink-0 rounded-xl overflow-hidden',
        'transition-all duration-150',
        isDragging && !isOverlay && 'z-0',
        isOverlay && 'shadow-2xl scale-105 z-50',
        instance.bypassed && 'opacity-70'
      )}
    >
      {/* Metallic gradient background (brushed aluminum) */}
      <div
        className="absolute inset-0 rounded-xl"
        style={{
          background: `linear-gradient(
            165deg,
            #2a2a2e 0%,
            #1e1e22 20%,
            #28282c 40%,
            #1c1c20 60%,
            #26262a 80%,
            #1a1a1e 100%
          )`,
          boxShadow: isOverlay
            ? `0 20px 40px rgba(0,0,0,0.6), 0 0 20px ${definition.color}30`
            : `0 4px 12px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.05), inset 0 -1px 0 rgba(0,0,0,0.3)`,
        }}
      />
      {/* Brushed metal texture overlay */}
      <div
        className="absolute inset-0 rounded-xl opacity-[0.03]"
        style={{
          backgroundImage: `repeating-linear-gradient(
            90deg,
            transparent,
            transparent 1px,
            rgba(255,255,255,0.5) 1px,
            rgba(255,255,255,0.5) 2px
          )`,
        }}
      />
      {/* Category color accent on top edge */}
      <div
        className="absolute top-0 left-0 right-0 h-[3px]"
        style={{
          background: `linear-gradient(90deg, transparent 0%, ${definition.color} 20%, ${definition.color} 80%, transparent 100%)`,
          boxShadow: `0 0 8px ${definition.color}40`,
        }}
      />

      {/* Content (relative to sit above backgrounds) */}
      <div className="relative z-10 flex flex-col">
        {/* Header: drag handle + LED + category badge */}
        <div
          className="flex items-center justify-between px-2.5 pt-3 pb-1 cursor-grab active:cursor-grabbing"
          {...(isOverlay ? {} : { ...attributes, ...listeners })}
        >
          {/* LED indicator */}
          <div className="relative">
            <div
              className="w-3 h-3 rounded-full transition-all duration-300"
              style={{
                backgroundColor: instance.bypassed ? '#444' : definition.color,
                boxShadow: instance.bypassed
                  ? 'inset 0 1px 2px rgba(0,0,0,0.5)'
                  : `0 0 8px ${definition.color}, 0 0 16px ${definition.color}60, inset 0 0 2px rgba(255,255,255,0.3)`,
              }}
            />
            {/* LED housing ring */}
            <div
              className="absolute inset-[-2px] rounded-full border border-gray-600/50"
              style={{ boxShadow: 'inset 0 1px 1px rgba(0,0,0,0.3)' }}
            />
          </div>

          {/* Category badge */}
          <span
            className="text-[7px] uppercase tracking-wider px-1.5 py-0.5 rounded-full font-bold"
            style={{
              backgroundColor: `${definition.color}18`,
              color: definition.color,
              border: `1px solid ${definition.color}25`,
            }}
          >
            {definition.category}
          </span>
        </div>

        {/* Pedal name */}
        <div className="px-2.5 pb-1.5">
          <p className="text-[11px] font-bold text-white/90 truncate leading-tight tracking-wide">
            {definition.name}
          </p>
        </div>

        {/* Knobs row */}
        <div className="flex justify-center gap-1.5 px-1.5 py-2">
          {definition.params.slice(0, 3).map((param, i) => (
            <Knob
              key={param.name}
              value={instance.paramValues[i]}
              min={param.min}
              max={param.max}
              label={param.name}
              unit={param.unit}
              color={definition.color}
              onChange={(v) => onParamChange(i, v)}
              size={36}
            />
          ))}
        </div>

        {/* Extra params row (if > 3) */}
        {definition.params.length > 3 && (
          <div className="flex justify-center gap-1.5 px-1.5 pb-1">
            {definition.params.slice(3).map((param, i) => (
              <Knob
                key={param.name}
                value={instance.paramValues[i + 3]}
                min={param.min}
                max={param.max}
                label={param.name}
                unit={param.unit}
                color={definition.color}
                onChange={(v) => onParamChange(i + 3, v)}
                size={30}
              />
            ))}
          </div>
        )}

        {/* Footswitch - realistic 3D stomp button */}
        <div className="flex justify-center pb-3 pt-1">
          <button
            onClick={(e) => {
              e.stopPropagation();
              onToggleBypass();
            }}
            className="relative group"
            style={{ width: 44, height: 44 }}
          >
            {/* Outer ring / housing */}
            <div
              className="absolute inset-0 rounded-full"
              style={{
                background: 'linear-gradient(180deg, #3a3a3a 0%, #1a1a1a 100%)',
                boxShadow: `
                  0 2px 4px rgba(0,0,0,0.5),
                  inset 0 1px 0 rgba(255,255,255,0.08)
                `,
              }}
            />
            {/* Button surface */}
            <div
              className={cn(
                'absolute rounded-full transition-all duration-100',
                'group-active:top-[5px] group-active:bottom-[3px]'
              )}
              style={{
                top: 3,
                left: 3,
                right: 3,
                bottom: 5,
                background: instance.bypassed
                  ? 'linear-gradient(180deg, #333 0%, #222 50%, #1a1a1a 100%)'
                  : `linear-gradient(180deg, ${definition.color}40 0%, ${definition.color}20 50%, #1a1a1a 100%)`,
                boxShadow: instance.bypassed
                  ? `inset 0 2px 3px rgba(255,255,255,0.05), 0 3px 6px rgba(0,0,0,0.4)`
                  : `inset 0 2px 3px rgba(255,255,255,0.08), 0 3px 6px rgba(0,0,0,0.4), 0 0 12px ${definition.color}25`,
                border: `1px solid ${instance.bypassed ? '#444' : definition.color + '30'}`,
              }}
            />
            {/* Center dot on button */}
            <div
              className="absolute rounded-full transition-colors"
              style={{
                top: '50%',
                left: '50%',
                width: 12,
                height: 12,
                marginLeft: -6,
                marginTop: -6,
                background: instance.bypassed
                  ? 'radial-gradient(circle, #444 0%, #333 100%)'
                  : `radial-gradient(circle, ${definition.color}90 0%, ${definition.color}50 100%)`,
                boxShadow: instance.bypassed
                  ? 'none'
                  : `0 0 6px ${definition.color}60`,
              }}
            />
          </button>
        </div>

        {/* Remove button (appears on hover) */}
        <button
          onClick={(e) => {
            e.stopPropagation();
            onRemove();
          }}
          className="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-[#FF3B30] text-[10px] text-white font-bold flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity z-20 shadow-lg"
        >
          x
        </button>
      </div>
    </div>
  );
}

/* ─── Static Pedal Card for DragOverlay ─────────────────────────── */

function StaticPedalCard({
  instance,
  definition,
}: {
  instance: PedalInstance;
  definition: PedalDefinition;
}) {
  return (
    <SortablePedalCard
      instance={instance}
      definition={definition}
      onToggleBypass={() => {}}
      onParamChange={() => {}}
      onRemove={() => {}}
      isOverlay
    />
  );
}

/* ─── Pedal Library Drawer (Slide-out panel) ─────────────────────── */

function PedalLibraryDrawer({
  open,
  onAdd,
  onClose,
}: {
  open: boolean;
  onAdd: (defId: string) => void;
  onClose: () => void;
}) {
  const [filterCat, setFilterCat] = useState<PedalCategory | 'All'>('All');

  const categories: (PedalCategory | 'All')[] = [
    'All',
    'Drive',
    'Distortion',
    'Modulation',
    'Delay',
    'Reverb',
    'Compression',
    'EQ',
    'Wah',
    'Utility',
  ];

  const grouped = useMemo(() => {
    if (filterCat === 'All') {
      const groups: Record<string, PedalDefinition[]> = {};
      for (const p of PEDAL_LIBRARY) {
        if (!groups[p.category]) groups[p.category] = [];
        groups[p.category].push(p);
      }
      return groups;
    }
    return { [filterCat]: PEDAL_LIBRARY.filter((p) => p.category === filterCat) };
  }, [filterCat]);

  return (
    <>
      {/* Backdrop */}
      {open && (
        <div
          className="fixed inset-0 z-40 bg-black/50 backdrop-blur-sm"
          onClick={onClose}
        />
      )}
      {/* Drawer */}
      <div
        className={cn(
          'fixed top-0 right-0 bottom-0 z-50 w-[340px] max-w-[90vw]',
          'flex flex-col overflow-hidden transition-transform duration-300 ease-out',
          open ? 'translate-x-0' : 'translate-x-full'
        )}
        style={{
          background: 'linear-gradient(180deg, #141416 0%, #0e0e10 100%)',
          boxShadow: open ? '-8px 0 30px rgba(0,0,0,0.5)' : 'none',
          borderLeft: '1px solid rgba(255,255,255,0.06)',
        }}
      >
        {/* Drawer header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-white/5">
          <div>
            <h2 className="text-sm font-bold text-white tracking-wide">Pedal Library</h2>
            <p className="text-[10px] text-gray-500 mt-0.5">
              {PEDAL_LIBRARY.length} effects available
            </p>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center text-gray-400 hover:text-white hover:bg-white/10 transition-colors"
          >
            <svg width="14" height="14" viewBox="0 0 14 14">
              <line x1="3" y1="3" x2="11" y2="11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
              <line x1="11" y1="3" x2="3" y2="11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
          </button>
        </div>

        {/* Category tabs */}
        <div className="flex gap-1 px-4 py-3 overflow-x-auto scrollbar-none border-b border-white/5">
          {categories.map((cat) => {
            const catColor = cat !== 'All' ? CATEGORY_COLORS[cat as PedalCategory] : '#00E5FF';
            const isActive = filterCat === cat;
            return (
              <button
                key={cat}
                onClick={() => setFilterCat(cat)}
                className={cn(
                  'shrink-0 px-3 py-1.5 rounded-lg text-[10px] font-bold uppercase tracking-wider transition-all',
                  isActive
                    ? 'text-black'
                    : 'text-gray-500 hover:text-gray-300 bg-white/[0.03] hover:bg-white/[0.06]'
                )}
                style={
                  isActive
                    ? {
                        backgroundColor: catColor,
                        boxShadow: `0 0 12px ${catColor}40`,
                      }
                    : undefined
                }
              >
                {/* Color dot for non-active tabs */}
                <span className="inline-flex items-center gap-1.5">
                  {!isActive && cat !== 'All' && (
                    <span
                      className="w-1.5 h-1.5 rounded-full inline-block"
                      style={{ backgroundColor: catColor }}
                    />
                  )}
                  {cat}
                </span>
              </button>
            );
          })}
        </div>

        {/* Pedal list grouped by category */}
        <div className="flex-1 overflow-y-auto px-4 py-3 space-y-4">
          {Object.entries(grouped).map(([category, pedals]) => (
            <div key={category}>
              <div className="flex items-center gap-2 mb-2">
                <div
                  className="w-2 h-2 rounded-full"
                  style={{ backgroundColor: CATEGORY_COLORS[category as PedalCategory] }}
                />
                <span
                  className="text-[9px] uppercase tracking-widest font-bold"
                  style={{ color: CATEGORY_COLORS[category as PedalCategory] }}
                >
                  {category}
                </span>
                <div className="flex-1 h-px bg-white/5" />
              </div>
              <div className="grid grid-cols-2 gap-2">
                {pedals.map((def) => (
                  <button
                    key={def.id}
                    onClick={() => onAdd(def.id)}
                    className={cn(
                      'flex flex-col items-start p-3 rounded-lg text-left group transition-all',
                      'bg-white/[0.03] hover:bg-white/[0.07] border border-white/[0.04] hover:border-white/[0.1]'
                    )}
                  >
                    <div className="flex items-center gap-1.5 mb-1">
                      <div
                        className="w-2 h-2 rounded-full transition-shadow group-hover:shadow-[0_0_6px]"
                        style={{
                          backgroundColor: def.color,
                          ['--tw-shadow-color' as string]: def.color,
                        }}
                      />
                      <span className="text-[11px] font-semibold text-white/80 group-hover:text-white">
                        {def.name}
                      </span>
                    </div>
                    <div className="flex gap-1 mt-1 flex-wrap">
                      {def.params.map((p) => (
                        <span
                          key={p.name}
                          className="text-[7px] text-gray-500 bg-white/[0.04] rounded px-1 py-0.5"
                        >
                          {p.name}
                        </span>
                      ))}
                    </div>
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}

/* ─── Live View Mode ─────────────────────────────────────────────── */

function LiveView({
  chain,
  onToggleBypass,
  onExit,
}: {
  chain: PedalInstance[];
  onToggleBypass: (uid: string) => void;
  onExit: () => void;
}) {
  return (
    <div
      className="fixed inset-0 z-50 flex flex-col"
      style={{ backgroundColor: '#050505' }}
    >
      {/* Live View header */}
      <div className="flex items-center justify-between px-6 py-4">
        <h2 className="text-xs font-bold text-gray-500 uppercase tracking-[0.3em]">
          Live Mode
        </h2>
        <button
          onClick={onExit}
          className="px-4 py-2 rounded-lg bg-white/5 text-gray-400 text-xs font-bold uppercase tracking-wider hover:bg-white/10 transition-colors"
        >
          Exit
        </button>
      </div>

      {/* Stomp buttons grid */}
      <div className="flex-1 flex items-center justify-center">
        <div className="flex flex-wrap justify-center gap-6 p-8 max-w-5xl">
          {chain.map((inst) => {
            const def = PEDAL_MAP.get(inst.definitionId)!;
            return (
              <button
                key={inst.uid}
                onClick={() => onToggleBypass(inst.uid)}
                className="flex flex-col items-center gap-4 group"
              >
                {/* Large LED */}
                <div
                  className="w-5 h-5 rounded-full transition-all duration-200"
                  style={{
                    backgroundColor: inst.bypassed ? '#333' : def.color,
                    boxShadow: inst.bypassed
                      ? 'none'
                      : `0 0 20px ${def.color}, 0 0 40px ${def.color}60, 0 0 60px ${def.color}30`,
                  }}
                />

                {/* Pedal name */}
                <span
                  className={cn(
                    'text-sm font-bold uppercase tracking-wider transition-colors',
                    inst.bypassed ? 'text-gray-600' : 'text-white'
                  )}
                >
                  {def.name}
                </span>

                {/* Large footswitch */}
                <div
                  className="relative transition-transform active:scale-95"
                  style={{ width: 80, height: 80 }}
                >
                  {/* Housing */}
                  <div
                    className="absolute inset-0 rounded-full"
                    style={{
                      background: 'linear-gradient(180deg, #2a2a2a 0%, #111 100%)',
                      boxShadow: `0 4px 8px rgba(0,0,0,0.6), inset 0 1px 0 rgba(255,255,255,0.06)`,
                    }}
                  />
                  {/* Button */}
                  <div
                    className="absolute rounded-full group-active:top-[7px] group-active:bottom-[5px] transition-all duration-75"
                    style={{
                      top: 5,
                      left: 5,
                      right: 5,
                      bottom: 9,
                      background: inst.bypassed
                        ? 'linear-gradient(180deg, #2a2a2a 0%, #1a1a1a 100%)'
                        : `linear-gradient(180deg, ${def.color}30 0%, ${def.color}15 50%, #111 100%)`,
                      boxShadow: inst.bypassed
                        ? `inset 0 2px 4px rgba(255,255,255,0.03), 0 4px 8px rgba(0,0,0,0.5)`
                        : `inset 0 2px 4px rgba(255,255,255,0.06), 0 4px 8px rgba(0,0,0,0.5), 0 0 20px ${def.color}15`,
                      border: `1px solid ${inst.bypassed ? '#333' : def.color + '25'}`,
                    }}
                  />
                  {/* Center circle */}
                  <div
                    className="absolute rounded-full"
                    style={{
                      top: '50%',
                      left: '50%',
                      width: 20,
                      height: 20,
                      marginLeft: -10,
                      marginTop: -10,
                      background: inst.bypassed
                        ? 'radial-gradient(circle, #333 0%, #222 100%)'
                        : `radial-gradient(circle, ${def.color}80 0%, ${def.color}40 100%)`,
                      boxShadow: inst.bypassed ? 'none' : `0 0 10px ${def.color}50`,
                    }}
                  />
                </div>

                {/* Status text */}
                <span
                  className={cn(
                    'text-[10px] font-bold uppercase tracking-[0.2em]',
                    inst.bypassed ? 'text-gray-700' : 'text-gray-400'
                  )}
                >
                  {inst.bypassed ? 'Off' : 'On'}
                </span>
              </button>
            );
          })}

          {chain.length === 0 && (
            <div className="text-gray-600 text-sm">No pedals in chain</div>
          )}
        </div>
      </div>
    </div>
  );
}

/* ─── Main Pedalboard Component ──────────────────────────────────── */

export default function Pedalboard() {
  /* ── Scene state ── */
  const [activeScene, setActiveScene] = useState<SceneId>('A');
  const [scenes, setScenes] = useState<Record<SceneId, SceneState>>({
    A: { chain: [] },
    B: { chain: [] },
    C: { chain: [] },
    D: { chain: [] },
  });

  const chain = scenes[activeScene].chain;

  const setChain = useCallback(
    (updater: PedalInstance[] | ((prev: PedalInstance[]) => PedalInstance[])) => {
      setScenes((prev) => ({
        ...prev,
        [activeScene]: {
          chain:
            typeof updater === 'function'
              ? updater(prev[activeScene].chain)
              : updater,
        },
      }));
    },
    [activeScene]
  );

  /* ── UI state ── */
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [liveMode, setLiveMode] = useState(false);
  const [activeDragId, setActiveDragId] = useState<string | null>(null);

  /* ── DnD sensors ── */
  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 8,
      },
    })
  );

  const handleDragStart = useCallback((event: DragStartEvent) => {
    setActiveDragId(event.active.id as string);
  }, []);

  const handleDragEnd = useCallback(
    (event: DragEndEvent) => {
      setActiveDragId(null);
      const { active, over } = event;
      if (!over || active.id === over.id) return;

      setChain((prev) => {
        const oldIndex = prev.findIndex((p) => p.uid === active.id);
        const newIndex = prev.findIndex((p) => p.uid === over.id);
        if (oldIndex === -1 || newIndex === -1) return prev;
        return arrayMove(prev, oldIndex, newIndex);
      });
    },
    [setChain]
  );

  const activeDragInstance = useMemo(() => {
    if (!activeDragId) return null;
    return chain.find((p) => p.uid === activeDragId) ?? null;
  }, [activeDragId, chain]);

  /* ── Tone.js audio chain management ── */
  const effectNodesRef = useRef<(Tone.ToneAudioNode | null)[]>([]);
  const micRef = useRef<Tone.UserMedia | null>(null);
  const audioStartedRef = useRef(false);
  const [audioLive, setAudioLive] = useState(false);

  const rebuildChain = useCallback(() => {
    // Dispose previous effects
    effectNodesRef.current.forEach((n) => {
      try {
        n?.dispose();
      } catch {
        /* noop */
      }
    });
    effectNodesRef.current = [];

    if (!micRef.current) return;

    // Disconnect mic
    try {
      micRef.current.disconnect();
    } catch {
      /* noop */
    }

    // Build active effects
    const activeEffects: Tone.ToneAudioNode[] = [];
    for (const inst of chain) {
      if (inst.bypassed) {
        effectNodesRef.current.push(null);
        continue;
      }
      const node = createToneEffect(inst);
      effectNodesRef.current.push(node);
      if (node) activeEffects.push(node);
    }

    // Chain: mic -> effects -> destination
    if (activeEffects.length === 0) {
      micRef.current.toDestination();
    } else {
      micRef.current.connect(activeEffects[0]);
      for (let i = 0; i < activeEffects.length - 1; i++) {
        activeEffects[i].connect(activeEffects[i + 1]);
      }
      activeEffects[activeEffects.length - 1].toDestination();
    }
  }, [chain]);

  // Rebuild chain when chain changes
  useEffect(() => {
    if (audioStartedRef.current) {
      rebuildChain();
    }
  }, [rebuildChain]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      effectNodesRef.current.forEach((n) => {
        try {
          n?.dispose();
        } catch {
          /* noop */
        }
      });
      try {
        micRef.current?.close();
        micRef.current?.dispose();
      } catch {
        /* noop */
      }
    };
  }, []);

  const startAudio = useCallback(async () => {
    if (audioStartedRef.current) return;
    try {
      await Tone.start();
      const mic = new Tone.UserMedia();
      await mic.open();
      micRef.current = mic;
      audioStartedRef.current = true;
      setAudioLive(true);
      rebuildChain();
    } catch (err) {
      console.warn('Pedalboard: could not open mic input', err);
    }
  }, [rebuildChain]);

  /* ── Actions ── */
  const addPedal = useCallback(
    (defId: string) => {
      setChain((prev) => [...prev, createInstance(defId)]);
    },
    [setChain]
  );

  const removePedal = useCallback(
    (uid: string) => {
      setChain((prev) => prev.filter((p) => p.uid !== uid));
    },
    [setChain]
  );

  const toggleBypass = useCallback(
    (uid: string) => {
      setChain((prev) =>
        prev.map((p) => (p.uid === uid ? { ...p, bypassed: !p.bypassed } : p))
      );
    },
    [setChain]
  );

  const updateParam = useCallback(
    (uid: string, paramIdx: number, value: number) => {
      setChain((prev) =>
        prev.map((p) => {
          if (p.uid !== uid) return p;
          const newVals = [...p.paramValues];
          newVals[paramIdx] = value;
          return { ...p, paramValues: newVals };
        })
      );
    },
    [setChain]
  );

  const switchScene = useCallback(
    (scene: SceneId) => {
      setActiveScene(scene);
    },
    []
  );

  /* ── Scene labels ── */
  const sceneIds: SceneId[] = useMemo(() => ['A', 'B', 'C', 'D'], []);

  const sortableIds = useMemo(() => chain.map((p) => p.uid), [chain]);

  /* ── Live View ── */
  if (liveMode) {
    return (
      <LiveView
        chain={chain}
        onToggleBypass={toggleBypass}
        onExit={() => setLiveMode(false)}
      />
    );
  }

  return (
    <div className="flex flex-col h-full" style={{ backgroundColor: '#0A0A0A' }}>
      {/* Signal flow keyframes */}
      <style>{`
        @keyframes signal-flow {
          0% { left: 0; opacity: 0; }
          5% { opacity: 1; }
          95% { opacity: 1; }
          100% { left: 100%; opacity: 0; }
        }
        @keyframes signal-pulse {
          0%, 100% { opacity: 0.4; }
          50% { opacity: 1; }
        }
      `}</style>

      {/* ── Top Bar ── */}
      <div
        className="flex items-center justify-between px-4 py-3 border-b border-white/[0.06]"
        style={{
          background: 'linear-gradient(180deg, #151517 0%, #111113 100%)',
        }}
      >
        {/* Scene selector */}
        <div className="flex gap-1.5">
          {sceneIds.map((s) => (
            <button
              key={s}
              onClick={() => switchScene(s)}
              className={cn(
                'w-10 h-10 rounded-lg font-bold text-sm transition-all relative overflow-hidden',
                activeScene === s
                  ? 'text-black'
                  : 'text-gray-500 hover:text-gray-300'
              )}
              style={
                activeScene === s
                  ? {
                      background: '#00E5FF',
                      boxShadow: '0 0 16px rgba(0,229,255,0.3), 0 2px 8px rgba(0,0,0,0.3)',
                    }
                  : {
                      background: 'rgba(255,255,255,0.04)',
                      boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.03), 0 1px 2px rgba(0,0,0,0.2)',
                    }
              }
            >
              {s}
              {/* Active indicator dot */}
              {activeScene === s && (
                <div className="absolute bottom-1 left-1/2 -translate-x-1/2 w-1 h-1 rounded-full bg-black/40" />
              )}
            </button>
          ))}
        </div>

        <h1 className="text-xs font-bold text-gray-500 uppercase tracking-[0.3em]">
          Pedalboard
        </h1>

        {/* Controls */}
        <div className="flex gap-2">
          <button
            onClick={() => setLiveMode(true)}
            className="px-3 py-2 rounded-lg text-[10px] font-bold uppercase tracking-wider transition-all bg-white/[0.04] text-gray-400 hover:text-white hover:bg-white/[0.08] border border-white/[0.06]"
          >
            Live
          </button>
          <button
            onClick={startAudio}
            className={cn(
              'px-3 py-2 rounded-lg text-[10px] font-bold uppercase tracking-wider transition-all border',
              audioLive
                ? 'border-[#00FF11]/30 text-[#00FF11]'
                : 'border-white/[0.06] text-gray-400 hover:text-white bg-white/[0.04] hover:bg-white/[0.08]'
            )}
            style={
              audioLive
                ? {
                    background: 'rgba(0,255,17,0.08)',
                    boxShadow: '0 0 12px rgba(0,255,17,0.15)',
                  }
                : undefined
            }
          >
            {audioLive ? 'Live' : 'Start Audio'}
          </button>
          <button
            onClick={() => setDrawerOpen(true)}
            className="w-10 h-10 rounded-lg font-bold text-lg flex items-center justify-center transition-all"
            style={{
              background: '#00E5FF',
              color: '#0A0A0A',
              boxShadow: '0 0 16px rgba(0,229,255,0.25), 0 2px 8px rgba(0,0,0,0.3)',
            }}
          >
            +
          </button>
        </div>
      </div>

      {/* ── Signal Chain Header ── */}
      <div
        className="flex items-center gap-2 px-4 py-2 border-b border-white/[0.04]"
        style={{ background: 'rgba(255,255,255,0.015)' }}
      >
        <div className="flex items-center gap-1.5 text-[9px] font-mono text-gray-500 uppercase tracking-wider">
          <span className="text-[#00E5FF]">Input</span>
          <svg width="16" height="8" viewBox="0 0 16 8">
            <line x1="0" y1="4" x2="12" y2="4" stroke="#00E5FF" strokeWidth="1" opacity="0.4" />
            <polygon points="12,1 16,4 12,7" fill="#00E5FF" opacity="0.4" />
          </svg>
          {chain.map((inst, idx) => {
            const def = PEDAL_MAP.get(inst.definitionId)!;
            return (
              <span key={inst.uid} className="flex items-center gap-1.5">
                <span
                  className={cn(
                    'px-1.5 py-0.5 rounded text-[8px] font-bold',
                    inst.bypassed ? 'opacity-40' : ''
                  )}
                  style={{
                    backgroundColor: `${def.color}15`,
                    color: def.color,
                    border: `1px solid ${def.color}20`,
                  }}
                >
                  {def.name}
                </span>
                {idx < chain.length - 1 && (
                  <svg width="12" height="8" viewBox="0 0 12 8">
                    <line x1="0" y1="4" x2="8" y2="4" stroke={def.color} strokeWidth="1" opacity="0.3" />
                    <polygon points="8,1 12,4 8,7" fill={def.color} opacity="0.3" />
                  </svg>
                )}
              </span>
            );
          })}
          <svg width="16" height="8" viewBox="0 0 16 8">
            <line x1="0" y1="4" x2="12" y2="4" stroke="#00E5FF" strokeWidth="1" opacity="0.4" />
            <polygon points="12,1 16,4 12,7" fill="#00E5FF" opacity="0.4" />
          </svg>
          <span className="text-[#00E5FF]">Output</span>
        </div>
        {/* Animated signal dot indicator */}
        {audioLive && chain.length > 0 && (
          <div className="ml-auto flex items-center gap-1.5">
            <div
              className="w-1.5 h-1.5 rounded-full bg-[#00E5FF]"
              style={{
                animation: 'signal-pulse 1s ease-in-out infinite',
                boxShadow: '0 0 4px #00E5FF',
              }}
            />
            <span className="text-[8px] text-[#00E5FF]/60 font-mono">SIGNAL</span>
          </div>
        )}
      </div>

      {/* ── Signal Chain (DnD area) ── */}
      <div className="flex-1 overflow-x-auto overflow-y-hidden">
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragStart={handleDragStart}
          onDragEnd={handleDragEnd}
        >
          <div className="flex items-center min-h-full px-6 py-6 gap-0">
            {/* Input jack */}
            <div className="flex flex-col items-center shrink-0 mr-1">
              <div
                className="w-12 h-12 rounded-full flex items-center justify-center"
                style={{
                  background: 'linear-gradient(180deg, #2a2a2a 0%, #1a1a1a 100%)',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.05)',
                  border: '2px solid rgba(255,255,255,0.06)',
                }}
              >
                <div
                  className="w-4 h-4 rounded-full"
                  style={{
                    background: 'radial-gradient(circle, #00E5FF 0%, #00E5FF80 60%, transparent 100%)',
                    boxShadow: '0 0 8px #00E5FF60',
                  }}
                />
              </div>
              <span className="text-[8px] text-gray-600 mt-1.5 uppercase tracking-[0.15em] font-bold">
                Input
              </span>
            </div>

            {/* Cable from input */}
            <CableSVG color="#00E5FF" animated={audioLive} />

            {/* Pedals with cables */}
            {chain.length === 0 ? (
              <button
                onClick={() => setDrawerOpen(true)}
                className="flex items-center justify-center w-[140px] h-[220px] rounded-xl shrink-0 mx-2 transition-all hover:border-[#00E5FF]/30 group"
                style={{
                  border: '2px dashed rgba(255,255,255,0.08)',
                  background: 'rgba(255,255,255,0.01)',
                }}
              >
                <div className="flex flex-col items-center gap-2">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center transition-all group-hover:scale-110"
                    style={{
                      background: 'rgba(0,229,255,0.08)',
                      border: '1px solid rgba(0,229,255,0.15)',
                    }}
                  >
                    <span className="text-xl text-[#00E5FF]/60 group-hover:text-[#00E5FF]">+</span>
                  </div>
                  <span className="text-[9px] uppercase tracking-wider text-gray-600 group-hover:text-gray-400">
                    Add Pedal
                  </span>
                </div>
              </button>
            ) : (
              <SortableContext items={sortableIds} strategy={horizontalListSortingStrategy}>
                {chain.map((inst, idx) => {
                  const def = PEDAL_MAP.get(inst.definitionId)!;
                  return (
                    <div key={inst.uid} className="flex items-center">
                      <SortablePedalCard
                        instance={inst}
                        definition={def}
                        onToggleBypass={() => toggleBypass(inst.uid)}
                        onParamChange={(pi, v) => updateParam(inst.uid, pi, v)}
                        onRemove={() => removePedal(inst.uid)}
                      />
                      {idx < chain.length - 1 && (
                        <CableSVG
                          color={inst.bypassed ? '#333' : def.color}
                          animated={audioLive && !inst.bypassed}
                        />
                      )}
                    </div>
                  );
                })}
              </SortableContext>
            )}

            {/* Cable to output */}
            <CableSVG color="#00E5FF" animated={audioLive} />

            {/* Output jack */}
            <div className="flex flex-col items-center shrink-0 ml-1">
              <div
                className="w-12 h-12 rounded-full flex items-center justify-center"
                style={{
                  background: 'linear-gradient(180deg, #2a2a2a 0%, #1a1a1a 100%)',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.05)',
                  border: '2px solid rgba(255,255,255,0.06)',
                }}
              >
                <svg width="18" height="18" viewBox="0 0 18 18">
                  <polygon
                    points="5,3 14,9 5,15"
                    fill="#00E5FF"
                    opacity="0.8"
                  />
                </svg>
              </div>
              <span className="text-[8px] text-gray-600 mt-1.5 uppercase tracking-[0.15em] font-bold">
                Output
              </span>
            </div>

            {/* Add pedal button at end of chain */}
            {chain.length > 0 && (
              <button
                onClick={() => setDrawerOpen(true)}
                className="ml-4 w-10 h-10 rounded-full flex items-center justify-center shrink-0 transition-all hover:scale-110"
                style={{
                  background: 'rgba(0,229,255,0.06)',
                  border: '1px dashed rgba(0,229,255,0.2)',
                }}
              >
                <span className="text-lg text-[#00E5FF]/50 hover:text-[#00E5FF]">+</span>
              </button>
            )}
          </div>

          {/* Drag overlay */}
          <DragOverlay>
            {activeDragInstance ? (
              <StaticPedalCard
                instance={activeDragInstance}
                definition={PEDAL_MAP.get(activeDragInstance.definitionId)!}
              />
            ) : null}
          </DragOverlay>
        </DndContext>
      </div>

      {/* ── Scene Info Bar ── */}
      <div
        className="flex items-center justify-between px-4 py-2.5 border-t border-white/[0.06]"
        style={{ background: 'rgba(255,255,255,0.02)' }}
      >
        <span className="text-[10px] text-gray-500 font-mono">
          Scene {activeScene} &middot; {chain.length} pedal
          {chain.length !== 1 ? 's' : ''} &middot;{' '}
          {chain.filter((p) => !p.bypassed).length} active
        </span>
        <div className="flex gap-3">
          <button
            onClick={() => {
              const src = cloneChain(chain);
              const target = sceneIds.find(
                (s) => s !== activeScene && scenes[s].chain.length === 0
              );
              if (target) {
                setScenes((prev) => ({
                  ...prev,
                  [target]: { chain: src },
                }));
              }
            }}
            className="text-[9px] text-gray-500 hover:text-[#00E5FF] transition-colors uppercase tracking-wider font-bold"
          >
            Copy Scene
          </button>
          <button
            onClick={() => setChain([])}
            className="text-[9px] text-gray-500 hover:text-[#FF3B30] transition-colors uppercase tracking-wider font-bold"
          >
            Clear
          </button>
        </div>
      </div>

      {/* ── Pedal Library Drawer ── */}
      <PedalLibraryDrawer
        open={drawerOpen}
        onAdd={addPedal}
        onClose={() => setDrawerOpen(false)}
      />
    </div>
  );
}
