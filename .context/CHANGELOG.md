# GrooveLab — Changelog

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
