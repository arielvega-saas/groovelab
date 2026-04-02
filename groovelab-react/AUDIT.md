# AUDIT.md — GrooveLab React v4.0

## Stack
- React 19.2.4 + TypeScript ~5.6.2 + Vite 5.4.10
- Tailwind CSS 3.4.19 (darkMode: 'class')
- Zustand 5.0.12 (app-store + multitrack-store)
- Tone.js 15.1.22 (audio-engine singleton)
- Motion 12.38.0, React Three Fiber 9.5.0, @dnd-kit, Lucide React
- cn() exists at src/lib/cn.ts + src/lib/utils.ts

## Stores
- **app-store**: activeTool, sidebarOpen, masterVolume, bpm, isPlaying, timeSig, audioInitialized (persisted)
- **multitrack-store**: currentTime, duration, pistaBase, pistasMultitrack, cancionActiva, repertorio
- **audio-engine**: Tone.js singleton. Gain > EQ3 > Reverb > Limiter > Destination

## Navigation
- No React Router active. app-store.activeTool dispatches lazy-loaded components via AppShell.

## Design System (already implemented)
- Studio palette, accent #04C5F7, LED/metal/pedal colors
- Fonts: Audiowide, Orbitron, Inter, JetBrains Mono
- Shadows: knob, pedal, led-*, metal-*, glow-accent
- CSS: .numeric, .hw-label, .no-select, .neu-*, .glow-*

## UI Components (already exist)
- LED, LEDBar, Knob, RotaryKnob, Fader, VUMeter, HardwarePanel
- AppShell, Sidebar, TopBar, AppHeader
- MetronomeDisplay, LooperTrackCard, TunerDisplay

## Module Status
| Module | Status | Audio |
|--------|--------|-------|
| Metronome | 100% | Tone.js Synth+Loop |
| Drums | 100% | Tone.js Synth+3D |
| Looper | 100% | WebAudio+Tone.js |
| Tuner | 100% | Mic FFT |
| Piano | 100% | Tone.js PolySynth+3D |
| Pedalboard | 100% | Tone.js effects |
| Sampler Pads | 100% | Tone.js Synth |
| Song Lab | ~40% | Placeholder stem |
| Multitracks | ~30% | UI only |

## Gaps
1. Multitracks: UI only, needs audio playback
2. Song Lab: No real stem separation
3. No useSharedPlayer connecting SongLab <-> Multitracks
