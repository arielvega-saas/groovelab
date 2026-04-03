# GrooveLab — Contexto para IAs

Esta carpeta contiene toda la documentacion necesaria para que cualquier IA pueda continuar el desarrollo de GrooveLab sin desviarse del proyecto.

## Archivos de contexto

| Archivo | Contenido |
|---------|-----------|
| `ARCHITECTURE.md` | Arquitectura general, stack, navegacion, providers |
| `LIVESTAGE.md` | Especificacion completa de la seccion LiveStage (ex-PlayBack) |
| `MUSIC_STUDIO.md` | Especificacion completa de Music Studio (IA, stems, acordes, lyrics) |
| `DESIGN_SYSTEM.md` | Colores, tipografia, tokens, efectos visuales |
| `INTEGRATION_GUIDE.md` | Como integrar un HTML en la app Flutter via InAppWebView |
| `CHANGELOG.md` | Historial de cambios realizados hasta la fecha |

## Reglas para IAs

1. **La app final es Flutter nativa** (macOS/iOS). NO es la version React ni Flutter Web.
2. **LiveStage reemplaza PlayBack y Secuencias** — son la misma funcionalidad unificada.
3. **Los modulos HTML se cargan via InAppWebView** con localhost server — NO usar iframes en nativo.
4. **Respetar el design system** definido en `DESIGN_SYSTEM.md` y `lib/core/theme.dart`.
5. **State management con Riverpod** — no usar setState local para features nuevas.
6. **No crear archivos ni features que ya existen** — revisar esta carpeta antes de empezar.
