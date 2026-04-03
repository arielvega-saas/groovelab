# Music Studio — Especificacion

## Que es Music Studio
Herramienta de IA para separacion de stems, deteccion de acordes, transcripcion de letras y reproduccion multitrack. Inspirada en Moises.ai pero con UI/UX personalizada para GrooveLab.

## Arquitectura

```
┌─────────────────┐     HTTP/WS      ┌──────────────────────┐
│  Flutter App     │ ◄──────────────► │  FastAPI Backend     │
│  (InAppWebView)  │                  │  (localhost:8000)    │
│  Port 8768       │                  │                      │
│                  │                  │  - Demucs htdemucs_6s│
│  music_studio    │                  │  - Whisper           │
│  .html           │                  │  - librosa           │
│                  │                  │  - yt-dlp            │
└─────────────────┘                  └──────────────────────┘
```

- **Frontend**: HTML autocontenido en `assets/music_studio/music_studio.html` (2895 lineas)
- **Backend**: FastAPI en `server/music_studio/` (Python)
- **Flutter wrapper**: `lib/features/music_studio/music_studio_tab.dart` (port 8768)

## Backend (FastAPI)

### Ubicacion: `server/music_studio/`

### Archivos
```
server/music_studio/
  main.py                    # FastAPI app (~420 lineas)
  models.py                  # Pydantic models
  requirements.txt           # Dependencias Python
  Dockerfile                 # Container con ffmpeg, rubberband, yt-dlp
  services/
    separator.py             # Demucs htdemucs_6s (6 stems)
    analyzer.py              # BPM, acordes, secciones, pitch, tempo
    transcriber.py           # Whisper transcripcion
    downloader.py            # yt-dlp descarga
```

### Endpoints
```
GET  /health                 # Estado del servidor
POST /api/upload             # Subir archivo audio (multipart)
POST /api/youtube            # Descargar de YouTube via yt-dlp
POST /api/separate           # Separar en 6 stems (Demucs)
POST /api/chords             # Detectar acordes (librosa)
POST /api/lyrics             # Transcribir letras (Whisper)
POST /api/bpm                # Detectar BPM + secciones
POST /api/pitch              # Cambiar tonalidad (pyrubberband)
POST /api/tempo              # Cambiar tempo (pyrubberband)
GET  /api/projects           # Listar proyectos
GET  /api/projects/{id}      # Detalle de proyecto
GET  /api/stems/{id}/{stem}  # Servir archivo WAV (streaming)
GET  /api/export/{id}        # Exportar ZIP con todos los stems
WS   /ws/progress            # Progreso en tiempo real
```

### Stems (6)
```
vocals   — Voz principal + coros
drums    — Bateria
bass     — Bajo
guitar   — Guitarra
piano    — Piano/teclado
other    — Otros instrumentos
```

### Calidad de separacion
- **fast**: 1 shift (rapido, menor calidad)
- **high**: 5 shifts (lento, maxima calidad)

### Como ejecutar
```bash
cd server/music_studio
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

O con Docker:
```bash
docker build -t groovelab-music-studio .
docker run -p 8000:8000 -v ./projects:/data/projects groovelab-music-studio
```

## Frontend HTML

### Ubicacion: `assets/music_studio/music_studio.html`

### Layout
```
+--------------------------------------------------+
|  TOOLBAR: Upload + YouTube URL + Process btn      |
+--------+-----------------------------------------+
|        |  WAVEFORM PANEL (60%)                   |
|  STEM  |  - Master waveform con playhead          |
| MIXER  |  - 6 lanes de stems sincronizados        |
| (200px)|  - Transport: play/pause/stop/seek/loop  |
|        +-----------------------------------------+
|        |  ANALYSIS PANEL (40%, tabs)             |
|        |  [Acordes] [Letras] [Estructura]        |
+--------+-----------------------------------------+
|  STATUS BAR: BPM | Key | Duracion | Estado       |
+--------------------------------------------------+
```

### Clases JS principales
```
StudioApp          — Controlador principal
APIClient          — Comunicacion HTTP con backend
WebSocketClient    — Progreso via WebSocket
WaveformManager    — WaveSurfer.js multitrack sincronizado
MixerController    — Web Audio API (gain, pan, solo/mute)
TransportController — Play/pause/stop/seek/loop
ChordView          — Grid de acordes (Easy/Medium/Advanced)
LyricsView         — Letras karaoke word-by-word
SectionsView       — Marcadores de secciones
PitchTempoController — Modal pitch/tempo
Metronome          — Click track sincronizado
ProjectBrowser     — Drawer con historial de proyectos
ExportController   — Modal de exportacion
```

### Keyboard Shortcuts
```
Space        Play/Pause
Left/Right   Seek ±5s
Shift+arrows Seek ±10s
L            Loop region
M            Metronomo toggle
?            Mostrar shortcuts
Esc          Cerrar modales
```

### CDN Dependencies
- WaveSurfer.js v7 (waveform rendering)

## Flutter Wrapper

### Archivos
```
lib/features/music_studio/
  music_studio_tab.dart            # Widget InAppWebView (port 8768)
  music_studio_providers.dart      # 6 Riverpod providers
  music_studio_stub_register.dart  # No-op nativo
  music_studio_web_register.dart   # Registro iframe web
```

### Providers
```dart
musicStudioBackendUrlProvider   // String — URL del backend (default http://localhost:8000)
musicStudioProjectIdProvider    // String? — proyecto activo
musicStudioProcessingProvider   // bool — procesando
musicStudioStemsReadyProvider   // bool — stems listos
musicStudioChordsReadyProvider  // bool — acordes listos
musicStudioLyricsReadyProvider  // bool — letras listas
```

### Puerto: 8768

### Navegacion: Index 13 en IndexedStack

## Trabajo pendiente
- Deploy del backend a produccion (Railway/Render/HuggingFace)
- Persistencia de proyectos en Firestore (actualmente solo local)
- Importar stems a LiveStage para reproduccion en vivo
- Cache de modelos Demucs/Whisper para carga rapida
- GPU acceleration para separacion mas rapida
- Exportacion a formatos adicionales (FLAC, AIFF)
