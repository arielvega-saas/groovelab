# GROOVELAB — AUDITORÍA COMPLETA (FASE 0)
**Fecha**: 2026-03-24
**Estado**: Proyecto Flutter/Dart maduro — NO es React

---

## HALLAZGO CRÍTICO

El prompt de especificación asume **React + JavaScript + Firebase + Web Audio API**.
El proyecto real es **Flutter 3.x + Dart + Riverpod + Platform Channels + Web Audio JS interop**.

### Stack Actual Real:
| Capa | Tecnología |
|------|-----------|
| Framework | Flutter 3.x (SDK >=3.2.0 <4.0.0) |
| Lenguaje | Dart |
| Estado | Riverpod 2.4.9 |
| Audio nativo iOS | AVAudioEngine + mach_absolute_time (<5ms latencia) |
| Audio nativo Android | Oboe/AAudio (<10ms latencia) |
| Audio web | Web Audio API via JS interop (web_audio_engine.js — 114KB) |
| Persistencia | SharedPreferences (offline-first) |
| IAP | RevenueCat (purchases_flutter 8.10.0) |
| Hosting | Firebase Hosting (arieldev-docs.web.app) |
| Backend stems | Python server (Hugging Face Space) |
| Diseño | Neumorphic dark theme (#0A0A0A base) |

---

## MÓDULOS EXISTENTES — ESTADO DE CADA UNO

### 1. METRÓNOMO (metronome_tab.dart — 1,412 líneas)
**Estado: PROFESIONAL**
- Knob circular draggable (20-500 BPM)
- Tap tempo (6 toques, media móvil filtrada)
- Tempo trainer (auto-incremento BPM por compás)
- 8 time signatures (2/4 a 12/8)
- Subdivisiones
- 12 sonidos de click
- Acentos personalizables por beat (volumen 0-1.0)
- Swing / human feel
- Flash visual por beat con animación
- **Audio**: Lookahead scheduling via native bridge (NO setTimeout)
- **Veredicto**: Ya está a nivel Soundbrenner. No necesita reescritura.

### 2. DRUMS (drums_tab.dart — 954 líneas)
**Estado: PROFESIONAL**
- 13 estilos de drum patterns
- Secuenciador de 16 pasos
- Mixer por instrumento (kick, snare, hi-hat, ride)
- Patrones custom editables
- Adaptación automática a time signature
- **Veredicto**: Profesional, sin equivalente directo en el prompt.

### 3. LOOPER (loop_station_tab.dart — 1,804 líneas)
**Estado: PROFESIONAL**
- Multi-layer recording
- 10 estados de transporte (state machine)
- Guide track (metrónomo o drums)
- Control por capa: mute/solo/pan/volumen/rename/delete
- Waveform por capa
- Count-in
- Export (mix completo, capas individuales, stems)
- Input level metering
- **Cuantización**: Sí existe
- **Veredicto**: Ya supera lo especificado en el prompt. Nivel Loopy Pro.

### 4. TUNER (tuner_tab.dart)
**Estado: PROFESIONAL**
- 10 presets de afinación (guitarra, bajo 4/5/6, ukulele, violín, saxo, trompeta, piano)
- Detección de pitch en tiempo real
- Display de cents
- Selector de cuerda/nota
- Indicador visual
- Display de frecuencia
- **Método de detección**: Via web_audio_engine.js (método no confirmado — podría ser YIN o autocorrelación)
- **Veredicto**: Funcional y profesional. Migrar a pitchy solo si hay problemas de precisión.

### 5. SONG LAB (song_lab_tab.dart)
**Estado: PROFESIONAL**
- Multi-track stems
- Control individual: volumen/pan/mute/solo
- Speed y pitch shift
- Loop region A-B
- Waveform visualization
- Chord detection
- Click track
- Export mixdown
- Stem separation UI (mock — backend en Hugging Face)
- **Speed/Pitch**: Método no confirmado en web_audio_engine.js
- **Veredicto**: Feature-complete. Verificar calidad de time-stretching.

### 6. PADS (pads_tab.dart)
**Estado: PROFESIONAL**
- 11 categorías de sonido (worship, ambient, cinematic, etc.)
- 8 pads factory (escala Do mayor)
- 13 assets MP3 de pads ambientales
- Modos de transición: instant, smooth, worship, cinematic, manual
- **Veredicto**: No mencionado en el prompt. Feature adicional valiosa.

### 7. RECORDING (recording_tab.dart — 451 líneas)
**Estado: PROFESIONAL**
- Grabación contra metrónomo
- Detección de onsets en tiempo real
- Desviación en ms (early/late)
- Histograma de distribución
- Lista de takes con scores de consistencia
- Best take highlighting
- **Veredicto**: Feature única de entrenamiento. No mencionada en el prompt.

### 8. PRACTICE (practice_tab.dart)
**Estado: PROFESIONAL**
- Speed trainer
- Rutinas multi-paso con avance automático
- Interval training (click/silencio alternados)
- Random silence (probabilístico)
- Timer de sesión
- Tracking de progreso
- **Veredicto**: Feature única de entrenamiento. No mencionada en el prompt.

### 9. STATS (stats_tab.dart)
**Estado: FUNCIONAL**
- Tracking de tiempo de práctica
- Conteo de sesiones
- **Veredicto**: Funcional, puede mejorarse con gráficos.

### 10. SETTINGS (settings_tab.dart)
**Estado: FUNCIONAL**
- Configuración de idioma
- Preferencias de audio
- **Veredicto**: Estándar.

---

## ARQUITECTURA DE AUDIO

### Capa de Abstracción (audio_service.dart)
- AudioService maneja NativeAudioBridge y WebAudioBridge
- Fallback automático a web en plataformas no soportadas
- Streams: beatEvents, onsetEvents, recordingEvents, midiEvents, loopPosition, inputLevel

### Síntesis de Sonidos (sound_generator.dart)
- Generación WAV 44.1kHz 16-bit PCM
- Clicks multi-capa (sine burst + transient + body resonance)
- Drums sintetizados (kick, snare, hi-hat, ride)
- Presets pro (wood block, sine burst, clave HQ)
- **Calidad**: Nivel Logic Pro / Soundbrenner

### Web Audio Engine (web/web_audio_engine.js — 114KB)
- Implementación completa de Web Audio API
- Metrónomo, drums, looper, tuner, song lab, pads
- MIDI device enumeration
- Export WAV/MP3
- Stem separation (mock)
- **NOTA**: Archivo monolítico de 114KB — candidato a modularización

### Headers COOP/COEP
- **YA CONFIGURADOS** en firebase.json
- Cross-Origin-Opener-Policy: same-origin
- Cross-Origin-Embedder-Policy: credentialless
- SharedArrayBuffer habilitado para Web Workers

---

## FIREBASE

### Configuración
- Proyecto: `arieldev-docs`
- Hosting: `build/web` (Flutter web build)
- Rewrites: SPA (todo a index.html)
- Cache: JS con max-age=31536000
- **Cloud Functions**: No configuradas
- **Firestore**: No configurado en el código Dart (usa SharedPreferences)
- **Auth**: No integrado actualmente

### Observación
El prompt pide "PRESERVAR Firebase Auth, Firestore, Functions" pero el proyecto
actual NO usa ninguno de estos servicios. Solo usa Firebase Hosting.

---

## MONETIZACIÓN

### RevenueCat
- **Configurado**: purchases_flutter 8.10.0
- Google Play key: configurado
- Apple key: PLACEHOLDER (esperando Developer Program)
- Entitlement: "GrooveLab Pro"
- Fallback web: todo desbloqueado
- **Estado**: Listo para producción en Android, pendiente Apple

---

## ASSETS

```
assets/
├── icons/icon.png
├── images/instruments/ (10 SVGs de presets de afinación)
└── (web/pads/ — 13 MP3s de pads ambientales)
```

---

## DECISIÓN REQUERIDA

### El proyecto actual es PROFESIONAL y COMPLETO en Flutter.
Tiene más features que las especificadas en el prompt React:

| Feature | Prompt React | Flutter Actual |
|---------|-------------|----------------|
| Metrónomo | Especificado | IMPLEMENTADO (profesional) |
| Tuner | Especificado | IMPLEMENTADO (profesional) |
| Looper | Especificado | IMPLEMENTADO (profesional) |
| Song Lab | Especificado | IMPLEMENTADO (profesional) |
| Pedalera | Especificado | NO EXISTE |
| Drums | No mencionado | IMPLEMENTADO (profesional) |
| Recording/Timing | No mencionado | IMPLEMENTADO (profesional) |
| Practice Modes | No mencionado | IMPLEMENTADO (profesional) |
| Pads | No mencionado | IMPLEMENTADO (profesional) |
| Stats | No mencionado | IMPLEMENTADO (funcional) |

### Opciones:
1. **Mejorar el Flutter existente** + agregar Pedalera como módulo Flutter
2. **Reescribir todo en React** (perdiendo ~45 archivos Dart + native bridges)
3. **Híbrido**: mantener Flutter para mobile, crear versión React para web

### Recomendación: Opción 1
Reescribir en React significaría perder:
- Audio nativo iOS (<5ms latencia) — React web no puede competir
- Audio nativo Android (Oboe, <10ms)
- 45+ archivos de código profesional probado
- Arquitectura Riverpod madura
- Meses de desarrollo

Lo que falta agregar al Flutter:
- Módulo Pedalera (nuevo)
- Firebase Auth + Firestore (para sync cross-device)
- Cloud Functions para stem separation (reemplazar Hugging Face mock)
- Cloudflare R2 para storage de audio
