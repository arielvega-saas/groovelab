// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

/// Registers the platform view factory for the playback iframe on Flutter Web.
void registerPlaybackWebView() {
  debugPrint('registerPlaybackWebView: registering...');
  ui_web.platformViewRegistry.registerViewFactory(
    'playback-webview',
    (int viewId, {Object? params}) {
      debugPrint('playback-webview factory creating iframe');
      final iframe = web.HTMLIFrameElement()
        ..src = 'assets/assets/playback/playback.html'
        ..style.setProperty('border', 'none')
        ..style.setProperty('width', '100%')
        ..style.setProperty('height', '100%')
        ..allow = 'microphone; autoplay; fullscreen'
        ..setAttribute('allowfullscreen', 'true');
      return iframe;
    },
  );
  debugPrint('registerPlaybackWebView: done');
}
