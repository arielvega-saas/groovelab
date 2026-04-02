import 'dart:js_interop';
import 'dart:ui_web' as ui;
import 'package:web/web.dart' as web;

/// Registers the 'livestage-webview' platform view for Flutter Web.
void registerLiveStageWebView() {
  ui.platformViewRegistry.registerViewFactory(
    'livestage-webview',
    (int viewId, {Object? params}) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.src = 'assets/assets/livestage/livestage.html';
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.allow = 'microphone; autoplay';
      return iframe;
    },
  );
}
