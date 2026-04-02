# LiveStage — Especificacion

## Que es LiveStage
Consola profesional de multitrack live para musicos. Reemplaza las secciones anteriores "PlayBack" y "Secuencias" en una sola.

## Archivo HTML
- **Ubicacion**: `assets/livestage/livestage.html`
- **Origen**: `livestage_v9.html` (2695 lineas, autocontenido)
- **Carga via**: InAppWebView en puerto `8767`

## Widget Flutter
- **Archivo**: `lib/features/livestage/livestage_tab.dart`
- **Clase**: `LiveStageTab` (ConsumerStatefulWidget)
- **Index en IndexedStack**: 12
- **Paywall**: Si (feature: 'LiveStage')

## Archivos relacionados
```
lib/features/livestage/
  livestage_tab.dart            # Widget principal con InAppWebView
  livestage_stub_register.dart  # No-op para nativo
  livestage_web_register.dart   # Registro iframe para Flutter Web
```

## Funcionalidades del HTML

### Transport Bar (52px)
- Info de cancion (titulo)
- LCD time display (MM:SS formato)
- BPM display con LED pulsante
- Time signature
- Botones: rewind, play/pause (cambia a stop cuando reproduce), forward
- Mode buttons (Vivo/Studio)

### Section Markers Bar (36px)
- Chips horizontales scrolleables con secciones de la cancion
- Intro, Verso, Pre-Coro, Coro, Puente, Outro, etc.
- Chip activo resaltado con accent color

### Mixer (area principal)
- Channel strips verticales (96px ancho cada uno)
- Cada canal tiene:
  - Nombre del canal
  - VU meter (6px ancho, 12 segmentos LED)
  - Fader vertical (320px alto) con thumb neumorfico
  - Botones Solo (S) y Mute (M)
  - Indicador de nivel en dB
  - Color por tipo de instrumento
- Master fader fijo a la derecha
- Colores por canal: click(orange), drums(cyan), bass(blue), guitar(red), keys(amber), vocals(orange), synth(purple), pad(violet), guide(cyan), loop(pink), coro(green), master(white)

### Panel lateral derecho (44px)
- Botones de acceso rapido verticales

## Comunicacion Flutter <-> HTML

### HTML -> Flutter
```javascript
window.GrooveLabChannel.postMessage(JSON.stringify({
  type: 'eventName',
  data: { ... }
}));
```

### Flutter -> HTML
```javascript
window.handleFlutterMessage({ type: 'action', data: { ... } });
```

### Tipos de eventos planeados
- `ready` — HTML cargado y listo
- `songChange` — cambio de cancion activa
- `transportAction` — play/pause/stop/seek
- `mixerChange` — cambio de fader/mute/solo
- `sectionChange` — navegacion a seccion
- `modeChange` — cambio entre Vivo/Studio
- `error` — error en el HTML

## Trabajo pendiente
- Conectar bridge JS con providers Riverpod
- Cargar setlist real desde Firestore
- Audio engine para reproduccion de stems
- MIDI mapping para control externo
- Persistencia de configuracion de mixer
