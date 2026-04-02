// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

/// Registers the platform view factory for the pedalera iframe on Flutter Web.
void registerPedaleraWebView() {
  debugPrint('registerPedaleraWebView: registering...');
  ui_web.platformViewRegistry.registerViewFactory(
    'pedalera-webview',
    (int viewId, {Object? params}) {
      debugPrint('pedalera-webview factory creating iframe');
      final iframe = web.HTMLIFrameElement()
        ..src = 'assets/assets/pedalera/pedalboard.html'
        ..style.setProperty('border', 'none')
        ..style.setProperty('width', '100%')
        ..style.setProperty('height', '100%')
        ..allow = 'microphone; autoplay';
      return iframe;
    },
  );
  debugPrint('registerPedaleraWebView: done');
}

/// Shows a full-screen iframe overlay with the pedalboard on web.
void showPedaleraOverlay() {
  // Remove existing if any
  hidePedaleraOverlay();

  final overlay = web.HTMLDivElement()
    ..id = 'pedalera-overlay'
    ..style.setProperty('position', 'fixed')
    ..style.setProperty('top', '0')
    ..style.setProperty('left', '80px') // leave space for sidebar
    ..style.setProperty('right', '0')
    ..style.setProperty('bottom', '0')
    ..style.setProperty('z-index', '9999')
    ..style.setProperty('background', '#0a0b0e');

  final iframe = web.HTMLIFrameElement()
    ..id = 'pedalera-iframe'
    ..src = 'assets/assets/pedalera/pedalboard.html'
    ..style.setProperty('border', 'none')
    ..style.setProperty('width', '100%')
    ..style.setProperty('height', '100%')
    ..allow = 'microphone; autoplay';

  overlay.appendChild(iframe);
  web.document.body!.appendChild(overlay);
  debugPrint('showPedaleraOverlay: iframe overlay injected');
}

/// Hides the pedalera overlay.
void hidePedaleraOverlay() {
  final existing = web.document.getElementById('pedalera-overlay');
  if (existing != null) {
    existing.remove();
    debugPrint('hidePedaleraOverlay: removed');
  }
}
