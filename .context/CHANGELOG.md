# GrooveLab — Changelog

## 2026-04-02 — Music Studio (Moises.ai-like AI features)

### Nuevas features
- **Music Studio completo** — seccion nueva con separacion IA, deteccion de acordes, transcripcion de letras, reproductor multitrack DAW-like
- Index 13 en IndexedStack, icono `auto_fix_high_rounded`

### Backend (FastAPI) — `server/music_studio/`
- **Demucs htdemucs_6s** — separacion en 6 stems (vocals, drums, bass, guitar, piano, other)
- **Whisper** — transcripcion de letras con timestamps word-level
- **librosa** — deteccion de BPM, acordes, secciones, pitch shift, tempo change
- **yt-dlp** — descarga de audio desde YouTube/URLs
- 14 endpoints REST + WebSocket para progreso en tiempo real
- Dockerfile incluido para deployment

### Frontend HTML — `assets/music_studio/music_studio.html`
- 2895 lineas, autocontenido (CSS + JS inline)
- WaveSurfer.js v7 para waveforms multitrack sincronizados
- Mixer con Web Audio API (volume, pan, solo/mute por stem)
- Vista de acordes (3 niveles de dificultad)
- Letras karaoke word-by-word
- Secciones de cancion detectadas automaticamente
- Controles de pitch (-12/+12 semitonos) y tempo (50-200%)
- Metronomo inteligente sincronizado
- Exportacion de stems (individual o ZIP completo)
- Historial de proyectos
- Keyboard shortcuts completos

### Flutter Integration — `lib/features/music_studio/`
- MusicStudioTab con InAppWebView (port 8768)
- 6 Riverpod providers para estado
- Registros web/stub para Flutter Web

### Archivos nuevos
```
server/music_studio/main.py
server/music_studio/models.py
server/music_studio/requirements.txt
server/music_studio/Dockerfile
server/music_studio/services/separator.py
server/music_studio/services/analyzer.py
server/music_studio/services/transcriber.py
server/music_studio/services/downloader.py
assets/music_studio/music_studio.html
lib/features/music_studio/music_studio_tab.dart
lib/features/music_studio/music_studio_providers.dart
lib/features/music_studio/music_studio_stub_register.dart
lib/features/music_studio/music_studio_web_register.dart
.context/MUSIC_STUDIO.md
```

### Archivos modificados
```
lib/app.dart          # Agregar Music Studio (index 13, sidebar, bottom nav)
pubspec.yaml          # Agregar assets/music_studio/
.context/ARCHITECTURE.md
.context/README.md
.context/CHANGELOG.md
```

---

## 2026-04-02 — Integracion LiveStage + Limpieza

### Nuevas features
- **LiveStage integrado**: Nuevo modulo multitrack live (`livestage_v9.html`) cargado via InAppWebView en puerto 8767
- **Carpeta .context/**: Documentacion completa para continuidad entre IAs

### Cambios en navegacion
- **Eliminada seccion "Secuencias"** (index 12 viejo) — era redundante con PlayBack
- **Eliminada seccion "PlayBack"** (index 13 viejo) — reemplazada por LiveStage
- **LiveStage ocupa index 12** con icono `play_circle_rounded`
- IndexedStack reducido de 14 a 13 items

### Archivos nuevos
```
assets/livestage/livestage.html                     # HTML autocontenido de LiveStage
assets/pedalera/pedalboard.html                     # Copiado desde backup (faltaba)
assets/pedalera/worklets/                           # Copiado desde backup (faltaba)
lib/features/livestage/livestage_tab.dart           # Widget Flutter para LiveStage
lib/features/livestage/livestage_stub_register.dart # Stub nativo
lib/features/livestage/livestage_web_register.dart  # Registro web
.context/                                           # Carpeta de documentacion
```

### Archivos modificados
```
lib/app.dart          # Navegacion: quitar Secuencias/PlayBack, agregar LiveStage
pubspec.yaml          # Nuevos assets: livestage/, pedalera/
macos/Podfile         # Deployment target 13.0 en post_install
```

### Bugs arreglados
- **Overflow 0.5px** en `multitrack_tab.dart:123` — Column con `mainAxisSize: MainAxisSize.min` + font 11px
- **Pedalera en blanco en macOS** — Faltaba carpeta `assets/pedalera/` con el HTML y worklets
- **PlayBack "Disponible en version web"** — Reemplazado por LiveStage con InAppWebView
- **GoogleService-Info.plist faltante** — Copiado desde backup para macOS e iOS
- **flutter_inappwebview build error** — Parcheado `@available(macOS 10.15, *)` innecesario en WebAuthenticationSession.swift

### Archivos deprecados (no eliminar aun)
```
lib/features/multitrack/multitrack_tab.dart   # Prototipo viejo de Multitracks
lib/features/playback/playback_tab.dart       # PlayBack viejo (reemplazado por LiveStage)
assets/playback/playback.html                 # HTML viejo de PlayBack
```

---

## 2026-03-25 — Setup inicial React + Flutter

- App React con Multitracks, Playback, Drums, Metronome
- App Flutter con todas las features nativas
- Pedalera HTML funcional
- Firebase + RevenueCat configurados
