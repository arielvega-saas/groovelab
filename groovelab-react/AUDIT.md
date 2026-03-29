# AUDIT.md — GrooveLab React Audit

## Stack Tecnologico
- **React 19.2.4** + **TypeScript**
- **Vite** (build + dev server)
- **Tailwind CSS 3.4.19** (custom theme)
- **Zustand 5.0.12** (state management, persisted)
- **Tone.js 15.1.22** (audio engine)
- **React Three Fiber + Drei** (3D: Drums, Piano)
- **@dnd-kit** (drag-reorder: Pedalboard)
- **Lucide React** (icons)
- **clsx + tailwind-merge** (class utilities)
- **idb** (IndexedDB storage)

## Arbol de Componentes
```
App.tsx
└── AppShell.tsx (layout)
    ├── Sidebar.tsx (72px, 8 nav items)
    ├── TopBar.tsx (title + BPM + masterVolume)
    └── main → Lazy-loaded modules:
        ├── features/metronome/Metronome.tsx
        ├── features/drums/Drums.tsx
        ├── features/sampler-pads/SamplerPads.tsx
        ├── features/looper/Looper.tsx
        ├── features/tuner/Tuner.tsx
        ├── features/pedalboard/Pedalboard.tsx
        ├── features/song-lab/SongLab.tsx
        └── features/piano/Piano.tsx
```

## Estado Global (Zustand — stores/app-store.ts)
- `activeTool`: ToolId (8 tools)
- `bpm`: 20-500, default 120
- `isPlaying`: transport state
- `timeSig`: [4, 4]
- `masterVolume`: 0-1, default 0.8
- `sidebarOpen`, `audioInitialized`
- Persisted: bpm, timeSig, masterVolume, activeTool

## Audio Engine (stores/audio-engine.ts)
- Singleton: init() creates AudioContext (48kHz, 5ms lookahead)
- Master chain: masterGain → 3-band EQ → limiter → destination
- Parallel reverb send bus
- 15+ effects via createEffectChain()
- WAV export, latency measurement, mic input

## Modulos — Estado Actual
| Modulo | Path | Estado | Audio |
|--------|------|--------|-------|
| Metronome | features/metronome/ | ✅ Completo | Tone.Synth + Transport Loop |
| Drums | features/drums/ | ✅ Completo + 3D | Tone.Synth x5 + Transport |
| Pads | features/sampler-pads/ | ✅ Completo | Tone.PolySynth, 3 modes |
| Looper | features/looper/ | ✅ Completo | Tone.Recorder + Players |
| Tuner | features/tuner/ | ✅ Completo | Autocorrelation pitch detect |
| Pedalboard | features/pedalboard/ | ✅ Completo | 20+ FX, drag-reorder, scenes |
| Song Lab | features/song-lab/ | ⚠️ Parcial | Player + stems (simulado) |
| Piano | features/piano/ | ✅ Completo + 3D | 5 instruments, 61 keys |

## Design System Actual
- Background: #0A0A0A (gl-deepest)
- Accent: #00E5FF (cyan)
- Fonts: Outfit (display), JetBrains Mono (mono)
- Shadows: neumorphism (.neu-raised, .neu-inset)
- Glows: .glow-accent, .glow-green, .glow-warm
- Dark mode: enabled by default

## Reproductor Song Lab
- Tone.Player for master playback
- Tone.PitchShift (±12 semitones)
- Per-stem: Player + EQ3 + Panner + Volume
- A-B loop markers
- Waveform via canvas
- Stem separation SIMULATED (no real processing)

## Lo que FALTA (segun prompt)
1. Design system upgrade (BIAS FX 2 level visuals)
2. Modulo Multitracks (completo, nuevo)
3. Shared audio player (Song Lab ↔ Multitracks)
4. Visual upgrades en todos los modulos
5. AppHeader premium
