# Guia de Integracion — Modulos HTML en Flutter

## Como funciona

Los modulos complejos de UI (LiveStage, Pedalera) se implementan como archivos HTML autocontenidos que se cargan dentro de Flutter usando `flutter_inappwebview`.

## Estructura de archivos para un modulo HTML

```
assets/
  [nombre_modulo]/
    [nombre_modulo].html       # HTML autocontenido (CSS + JS inline)

lib/features/[nombre_modulo]/
    [nombre]_tab.dart           # Widget Flutter con InAppWebView
    [nombre]_stub_register.dart # No-op para plataformas nativas
    [nombre]_web_register.dart  # Registro iframe para Flutter Web
```

## Puertos asignados

| Modulo        | Puerto | Estado     |
|---------------|--------|------------|
| Pedalera      | 8765   | Activo     |
| PlayBack      | 8766   | Deprecado  |
| LiveStage     | 8767   | Activo     |
| Music Studio  | 8768   | Activo     |

**Importante**: Cada modulo usa un puerto diferente para evitar conflictos.

## Widget Flutter template

```dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io' show Platform;

class MiModuloTab extends ConsumerStatefulWidget {
  const MiModuloTab({super.key});
  @override
  ConsumerState<MiModuloTab> createState() => _MiModuloTabState();
}

class _MiModuloTabState extends ConsumerState<MiModuloTab> {
  InAppWebViewController? _webViewController;
  InAppLocalhostServer? _localhostServer;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _startLocalServer();
  }

  @override
  void dispose() {
    _localhostServer?.close();
    _webViewController = null;
    super.dispose();
  }

  Future<void> _startLocalServer() async {
    _localhostServer = InAppLocalhostServer(port: XXXX); // Puerto unico
    try {
      await _localhostServer!.start();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _errorWidget();
    if (kIsWeb) return const HtmlElementView(viewType: 'mi-modulo-webview');
    return _buildNative();
  }

  Widget _buildNative() {
    if (_localhostServer == null || !_localhostServer!.isRunning()) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('http://localhost:XXXX/assets/mi_modulo/mi_modulo.html'),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        transparentBackground: true,
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
        // Registrar bridge JS
        controller.addJavaScriptHandler(
          handlerName: 'GrooveLabChannel',
          callback: (args) { /* manejar mensajes del HTML */ },
        );
      },
      onLoadStop: (controller, url) async {
        // Inyectar bridge
        await controller.evaluateJavascript(source: \'\'\'
          window.GrooveLabChannel = {
            postMessage: function(str) {
              try {
                var data = (typeof str === 'string') ? JSON.parse(str) : str;
                window.flutter_inappwebview.callHandler('GrooveLabChannel', data);
              } catch(e) {
                window.flutter_inappwebview.callHandler('GrooveLabChannel', str);
              }
            }
          };
        \'\'\');
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }
}
```

## Registro en app.dart

### 1. Agregar import
```dart
import 'features/mi_modulo/mi_modulo_tab.dart';
import 'features/mi_modulo/mi_modulo_stub_register.dart'
    if (dart.library.js_interop) 'features/mi_modulo/mi_modulo_web_register.dart';
```

### 2. Agregar al IndexedStack
```dart
PaywallGate(feature: 'Mi Modulo', child: const MiModuloTab()), // index N
```

### 3. Agregar al sidebar
```dart
(N, Icons.mi_icono, 'Mi Modulo'),
```

### 4. Agregar al pubspec.yaml
```yaml
assets:
  - assets/mi_modulo/
```

## Bridge de comunicacion

### HTML -> Flutter
```javascript
// En el HTML, enviar evento a Flutter:
window.GrooveLabChannel.postMessage(JSON.stringify({
  type: 'miEvento',
  data: { key: 'value' }
}));
```

### Flutter -> HTML
```dart
// En Flutter, enviar mensaje al HTML:
await _webViewController!.evaluateJavascript(
  source: 'if(window.handleFlutterMessage) window.handleFlutterMessage(${jsonEncode(message)});',
);
```

## Modulos existentes como referencia

- **Pedalera** (funcional): `lib/features/pedalera/pedalera_webview.dart` (458 lineas)
- **LiveStage** (en desarrollo): `lib/features/livestage/livestage_tab.dart`
