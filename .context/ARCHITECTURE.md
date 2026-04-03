# GrooveLab — Arquitectura

## Stack
- **Flutter** (Dart) — app nativa macOS/iOS (version final)
- **Riverpod** — state management
- **flutter_inappwebview** — carga modulos HTML en nativo
- **Firebase** — auth, firestore, storage
- **RevenueCat** — IAP/suscripciones
- Audio custom via native bridges + Web Audio API

## Estructura de directorios

```
lib/
  app.dart                    # Shell principal, navegacion, IndexedStack
  main.dart                   # Entry point
  core/
    theme.dart                # AppColors, AppSpacing, AppRadius, etc.
    app_fonts.dart            # AppFonts (Outfit, JetBrains Mono, Space Mono)
    constants.dart            # Constantes globales
    responsive.dart           # Breakpoints responsive
    audio/
      audio_service.dart      # Motor de audio principal (577 lineas)
      native_audio_bridge.dart # Platform channels iOS/Android/macOS
      web_audio_bridge.dart   # Web Audio API
      sound_generator.dart    # Sintesis procedural
  features/
    home/                     # Pantalla principal
    metronome/                # Metronomo de precision
    drums/                    # Kit de bateria
    pads/                     # Pads de sonido
    loop_station/             # Loop station
    tuner/                    # Afinador
    pedalera/                 # Pedalera de efectos (HTML via WebView)
    song_lab/                 # Creador de canciones
    library/                  # Biblioteca de canciones
    recording/                # Grabacion de audio
    practice/                 # Modos de practica
    stats/                    # Estadisticas de sesion
    settings/                 # Configuracion
    timing_analysis/          # Analisis de timing
    livestage/                # LiveStage — consola multitrack live (HTML via WebView)
    music_studio/             # Music Studio — separacion IA, acordes, lyrics, multitrack DAW (HTML via WebView + FastAPI backend)
    multitrack/               # [DEPRECADO] Prototipo viejo de multitracks
    playback/                 # [DEPRECADO] Reemplazado por LiveStage
    shared/                   # Widgets compartidos (PaywallGate, etc.)
  providers/
    app_providers.dart        # Providers globales Riverpod
  services/
    persistence_service.dart
    data_loading_service.dart
    audio_management_service.dart
  l10n/
    translations.dart         # Traducciones ES/EN
  models/
    take.dart                 # Modelo de grabacion
assets/
  livestage/livestage.html    # UI HTML de LiveStage (autocontenido)
  pedalera/pedalboard.html    # UI HTML de Pedalera
  playback/playback.html      # [DEPRECADO] HTML viejo de PlayBack
  icons/                      # Iconos de la app
  images/instruments/         # Imagenes de instrumentos
  fonts/                      # Outfit, JetBrains Mono, Space Mono
```

## Navegacion (IndexedStack)

```
Index  Widget                  Seccion          Estado
-----  ----------------------  ---------------  --------
0      MetronomeTab            Metronomo        OK
1      DrumsTab                Bateria          OK
2      RecordingTab            Grabacion        OK (paywall)
3      LoopStationTab          Loop Station     OK (paywall)
4      PadsTab                 Pads             OK (paywall)
5      PracticeTab             Practica         OK
6      LibraryTab              Biblioteca       OK
7      StatsTab                Estadisticas     OK
8      TunerTab                Afinador         OK
9      HomeTab                 Home (default)   OK
10     SongLabTab              Song Lab         OK (paywall)
11     PedaleraWebView         Pedalera         OK (paywall)
12     LiveStageTab            LiveStage        EN DESARROLLO (paywall)
13     MusicStudioTab          Music Studio     EN DESARROLLO (paywall)
```

**Eliminados:**
- Index 12 anterior (MultitrackTab / Secuencias) — fusionado en LiveStage
- Index 13 anterior (PlaybackTab) — reemplazado por LiveStage

## Sidebar (NavigationRail)

```dart
(9,  Icons.home_rounded,          'Home')
(0,  Icons.speed_rounded,         'Metronomo')
(1,  Icons.view_week_rounded,     'Drums')
(4,  Icons.piano_rounded,         'Pads')
(3,  Icons.autorenew_rounded,     'Loop')
(8,  Icons.graphic_eq_rounded,    'Tuner')
(11, Icons.cable_rounded,         'Pedalera')
(10, Icons.library_music_rounded, 'Song Lab')
(12, Icons.play_circle_rounded,      'LiveStage')
(13, Icons.auto_fix_high_rounded,    'Music Studio')
(6,  Icons.library_books_rounded,    'Library')
```

## Providers Riverpod principales

```dart
// Navegacion
tabIndexProvider              // StateProvider<int> — tab activo (default: 9)
langProvider                  // StateProvider<String> — idioma (default: 'es')

// Stage / Setlists
stageModeProvider             // StateProvider<bool>
setlistsProvider              // StateProvider<List<Map<String, dynamic>>>
activeSetlistProvider         // StateProvider<Map<String, dynamic>?>
activeSetlistSongIndexProvider // StateProvider<int>
setlistAutoAdvanceProvider    // StateProvider<bool>

// Audio
audioServiceProvider          // Provider<AudioService>
audioManagementProvider       // Provider<AudioManagementService>

// MIDI
midiEnabledProvider           // StateProvider<bool>
midiDevicesProvider           // StateProvider<List<Map<String, String>>>

// IAP
revenueCatProvider            // StateNotifierProvider<RevenueCatNotifier, RevenueCatState>
isProProvider                 // Provider<bool> (actualmente true)
```

## Audio Engine

Archivo: `lib/core/audio/audio_service.dart` (577 lineas)

Capacidades:
- Metronomo: start/stop, BPM, time signature, subdivision, swing, click sounds
- Bateria: patterns, volumes por instrumento
- Loop Station: grabacion multicapa, mute/solo/pan por capa
- Pads: load/play/stop, volume/pan/pitch
- Song Lab: carga de tracks, play/seek/volume
- Pedalera: init, pedal chain, parametros, bypass
- MIDI: init, devices, note on/off, clock
- Grabacion: start/stop, onset detection
- Streams: beatEvents, onsetEvents, recordingEvents, songLabPosition, loopPosition
