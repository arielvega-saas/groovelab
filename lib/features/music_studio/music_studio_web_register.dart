import 'dart:js_interop';
import 'dart:ui_web' as ui;
import 'package:web/web.dart' as web;

/// Registers the 'music-studio-webview' platform view for Flutter Web.
void registerMusicStudioWebView() {
  ui.platformViewRegistry.registerViewFactory(
    'music-studio-webview',
    (int viewId, {Object? params}) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.src = 'assets/assets/music_studio/music_studio.html';
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.allow = 'microphone; autoplay';
      return iframe;
    },
  );
}
