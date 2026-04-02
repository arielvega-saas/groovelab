import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io' show Platform;

// ═══════════════════════════════════════════════════════════════════════
//  PLAYBACK TAB — Multitrack Live Console via WebView / iframe
//  Loads the professional playback-multitrack UI from assets/playback/
// ═══════════════════════════════════════════════════════════════════════

class PlaybackTab extends ConsumerStatefulWidget {
  const PlaybackTab({super.key});

  @override
  ConsumerState<PlaybackTab> createState() => _PlaybackTabState();
}

class _PlaybackTabState extends ConsumerState<PlaybackTab> {
  InAppWebViewController? _webViewController;
  InAppLocalhostServer? _localhostServer;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _startLocalServer();
    }
  }

  @override
  void dispose() {
    _localhostServer?.close();
    _webViewController = null;
    super.dispose();
  }

  Future<void> _startLocalServer() async {
    _localhostServer = InAppLocalhostServer(port: 8766);
    try {
      await _localhostServer!.start();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('PlaybackTab: failed to start local server: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to start local asset server: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildErrorFallback();
    if (kIsWeb) return _buildWebPlatform();
    return _buildNativePlatform();
  }

  /// Web platform: use the registered HtmlElementView (iframe).
  Widget _buildWebPlatform() {
    const viewType = 'playback-webview';
    return const HtmlElementView(viewType: viewType);
  }

  /// Native platform: use InAppWebView with localhost server.
  Widget _buildNativePlatform() {
    if (_localhostServer == null || !_localhostServer!.isRunning()) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    const url = 'http://localhost:8766/assets/playback/playback.html';

    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(url)),
          initialSettings: _buildSettings(),
          onWebViewCreated: (controller) {
            _webViewController = controller;
          },
          onLoadStop: (controller, url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onReceivedError: (controller, request, error) {
            debugPrint('PlaybackTab: error (${error.type}): ${error.description}');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
                _errorMessage = 'Failed to load playback (${error.type}): ${error.description}';
              });
            }
          },
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint('PlaybackTab [JS]: ${consoleMessage.message}');
          },
        ),
        if (_isLoading)
          const Center(child: CircularProgressIndicator.adaptive()),
      ],
    );
  }

  InAppWebViewSettings _buildSettings() {
    final settings = InAppWebViewSettings(
      javaScriptEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      allowFileAccessFromFileURLs: true,
      allowUniversalAccessFromFileURLs: true,
      useShouldOverrideUrlLoading: false,
      transparentBackground: true,
    );

    if (!kIsWeb) {
      if (Platform.isAndroid) {
        settings.useHybridComposition = true;
        settings.domStorageEnabled = true;
        settings.mixedContentMode = MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW;
      }
      if (Platform.isIOS) {
        settings.allowsBackForwardNavigationGestures = false;
        settings.applePayAPIEnabled = false;
      }
    }

    return settings;
  }

  Widget _buildErrorFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48,
              color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('PlayBack unavailable',
              style: Theme.of(context).textTheme.titleMedium),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                )),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _isLoading = true;
    });
    if (!kIsWeb) {
      _localhostServer?.close();
      _startLocalServer();
    }
  }
}
